import ApplicationServices
import Foundation

let cardIDs: Set<String> = ["CPUCard", "MemoryCard", "NetworkCard", "DiskCard"]

func attribute(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var result: AnyObject?
    return AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success
        ? result : nil
}

func cardDescriptions(_ element: AXUIElement, depth: Int,
                      result: inout [String: String]) {
    guard depth < 14, result.count < cardIDs.count else { return }
    if let id = attribute(element, kAXIdentifierAttribute) as? String,
       cardIDs.contains(id),
       let description = attribute(element, kAXDescriptionAttribute) as? String {
        result[id] = description
    }
    guard let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
    for child in children { cardDescriptions(child, depth: depth + 1, result: &result) }
}

guard CommandLine.arguments.count == 4,
      let pid = Int32(CommandLine.arguments[1]),
      let seconds = Int(CommandLine.arguments[3]), (1...10).contains(seconds),
      AXIsProcessTrusted() else {
    fputs("usage: target_ax_probe PID OUTPUT_JSONL SECONDS(1...10) or AX unavailable\n", stderr)
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard !FileManager.default.fileExists(atPath: output.path) else {
    fputs("output exists\n", stderr)
    exit(3)
}
FileManager.default.createFile(atPath: output.path, contents: nil)
let handle = try FileHandle(forWritingTo: output)
defer { try? handle.close() }
let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 0.15)
let end = Date().addingTimeInterval(TimeInterval(seconds))
var sequence = 0
while Date() < end {
    let started = mach_absolute_time()
    var cards: [String: String] = [:]
    cardDescriptions(app, depth: 0, result: &cards)
    let finished = mach_absolute_time()
    let row: [String: Any] = ["sequence": sequence, "startedMach": started,
        "finishedMach": finished, "cards": cards]
    if let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) {
        handle.write(data)
        handle.write(Data([0x0a]))
    }
    sequence += 1
    Thread.sleep(forTimeInterval: 0.01)
}
print("AX snapshots=\(sequence)")
