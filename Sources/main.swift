import AppKit
import IOKit.ps

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem?
    private var source: CFRunLoopSource?
    private let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.addItem(status)
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Battery Settings…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Watt’s Inside", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item?.menu = menu
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            // The source is installed on the main run loop, so this callback is main-actor isolated.
            MainActor.assumeIsolated {
                Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        refresh()
        if source == nil { status.title = "Battery updates unavailable — reopen the app" }
    }

    @objc func refresh() {
        let battery = Battery.read()
        let summary = battery?.summary ?? "Battery unavailable"
        status.title = summary
        item?.button?.image = batteryIcon(percent: battery?.percent, charging: battery?.charging ?? false)
        item?.button?.toolTip = "Watt’s Inside: \(summary)"
        item?.button?.setAccessibilityLabel("Battery: \(summary)")
    }

    @objc private func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") else { return }
        NSWorkspace.shared.open(url)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let source { CFRunLoopSourceInvalidate(source) }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
