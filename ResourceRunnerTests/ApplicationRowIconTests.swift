//
//  ApplicationRowIconTests.swift
//  ResourceRunnerTests
//
//  task-010 검증 조건: 순위·목록 행 앞 아이콘 자리의 크기·내용·접근성 감춤을 확인합니다.
//

import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

/// 미리 정해 둔 아이콘만 돌려주는 가짜 제공자. 없는 키에는 `nil`을 돌려주므로
/// 「아이콘을 얻지 못한 행」을 시스템 상태와 무관하게 만들 수 있습니다.
@MainActor
final class StubApplicationIconProvider: ApplicationIconProviding {
    private let images: [ApplicationKey: NSImage]
    private(set) var requestedKeys: [ApplicationKey] = []

    init(images: [ApplicationKey: NSImage] = [:]) {
        self.images = images
    }

    func icon(for key: ApplicationKey) -> NSImage? {
        requestedKeys.append(key)
        return images[key]
    }
}

@MainActor
struct ApplicationRowIconTests {

    private static let knownKey = ApplicationKey(value: "/Applications/Safari.app")
    private static let unknownKey = ApplicationKey(value: "/Applications/NoIcon.app")

    private static func stub() -> StubApplicationIconProvider {
        StubApplicationIconProvider(images: [knownKey: NSImage(size: NSSize(width: 16, height: 16))])
    }

