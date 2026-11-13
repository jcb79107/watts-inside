import AppKit
import IOKit.ps

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSStatusItem?
    private var source: CFRunLoopSource?
    private let menu = NSMenu()
    private var restoreError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item?.autosaveName = "WattsInsideBattery"
        item?.button?.title = "Watt’s Inside"
        item?.button?.imagePosition = .imageOnly
        menu.delegate = self
        item?.button?.target = self
        item?.button?.action = #selector(showMenu)
        item?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            // This source is installed on the main run loop.
            MainActor.assumeIsolated {
                Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .NSProcessInfoPowerStateDidChange, object: nil)
        refresh()
    }

    @objc private func showMenu() {
        guard let button = item?.button else { return }
        let rightClick = NSApp.currentEvent?.type == .rightMouseDown || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        let selectedMenu: NSMenu
        if rightClick {
            selectedMenu = NSMenu()
            selectedMenu.addItem(withTitle: "Quit Watt’s Inside", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        } else {
            selectedMenu = menu
        }
        // Temporarily attaching the menu preserves native status-item tracking and positioning.
        item?.menu = selectedMenu
        button.performClick(nil)
        item?.menu = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        menu.removeAllItems()
        let battery = Battery.read()
        let smart = SmartCharge.shared.state()
        let title = battery.map { "Battery   \($0.percent)%" } ?? "Battery Unavailable"
        var lines = [title] + (battery?.detailLines(smart: smart, slowCharger: readSlowCharger()) ?? [])
        if source == nil { lines.append("Live updates unavailable; reopen to refresh") }
        // Disabled NSMenuItem titles are dimmed even with an explicit text color.
        let labels = lines.enumerated().map { index, text in
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: index == 0 ? .semibold : .regular)
            label.textColor = .labelColor
            label.sizeToFit()
            return label
        }
        let width = max(232, (labels.map { $0.frame.width }.max() ?? 0) + 32)
        let info = NSView(frame: NSRect(x: 0, y: 0, width: width, height: CGFloat(labels.count) * 24 + 8))
        for (index, label) in labels.enumerated() {
            label.frame.origin = NSPoint(x: 16, y: info.frame.height - CGFloat(index + 1) * 24)
            info.addSubview(label)
        }
        let heading = NSMenuItem()
        heading.view = info
        menu.addItem(heading)
        menu.addItem(.separator())
        if let saved = SmartCharge.shared.savedLimit {
            let restore = menu.addItem(withTitle: "Restore \(saved)% Charge Limit", action: #selector(restoreChargeLimit), keyEquivalent: "")
            restore.target = self
            if let restoreError { menu.addItem(withTitle: restoreError, action: nil, keyEquivalent: "") }
            menu.addItem(.separator())
        } else if battery?.canChargeToFull(smart) == true {
            let charge = menu.addItem(withTitle: "Charge to Full Now", action: #selector(chargeToFull), keyEquivalent: "")
            charge.target = self
            menu.addItem(.separator())
        }
        let energy = menu.addItem(withTitle: "Low Power Mode: " + (ProcessInfo.processInfo.isLowPowerModeEnabled ? "On…" : "Off…"), action: #selector(openSettings), keyEquivalent: "")
        energy.target = self
        energy.toolTip = "Change energy mode in Battery Settings."
        let settings = menu.addItem(withTitle: "Battery Settings…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
    }

    @objc func refresh() {
        let battery = Battery.read()
        do {
            try SmartCharge.shared.restoreIfFinished(battery: battery)
            restoreError = nil
        } catch { restoreError = "Couldn’t restore limit. Select Restore to retry." }
        let summary = battery?.summary ?? "Battery unavailable"
        let icon = batteryIcon(percent: battery?.percent, charging: battery?.charging ?? false)
        // The image includes a two-point leading inset for optical balance beside system icons.
        item?.length = icon.size.width + 10
        item?.button?.imageScaling = .scaleNone
        item?.button?.image = icon
        item?.button?.window?.title = "Watt’s Inside"
        item?.button?.toolTip = summary
        item?.button?.setAccessibilityLabel("Battery: \(summary)")
        item?.button?.setAccessibilityHelp("Open battery menu. Right-click to quit Watt’s Inside.")
    }

    @objc private func chargeToFull() {
        guard Battery.read()?.canChargeToFull(SmartCharge.shared.state()) == true else { return }
        do {
            try SmartCharge.shared.chargeToFullNow()
            refresh()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t Start Charging"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Battery Settings…")
            if alert.runModal() == .alertSecondButtonReturn { openSettings() }
        }
    }

    @objc private func restoreChargeLimit() {
        do {
            try SmartCharge.shared.restoreLimit()
            restoreError = nil
            refresh()
        } catch {
            restoreError = "Couldn’t restore limit. Select Restore to retry."
            let alert = NSAlert()
            alert.messageText = "Couldn’t Restore Charge Limit"
            alert.informativeText = "Your original limit is saved. Try Restore again or set it in Battery Settings."
            alert.addButton(withTitle: "Battery Settings…")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn { openSettings() }
        }
    }

    @objc private func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") else { return }
        if !NSWorkspace.shared.open(url) {
            let alert = NSAlert()
            alert.messageText = "Open Battery Settings"
            alert.informativeText = "Open System Settings, then choose Battery."
            alert.runModal()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard SmartCharge.shared.savedLimit != nil else { return .terminateNow }
        restoreChargeLimit()
        return SmartCharge.shared.savedLimit == nil ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let source { CFRunLoopSourceInvalidate(source) }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
