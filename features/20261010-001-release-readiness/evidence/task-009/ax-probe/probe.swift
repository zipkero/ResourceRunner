import AppKit
import ApplicationServices

func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?; return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
}
func names(_ e: AXUIElement) -> [String] { var n: CFArray?; AXUIElementCopyAttributeNames(e, &n); return (n as? [String]) ?? [] }
func dump(_ e: AXUIElement, _ d: Int) {
    if d > 8 { return }
    print(String(repeating: "  ", count: d) + desc(e))
    for c in (attr(e, "AXChildren") as? [AXUIElement]) ?? [] { dump(c, d + 1) }
}
func find(_ e: AXUIElement, id: String, depth: Int = 0) -> AXUIElement? {
    if (attr(e, "AXIdentifier") as? String) == id { return e }
    if depth > 30 { return nil }
    for c in (attr(e, "AXChildren") as? [AXUIElement]) ?? [] { if let f = find(c, id: id, depth: depth + 1) { return f } }
    return nil
}
func desc(_ e: AXUIElement?) -> String {
    guard let e else { return "nil" }
    return "role=\(attr(e,"AXRole") as? String ?? "?") id=\(attr(e,"AXIdentifier") as? String ?? "-") desc=\(attr(e,"AXDescription") as? String ?? "-") value=\(String(describing: attr(e,"AXValue")))"
}
let pid = pid_t(CommandLine.arguments[1])!
let app = AXUIElementCreateApplication(pid)
func snapshot(_ label: String) {
    let wl = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []).filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
    print("cgwindows=\(wl.map { ($0[kCGWindowBounds as String] as? [String: Any]).map { "\($0)" } ?? "" })")
    let wins = (attr(app, "AXWindows") as? [AXUIElement]) ?? []
    var c: AXUIElement?
    for w in wins { if let f = find(w, id: "DashboardContainer") { c = f; break } }
    let foc = attr(app, "AXFocusedUIElement") as! AXUIElement?
    var top: AXUIElement? = foc
    var chain: [String] = []
    while let t = top, let p = attr(t, "AXParent") { chain.append(desc(t)); top = (p as! AXUIElement) }
    print("  chain: " + chain.joined(separator: " <- "))
    if c == nil, let t = top { c = find(t, id: "DashboardContainer"); print("  top: \(desc(t))") }
    print("[\(label)] windows=\(wins.count) container: \(desc(c))")
    if c == nil, let w = wins.first { dump(w, 0) }
    if let c { print("  valueDescription=\(String(describing: attr(c, "AXValueDescription")))") }
    print("  focused: \(desc(attr(app, "AXFocusedUIElement") as! AXUIElement?))")
}
func key(_ code: CGKeyCode, shift: Bool = false) {
    for down in [true, false] {
        let ev = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        if shift { ev.flags = .maskShift }
        ev.postToPid(pid)
    }
}
NSRunningApplication(processIdentifier: pid)?.activate()
Thread.sleep(forTimeInterval: 0.5)
// open popover via status item AXPress
if let bar = attr(app, "AXExtrasMenuBar") {
    let items = (attr(bar as! AXUIElement, "AXChildren") as? [AXUIElement]) ?? []
    print("status items=\(items.count)")
    if let first = items.first {
        var pt = CGPoint.zero, sz = CGSize.zero
        AXValueGetValue(attr(first, "AXPosition") as! AXValue, .cgPoint, &pt)
        AXValueGetValue(attr(first, "AXSize") as! AXValue, .cgSize, &sz)
        let c = CGPoint(x: pt.x + sz.width / 2, y: pt.y + sz.height / 2)
        print("click at \(c)")
        for t in [CGEventType.leftMouseDown, .leftMouseUp] {
            let ev = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: t, mouseCursorPosition: c, mouseButton: .left)!
            ev.setIntegerValueField(.mouseEventClickState, value: 1)
            ev.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
}
Thread.sleep(forTimeInterval: 1.5)
snapshot("open")
key(48); Thread.sleep(forTimeInterval: 0.7); snapshot("tab")
key(48); Thread.sleep(forTimeInterval: 0.7); snapshot("tab2")
key(48, shift: true); Thread.sleep(forTimeInterval: 0.7); snapshot("shift-tab")
