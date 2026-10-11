import AppKit
import ApplicationServices
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ScreenCaptureKit
import VideoToolbox

// 표시 프레임 시각과 callback 시점의 별도 창 목록 조회를 함께 기록한다.
final class FrameRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    let pid: Int32
    let output: FileHandle
    let imageDirectory: URL
    let displayFrame: CGRect
    let scale: CGFloat
    let fixedROI: CGRect
    let context = CIContext()
    let lock = NSLock()
    var sequence = 0
    var savedImages = 0
    var imageBytes = 0
    var failed = false

    init(pid: Int32, output: FileHandle, imageDirectory: URL,
         displayFrame: CGRect, scale: CGFloat, fixedROI: CGRect) {
        self.pid = pid
        self.output = output
        self.imageDirectory = imageDirectory
        self.displayFrame = displayFrame
        self.scale = scale
        self.fixedROI = fixedROI
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
        if status == SCFrameStatus.complete.rawValue,
           let pixel = CMSampleBufferGetImageBuffer(buffer) {
            row["fixedROIFingerprint"] = fingerprint(pixel)
        }
        if status == SCFrameStatus.complete.rawValue,
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
            let image = CIImage(cvPixelBuffer: pixel)
            if let cgImage = context.createCGImage(image, from: crop),
               let representation = NSBitmapImageRep(cgImage: cgImage)
                   .representation(using: .jpeg, properties: [.compressionFactor: 0.55]),
               imageBytes + representation.count <= 20_000_000 {
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
        }
        write(row)
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
    guard CommandLine.arguments.count == 4,
          let pid = Int32(CommandLine.arguments[1]),
          let seconds = Int(CommandLine.arguments[3]), (1...10).contains(seconds),
          CGPreflightScreenCaptureAccess() else {
        throw NSError(domain: "usage: external_frame_probe PID OUTPUT_DIRECTORY SECONDS(1...10) or capture access unavailable", code: 2)
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
    let menuWindows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly,
        .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
        .filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
    guard let menuBounds = menuWindows.compactMap({ window -> [String: NSNumber]? in
        guard (window[kCGWindowLayer as String] as? Int) == 103 else { return nil }
        return window[kCGWindowBounds as String] as? [String: NSNumber]
    }).first else { throw NSError(domain: "target menu anchor unavailable", code: 6) }
    let anchorX = CGFloat(menuBounds["X"]?.doubleValue ?? 0)
    let anchorY = CGFloat(menuBounds["Y"]?.doubleValue ?? 0)
    let fixedPoints = CGRect(x: anchorX - 200, y: anchorY + 5,
        width: 400, height: 760)
    let fixedPixels = CGRect(x: (fixedPoints.minX - display.frame.minX) *
            CGFloat(display.width) / display.frame.width,
        y: (fixedPoints.minY - display.frame.minY) *
            CGFloat(display.height) / display.frame.height,
        width: fixedPoints.width * CGFloat(display.width) / display.frame.width,
        height: fixedPoints.height * CGFloat(display.height) / display.frame.height)
    let recorder = FrameRecorder(pid: pid, output: handle, imageDirectory: directory,
        displayFrame: display.frame,
        scale: CGFloat(display.width) / display.frame.width,
        fixedROI: fixedPixels)
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
