import AppKit
import ApplicationServices
import Foundation

func attribute(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success
        ? value : nil
}

func describe(_ element: AXUIElement?) -> [String: String] {
    guard let element else { return [:] }
    var result: [String: String] = [:]
    for (name, key) in ["identifier": kAXIdentifierAttribute,
                        "title": kAXTitleAttribute,
                        "role": kAXRoleAttribute,
                        "focused": kAXFocusedAttribute] {
        if let value = attribute(element, key) { result[name] = String(describing: value) }
    }
    return result
}

guard CommandLine.arguments.count == 4,
      let seconds = Int(CommandLine.arguments[3]), (1...60).contains(seconds),
      AXIsProcessTrusted() else {
    fputs("usage: focus_probe BUNDLE_ID OUTPUT_JSONL SECONDS(1...60)\n", stderr)
    exit(2)
}
let bundleID = CommandLine.arguments[1]
let url = URL(fileURLWithPath: CommandLine.arguments[2])
guard !FileManager.default.fileExists(atPath: url.path) else {
    fputs("output exists\n", stderr)
    exit(3)
}
FileManager.default.createFile(atPath: url.path, contents: nil)
let output = try FileHandle(forWritingTo: url)
defer { try? output.close() }
let end = Date().addingTimeInterval(TimeInterval(seconds))
var sequence = 0
while Date() < end {
    let started = mach_absolute_time()
    let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        .first(where: { !$0.isTerminated })?.processIdentifier
    var row: [String: Any] = ["sequence": sequence, "startedMach": started,
        "startedEpoch": Date().timeIntervalSince1970,
        "pid": pid ?? 0]
    if let pid {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.1)
        let window = attribute(app, kAXFocusedWindowAttribute) as! AXUIElement?
        let focusedElement = attribute(app, kAXFocusedUIElementAttribute) as! AXUIElement?
        row["focusedWindow"] = describe(window)
        row["focusedElement"] = describe(focusedElement)
        if let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] {
            row["windows"] = windows.map { describe($0) }
        }
    }
    row["finishedMach"] = mach_absolute_time()
    if let data = try? JSONSerialization.data(withJSONObject: row,
        options: [.sortedKeys]) {
        output.write(data)
        output.write(Data([0x0a]))
    }
    sequence += 1
    Thread.sleep(forTimeInterval: 0.02)
}
print("focus snapshots=\(sequence)")
