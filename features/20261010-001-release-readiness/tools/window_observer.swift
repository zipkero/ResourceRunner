import ApplicationServices
import CryptoKit
import Foundation

// measure.swift와 같은 화면 위 창 집합을 기록해 변동의 종류를 사후 분류합니다.
guard CommandLine.arguments.count == 4,
      let pid = Int32(CommandLine.arguments[1]),
      let seconds = Int(CommandLine.arguments[3]), seconds > 0, seconds <= 1800 else {
    fputs("usage: window_observer PID OUTPUT_JSONL SECONDS\n", stderr)
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

for sequence in 0...seconds {
    let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID) as? [[String: Any]] ?? [])
        .filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
    let signatures = windows.map { window -> String in
        let id = window[kCGWindowNumber as String] ?? "?"
        let layer = window[kCGWindowLayer as String] ?? "?"
        let bounds = window[kCGWindowBounds as String] as? [String: NSNumber] ?? [:]
        let geometry = ["X", "Y", "Width", "Height"].map {
            "\($0)=\(bounds[$0]?.doubleValue ?? .nan)"
        }.joined(separator: ",")
        return "\(id)|\(layer)|\(geometry)"
    }.sorted().joined(separator: ";")
    let hash = SHA256.hash(data: Data(signatures.utf8)).map { String(format: "%02x", $0) }.joined()
    let details = windows.map { window -> [String: Any] in
        ["number": window[kCGWindowNumber as String] ?? NSNull(),
         "layer": window[kCGWindowLayer as String] ?? NSNull(),
         "bounds": window[kCGWindowBounds as String] ?? NSNull(),
         "name": window[kCGWindowName as String] ?? NSNull()]
    }
    let row: [String: Any] = ["sequence": sequence,
        "wallTime": ISO8601DateFormatter().string(from: Date()),
        "pid": pid, "windowSHA256": hash, "windows": details]
    let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
    handle.write(data)
    handle.write(Data([0x0a]))
    if sequence < seconds { Thread.sleep(forTimeInterval: 1) }
}
