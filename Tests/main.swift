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
assert(Battery(description: paused)?.summary == "80% — Power adapter")

let values: [Int?] = [0, 9, 85, 100, nil]
let preview = NSImage(size: NSSize(width: 300, height: 100))
preview.lockFocus()
NSColor.darkGray.setFill()
NSRect(x: 0, y: 0, width: 300, height: 100).fill()
for (index, value) in values.enumerated() {
    for charging in [false, true] {
        let icon = batteryIcon(percent: value, charging: charging)
        assert(icon.isTemplate && icon.size.width <= 50)
        guard let tiff = icon.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { fatalError("Icon failed to render") }
        assert(bitmap.pixelsWide > 0)
        icon.draw(at: NSPoint(x: 10 + index * 58, y: charging ? 20 : 60), from: .zero, operation: .sourceOver, fraction: 1)
    }
}
preview.unlockFocus()
if CommandLine.arguments.count > 1, let tiff = preview.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
print("Battery parsing and rendering checks passed. Live battery: \(Battery.read()?.summary ?? "unavailable")")
