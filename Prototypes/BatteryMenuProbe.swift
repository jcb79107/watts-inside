import AppKit
import ApplicationServices

func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
    return result
}
let control = CommandLine.arguments.contains("--press-control-center")
let edit = CommandLine.arguments.contains("--edit-controls")
let press = edit || CommandLine.arguments.contains("--press-battery") || control
print("Accessibility trusted: \(AXIsProcessTrusted())")
var found = false
func scan(_ element: AXUIElement, depth: Int = 0) {
    guard depth < 9 else { return }
    let role = value(element, kAXRoleAttribute) as? String ?? ""
    let identifier = value(element, kAXIdentifierAttribute) as? String ?? ""
    let title = value(element, kAXTitleAttribute) as? String ?? ""
    let description = value(element, kAXDescriptionAttribute) as? String ?? ""
    var actions: CFArray?
    AXUIElementCopyActionNames(element, &actions)
    print(String(repeating: " ", count: depth) + "\(role) id=\(identifier) title=\(title) description=\(description) actions=\(actions as? [String] ?? [])")
    if !found, CommandLine.arguments.contains("--remove-tile"), role == "AXMenuItem", title == "Remove" {
        found = true
        print("REMOVE_RESULT=\(AXUIElementPerformAction(element, kAXPressAction as CFString).rawValue)")
    }
    if !found, CommandLine.arguments.contains("--battery-context"), identifier == "controlcenter-battery", role == "AXButton" {
        found = true
        print("CONTEXT_RESULT=\(AXUIElementPerformAction(element, kAXShowMenuAction as CFString).rawValue)")
    }
    if !found, CommandLine.arguments.contains("--add-battery"), identifier == "controlcenter-battery",
       let action = (actions as? [String])?.first(where: { $0.contains("Add to Control Center") }) {
        found = true
        print("ADD_RESULT=\(AXUIElementPerformAction(element, action as CFString).rawValue)")
    }
    if !found, CommandLine.arguments.contains("--done"), description == "Done" {
        found = true
        print("DONE_RESULT=\(AXUIElementPerformAction(element, kAXPressAction as CFString).rawValue)")
    }
    if press && !found && (edit ? description == "Edit Controls" : control ? identifier == "com.apple.menuextra.controlcenter" : (identifier.lowercased().contains("battery") || description.lowercased().hasPrefix("battery"))),
       (actions as? [String] ?? []).contains(kAXPressAction) {
        found = true
        print("PRESS_RESULT=\(AXUIElementPerformAction(element, kAXPressAction as CFString).rawValue)")
    }
    for child in value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { scan(child, depth: depth + 1) }
}
for app in NSWorkspace.shared.runningApplications where ["com.apple.controlcenter", "com.apple.systemuiserver", "com.apple.menuextra.controlcenter"].contains(app.bundleIdentifier ?? "") {
    print("PROCESS \(app.bundleIdentifier ?? "") pid=\(app.processIdentifier)")
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 2)
    scan(element)
    for attribute in [kAXMenuBarAttribute, "AXExtrasMenuBar"] {
        if let bar = value(element, attribute), CFGetTypeID(bar) == AXUIElementGetTypeID() {
            scan(unsafeBitCast(bar, to: AXUIElement.self))
        }
    }
}
if press { print("BATTERY_ACTION_FOUND=\(found)") }