    /// 뷰의 렌더 크기를 잽니다. 자리 크기가 세 경우에 같은지는 이 측정으로만 관찰됩니다.
    private static func measuredSize(_ view: some View) -> CGSize {
        NSHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: CGFloat(248), height: CGFloat.greatestFiniteMagnitude))
    }

    // MARK: - 그릴 내용 결정

    /// 캐시가 이미지를 돌려주는 입력과 돌려주지 않는 입력이 구분되어야 합니다 —
    /// 행 조립이 캐시를 아예 조회하지 않게 되면(아이콘을 통째로 지우는 mutation) 이 구분이 무너집니다.
    @Test func resolvesCachedImageAndMissingIconAsDifferentContents() throws {
        let provider = Self.stub()

        let resolved = ApplicationRowIconLayout.content(for: Self.knownKey, from: provider)
        let missing = ApplicationRowIconLayout.content(for: Self.unknownKey, from: provider)

        guard case .icon(let image) = resolved else {
            Issue.record("아이콘이 있는 앱 키에서 `.icon`이 나오지 않았습니다: \(resolved)")
            return
        }
        #expect(image === (try #require(provider.icon(for: Self.knownKey))))
        #expect(missing == .missing)
        #expect(resolved != missing)
    }

    /// 값이 없는 줄·조사 실패 줄은 물을 앱이 없으므로 캐시를 조회하지 않고 자리만 잡습니다.
    @Test func reservesTheSlotWithoutQueryingTheCacheWhenThereIsNoApplication() {
        let provider = Self.stub()

        let content = ApplicationRowIconLayout.content(for: nil, from: provider)

        #expect(content == .reserved)
        #expect(provider.requestedKeys.isEmpty)
    }

    // MARK: - 자리 크기

    /// task-010 검증 조건: 아이콘이 있는 행과 없는 행, 앱이 없는 줄의 앞쪽 자리 크기가 같아야 합니다.
    /// 아이콘이 있는 행에만 자리를 두거나 중립 기호를 지워 자리를 없애는 mutation이 여기서 실패합니다.
    @Test func iconSlotOccupiesTheSameSizeForEveryContent() throws {
        let image = try #require(Self.stub().icon(for: Self.knownKey))
        let pointSize = ApplicationRowIconLayout.detailPointSize
        let contents: [ApplicationRowIconContent] = [.icon(image), .missing, .reserved]

        let sizes = contents.map { content in
            Self.measuredSize(ApplicationRowIconView(content: content, pointSize: pointSize))
        }

        try #require(sizes.count == 3)
        #expect(sizes[0] == CGSize(width: pointSize, height: pointSize), "아이콘이 있는 자리 크기가 다릅니다: \(sizes[0])")
        #expect(sizes[1] == sizes[0], "아이콘을 얻지 못한 자리 크기가 다릅니다: \(sizes[1]) vs \(sizes[0])")
        #expect(sizes[2] == sizes[0], "앱이 없는 줄의 자리 크기가 다릅니다: \(sizes[2]) vs \(sizes[0])")
    }

    /// task-010 검증 조건: 카드 아이콘 크기가 그 줄의 텍스트 높이를 넘으면 카드 높이가 늘어납니다.
    /// 기준은 카드 순위 행 수치가 실제로 쓰는 `value` 역할 한 줄의 렌더 높이이며, 리터럴이 아니라 여기서 잽니다.
    @Test func cardIconIsNotTallerThanTheRowTextItSitsOn() {
        let valueLineHeight = Self.measuredSize(
            Text("Ag").dashboardTypography(DashboardStyle.TypographyRole.value)
        ).height

        #expect(
            ApplicationRowIconLayout.cardPointSize <= valueLineHeight,
            "카드 아이콘 크기 \(ApplicationRowIconLayout.cardPointSize)pt가 값 역할 줄 높이 \(valueLineHeight)pt를 넘습니다"
        )
    }

    /// 상세 자리는 캐시가 담고 있는 표시 크기를 넘지 않아야 확대로 흐려지지 않습니다.
    /// 두 크기 모두 하나의 캐시 이미지에서 그립니다(ANALYSIS §5 DP12).
    @Test func detailIconIsNotLargerThanTheCachedImage() {
        #expect(ApplicationRowIconLayout.detailPointSize <= ApplicationIconCache.displayPointSize)
        #expect(ApplicationRowIconLayout.cardPointSize <= ApplicationIconCache.displayPointSize)
    }

    /// task-010 검증 조건: 값 없음 줄과 조사 실패 줄에도 같은 크기의 자리가 남아야 합니다.
    /// 자리 목록이 정원 길이보다 짧아지는 mutation — 아이콘이 있는 줄만 남기거나 값 없음·실패 줄을 빼면 —
    /// 이 길이 단언에서 실패합니다.
    @Test func everyCardRankingRowGetsAnIconSlot() throws {
        let entries = (0..<3).map { index in
            ApplicationRankingEntry(
                key: ApplicationKey(value: "/Applications/App\(index).app"),
                displayName: "App\(index)",
                value: Double(index)
            )
        }

        let partial = ApplicationRowIconLayout.cardRowIconKeys(entries: entries, failed: false, capacity: 5)
        let failed = ApplicationRowIconLayout.cardRowIconKeys(entries: entries, failed: true, capacity: 5)
        let empty = ApplicationRowIconLayout.cardRowIconKeys(entries: [], failed: false, capacity: 5)

        try #require(partial.count == 5)
        #expect(partial[0] == entries[0].key)
        #expect(partial[1] == entries[1].key)
        #expect(partial[2] == entries[2].key)
        #expect(partial[3] == nil)
        #expect(partial[4] == nil)

        try #require(failed.count == 5)
        #expect(failed.allSatisfy { $0 == nil }, "조사 실패 줄이 앱을 가리켰습니다: \(failed)")

        try #require(empty.count == 5)
        #expect(empty.allSatisfy { $0 == nil }, "값이 없는 줄이 앱을 가리켰습니다: \(empty)")
    }

    // MARK: - 중립 기호와 접근성

    /// 중립 기호가 실제로 그려질 수 있어야 「아이콘 없음」이 화면에 드러납니다 —
    /// 이름이 틀리면 SwiftUI가 조용히 빈 자리를 그립니다.
    @Test func neutralSymbolResolvesToARealSystemSymbol() {
        let symbol = NSImage(
            systemSymbolName: ApplicationRowIconLayout.missingSymbolName,
            accessibilityDescription: nil
        )

        #expect(symbol != nil, "중립 기호 `\(ApplicationRowIconLayout.missingSymbolName)`를 시스템에서 찾지 못했습니다")
    }

    /// 아이콘은 같은 행의 앱 이름과 정보가 겹치므로 접근성 계층에 독립 요소로 나타나지 않아야 합니다.
    /// 이 상수를 `false`로 바꾸는 mutation이 여기서 실패합니다 —
    /// 접근성 요소 수로는 잡을 수 없습니다(`ApplicationRowIconLayout.isHiddenFromAccessibility` 주석).
    @Test func rowIconIsHiddenFromAccessibility() {
        #expect(ApplicationRowIconLayout.isHiddenFromAccessibility)
    }
}
