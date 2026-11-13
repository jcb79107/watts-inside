// Adapted from Lithe, Copyright (c) 2026 Aaron Meurer, MIT. See THIRD_PARTY_NOTICES.md.
import Foundation

/// Access to the system's smart-charging controls: whether Optimized Battery
/// Charging or a charge limit is holding the charge, and the "Charge to Full
/// Now" override that Apple's own battery menu offers.
///
/// There is no public API for this. Control Center uses the private PowerUI
/// framework's `PowerUISmartChargeClient`, and so does this wrapper, loaded
/// at runtime and guarded at every step: if the framework, the class, or a
/// method is missing on some macOS version, the feature simply disappears.
@MainActor
final class SmartCharge {
    static let shared = SmartCharge()

    /// What the system reports about charge holding.
    struct State: Equatable, Sendable {
        /// Optimized Battery Charging is currently holding the charge.
        var optimizedChargingEngaged: Bool
        /// The charge limit setting (for example 80%) is turned on.
        var chargeLimitEnabled: Bool
        /// The limit in percent when `chargeLimitEnabled`, otherwise 100.
        var chargeLimit: Int
        /// Whether the system allows a "charge to full" override right now.
        var overrideAllowed: Bool
        var overrideActive: Bool = false

        /// Whether either mechanism is configured to hold the charge. Whether
        /// it is holding right now also depends on being plugged in; see the
        /// power snapshot for that.
        var canHold: Bool { optimizedChargingEngaged || (chargeLimitEnabled && chargeLimit < 100) }
    }

