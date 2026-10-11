import AppKit
import ApplicationServices
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ScreenCaptureKit
import VideoToolbox

func menuAnchor(for pid: Int32) -> (bounds: CGRect, identifier: String)? {
    let app = AXUIElementCreateApplication(pid)
    func find(_ element: AXUIElement, depth: Int) -> (bounds: CGRect, identifier: String)? {
        guard depth < 14 else { return nil }
        var rawSubrole: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString,
            &rawSubrole) == .success, rawSubrole as? String == "AXMenuExtra" {
            var owner: pid_t = 0
            var rawPosition: AnyObject?
            var rawSize: AnyObject?
            if AXUIElementGetPid(element, &owner) == .success, owner == pid,
               AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString,
                   &rawPosition) == .success,
               AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString,
                   &rawSize) == .success,
               let position = rawPosition, let size = rawSize,
               CFGetTypeID(position) == AXValueGetTypeID(),
               CFGetTypeID(size) == AXValueGetTypeID() {
                var point = CGPoint.zero
                var extent = CGSize.zero
                if AXValueGetValue(position as! AXValue, .cgPoint, &point),
                   AXValueGetValue(size as! AXValue, .cgSize, &extent),
                   extent.width > 0, extent.height > 0 {
                    var rawIdentifier: AnyObject?
                    let found = AXUIElementCopyAttributeValue(element,
                        kAXIdentifierAttribute as CFString, &rawIdentifier) == .success
                    return (CGRect(origin: point, size: extent),
                        found ? (rawIdentifier as? String ?? "") : "")
                }
            }
        }
        var rawChildren: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString,
            &rawChildren) == .success,
            let children = rawChildren as? [AXUIElement] else { return nil }
        for child in children {
            if let anchor = find(child, depth: depth + 1) { return anchor }
        }
        return nil
    }
    return find(app, depth: 0)
}

