import ApplicationServices
import CoreGraphics
import Foundation

// 대상 프로세스로 향하는 mouse-up을 읽기 전용 tap에서 기록한다.
final class EventRecorder {
    let output: FileHandle
    var count = 0

    init(output: FileHandle) { self.output = output }

    func record(_ event: CGEvent) {
        count += 1
        let row: [String: Any] = ["sequence": count,
            "eventTimestamp": event.timestamp,
            "observedMach": mach_absolute_time(),
            "x": event.location.x, "y": event.location.y]
        guard let data = try? JSONSerialization.data(withJSONObject: row,
            options: [.sortedKeys]) else { return }
        output.write(data)
        output.write(Data([0x0a]))
    }
}

guard CommandLine.arguments.count == 4,
      let pid = Int32(CommandLine.arguments[1]),
      let seconds = Int(CommandLine.arguments[3]), (1...10).contains(seconds),
      CGPreflightListenEventAccess() else {
    fputs("usage: target_event_probe PID OUTPUT_JSONL SECONDS(1...10) or event access unavailable\n", stderr)
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard !FileManager.default.fileExists(atPath: output.path) else {
    fputs("output exists\n", stderr)
    exit(3)
}
FileManager.default.createFile(atPath: output.path, contents: nil)
let handle = try FileHandle(forWritingTo: output)
let recorder = EventRecorder(output: handle)
let opaque = Unmanaged.passUnretained(recorder).toOpaque()
let mask: CGEventMask = 1 << CGEventType.leftMouseUp.rawValue
guard let tap = CGEvent.tapCreateForPid(pid: pid, place: .tailAppendEventTap,
    options: .listenOnly, eventsOfInterest: mask,
    callback: { _, type, event, userInfo in
        if type == .leftMouseUp, let userInfo {
            Unmanaged<EventRecorder>.fromOpaque(userInfo).takeUnretainedValue().record(event)
        }
        return Unmanaged.passUnretained(event)
    }, userInfo: opaque) else {
    fputs("target event tap unavailable\n", stderr)
    exit(4)
}
let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
RunLoop.current.run(until: Date().addingTimeInterval(TimeInterval(seconds)))
CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
try handle.close()
print("mouseUps=\(recorder.count)")
