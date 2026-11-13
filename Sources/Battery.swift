import AppKit
import IOKit.ps

struct Battery {
    let percent: Int
    let charging: Bool
    let pluggedIn: Bool
    let charged: Bool
    let finishing: Bool
    let minutesToFull: Int?
    let health: String?

    init?(description: [String: Any]) {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              description[kIOPSIsPresentKey] as? Bool == true,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let maximum = description[kIOPSMaxCapacityKey] as? Int,
              maximum > 0, current >= 0,
              let powerSource = description[kIOPSPowerSourceStateKey] as? String,
              [kIOPSACPowerValue, kIOPSBatteryPowerValue].contains(powerSource) else { return nil }
        percent = Int((min(Double(current) / Double(maximum), 1) * 100).rounded())
        charged = description[kIOPSIsChargedKey] as? Bool ?? false
        finishing = description[kIOPSIsFinishingChargeKey] as? Bool ?? false
        minutesToFull = description[kIOPSTimeToFullChargeKey] as? Int
        health = description[kIOPSBatteryHealthKey] as? String
        charging = description[kIOPSIsChargingKey] as? Bool ?? false
        pluggedIn = powerSource == kIOPSACPowerValue
    }

    static func read() -> Battery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
               let battery = Battery(description: description) { return battery }
        }
        return nil
    }

    var status: String {
        if charging { return finishing ? "Finishing Charge" : "Charging" }
        if pluggedIn { return charged && percent == 100 ? "Fully Charged" : "Not Charging" }
        return percent <= 20 ? "Low Battery" : "On Battery"
    }

    var summary: String { "\(percent)% — \(status)" }

    @MainActor
    func detailLines(smart: SmartCharge.State?, slowCharger: Bool = false) -> [String] {
        var lines = ["Power Source: " + (pluggedIn ? "Power Adapter" : "Battery")]
        if pluggedIn, let smart, smart.overrideActive {
            lines.append("Charging to Full")
        } else if pluggedIn, !charging, let smart, smart.chargeLimitEnabled, smart.chargeLimit < 100 {
            if abs(percent - smart.chargeLimit) <= 2 {
                lines.append("Charged to \(smart.chargeLimit)% Limit")
            } else {
                lines.append("Charge Limit: \(smart.chargeLimit)%")
            }
        } else if pluggedIn, !charging, let smart, smart.optimizedChargingEngaged {
            lines.append("Charging On Hold")
        } else {
            lines.append(status)
        }
        if pluggedIn, slowCharger { lines.append("Slow Charger") }
        if charging, !finishing, let minutes = minutesToFull, minutes > 0 {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .short
            if let time = formatter.string(from: TimeInterval(minutes) * 60) {
                lines.append("About \(time) Until Full")
            }
        }

        if health == kIOPSPoorValue { lines.append("Battery Health: Service Recommended") }
        if health == kIOPSFairValue { lines.append("Battery Health: Reduced Capacity") }
        return lines
    }

    @MainActor
    func canChargeToFull(_ smart: SmartCharge.State?) -> Bool {
        guard pluggedIn, let smart else { return false }
        return smart.canHold && smart.overrideAllowed && !smart.overrideActive
    }

}

@MainActor
func batteryIcon(percent: Int?, charging: Bool) -> NSImage {
    let text = percent.map(String.init) ?? "?"
    let base = NSFont.systemFont(ofSize: 10, weight: .bold)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 10) } ?? base
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
    let textSize = (text as NSString).size(withAttributes: attributes)
    let bodyWidth = max(22, ceil(textSize.width) + 6 + (charging ? 7 : 0))
    let image = NSImage(size: NSSize(width: bodyWidth + 5, height: 18), flipped: false) { _ in
        let opticalOffset = NSAffineTransform()
        opticalOffset.translateX(by: 2, yBy: 0)
        opticalOffset.concat()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 3.5, width: bodyWidth, height: 11), xRadius: 3, yRadius: 3).fill()
        let terminal = NSBezierPath()
        terminal.move(to: NSPoint(x: bodyWidth + 1, y: 6.5))
        terminal.line(to: NSPoint(x: bodyWidth + 1, y: 11.5))
        terminal.curve(to: NSPoint(x: bodyWidth + 1, y: 6.5), controlPoint1: NSPoint(x: bodyWidth + 3.5, y: 11.5), controlPoint2: NSPoint(x: bodyWidth + 3.5, y: 6.5))
        terminal.fill()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        let textX = charging ? 3 : (bodyWidth - textSize.width) / 2
        (text as NSString).draw(at: NSPoint(x: textX, y: (18 - textSize.height) / 2), withAttributes: attributes)
        if charging {
            let x = bodyWidth - 7
            let bolt = NSBezierPath()
            bolt.move(to: NSPoint(x: x + 5.5, y: 13.5))
            bolt.line(to: NSPoint(x: x, y: 8))
            bolt.line(to: NSPoint(x: x + 3, y: 8))
            bolt.line(to: NSPoint(x: x + 1, y: 4.5))
            bolt.line(to: NSPoint(x: x + 6, y: 10))
            bolt.line(to: NSPoint(x: x + 4, y: 10))
            bolt.close()
            bolt.fill()
        }
        return true
    }
    image.isTemplate = true
    return image
}

// Control Center reads this same state; missing/unknown states never imply a slow charger.
func readSlowCharger(notificationName: String = "com.apple.PerfPowerServices.slowChargerUpdatedNotification") -> Bool {
    var token: Int32 = 0
    guard notify_register_check(notificationName, &token) == NOTIFY_STATUS_OK else { return false }
    defer { notify_cancel(token) }
    var state: UInt64 = 0
    return notify_get_state(token, &state) == NOTIFY_STATUS_OK && state == 1
}
