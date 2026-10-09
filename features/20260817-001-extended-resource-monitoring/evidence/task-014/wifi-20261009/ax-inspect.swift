import ApplicationServices
import Foundation

let pid = pid_t(Int(CommandLine.arguments[1])!)
let root = AXUIElementCreateApplication(pid)
var seen = Set<String>()
func attr(_ element: AXUIElement, _ key: CFString) -> AnyObject? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key, &value) == .success else { return nil }
    return value
}
func walk(_ item: AXUIElement, _ depth: Int) {
    guard depth < 20 else { return }
    let id = attr(item, kAXIdentifierAttribute as CFString) as? String ?? ""
    let role = attr(item, kAXRoleAttribute as CFString) as? String ?? ""
    let label = attr(item, kAXDescriptionAttribute as CFString) as? String ?? attr(item, kAXTitleAttribute as CFString) as? String ?? ""
    if depth < 3 || id.hasPrefix("Network") || label.contains("Network") {
        let value = attr(item, kAXValueAttribute as CFString).map { String(describing: $0) } ?? ""
        print("depth=\(depth) id=\(id) role=\(role) label=\(label) value=\(value)")
    }
    if let children = attr(item, kAXChildrenAttribute as CFString) as? [AXUIElement] {
        for child in children { walk(child, depth + 1) }
    }
}
walk(root, 0)
