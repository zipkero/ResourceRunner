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
func statusItem() -> AXUIElement? {
    for menu in (value(root, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []) {
        for item in (value(menu, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []) {
            let label = value(item, kAXDescriptionAttribute as CFString) as? String ?? ""
            if label.hasPrefix("ResourceRunner,") { return item }
        }
    }
    return nil
}
func stamp() -> String { Date().ISO8601Format() }
for tick in 0..<65 {
    if find(root, id: "NetworkCard") == nil, let button = statusItem() {
        print("AX wall=\(stamp()) tick=\(tick) press-status rc=\(AXUIElementPerformAction(button, kAXPressAction as CFString).rawValue)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 0.2)
    }
    if tick == 0, find(root, id: "NetworkDetail") == nil, let card = find(root, id: "NetworkCard") {
        print("AX wall=\(stamp()) tick=\(tick) press-card rc=\(AXUIElementPerformAction(card, kAXPressAction as CFString).rawValue)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 0.2)
    }
    for id in ["NetworkCard", "NetworkDetail", "NetworkInterface-en0", "NetworkInterface-awdl0", "DiskCard"] {
        if let item = find(root, id: id) {
            let label = value(item, kAXDescriptionAttribute as CFString) as? String ?? ""
            print("AX wall=\(stamp()) tick=\(tick) id=\(id) label=\(label)")
        } else {
            print("AX wall=\(stamp()) tick=\(tick) id=\(id) missing")
        }
    }
    fflush(stdout)
    Thread.sleep(forTimeInterval: 1)
}
