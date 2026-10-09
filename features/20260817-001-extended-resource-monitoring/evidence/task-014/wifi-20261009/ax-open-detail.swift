import ApplicationServices
import Foundation
let pid = pid_t(Int(CommandLine.arguments[1])!)
let root = AXUIElementCreateApplication(pid)
func value(_ item: AXUIElement, _ key: CFString) -> AnyObject? {
    var result: CFTypeRef?
    return AXUIElementCopyAttributeValue(item, key, &result) == .success ? result : nil
}
func find(_ item: AXUIElement, id: String, depth: Int = 0) -> AXUIElement? {
    guard depth < 10 else { return nil }
    if value(item, kAXIdentifierAttribute as CFString) as? String == id { return item }
    for child in (value(item, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []) {
        if let found = find(child, id: id, depth: depth + 1) { return found }
    }
    return nil
}
let stamp = Date().ISO8601Format()
if find(root, id: "NetworkCard") == nil {
    for menu in (value(root, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []) {
        for item in (value(menu, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []) {
            let label = value(item, kAXDescriptionAttribute as CFString) as? String ?? ""
            if label.hasPrefix("ResourceRunner,") {
                print("wall=\(stamp) status-press=\(AXUIElementPerformAction(item, kAXPressAction as CFString).rawValue)")
            }
        }
    }
}
Thread.sleep(forTimeInterval: 0.4)
let down = CGEvent(keyboardEventSource: nil, virtualKey: 20, keyDown: true)!
let up = CGEvent(keyboardEventSource: nil, virtualKey: 20, keyDown: false)!
down.flags = .maskCommand
up.flags = .maskCommand
down.postToPid(pid)
up.postToPid(pid)
print("wall=\(Date().ISO8601Format()) sent-command-3-to-pid=\(pid)")
Thread.sleep(forTimeInterval: 1)
for id in ["NetworkCard", "NetworkDetail", "NetworkInterface-en0", "NetworkInterface-awdl0"] {
    if let item = find(root, id: id) {
        let label = value(item, kAXDescriptionAttribute as CFString) as? String ?? ""
        print("wall=\(Date().ISO8601Format()) id=\(id) label=\(label)")
    } else { print("wall=\(Date().ISO8601Format()) id=\(id) missing") }
}
