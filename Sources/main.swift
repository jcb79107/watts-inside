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
        let heading = NSMenuItem(title: battery.map { "Battery   \($0.percent)%" } ?? "Battery Unavailable", action: nil, keyEquivalent: "")
        heading.attributedTitle = NSAttributedString(string: heading.title, attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)])
        menu.addItem(heading)
        for line in battery?.detailLines(smart: smart) ?? [] {
            menu.addItem(withTitle: line, action: nil, keyEquivalent: "")
        }
        if source == nil { menu.addItem(withTitle: "Live updates unavailable; reopen to refresh", action: nil, keyEquivalent: "") }
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
        item?.length = icon.size.width + 12
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
