//
//  CPUCoreGridLayoutTests.swift
//  ResourceRunnerTests
//
//  task-001 검증 조건: 코어 수를 따라가는 격자의 행·열 분할을 덮습니다.
//

import Testing
@testable import ResourceRunner

/// 실측 표(DESIGN §근거 「격자 후보의 실측」)가 정한 코어 수별 행·열입니다.
private let expectedShapes: [(coreCount: Int, rowCount: Int, columnCount: Int)] = [
    (8, 1, 8),
    (10, 2, 5),
    (14, 2, 7),
    (16, 2, 8),
    (24, 3, 8),
    (64, 8, 8)
]

@Suite("CPU 코어 격자 행·열 분할")
struct CPUCoreGridLayoutTests {
    @Test("코어 수별 행·열이 실측 표와 같다", arguments: expectedShapes.map(\.coreCount))
    func rowAndColumnCountMatchesMeasuredTable(coreCount: Int) {
        let expected = expectedShapes.first { $0.coreCount == coreCount }!
        let rows = CPUCoreGridLayout.rows(coreCount: coreCount)

        #expect(rows.count == expected.rowCount)
        #expect(rows.first?.count == expected.columnCount)
    }

    @Test("모든 행을 이어 붙이면 0부터 코어 수 - 1까지가 순서대로 한 번씩 나온다", arguments: 1...80)
    func concatenatedRowsCoverEveryCoreIndexInOrder(coreCount: Int) {
        let rows = CPUCoreGridLayout.rows(coreCount: coreCount)

        #expect(rows.flatMap { $0 } == Array(0..<coreCount))
    }

    @Test("각 행 안에서 코어 인덱스가 오름차순이다", arguments: 1...80)
    func eachRowIsAscending(coreCount: Int) {
        for row in CPUCoreGridLayout.rows(coreCount: coreCount) {
            #expect(row == row.sorted())
            #expect(Set(row).count == row.count)
        }
    }

    @Test("마지막 행을 뺀 모든 행의 길이가 같고 마지막 행은 그보다 길지 않다", arguments: 1...80)
    func onlyTheLastRowIsShorter(coreCount: Int) {
        let rows = CPUCoreGridLayout.rows(coreCount: coreCount)
        guard let columnCount = rows.first?.count else {
            Issue.record("코어 \(coreCount)에서 행이 하나도 없습니다")
            return
        }

        for row in rows.dropLast() {
            #expect(row.count == columnCount)
        }
        #expect(rows.last.map { $0.count <= columnCount } == true)
        #expect(rows.last.map { $0.count >= 1 } == true)
    }

    @Test("어떤 코어 수에서도 열 수가 열 상한을 넘지 않는다", arguments: 1...80)
    func columnCountNeverExceedsMaximum(coreCount: Int) {
        for row in CPUCoreGridLayout.rows(coreCount: coreCount) {
            #expect(row.count <= CPUCoreGridLayout.maximumColumnCount)
        }
    }

    @Test("코어 수 0이면 빈 배열이다")
    func zeroCoresProducesNoRows() {
        #expect(CPUCoreGridLayout.rows(coreCount: 0).isEmpty)
    }

    @Test("코어 수 1이면 1행 1열이다")
    func oneCoreProducesSingleCell() {
        #expect(CPUCoreGridLayout.rows(coreCount: 1) == [[0]])
    }
}
