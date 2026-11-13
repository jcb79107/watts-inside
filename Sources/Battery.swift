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
              maximum > 0, current >= 0 else { return nil }
        percent = Int((min(Double(current) / Double(maximum), 1) * 100).rounded())
        charged = description[kIOPSIsChargedKey] as? Bool ?? false
        finishing = description[kIOPSIsFinishingChargeKey] as? Bool ?? false
        minutesToFull = description[kIOPSTimeToFullChargeKey] as? Int
        health = description[kIOPSBatteryHealthKey] as? String
        charging = description[kIOPSIsChargingKey] as? Bool ?? false
        pluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
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
    func detailLines(smart: SmartCharge.State?) -> [String] {
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
func batteryIcon(percent: Int?, charging: Bool, pluggedIn: Bool = false) -> NSImage {
    let text = percent.map(String.init) ?? "?"
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .heavy)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
    let textSize = (text as NSString).size(withAttributes: attributes)
    let bodyWidth = max(25, ceil(textSize.width) + 8 + ((charging || pluggedIn) ? 9 : 0))
    let image = NSImage(size: NSSize(width: bodyWidth + 4, height: 18), flipped: false) { _ in
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 1, width: bodyWidth, height: 16), xRadius: 4, yRadius: 4).fill()
        NSBezierPath(roundedRect: NSRect(x: bodyWidth + 1, y: 6, width: 2, height: 6), xRadius: 1, yRadius: 1).fill()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        let textX = (charging || pluggedIn) ? 4 : (bodyWidth - textSize.width) / 2
        (text as NSString).draw(at: NSPoint(x: textX, y: (18 - textSize.height) / 2), withAttributes: attributes)
        if charging {
            let x = bodyWidth - 10
            let bolt = NSBezierPath()
            bolt.move(to: NSPoint(x: x + 7, y: 15))
            bolt.line(to: NSPoint(x: x, y: 8))
            bolt.line(to: NSPoint(x: x + 4, y: 8))
            bolt.line(to: NSPoint(x: x + 2, y: 3))
            bolt.line(to: NSPoint(x: x + 9, y: 10))
            bolt.line(to: NSPoint(x: x + 5, y: 10))
            bolt.close()
            bolt.fill()
        } else if pluggedIn {
            let x = bodyWidth - 10
            NSBezierPath(roundedRect: NSRect(x: x + 1, y: 6, width: 7, height: 5), xRadius: 2, yRadius: 2).fill()
            NSRect(x: x + 2, y: 10, width: 1.5, height: 4).fill()
            NSRect(x: x + 5.5, y: 10, width: 1.5, height: 4).fill()
            NSRect(x: x + 3.5, y: 3, width: 2, height: 4).fill()
        }
        return true
    }
    image.isTemplate = true
    return image
}

