//
//  DashboardProcessListDisplayUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/17/26.
//

import XCTest

/// 상세 팝업 앱별 하위 프로세스 목록의 화면 표시 회귀 테스트(SPEC §5.2, SPEC §5.6).
///
/// 정렬 기준 안내 문구·앱 행 값·하위 프로세스 행 이름이 실제로 화면에 나타나는지, 그리고 앱 행 값이
/// `ApplicationProcessGroup.sortValue`(정렬에 쓴 바로 그 합계)에서 온 것인지를 직접 확인합니다.
/// 이 세 성질을 지우거나(머리글 삭제, 값을 `EmptyView()`로, 하위 행을 `PID`만으로 축소) 다른 계산으로
/// 바꿔치기해도(Memory 상세에 CPU 값을 흘려보내는 것처럼) 기존 단위·UI 테스트가 하나도 잡지 못했던
/// 결함(verify 반려 근거 1)의 회귀 테스트입니다.
///
/// `ResourceRunnerUITests-Runner` 자신의 앱 행은 `AppRow-<앱 키>` 식별자로 결정적으로 추적할 수 있고
/// (`DashboardDetailExpansionUITests`와 같은 관례), 테스트가 끝날 때까지 항상 살아 있으므로 CPU 쪽 단언에
/// 이 행을 그대로 씁니다. Memory 값이 실제로 `sortValue`에서 왔는지는 개별 앱을 특정하지 않고, 목록에
/// 나타나는 모든 앱 행이 바이트 단위(KB·MB·GB)로 표시되는지를 확인합니다 — 실행 중인 프로세스의 메모리
/// 사용량은 항상 수백 바이트를 훨씬 넘으므로, `groupValueText`에 CPU 사용률(0~수백대 숫자)처럼 훨씬 작은
/// 값이 흘러들면 `ByteCountFormatter`가 "N bytes"로 표시해 이 단언이 실패합니다.
final class DashboardProcessListDisplayUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func detailValue(_ app: XCUIApplication, containing substring: String) -> XCUIElement {
        app.popovers.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", substring)).firstMatch
    }

    private func openDashboard(_ app: XCUIApplication) -> XCUIElement {
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")
        statusItem.click()

        let cpuCard = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "팝오버를 연 뒤 CPU 카드가 나타나지 않았습니다.")

        XCTAssertTrue(
            waitUntil({ !cpuCard.label.contains("수집 중") }, timeout: 5),
            "CPU 카드가 5초 안에 수집 중 상태를 벗어나지 못했습니다. 실제 값: \(cpuCard.label)"
        )
        return cpuCard
    }

    private func isExpanded(_ triangle: XCUIElement) -> Bool {
        (triangle.value as? NSNumber)?.intValue == 1
    }

    private func clickRowLabel(_ triangle: XCUIElement) {
        triangle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 8))
            .click()
    }

    @MainActor
    private func openCPUDetailAndFindRunnerRow(_ app: XCUIApplication) -> XCUIElement {
        let loadAverageText = detailValue(app, containing: "Load Average")
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(loadAverageText.waitForExistence(timeout: 2), "⌘1로 CPU 상세가 나타나지 않았습니다.")

        let triangle = app.popovers.descendants(matching: .disclosureTriangle)
            .matching(NSPredicate(format: "identifier CONTAINS %@", "ResourceRunnerUITests-Runner.app"))
            .firstMatch
        XCTAssertTrue(
            waitUntil({ triangle.exists }, timeout: 5),
            "테스트 러너 자신의 행을 앱 목록에서 찾지 못했습니다 — 프로세스 조사 결과가 아직 도착하지 않았을 수 있습니다."
        )
        XCTAssertTrue(
            waitUntil({ triangle.isHittable }, timeout: 5),
            "테스트 러너 행이 화면에 보이도록 스크롤되지 않았습니다."
        )
        return triangle
    }

    /// 머리글(정렬 기준 안내)과 앱 행 값이 CPU 상세에 실제로 나타나는지 확인합니다.
    /// 머리글 `Text`를 지우거나 앱 행 값을 `EmptyView()`로 바꾸면 각각 실패해야 합니다.
    @MainActor
    func testCPUProcessListShowsSortHeaderAndAppRowValue() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)
        let triangle = openCPUDetailAndFindRunnerRow(app)

        XCTAssertTrue(
            detailValue(app, containing: "전체 프로세스").exists,
            "정렬 기준을 알리는 머리글이 CPU 상세에 나타나지 않았습니다."
        )

        // DisclosureTriangle의 접근성 라벨은 "표시 이름, 값" 형태로 합쳐집니다(`ApplicationProcessGroupRow`).
        // 값이 `EmptyView()`로 사라지면 쉼표 뒤 값 부분이 없어져 이 조건이 실패합니다.
        XCTAssertTrue(
            triangle.label.contains("ResourceRunnerUITests-Runner") && triangle.label.contains("%"),
            "테스트 러너 앱 행에 이름과 값이 함께 나타나지 않았습니다. 실제 라벨: \(triangle.label)"
        )
    }

    /// 앱 행을 펼쳤을 때 하위 프로세스 행이 실행 파일 이름과 PID를 함께 보여주는지 확인합니다.
    /// 하위 행을 `Text("PID \(process.pid)")`로 축소하면(이름·괄호 서식 소실) 실패해야 합니다.
    @MainActor
    func testChildProcessRowShowsExecutableNameAlongsidePID() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)
        let triangle = openCPUDetailAndFindRunnerRow(app)

        clickRowLabel(triangle)
        XCTAssertTrue(
            waitUntil({ triangle.exists && isExpanded(triangle) }, timeout: 3),
            "행 중앙 클릭 직후 펼쳐지지 않았습니다."
        )

        let childProcessRow = app.popovers.staticTexts
            .matching(NSPredicate(format: "value CONTAINS %@", "(PID"))
            .firstMatch
        XCTAssertTrue(
            childProcessRow.waitForExistence(timeout: 2),
            "펼친 뒤에도 \"이름 (PID 번호)\" 형식의 하위 프로세스 행이 나타나지 않았습니다."
        )
    }

    /// Memory 상세의 모든 앱 행 값이 바이트 단위(KB·MB·GB)로 표시되는지 확인합니다.
    /// 값을 `EmptyView()`로 지우면 앱 행이 라벨만 남아 이 조건이 실패하고, CPU 사용률처럼 훨씬 작은 값을
    /// 대신 흘려보내면(별도 계산 mutation) `ByteCountFormatter`가 "N bytes"로 표시해 실패합니다.
    @MainActor
    func testMemoryProcessListAppRowValuesUseByteUnitsNotRawNumbers() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)
        _ = openCPUDetailAndFindRunnerRow(app)

        let currentUsageHeading = detailValue(app, containing: "현재 사용량 순위")
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(currentUsageHeading.waitForExistence(timeout: 2), "⌘2로 Memory 상세가 나타나지 않았습니다.")

        XCTAssertTrue(
            waitUntil({ self.detailValue(app, containing: "전체 프로세스").exists }, timeout: 5),
            "정렬 기준을 알리는 머리글이 Memory 상세에 나타나지 않았습니다."
        )

        // 실행 중인 앱이 수백 개일 수 있고 `allElementsBoundByIndex`로 전부 순회하면
        // 접근성 쿼리 비용이 테스트 하나를 5분 가까이 끌고 갑니다(실측 283초).
        // 값 서식은 모든 행이 같은 `groupValueText` 클로저 하나를 지나므로 앞쪽 몇 행만 봐도
        // 서식이 바뀌치기된 것을 잡습니다 — 표본을 앞 3개로 제한합니다.
        let allGroupRows = app.popovers.descendants(matching: .disclosureTriangle)
        let sampledRows = (0..<3).map { allGroupRows.element(boundBy: $0) }
        XCTAssertTrue(
            sampledRows[0].waitForExistence(timeout: 5),
            "Memory 상세에 앱별 하위 프로세스 그룹 행이 하나도 나타나지 않았습니다."
        )

        for row in sampledRows where row.exists {
            let label = row.label
            XCTAssertTrue(
                label.contains("KB") || label.contains("MB") || label.contains("GB"),
                "앱 행 값이 바이트 단위로 표시되지 않았습니다(별도 계산으로 바꿔치기됐거나 값이 비어 있을 수 있습니다). 실제 라벨: \(label)"
            )
            XCTAssertFalse(
                label.contains("bytes"),
                "앱 행 값이 \"N bytes\"로 표시됐습니다 — CPU 사용률처럼 훨씬 작은 값이 잘못 흘러든 것으로 보입니다. 실제 라벨: \(label)"
            )
        }
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
