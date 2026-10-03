import CoreGraphics
import AppKit
import Foundation
let values = CommandLine.arguments.dropFirst().compactMap(Int.init)
guard values.count == 5 else { fatalError("width height pixelWidth pixelHeight refresh") }
let display = CGMainDisplayID()
let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
let modes = CGDisplayCopyAllDisplayModes(display, options) as! [CGDisplayMode]
let mode = modes.first { $0.width == values[0] && $0.height == values[1] && $0.pixelWidth == values[2] && $0.pixelHeight == values[3] && abs($0.refreshRate - Double(values[4])) < 0.5 }!
var config: CGDisplayConfigRef?
let start = CGBeginDisplayConfiguration(&config)
let configure = config.map { CGConfigureDisplayWithDisplayMode($0, display, mode, nil) } ?? .failure
let finish = config.map { CGCompleteDisplayConfiguration($0, .forSession) } ?? .failure
print("results",start.rawValue,configure.rawValue,finish.rawValue)
for s in NSScreen.screens { print("screen",s.frame,s.visibleFrame,s.backingScaleFactor) }
