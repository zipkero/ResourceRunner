import AppKit
import ApplicationServices
import Foundation
let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "com.zipkero.ResourceRunner" }
var records: [[String: Any]] = []
for app in apps {
 let ax = AXUIElementCreateApplication(app.processIdentifier)
 var value: CFTypeRef?
 let result = AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &value)
 let windows = (value as? [AXUIElement]) ?? []
 let titles = windows.map { window -> String in
  var title: CFTypeRef?
  AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
  return (title as? String) ?? ""
 }
 let cg = (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).filter { ($0[kCGWindowOwnerPID as String] as? Int) == Int(app.processIdentifier) }
 records.append(["pid": Int(app.processIdentifier), "bundleURL": app.bundleURL?.path ?? "", "executableURL": app.executableURL?.path ?? "", "launchDate": app.launchDate.map { ISO8601DateFormatter().string(from: $0) } ?? "", "activationPolicy": app.activationPolicy.rawValue, "AXTrusted": AXIsProcessTrusted(), "AXResult": result.rawValue, "AXWindowCount": windows.count, "AXWindowTitles": titles, "CGWindows": cg])
}
let data = try JSONSerialization.data(withJSONObject: ["observedAt": ISO8601DateFormatter().string(from: Date()), "applications": records], options: [.prettyPrinted, .sortedKeys])
print(String(data: data, encoding: .utf8)!)
