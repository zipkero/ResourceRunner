import Foundation

/// 현재 속도·누적 바이트·링크 비트율·드라이버 작업률의 단위를 섞지 않습니다.
nonisolated enum ResourceQuantityFormatter {
    static func byteRate(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite, value >= 0 else { return "-" }
        let units: [(Double, String)] = [
            (Double(1 << 30), "GB/s"), (Double(1 << 20), "MB/s"),
            (Double(1 << 10), "KB/s"), (1, "B/s")
        ]
        let selected = units.first { value >= $0.0 } ?? units[units.count - 1]
        return formatted(value / selected.0, unit: selected.1, locale: locale)
    }

    static func bytes(_ value: UInt64, locale: Locale = .current) -> String {
        let units: [(Double, String)] = [
            (Double(1 << 40), "TB"), (Double(1 << 30), "GB"),
            (Double(1 << 20), "MB"), (Double(1 << 10), "KB"), (1, "B")
        ]
        let selected = units.first { Double(value) >= $0.0 } ?? units[units.count - 1]
        return formatted(Double(value) / selected.0, unit: selected.1, locale: locale)
    }

    /// 저장 공간은 macOS와 같은 십진 단위로 표시하며 속도·누적량의 이진 단위와 분리합니다.
    static func storageBytes(_ value: UInt64, locale: Locale = .current) -> String {
        let units: [(Double, String)] = [
            (1_000_000_000_000, "TB"), (1_000_000_000, "GB"),
            (1_000_000, "MB"), (1_000, "KB"), (1, "B")
        ]
        let selected = units.first { Double(value) >= $0.0 } ?? units[units.count - 1]
        return formatted(Double(value) / selected.0, unit: selected.1, locale: locale)
    }

    static func linkBitsPerSecond(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite, value > 0 else { return "-" }
        let units: [(Double, String)] = [
            (1_000_000_000, "Gbit/s"), (1_000_000, "Mbit/s"),
            (1_000, "Kbit/s"), (1, "bit/s")
        ]
        let selected = units.first { value >= $0.0 } ?? units[units.count - 1]
        return formatted(value / selected.0, unit: selected.1, locale: locale)
    }

    static func driverOperationsPerSecond(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite, value >= 0 else { return "-" }
        return formatted(value, unit: "회/s", locale: locale)
    }

    private static func formatted(_ value: Double, unit: String, locale: Locale) -> String {
        let minimum = 0.1.formatted(.number.locale(locale).precision(.fractionLength(1)))
        if value > 0 && value < 0.05 { return "<\(minimum) \(unit)" }
        let number = value.formatted(.number.locale(locale).precision(.fractionLength(1)))
        return "\(number) \(unit)"
    }
}