    enum Failure: LocalizedError {
        case unavailable
        case rejected(NSError?)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Smart charging controls are not available on this Mac."
            case .rejected(let error):
                return error?.localizedDescription ?? "The system declined the request."
            }
        }
    }

    private let defaults: UserDefaults
    var savedLimit: Int? {
        let value = defaults.integer(forKey: "chargeOverrideLimit")
        return (80...100).contains(value) ? value : nil
    }
    var restorationPending: Bool { defaults.bool(forKey: "chargeOverrideRestoring") }

    private let client: (any SmartChargeClientProtocol)?

    /// Loads the private client, or `nil` if it cannot be used.
    static func loadClient() -> (any SmartChargeClientProtocol)? {
        guard dlopen("/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI", RTLD_NOW) != nil,
              let cls = NSClassFromString("PowerUISmartChargeClient") as? NSObject.Type else { return nil }
        let required: [Selector] = [
            #selector(SmartChargeClientProtocol.isOBCEngaged(_:chargeLimit:chargingOverrideAllowed:withError:)),
            #selector(SmartChargeClientProtocol.isMCLCurrentlyEnabled(_:)),
            #selector(SmartChargeClientProtocol.getMCLLimit(_:)),
            #selector(SmartChargeClientProtocol.temporarilyEnableCharging(_:)),
            #selector(SmartChargeClientProtocol.temporarilyDisableMCL(_:)),
            #selector(SmartChargeClientProtocol.enableMCL(_:)),
            #selector(SmartChargeClientProtocol.setMCLLimit(_:error:)),
        ]
        let initializer = NSSelectorFromString("initWithClientName:")
        guard cls.instancesRespond(to: initializer),
              required.allSatisfy({ cls.instancesRespond(to: $0) }) else { return nil }
        // alloc/init through the runtime: `init` consumes alloc's reference
        // and returns an owned one.
        guard let allocated = cls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
              let instance = allocated.perform(initializer, with: "WattsInside")?.takeRetainedValue() else { return nil }
        return unsafeBitCast(instance, to: (any SmartChargeClientProtocol).self)
    }

    init(client: (any SmartChargeClientProtocol)? = SmartCharge.loadClient(), defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
    }

    var isAvailable: Bool { client != nil }

    /// Queries the system. Returns `nil` when the controls are unavailable or
    /// the query fails.
    func state() -> State? {
        guard let client else { return nil }
        var engaged = ObjCBool(false)
        var limit: UInt = 100
        var override = ObjCBool(false)
        var error: NSError?
        guard client.isOBCEngaged(&engaged, chargeLimit: &limit, chargingOverrideAllowed: &override, withError: &error) else {
            NSLog("WattsInside: smart charge query failed: \(error?.localizedDescription ?? "unknown error")")
            return nil
        }
        error = nil
        let rawEnabled = client.isMCLCurrentlyEnabled(&error)
        guard [0, 1, 3].contains(rawEnabled) else { return nil }
        let mclEnabled = rawEnabled == 1
        if let error {
            NSLog("WattsInside: charge limit state query failed: \(error.localizedDescription)")
            return nil
        }
        let mclLimit = Int(client.getMCLLimit(&error))
        if let error {
            NSLog("WattsInside: charge limit query failed: \(error.localizedDescription)")
            return nil
        }
        guard !mclEnabled || (80...100).contains(mclLimit) else { return nil }
        return State(
            optimizedChargingEngaged: engaged.boolValue,
            chargeLimitEnabled: mclEnabled,
            chargeLimit: mclEnabled ? mclLimit : 100,
            overrideAllowed: override.boolValue,
            overrideActive: rawEnabled == 3
        )
    }

    private func forgetOverride() {
        defaults.removeObject(forKey: "chargeOverrideLimit")
        defaults.removeObject(forKey: "chargeOverrideRestoring")
        defaults.synchronize()
    }

    func chargeToFullNow() throws {
        guard let client, let current = state(), current.canHold, current.overrideAllowed,
              !current.overrideActive, savedLimit == nil else { throw Failure.unavailable }
        if current.chargeLimitEnabled {
            // Persist before changing hardware policy so quitting/crashing cannot lose the original limit.
            defaults.set(current.chargeLimit, forKey: "chargeOverrideLimit")
            guard defaults.synchronize() else { throw Failure.rejected(nil) }
        }
        var error: NSError?
        let ok = current.chargeLimitEnabled ? client.temporarilyDisableMCL(&error) : client.temporarilyEnableCharging(&error)
        guard ok else {
            if let after = state(), !after.overrideActive, after.chargeLimit == savedLimit { forgetOverride() }
            throw Failure.rejected(error)
        }
        NSLog("WattsInside: charging override accepted; saved limit: %@", savedLimit.map(String.init) ?? "optimized charging")
    }

    func restoreLimit() throws {
        guard let client, let target = savedLimit, let before = state() else { throw Failure.unavailable }
        defaults.set(true, forKey: "chargeOverrideRestoring")
        guard defaults.synchronize() else { throw Failure.rejected(nil) }
        var error: NSError?
        if before.overrideActive {
            guard client.enableMCL(&error) else { throw Failure.rejected(error) }
        }
        guard let resumed = state(), !resumed.overrideActive else { throw Failure.rejected(nil) }
        if resumed.chargeLimit != target {
            // enableMCL restored 80 instead of the saved 95 on macOS 26.5.2; correct once, then verify.
            guard client.setMCLLimit(UInt8(target), error: &error) else { throw Failure.rejected(error) }
        }
        guard let verified = state(), !verified.overrideActive, verified.chargeLimit == target else {
            throw Failure.rejected(nil)
        }
        NSLog("WattsInside: verified restoration to %d%%", target)
        forgetOverride()
    }

    func restoreIfFinished(battery: Battery?) throws {
        guard let target = savedLimit else { return }
        guard let current = state() else { throw Failure.unavailable }
        if !current.overrideActive && current.chargeLimit == target {
            forgetOverride()
        } else if restorationPending {
            try restoreLimit()
        } else if let battery, !battery.pluggedIn || (battery.percent == 100 && battery.charged && !battery.charging) {
            try restoreLimit()
        }
    }

}

/// The subset of `PowerUISmartChargeClient` that Control Center's battery
/// menu uses, declared so it can be called through the Objective-C runtime.
@objc protocol SmartChargeClientProtocol {
    @objc(enableMCL:) func enableMCL(_ error: NSErrorPointer) -> Bool
    @objc(setMCLLimit:error:) func setMCLLimit(_ limit: UInt8, error: NSErrorPointer) -> Bool
    init(clientName: String)
    @objc(isOBCEngaged:chargeLimit:chargingOverrideAllowed:withError:)
    func isOBCEngaged(_ engaged: UnsafeMutablePointer<ObjCBool>, chargeLimit: UnsafeMutablePointer<UInt>,
                      chargingOverrideAllowed: UnsafeMutablePointer<ObjCBool>, withError: NSErrorPointer) -> Bool
    @objc(isMCLCurrentlyEnabled:)
    func isMCLCurrentlyEnabled(_ error: NSErrorPointer) -> UInt
    @objc(getMCLLimitWithError:)
    func getMCLLimit(_ error: NSErrorPointer) -> UInt8
    @objc(temporarilyEnableCharging:)
    func temporarilyEnableCharging(_ error: NSErrorPointer) -> Bool
    @objc(temporarilyDisableMCL:)
    func temporarilyDisableMCL(_ error: NSErrorPointer) -> Bool
}
