//
//  DetailAccessibilityFormattingTests.swift
//  ResourceRunnerTests
//
//  task-005 검증 조건: 코어 칸과 하위 프로세스 이름 줄의 접근성 문자열을 순수 함수로 검증합니다.
//

import Testing
@testable import ResourceRunner

@Suite("CPU 코어 칸 접근성 서식")
struct CPUCoreUsageAccessibilityFormattingTests {
    @Test("이름·값·식별자가 화면 번호와 수치에서 갈리지 않는다")
    func stringsShareTheDisplayedCoreIndexAndValueFormatting() {
        let coreIndex = 13
        let usage = 12.5

        #expect(CPUCoreUsageFormatting.accessibilityLabel(coreIndex: coreIndex) == "코어 13")
        #expect(
            CPUCoreUsageFormatting.accessibilityLabel(coreIndex: coreIndex)
                == "코어 \(CPUCoreUsageFormatting.coreNumberText(coreIndex: coreIndex))"
        )
        #expect(CPUCoreUsageFormatting.accessibilityValue(usage) == "13%")
        #expect(
            CPUCoreUsageFormatting.accessibilityValue(usage)
                == CPUCoreUsageFormatting.valueText(usage)
        )
        #expect(CPUCoreUsageFormatting.cellAccessibilityIdentifier(coreIndex: coreIndex) == "CPUCore-13")
    }

    @Test("코어 수가 달라도 모든 칸 식별자가 번호를 보존하고 겹치지 않는다", arguments: [1, 8, 14, 24, 64])
    func identifiersAreUniqueForEveryCore(coreCount: Int) {
        let identifiers = (0..<coreCount).map {
            CPUCoreUsageFormatting.cellAccessibilityIdentifier(coreIndex: $0)
        }

        #expect(Set(identifiers).count == coreCount)
        #expect(identifiers == (0..<coreCount).map { "CPUCore-\($0)" })
    }

    @Test("화면 수치와 접근성 값은 경계 반올림에서도 같은 문자열이다", arguments: [0.0, 0.49, 0.5, 12.49, 12.5, 99.5, 100.0])
    func accessibilityValueUsesTheDisplayedRounding(_ usage: Double) {
        #expect(
            CPUCoreUsageFormatting.accessibilityValue(usage)
                == CPUCoreUsageFormatting.valueText(usage)
        )
        #expect(CPUCoreUsageFormatting.accessibilityValue(usage).hasSuffix("%"))
    }
}

@Suite("하위 프로세스 이름 줄 접근성 서식")
struct ApplicationProcessRowAccessibilityFormattingTests {
    @Test("소속 앱·실행 파일 이름·PID가 모두 들어간다")
    func labelContainsApplicationExecutableAndPID() {
        let process = ApplicationProcessDetail(
            pid: 12_345,
            executableName: "Google Chrome Helper (Renderer)",
            cpuUsagePercent: 12.3,
            residentBytes: 1_024,
            isTranslated: true
        )

        let label = ApplicationProcessRowFormatting.childAccessibilityLabel(
            applicationDisplayName: "Google Chrome",
            process: process
        )

        #expect(label == "Google Chrome, Google Chrome Helper (Renderer) (PID 12345)")
        #expect(label.contains("Google Chrome"))
        #expect(label.contains(process.executableName))
        #expect(label.contains("PID \(process.pid)"))
    }
}
