import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// 앱 바깥의 읽기 전용 AX 관찰 및 명시적 버튼 동작만 수행합니다.
func attribute(_ element: AXUIElement, _ key: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key, &value) == .success ? value : nil
}
func string(_ element: AXUIElement, _ key: CFString) -> String {
    (attribute(element, key) as? String) ?? ""
}
func children(_ element: AXUIElement) -> [AXUIElement] {
    (attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement]) ?? []
}
func rect(_ element: AXUIElement) -> CGRect? {
    guard let position = attribute(element, kAXPositionAttribute as CFString) as! AXValue?,
          let size = attribute(element, kAXSizeAttribute as CFString) as! AXValue? else { return nil }
    var point = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetValue(position, .cgPoint, &point),
          AXValueGetValue(size, .cgSize, &dimensions) else { return nil }
    return CGRect(origin: point, size: dimensions)
}
func find(_ root: AXUIElement, match: (AXUIElement) -> Bool) -> AXUIElement? {
    var seen = 0
    func search(_ element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 20, seen < 3000 else { return nil }
        seen += 1
        if match(element) { return element }
        for child in children(element) {
            if let result = search(child, depth: depth + 1) { return result }
        }
        return nil
    }
    return search(root, depth: 0)
}
func describe(_ element: AXUIElement) -> String {
    let value = attribute(element, kAXValueAttribute as CFString)
    return "id=\(string(element, kAXIdentifierAttribute as CFString)) role=\(string(element, kAXRoleAttribute as CFString)) title=\(string(element, kAXTitleAttribute as CFString)) desc=\(string(element, kAXDescriptionAttribute as CFString)) value=\(String(describing: value)) frame=\(String(describing: rect(element)))"
}

guard CommandLine.arguments.count >= 3, let pid = Int32(CommandLine.arguments[1]) else { exit(2) }
let command = CommandLine.arguments[2]
let root = AXUIElementCreateApplication(pid)
guard AXIsProcessTrusted() else { fputs("AX not trusted\n", stderr); exit(3) }
let statusItems = children(root).filter({
    string($0, kAXRoleAttribute as CFString) == "AXMenuBar"
}).flatMap(children).filter {
    string($0, kAXDescriptionAttribute as CFString).hasPrefix("ResourceRunner,")
}
let owned = statusItems.flatMap(children)
print("pid=\(pid) command=\(command) ownedPopovers=\(owned.count) time=\(ISO8601DateFormatter().string(from: Date()))")
for item in statusItems {
        print("status " + describe(item))
        if command == "open" || command == "toggle" {
            print("press status result=\(AXUIElementPerformAction(item, kAXPressAction as CFString).rawValue)")
        }
}
let important: Set<String> = [
    "DashboardContainer", "CPUCard", "MemoryCard", "NetworkCard", "DiskCard",
    "DashboardDetail", "NetworkDetail", "DiskDetail", "CPUDetailClose",
    "MemoryDetailClose", "NetworkDetailClose", "DiskDetailClose", "DiskSummary",
    "NetworkUpdateCadence", "DiskMiniGraph"
]
func visit(_ element: AXUIElement, depth: Int, count: inout Int) {
    guard depth < 20, count < 3000 else { return }
    count += 1
    let id = string(element, kAXIdentifierAttribute as CFString)
    if important.contains(id) || id.hasPrefix("NetworkInterface-")
        || id.hasPrefix("DiskDevice-") || id.hasPrefix("DiskVolume-") {
        print("AX " + describe(element))
    }
    for child in children(element) { visit(child, depth: depth + 1, count: &count) }
}
if command == "dump" || command == "open" || command == "toggle" {
    for popover in owned { var count = 0; visit(popover, depth: 0, count: &count) }
} else if command == "press", CommandLine.arguments.count >= 4 {
    let identifier = CommandLine.arguments[3]
    for popover in owned {
        if let element = find(popover, match: {
            string($0, kAXIdentifierAttribute as CFString) == identifier
        }) {
            print("target " + describe(element))
            print("press result=\(AXUIElementPerformAction(element, kAXPressAction as CFString).rawValue)")
            break
        }
    }
} else if command == "windows" {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    for item in list where (item[kCGWindowOwnerPID as String] as? Int32) == pid {
        let number = item[kCGWindowNumber as String] ?? "?"
        let bounds = item[kCGWindowBounds as String] ?? "?"
        let layer = item[kCGWindowLayer as String] ?? "?"
        print("CGWindow id=\(number) layer=\(layer) bounds=\(bounds)")
    }
} else if command == "click", CommandLine.arguments.count >= 5,
          let x = Double(CommandLine.arguments[3]), let y = Double(CommandLine.arguments[4]) {
    let point = CGPoint(x: x, y: y)
    for kind in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: kind, mouseCursorPosition: point,
                mouseButton: .left)?.post(tap: .cghidEventTap)
    }
    print("clicked=\(point)")
} else if command == "page", CommandLine.arguments.count >= 4,
          let repeatCount = Int(CommandLine.arguments[3]) {
    for _ in 0..<repeatCount {
        CGEvent(keyboardEventSource: nil, virtualKey: 121, keyDown: true)?
            .post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: nil, virtualKey: 121, keyDown: false)?
            .post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.03)
    }
    print("pageDown=\(repeatCount)")
}
