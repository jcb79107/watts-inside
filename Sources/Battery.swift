import AppKit
import IOKit.ps

struct Battery {
    let percent: Int
    let charging: Bool
    let pluggedIn: Bool

    init?(description: [String: Any]) {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              description[kIOPSIsPresentKey] as? Bool == true,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let maximum = description[kIOPSMaxCapacityKey] as? Int,
              maximum > 0, current >= 0 else { return nil }
        percent = Int((min(Double(current) / Double(maximum), 1) * 100).rounded())
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

    var summary: String {
        "\(percent)% — " + (charging ? "Charging" : pluggedIn ? "Power adapter" : "On battery")
    }
}

@MainActor
func batteryIcon(percent: Int?, charging: Bool) -> NSImage {
    let text = percent.map(String.init) ?? "?"
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .heavy)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
    let textSize = (text as NSString).size(withAttributes: attributes)
    let bodyWidth = max(25, ceil(textSize.width) + 8 + (charging ? 9 : 0))
    let image = NSImage(size: NSSize(width: bodyWidth + 4, height: 18), flipped: false) { _ in
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 1, width: bodyWidth, height: 16), xRadius: 4, yRadius: 4).fill()
        NSBezierPath(roundedRect: NSRect(x: bodyWidth + 1, y: 6, width: 2, height: 6), xRadius: 1, yRadius: 1).fill()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        let textX = charging ? 4 : (bodyWidth - textSize.width) / 2
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
        }
        return true
    }
    image.isTemplate = true
    return image
}

