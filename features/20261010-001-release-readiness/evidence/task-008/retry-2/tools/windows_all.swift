// 대상 PID의 화면 밖 창까지 포함한 창 목록(번호·layer·크기·onscreen·backing 저장 방식)을 JSON 한 줄로 출력한다.
import CoreGraphics
import Foundation
let pid = Int32(CommandLine.arguments[1])!
let all = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
let rows = all.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }.map { w -> [String: Any] in
    ["number": w[kCGWindowNumber as String] ?? -1, "layer": w[kCGWindowLayer as String] ?? -1,
     "bounds": w[kCGWindowBounds as String] ?? [:], "onscreen": w[kCGWindowIsOnscreen as String] ?? false,
     "store": w[kCGWindowStoreType as String] ?? -1, "memory": w[kCGWindowMemoryUsage as String] ?? -1,
     "alpha": w[kCGWindowAlpha as String] ?? -1]
}
let data = try! JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
print(String(data: data, encoding: .utf8)!)
