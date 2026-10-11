import AppKit
import ApplicationServices
import CryptoKit
import Darwin
import Foundation

@_silgen_name("CGSessionCopyCurrentDictionary")
private func sessionDictionary() -> CFDictionary?

struct Sample: Encodable {
    let kind = "sample"
    let sequence: Int
    let scheduledNS: UInt64
    let actualNS: UInt64
    let delayNS: UInt64
    let wallTime: String
    let pid: Int32
    let executablePath: String?
    let startTicks: UInt64?
    let userTicks: UInt64?
    let systemTicks: UInt64?
    let timebaseNumer: UInt32
    let timebaseDenom: UInt32
    let cpuPercent: Double?
    let rssBytes: UInt64?
    let footprintBytes: UInt64?
    let lifetimeMaxFootprintBytes: UInt64?
    let state: String
    let session: String
    let settingsSHA256: String?
    let settingsSource: String
    let windowSHA256: String?
    let valid: Bool
    let reasons: [String]
}

struct Event: Encodable {
    let kind = "event"
    let sequence: Int
    let wallTime: String
    let name: String
    let value: String
}

func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func encode<T: Encodable>(_ value: T) throws -> Data {
    var data = try JSONEncoder().encode(value)
    data.append(10)
    return data
}

func nowString() -> String { ISO8601DateFormatter().string(from: Date()) }

func sessionState() -> String {
    guard let dictionary = sessionDictionary() as? [String: Any] else { return "unknown" }
    if let locked = dictionary["CGSSessionScreenIsLocked"] as? Bool, locked { return "locked" }
    if let onConsole = dictionary["kCGSessionOnConsoleKey"] as? Bool, !onConsole { return "inactive" }
    return "active"
}

func settingsFingerprint(_ domain: String) -> (String?, String) {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let sandbox = "\(home)/Library/Containers/\(domain)/Data/Library/Preferences/\(domain).plist"
    let global = "\(home)/Library/Preferences/\(domain).plist"
    let path = FileManager.default.fileExists(atPath: sandbox) ? sandbox : global
    guard let data = FileManager.default.contents(atPath: path),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        return (nil, path)
    }
    let preferences = plist["preferences.v1"]
    guard let preferences,
          JSONSerialization.isValidJSONObject(preferences),
          let canonical = try? JSONSerialization.data(withJSONObject: preferences, options: [.sortedKeys]) else {
        return ("absent", path)
    }
    return (digest(canonical), path)
}

func windowHash(_ pid: Int32) -> String? {
    guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    let relevant = windows.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }.map { window in
        let id = window[kCGWindowNumber as String] ?? "?"
        let layer = window[kCGWindowLayer as String] ?? "?"
        let bounds = window[kCGWindowBounds as String] as? [String: NSNumber] ?? [:]
        let geometry = ["X", "Y", "Width", "Height"].map { "\($0)=\(bounds[$0]?.doubleValue ?? .nan)" }.joined(separator: ",")
        return "\(id)|\(layer)|\(geometry)"
    }.sorted().joined(separator: ";")
    return digest(Data(relevant.utf8))
}

func process(_ pid: Int32) -> (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64)? {
    var task = proc_taskinfo()
    let count = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, Int32(MemoryLayout<proc_taskinfo>.size))
    guard count == MemoryLayout<proc_taskinfo>.size else { return nil }
    var usage = rusage_info_v4()
    let result = withUnsafeMutablePointer(to: &usage) { pointer in
        pointer.withMemoryRebound(to: Optional<rusage_info_t>.self, capacity: 1) {
            proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
        }
    }
    guard result == 0 else { return nil }
    return (task.pti_total_user, task.pti_total_system, usage.ri_resident_size,
            usage.ri_phys_footprint, usage.ri_lifetime_max_phys_footprint,
            usage.ri_proc_start_abstime)
}

func executablePath(_ pid: Int32) -> String? {
    var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
    guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
    return String(cString: buffer)
}