// 표시 프레임 시각과 callback 시점의 별도 창 목록 조회를 함께 기록한다.
final class FrameRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    let pid: Int32
    let output: FileHandle
    let imageDirectory: URL
    let displayFrame: CGRect
    let scale: CGFloat
    let fixedROI: CGRect
    let anchor: [String: Any]
    let captureFixedROI: Bool
    let context = CIContext()
    let lock = NSLock()
    var sequence = 0
    var savedImages = 0
    var imageBytes = 0
    var failed = false

    init(pid: Int32, output: FileHandle, imageDirectory: URL,
         displayFrame: CGRect, scale: CGFloat, fixedROI: CGRect,
         anchor: [String: Any],
         captureFixedROI: Bool) {
        self.pid = pid
        self.output = output
        self.imageDirectory = imageDirectory
        self.displayFrame = displayFrame
        self.scale = scale
        self.fixedROI = fixedROI
        self.anchor = anchor
        self.captureFixedROI = captureFixedROI
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        lock.lock()
        failed = true
        write(["event": "streamStopped", "error": String(describing: error)])
        lock.unlock()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer,
                createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let first = attachments.first,
              let displayTime = first[.displayTime] as? UInt64,
              let status = first[.status] as? Int else { return }
        lock.lock()
        defer { lock.unlock() }
        sequence += 1
        let metadataStartedMach = mach_absolute_time()
        let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly,
            .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
            .filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
        let metadataEndedMach = mach_absolute_time()
        let visible = windows.map { window -> [String: Any] in
            ["id": window[kCGWindowNumber as String] ?? NSNull(),
             "layer": window[kCGWindowLayer as String] ?? NSNull(),
             "bounds": window[kCGWindowBounds as String] ?? NSNull()]
        }
        var row: [String: Any] = ["sequence": sequence, "displayTimeMach": displayTime,
            "samplePTSSeconds": CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(buffer)),
            "status": status, "windows": visible,
            "observedMach": mach_absolute_time(),
            "metadataStartedMach": metadataStartedMach,
            "metadataEndedMach": metadataEndedMach]
        if sequence == 1 {
            row["fixedROIPixels"] = ["x": fixedROI.minX, "y": fixedROI.minY,
                "width": fixedROI.width, "height": fixedROI.height]
            row["captureFixedROI"] = captureFixedROI
            row["anchor"] = anchor
        }
        if status == SCFrameStatus.complete.rawValue,
           let pixel = CMSampleBufferGetImageBuffer(buffer) {
            row["pixelFormat"] = CVPixelBufferGetPixelFormatType(pixel)
            if !captureFixedROI { row["fixedROIFingerprint"] = fingerprint(pixel) }
        }
        if captureFixedROI, status == SCFrameStatus.complete.rawValue,
           savedImages < 256, imageBytes < 20_000_000,
           let pixel = CMSampleBufferGetImageBuffer(buffer) {
            saveImage(pixel, crop: fixedROI, row: &row)
        }
        if !captureFixedROI, status == SCFrameStatus.complete.rawValue,
           let window = windows.first(where: {
               let layer = $0[kCGWindowLayer as String] as? Int
               let bounds = $0[kCGWindowBounds as String] as? [String: NSNumber]
               return layer == 25 && (bounds?["Width"]?.doubleValue ?? 0) > 8 &&
                   (bounds?["Height"]?.doubleValue ?? 0) > 50
           }), savedImages < 48, imageBytes < 20_000_000,
           let bounds = window[kCGWindowBounds as String] as? [String: NSNumber],
           let pixel = CMSampleBufferGetImageBuffer(buffer) {
            let x = CGFloat(bounds["X"]?.doubleValue ?? 0)
            let y = CGFloat(bounds["Y"]?.doubleValue ?? 0)
            let width = CGFloat(bounds["Width"]?.doubleValue ?? 0)
            let height = CGFloat(bounds["Height"]?.doubleValue ?? 0)
            let crop = CGRect(x: (x - displayFrame.minX) * scale,
                y: (displayFrame.maxY - y - height) * scale,
                width: width * scale, height: height * scale)
            saveImage(pixel, crop: crop, row: &row)
        }
        write(row)
    }

    private func saveImage(_ pixel: CVPixelBuffer, crop: CGRect,
                           row: inout [String: Any]) {
        let image = CIImage(cvPixelBuffer: pixel)
        guard let cgImage = context.createCGImage(image, from: crop),
              let representation = NSBitmapImageRep(cgImage: cgImage)
                .representation(using: .jpeg, properties: [.compressionFactor: 0.65]),
              imageBytes + representation.count <= 20_000_000 else { return }
        let name = String(format: "frame-%04d.jpg", sequence)
        let url = imageDirectory.appendingPathComponent(name)
        do {
            try representation.write(to: url, options: .atomic)
            savedImages += 1
            imageBytes += representation.count
            row["image"] = name
            row["imageBytes"] = representation.count
        } catch { row["imageError"] = String(describing: error) }
    }

    private func fingerprint(_ pixel: CVPixelBuffer) -> String {
        guard CVPixelBufferGetPixelFormatType(pixel) == kCVPixelFormatType_32BGRA,
              CVPixelBufferLockBaseAddress(pixel, .readOnly) == kCVReturnSuccess,
              let base = CVPixelBufferGetBaseAddress(pixel) else { return "unavailable" }
        defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixel)
        let pixelWidth = CVPixelBufferGetWidth(pixel)
        let pixelHeight = CVPixelBufferGetHeight(pixel)
        var hash: UInt64 = 14695981039346656037
        for iy in 0..<128 {
            let y = min(pixelHeight - 1, max(0,
                Int(fixedROI.minY + CGFloat(iy) * fixedROI.height / 128)))
            for ix in 0..<128 {
                let x = min(pixelWidth - 1, max(0,
                    Int(fixedROI.minX + CGFloat(ix) * fixedROI.width / 128)))
                let offset = y * rowBytes + x * 4
                for channel in 0..<4 {
                    hash = (hash ^ UInt64(bytes[offset + channel])) &* 1099511628211
                }
            }
        }
        return String(format: "%016llx", hash)
    }

    private func write(_ row: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: row,
            options: [.sortedKeys]) else { return }
        output.write(data)
        output.write(Data([0x0a]))
    }
}

