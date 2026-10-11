import ApplicationServices
import CoreGraphics
import Foundation

func attribute(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var result: AnyObject?
    return AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success ? result : nil
}

func string(_ element: AXUIElement, _ key: String) -> String? {
    attribute(element, key) as? String
}

func descendants(_ root: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 14 else { return [] }
    let children = attribute(root, kAXChildrenAttribute) as? [AXUIElement] ?? []
    return children.flatMap { [$0] + descendants($0, depth: depth + 1) }
}

func identified(_ elements: [AXUIElement], _ id: String) -> AXUIElement? {
    elements.first { string($0, kAXIdentifierAttribute) == id }
}

func click(_ element: AXUIElement, right: Bool = false) throws {
    guard let rawPosition = attribute(element, kAXPositionAttribute),
          let rawExtent = attribute(element, kAXSizeAttribute) else {
        throw NSError(domain: "AX bounds unavailable", code: 1)
    }
    let position = rawPosition as! AXValue
    let extent = rawExtent as! AXValue
    var point = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(position, .cgPoint, &point)
    AXValueGetValue(extent, .cgSize, &size)
    let center = CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
    guard let down = CGEvent(mouseEventSource: nil,
                             mouseType: right ? .rightMouseDown : .leftMouseDown,
                             mouseCursorPosition: center, mouseButton: right ? .right : .left),
          let up = CGEvent(mouseEventSource: nil,
                           mouseType: right ? .rightMouseUp : .leftMouseUp,
                           mouseCursorPosition: center, mouseButton: right ? .right : .left) else {
        throw NSError(domain: "CGEvent unavailable", code: 2)
    }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

func inspect(_ app: AXUIElement) -> [String: Any] {
    let elements = descendants(app)
    let settings = identified(elements, "ResourceRunnerSettingsWindow") != nil
    let body = identified(elements, "DashboardContainer") != nil
    let detail = identified(elements, "DashboardDetail") != nil
    let headings = ["CPU 상세", "Memory 상세", "Network 상세", "Disk 상세"]
    let found = elements.compactMap { string($0, kAXValueAttribute) }.filter { headings.contains($0) }
    let controls = ["SettingsCPUCard", "SettingsMemoryCard", "SettingsNetworkCard", "SettingsDiskCard",
                    "SettingsCPUTop5", "SettingsMemoryTop5", "SettingsIncludeSystemProcesses",
                    "SettingsDetailListLimit", "SettingsGraphRange", "SettingsRefreshProfile",
                    "SettingsAutomaticallyClosesPopover"]
    var values: [String: String] = [:]
    for id in controls {
        if let element = identified(elements, id), let value = attribute(element, kAXValueAttribute) {
            values[id] = String(describing: value)
        }
    }
    let focusedWindow = attribute(app, kAXFocusedWindowAttribute).map { $0 as! AXUIElement }
    let focusedTitle = focusedWindow.flatMap { string($0, kAXTitleAttribute) }
    let focusedIdentifier = focusedWindow.flatMap { string($0, kAXIdentifierAttribute) }
    let cards = ["CPUCard", "MemoryCard", "NetworkCard", "DiskCard"]
    let visibleCards = cards.filter { identified(elements, $0) != nil }
    var cardDescriptions: [String: String] = [:]
    for id in visibleCards {
        if let element = identified(elements, id), let description = string(element, kAXDescriptionAttribute) {
            cardDescriptions[id] = description
        }
    }
    let state: String
    if settings { state = body ? "mixed_settings_body" : "settings" }
    else if body && detail && found.count == 1 {
        state = ["CPU 상세": "cpu", "Memory 상세": "memory", "Network 상세": "network", "Disk 상세": "disk"][found[0]]!
    } else if body && !detail { state = "body" }
    else if !body && !detail { state = "closed" }
    else { state = "ambiguous" }
    return ["state": state, "settings": values, "cards": visibleCards, "cardDescriptions": cardDescriptions, "detailHeadings": found,
            "body": body, "detail": detail, "focusedWindowTitle": focusedTitle ?? "",
            "focusedWindowIdentifier": focusedIdentifier ?? ""]
}

func main() throws {
    guard CommandLine.arguments.count >= 3, let pid = Int32(CommandLine.arguments[1]),
          AXIsProcessTrusted() else { throw NSError(domain: "usage or AX untrusted", code: 3) }
    let app = AXUIElementCreateApplication(pid)
    let command = CommandLine.arguments[2]
    let elements = descendants(app)
    let menuExtra = elements.first { string($0, kAXSubroleAttribute) == "AXMenuExtra" }
    guard let menuExtra else { throw NSError(domain: "diagnostic menu extra unavailable", code: 11) }
    var owner: pid_t = 0
    guard AXUIElementGetPid(menuExtra, &owner) == .success, owner == pid else {
        throw NSError(domain: "menu extra PID mismatch", code: 12)
    }
    switch command {
    case "inspect": break
    case "toggle":
        try click(menuExtra)
    case "card":
        guard CommandLine.arguments.count == 4,
              let card = identified(elements, CommandLine.arguments[3]) else {
            throw NSError(domain: "card unavailable", code: 5)
        }
        try click(card)
    case "detail-close":
        guard let button = ["CPUDetailClose", "MemoryDetailClose", "NetworkDetailClose", "DiskDetailClose"]
            .compactMap({ identified(elements, $0) }).first else {
            throw NSError(domain: "detail close unavailable", code: 6)
        }
        try click(button)
    case "settings-open":
        try click(menuExtra, right: true)
        usleep(200_000)
        let menuItems = descendants(app)
        guard let item = menuItems.first(where: {
            string($0, kAXTitleAttribute) == "설정…" &&
            string($0, kAXIdentifierAttribute) == "openSettingsFromMenu:"
        }), AXUIElementPerformAction(item, kAXPressAction as CFString) == .success else {
            throw NSError(domain: "settings menu unavailable", code: 8)
        }
    case "settings-close":
        guard let window = identified(elements, "ResourceRunnerSettingsWindow"),
              let rawButton = attribute(window, kAXCloseButtonAttribute),
              AXUIElementPerformAction(rawButton as! AXUIElement, kAXPressAction as CFString) == .success else {
            throw NSError(domain: "settings close unavailable", code: 9)
        }
    default: throw NSError(domain: "unknown command", code: 10)
    }
    usleep(200_000)
    let result = inspect(app)
    let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}

do { try main() } catch { fputs("\(error)\n", stderr); exit(1) }