func nanos(_ ticks: UInt64, _ base: mach_timebase_info_data_t) -> UInt64? {
    guard base.numer > 0, base.denom > 0 else { return nil }
    let quotient = ticks / UInt64(base.denom)
    let remainder = ticks % UInt64(base.denom)
    let (whole, overflow1) = quotient.multipliedReportingOverflow(by: UInt64(base.numer))
    let (fraction, overflow2) = remainder.multipliedReportingOverflow(by: UInt64(base.numer))
    let (sum, overflow3) = whole.addingReportingOverflow(fraction / UInt64(base.denom))
    return overflow1 || overflow2 || overflow3 ? nil : sum
}

func run() throws {
    // 인자는 고정 절차만 받습니다. 측정 중 대상 앱과 설정은 읽기만 합니다.
    let args = CommandLine.arguments
    guard args.count == 21, args[1] == "--pid", args[3] == "--state", args[5] == "--domain",
          args[7] == "--output", args[9] == "--duration", args[11] == "--interval",
          args[13] == "--events", args[15] == "--exe", args[17] == "--sha", args[19] == "--max-bytes",
          let pid = Int32(args[2]),
          let duration = Int(args[10]), (1...1800).contains(duration),
          let interval = Double(args[12]), interval >= 0.25, interval <= 5,
          let requestedMax = Int(args[20]), (1024...32 * 1024 * 1024).contains(requestedMax) else {
        throw NSError(domain: "usage: measure --pid PID --state NAME --domain BUNDLE_ID --output PATH --duration 1..1800 --interval 0.25..5 --events PATH --exe PATH --sha SHA256 --max-bytes 1024..33554432", code: 2)
    }
    let state = args[4], domain = args[6], output = args[8], eventPath = args[14]
    let expectedPath = args[16], expectedSHA = args[18].lowercased()
    guard (1...64).contains(state.utf8.count), (1...256).contains(domain.utf8.count) else {
        throw NSError(domain: "state/domain length out of range", code: 10)
    }
    guard !FileManager.default.fileExists(atPath: output) else { throw NSError(domain: "output exists", code: 3) }
    guard let initialEvent = try? String(contentsOfFile: eventPath, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines), initialEvent == state else {
        throw NSError(domain: "event file must initially contain the declared state", code: 9)
    }
    guard executablePath(pid) == expectedPath,
          let binary = FileManager.default.contents(atPath: expectedPath),
          digest(binary) == expectedSHA else { throw NSError(domain: "executable identity mismatch", code: 8) }
    var base = mach_timebase_info_data_t()
    guard mach_timebase_info(&base) == KERN_SUCCESS, base.numer > 0, base.denom > 0 else {
        throw NSError(domain: "mach_timebase_info failed", code: 4)
    }
    guard let initial = process(pid), initial.5 > 0 else { throw NSError(domain: "initial process read failed", code: 5) }
    let initialSettings = settingsFingerprint(domain)
    let initialWindows = windowHash(pid)
    let initialSession = sessionState()
    guard initialSettings.0 != nil, initialWindows != nil, initialSession == "active" else {
        throw NSError(domain: "initial settings/window/session unavailable", code: 6)
    }
    FileManager.default.createFile(atPath: output, contents: nil)
    let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: output))
    defer { try? handle.close() }
    let maxBytes = requestedMax
    var bytes = 0
    func write<T: Encodable>(_ value: T, ending: Bool = false) throws {
        let data = try encode(value)
        guard bytes + data.count <= maxBytes - (ending ? 0 : 512) else {
            throw NSError(domain: "output_limit", code: 7)
        }
        try handle.write(contentsOf: data)
        bytes += data.count
    }
    let start = mach_continuous_time()
    let intervalNS = UInt64(interval * 1_000_000_000)
    let startNS = nanos(start, base)!
    var lastEvent = initialEvent
    var lastCPU: UInt64? = nil
    var lastActual: UInt64? = nil
    var lastContinuous: UInt64? = nil
    var lastAbsolute: UInt64? = nil
    var invalid = false
    var reason = "duration_complete"
    try write(Event(sequence: -1, wallTime: nowString(), name: "start",
                    value: "pid=\(pid) startTicks=\(initial.5) state=\(state) duration=\(duration) interval=\(interval) operator=\(initialEvent)"))
    for sequence in 0...Int(Double(duration) / interval) {
        let scheduled = startNS + UInt64(sequence) * intervalNS
        while true {
            let current = nanos(mach_continuous_time(), base)!
            if current >= scheduled { break }
            usleep(useconds_t(min((scheduled - current) / 1000, 100_000)))
        }
        let actual = nanos(mach_continuous_time(), base)!
        let continuous = mach_continuous_time()
        let absolute = mach_absolute_time()
        let reading = process(pid)
        let path = executablePath(pid)
        let settings = settingsFingerprint(domain)
        let windows = windowHash(pid)
        let session = sessionState()
        let observedEvent = (try? String(contentsOfFile: eventPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let event = observedEvent.utf8.count <= 256 ? observedEvent : "operator_event_oversize"
        var reasons: [String] = []
        if actual - scheduled > 250_000_000 { reasons.append("late_over_250ms") }
        if reading == nil { reasons.append("api_error") }
        if reading?.5 != initial.5 { reasons.append("pid_start_changed") }
        if path != expectedPath { reasons.append("executable_changed") }
        if settings != initialSettings { reasons.append("settings_changed") }
        if windows != initialWindows { reasons.append("windows_changed") }
        if session != "active" { reasons.append("session_\(session)") }
        if let oldContinuous = lastContinuous, let oldAbsolute = lastAbsolute,
           let elapsedContinuous = nanos(continuous - oldContinuous, base),
           let elapsedAbsolute = nanos(absolute - oldAbsolute, base),
           elapsedContinuous > elapsedAbsolute + 250_000_000 { reasons.append("sleep_transition") }
        let ticks = reading.flatMap { user, system, _, _, _, _ -> UInt64? in
            let (sum, overflow) = user.addingReportingOverflow(system)
            return overflow ? nil : sum
        }
        var cpu: Double? = nil
        if let ticks, let previous = lastCPU, let oldActual = lastActual {
            if ticks < previous { reasons.append("counter_reversed") }
            else if let deltaNS = nanos(ticks - previous, base), actual > oldActual {
                cpu = Double(deltaNS) / Double(actual - oldActual) * 100
            } else { reasons.append("cpu_conversion_failed") }
        }
        if ticks == nil { reasons.append("cpu_counter_unavailable") }
        if event != lastEvent {
            do {
                try write(Event(sequence: sequence, wallTime: nowString(), name: "operator_event", value: event))
            } catch {
                reason = "output_limit"
                invalid = true
                break
            }
            reasons.append("event_changed")
            lastEvent = event
        }
        if !reasons.isEmpty { invalid = true }
        let sample = Sample(sequence: sequence, scheduledNS: scheduled, actualNS: actual,
                            delayNS: actual - scheduled, wallTime: nowString(), pid: pid,
                            executablePath: path,
                            startTicks: reading?.5, userTicks: reading?.0, systemTicks: reading?.1,
                            timebaseNumer: base.numer, timebaseDenom: base.denom,
                            cpuPercent: cpu, rssBytes: reading?.2, footprintBytes: reading?.3,
                            lifetimeMaxFootprintBytes: reading?.4, state: state, session: session,
                            settingsSHA256: settings.0, settingsSource: settings.1,
                            windowSHA256: windows,
                            valid: reasons.isEmpty, reasons: reasons)
        do { try write(sample) } catch { reason = "output_limit"; invalid = true; break }
        lastCPU = ticks
        lastActual = actual
        lastContinuous = continuous
        lastAbsolute = absolute
    }
    try write(Event(sequence: -1, wallTime: nowString(), name: "end", value: "reason=\(reason) invalid=\(invalid) bytes=\(bytes)"), ending: true)
}

do { try run() } catch {
    fputs("measure: \(error)\n", stderr)
    exit(1)
}
