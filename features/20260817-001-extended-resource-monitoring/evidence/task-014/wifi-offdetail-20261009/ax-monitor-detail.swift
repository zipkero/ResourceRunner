import ApplicationServices
import Foundation

let pid = pid_t(Int(CommandLine.arguments[1])!)
let ticks = Int(CommandLine.arguments[2]) ?? 12
let root = AXUIElementCreateApplication(pid)
func value(_ item: AXUIElement, _ key: CFString) -> AnyObject? {
    var result: CFTypeRef?
    return AXUIElementCopyAttributeValue(item, key, &result) == .success ? result : nil
}
func find(_ item: AXUIElement, id: String, depth: Int = 0) -> AXUIElement? {
    guard depth < 20 else { return nil }
    if value(item, kAXIdentifierAttribute as CFString) as? String == id { return item }
    for child in (value(item, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []) {
        if let found = find(child, id: id, depth: depth + 1) { return found }
    }
    return nil
}
func stamp() -> String { Date().ISO8601Format() }
func openStatus() {
    for menu in (value(root, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []) {
        for item in (value(menu, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []) {
            let label = value(item, kAXDescriptionAttribute as CFString) as? String ?? ""
            if label.hasPrefix("ResourceRunner,") {
                print("AX wall=\(stamp()) status-press=\(AXUIElementPerformAction(item, kAXPressAction as CFString).rawValue)")
                return
            }
        }
    }
}
func selectNetwork() {
    let down = CGEvent(keyboardEventSource: nil, virtualKey: 20, keyDown: true)!
    let up = CGEvent(keyboardEventSource: nil, virtualKey: 20, keyDown: false)!
    down.flags = .maskCommand
    up.flags = .maskCommand
    down.postToPid(pid)
    up.postToPid(pid)
    print("AX wall=\(stamp()) command-3-sent pid=\(pid)")
}
if find(root, id: "NetworkCard") == nil {
    openStatus()
    Thread.sleep(forTimeInterval: 0.4)
}
if find(root, id: "NetworkDetail") == nil {
    selectNetwork()
    Thread.sleep(forTimeInterval: 0.8)
}
for tick in 0..<ticks {
    for id in ["NetworkCard", "NetworkDetail", "NetworkInterface-en0", "NetworkInterface-llw0", "NetworkInterface-awdl0"] {
        if let item = find(root, id: id) {
            let label = value(item, kAXDescriptionAttribute as CFString) as? String ?? ""
            print("AX wall=\(stamp()) tick=\(tick) id=\(id) label=\(label)")
        } else { print("AX wall=\(stamp()) tick=\(tick) id=\(id) missing") }
    }
    fflush(stdout)
    Thread.sleep(forTimeInterval: 1)
}
