//
//  DashboardDetailExpansionUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/17/26.
//

import XCTest

/// 상세 팝업의 앱 항목 펼침 결함(SPEC §5.2, SPEC §5.6) 회귀 테스트.
///
/// 진짜 원인은 매초 재렌더링이 아니라 클릭 반응 영역이었습니다 — `DisclosureGroup`의 기본 동작은 왼쪽
/// 삼각형 아이콘만 토글 대상으로 삼고, 라벨(앱 이름·값) 위를 클릭해도 반응하지 않습니다. 그래서 이 테스트의
/// 핵심 단언은 "행 중앙(라벨·값 위치)을 클릭해도 펼쳐지는가"입니다. `AXDisclosureTriangle`의 접근성 프레임은
/// 행 전체 너비로 보고되므로, 이 요소의 좌표를 그대로 써서 중앙·왼쪽 끝을 구분해 클릭합니다.
///
/// 앱 목록은 매 tick CPU 사용량 합계 내림차순으로 다시 정렬되므로, 화면 위치나 표시 이름으로 행을 잡으면
/// 클릭 시점과 확인 시점 사이에 다른 앱을 가리킬 수 있습니다. `ApplicationProcessGroupListView`가 각 행에
/// 붙이는 `AppRow-<앱 키>` 식별자로 같은 행을 계속 추적합니다 — 이 테스트 자신을 구동하는
/// `ResourceRunnerUITests-Runner` 프로세스는 테스트가 끝날 때까지 항상 살아 있으므로, 목록에서 사라지거나
/// 종료될 걱정 없이 추적할 수 있는 안정적인 대상입니다.
///
/// `AXDisclosureTriangle`의 실제 반응 영역은 왼쪽 삼각형 아이콘 부분뿐이었고, 그 프레임의 맨 왼쪽 몇 pt는
/// `ScrollView`가 잘라내는 영역 밖이라 클릭하면 팝오버 바깥을 클릭한 것으로 처리되어 부모·자식 팝오버가
/// 통째로 닫혔습니다. 왼쪽 끝을 클릭해도 팝오버가 살아남는지를 별도로 확인합니다.
/// `value`는 문자열이 아니라 `NSNumber`(0/1)로 노출되므로 비교할 때 문자열로 캐스팅하지 않습니다.
final class DashboardDetailExpansionUITests: XCTestCase {

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

    /// 행 라벨(앱 이름·값이 있는 첫 줄) 위를 클릭합니다. 펼쳐지면 이 요소의 접근성 프레임이 하위 프로세스
    /// 행까지 포함해 세로로 커지므로, 프레임 중앙이 아니라 위쪽 끝에서 고정 픽셀만큼만 내려온 자리를 써야
    /// 펼침 여부와 상관없이 항상 라벨 줄을 클릭합니다.
    private func clickRowLabel(_ triangle: XCUIElement) {
        triangle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 8))
            .click()
    }

    /// CPU 상세를 열고 테스트 러너 자신의 앱 행을 나타내는 `AXDisclosureTriangle`을 찾아 돌려줍니다.
    /// 이 요소의 접근성 프레임이 행 전체 너비로 보고되므로, 반환값의 좌표로 행 중앙·왼쪽 끝을 모두 클릭할 수 있습니다.
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

    /// 이번 결함 수정의 핵심 단언 — 행 중앙(라벨·값이 있는 자리)을 클릭해도 펼쳐져야 합니다.
    /// 기본 `DisclosureGroup` 동작(삼각형만 반응)만 남아 있으면 이 클릭은 아무 효과가 없어야 실패합니다.
    /// 펼친 뒤 1초 넘게 기다려 최소 한 번 이상 tick 재렌더링을 거친 뒤에도 계속 펼쳐져 있는지도 함께 확인합니다.
    @MainActor
    func testRowCenterClickExpandsAndPersistsAcrossRerenders() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)
        let triangle = openCPUDetailAndFindRunnerRow(app)

        // 라벨(앱 이름)과 값이 있는 자리이지 삼각형 아이콘 자리가 아닙니다.
        clickRowLabel(triangle)

        XCTAssertTrue(
            waitUntil({ triangle.exists && isExpanded(triangle) }, timeout: 3),
            "행 중앙 클릭 직후 펼쳐지지 않았습니다. 현재 값: \(String(describing: triangle.value))"
        )

        let childProcessRow = app.popovers.staticTexts
            .matching(NSPredicate(format: "value CONTAINS %@", "PID"))
            .firstMatch
        XCTAssertTrue(childProcessRow.waitForExistence(timeout: 2), "펼친 뒤에도 하위 프로세스 행이 나타나지 않았습니다.")

        // 이 앱은 약 1초마다 최신 조사 결과로 다시 그립니다. 최소 한 번 이상 그 재렌더링을 거친 뒤에도
        // 펼침 상태와 하위 프로세스 행이 그대로인지가 이번 결함의 핵심입니다.
        Thread.sleep(forTimeInterval: 2.5)

        XCTAssertTrue(
            triangle.exists && isExpanded(triangle),
            "1초 이상(재렌더링 이후)이 지난 뒤 펼침이 유지되지 않았습니다."
        )
        XCTAssertTrue(childProcessRow.exists, "재렌더링 이후 하위 프로세스 행이 사라졌습니다.")
    }

    /// 펼친 행을 다시 중앙 클릭하면 접혀야 합니다.
    @MainActor
    func testRowCenterClickTogglesClosedOnSecondClick() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)
        let triangle = openCPUDetailAndFindRunnerRow(app)

        clickRowLabel(triangle)
        XCTAssertTrue(
            waitUntil({ triangle.exists && isExpanded(triangle) }, timeout: 3),
            "행 중앙 클릭 직후 펼쳐지지 않았습니다."
        )

        clickRowLabel(triangle)
        XCTAssertTrue(
            waitUntil({ triangle.exists && !isExpanded(triangle) }, timeout: 3),
            "다시 중앙을 클릭했는데도 접히지 않았습니다."
        )
    }

    /// 행 왼쪽 끝은 `ScrollView` 클립 경계 바로 위에 걸쳐 있던 자리라, 이번 수정 전에는 이 자리를 클릭하면
    /// 팝오버 바깥 클릭으로 처리되어 부모·자식 팝오버가 통째로 닫혔습니다. 그 회귀를 고정합니다.
    @MainActor
    func testLeftEdgeClickDoesNotDismissPopover() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)
        let triangle = openCPUDetailAndFindRunnerRow(app)

        XCTAssertEqual(app.popovers.count, 2, "CPU 카드를 선택하면 자식 팝오버가 열려 팝오버 수가 2가 되어야 합니다.")

        triangle.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: 2, dy: 0))
            .click()

        XCTAssertEqual(
            app.popovers.count, 2,
            "행 왼쪽 끝을 클릭한 뒤 팝오버 수가 줄었습니다 — 팝오버 밖 클릭으로 처리되어 닫힌 것으로 보입니다."
        )
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
