import AppKit
import IOKit.ps

func description(_ current: Int, _ maximum: Int = 100) -> [String: Any] {
    [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true,
     kIOPSCurrentCapacityKey: current, kIOPSMaxCapacityKey: maximum,
     kIOPSIsChargingKey: true, kIOPSPowerSourceStateKey: kIOPSACPowerValue]
}
assert(Battery(description: [:]) == nil)
assert(Battery(description: description(1, 0)) == nil)
assert(Battery(description: description(-1)) == nil)
assert(Battery(description: description(150))?.percent == 100)
assert(Battery(description: description(1, 3))?.percent == 33)
assert(Battery(description: description(0))?.percent == 0)
assert(Battery(description: description(75))?.summary == "75% — Charging")
var external = description(85)
external[kIOPSTypeKey] = "UPS"
assert(Battery(description: external) == nil)
var paused = description(80)
paused[kIOPSIsChargingKey] = false
assert(Battery(description: paused)?.summary == "80% — Not Charging")

let values: [Int?] = [0, 9, 85, 100, nil]
let preview = NSImage(size: NSSize(width: 300, height: 140))
preview.lockFocus()
NSColor.darkGray.setFill()
NSRect(x: 0, y: 0, width: 300, height: 140).fill()
for (index, value) in values.enumerated() {
    for mode in 0...2 {
        let charging = mode == 1
        let icon = batteryIcon(percent: value, charging: charging, pluggedIn: mode == 2)
        assert(icon.isTemplate && icon.size.width <= 50)
        guard let tiff = icon.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { fatalError("Icon failed to render") }
        assert(bitmap.pixelsWide > 0)
        icon.draw(at: NSPoint(x: 10 + index * 58, y: 100 - mode * 40), from: .zero, operation: .sourceOver, fraction: 1)
    }
}
preview.unlockFocus()
if CommandLine.arguments.count > 1, let tiff = preview.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
print("Battery parsing and rendering checks passed. Live battery: \(Battery.read()?.summary ?? "unavailable")")

var full = paused
full[kIOPSCurrentCapacityKey] = 100
assert(Battery(description: full)?.status == "Not Charging")
full[kIOPSIsChargedKey] = true
assert(Battery(description: full)?.status == "Fully Charged")
full[kIOPSIsChargingKey] = true
full[kIOPSIsFinishingChargeKey] = true
assert(Battery(description: full)?.status == "Finishing Charge")
var unplugged = description(15)
unplugged[kIOPSIsChargingKey] = false
unplugged[kIOPSPowerSourceStateKey] = kIOPSBatteryPowerValue
assert(Battery(description: unplugged)?.status == "Low Battery")
let hold = SmartCharge.State(optimizedChargingEngaged: true, chargeLimitEnabled: false, chargeLimit: 100, overrideAllowed: true)
let limit = SmartCharge.State(optimizedChargingEngaged: false, chargeLimitEnabled: true, chargeLimit: 80, overrideAllowed: true)
assert(Battery(description: paused)!.detailLines(smart: hold).contains("Charging On Hold"))
assert(Battery(description: paused)!.detailLines(smart: limit).contains("Charged to 80% Limit"))
assert(!Battery(description: unplugged)!.canChargeToFull(hold))
assert(Battery(description: paused)!.canChargeToFull(hold))
assert(!Battery(description: paused)!.canChargeToFull(nil))

final class FakeChargeClient: NSObject, SmartChargeClientProtocol {
    var engaged = true
    var allowed = true
    var enabled: UInt = 0
    var limit: UInt8 = 80
    var fails = false
    var reject = false
    var calls: [String] = []
    override init() { super.init() }
    required init(clientName: String) { super.init() }
    func isOBCEngaged(_ engaged: UnsafeMutablePointer<ObjCBool>, chargeLimit: UnsafeMutablePointer<UInt>, chargingOverrideAllowed: UnsafeMutablePointer<ObjCBool>, withError: NSErrorPointer) -> Bool {
        engaged.pointee = ObjCBool(self.engaged)
        chargeLimit.pointee = UInt(limit)
        chargingOverrideAllowed.pointee = ObjCBool(allowed)
        return !fails
    }
    func isMCLCurrentlyEnabled(_ error: NSErrorPointer) -> UInt { enabled }
    func getMCLLimit(_ error: NSErrorPointer) -> UInt8 { limit }
    func temporarilyEnableCharging(_ error: NSErrorPointer) -> Bool { calls.append("optimized"); return !reject }
    func temporarilyDisableMCL(_ error: NSErrorPointer) -> Bool { calls.append("limit"); return !reject }
}
let fake = FakeChargeClient()
let service = SmartCharge(client: fake)
try service.chargeToFullNow()
assert(fake.calls == ["optimized"])
fake.enabled = 1
try service.chargeToFullNow()
assert(fake.calls == ["optimized", "limit"])
fake.allowed = false
assert((try? service.chargeToFullNow()) == nil)
assert(fake.calls.count == 2)
fake.allowed = true
fake.reject = true
assert((try? service.chargeToFullNow()) == nil)
fake.fails = true
assert(service.state() == nil)
fake.fails = false
fake.enabled = 2
assert(service.state() == nil)
fake.enabled = 1
fake.limit = 0
assert(service.state() == nil)
assert(SmartCharge(client: nil).state() == nil)
print("Charging states, override routing, rejection and availability checks passed.")
print("Live smart-charge availability: \(SmartCharge.shared.isAvailable); state: \(String(describing: SmartCharge.shared.state()))")