func main() async throws {
    guard CommandLine.arguments.count == 4 ||
            (CommandLine.arguments.count == 5 && CommandLine.arguments[4] == "--fixed-roi"),
          let pid = Int32(CommandLine.arguments[1]),
          let seconds = Int(CommandLine.arguments[3]), (1...10).contains(seconds),
          CGPreflightScreenCaptureAccess() else {
        throw NSError(domain: "usage: external_frame_probe PID OUTPUT_DIRECTORY SECONDS(1...10) [--fixed-roi] or capture access unavailable", code: 2)
    }
    let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    guard !FileManager.default.fileExists(atPath: directory.path) else {
        throw NSError(domain: "output directory exists", code: 3)
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let log = directory.appendingPathComponent("frames.jsonl")
    FileManager.default.createFile(atPath: log.path, contents: nil)
    let handle = try FileHandle(forWritingTo: log)
    defer { try? handle.close() }
    let content = try await SCShareableContent.current
    guard let display = content.displays.first else {
        throw NSError(domain: "no display", code: 4)
    }
    let filter = SCContentFilter(display: display, excludingWindows: [])
    let config = SCStreamConfiguration()
    config.width = display.width
    config.height = display.height
    config.minimumFrameInterval = CMTime(value: 1, timescale: 120)
    config.queueDepth = 8
    config.showsCursor = false
    // macOS 메뉴바 scene은 ControlCenter 소유일 수 있어 대상 PID의 AXMenuExtra로 고정 영역을 잡습니다.
    let anchorQueryStartedMach = mach_absolute_time()
    guard let anchor = menuAnchor(for: pid) else {
        throw NSError(domain: "target menu anchor unavailable", code: 6)
    }
    let anchorQueryEndedMach = mach_absolute_time()
    let anchorX = anchor.bounds.midX
    let anchorY = anchor.bounds.minY
    let fixedPoints = CGRect(x: anchorX - 200, y: anchorY + 5,
        width: 400, height: 760)
    let fixedPixels = CGRect(x: (fixedPoints.minX - display.frame.minX) *
            CGFloat(display.width) / display.frame.width,
        y: (display.frame.maxY - fixedPoints.maxY) *
            CGFloat(display.height) / display.frame.height,
        width: fixedPoints.width * CGFloat(display.width) / display.frame.width,
        height: fixedPoints.height * CGFloat(display.height) / display.frame.height)
    let recorder = FrameRecorder(pid: pid, output: handle, imageDirectory: directory,
        displayFrame: display.frame,
        scale: CGFloat(display.width) / display.frame.width,
        fixedROI: fixedPixels,
        anchor: ["source": "targetAXMenuExtra", "pid": pid,
            "identifier": anchor.identifier,
            "queryStartedMach": anchorQueryStartedMach,
            "queryEndedMach": anchorQueryEndedMach,
            "bounds": ["x": anchor.bounds.minX, "y": anchor.bounds.minY,
                "width": anchor.bounds.width, "height": anchor.bounds.height]],
        captureFixedROI: CommandLine.arguments.count == 5)
    let stream = SCStream(filter: filter, configuration: config, delegate: recorder)
    try stream.addStreamOutput(recorder, type: .screen,
        sampleHandlerQueue: DispatchQueue(label: "resourceRunner.externalFrameProbe"))
    try await stream.startCapture()
    try await Task.sleep(for: .seconds(seconds))
    try await stream.stopCapture()
    if recorder.failed { throw NSError(domain: "capture stream stopped with error", code: 5) }
    print("frames=\(recorder.sequence) images=\(recorder.savedImages) bytes=\(recorder.imageBytes)")
}

Task {
    do { try await main(); exit(0) }
    catch { fputs("\(error)\n", stderr); exit(1) }
}
RunLoop.main.run()
