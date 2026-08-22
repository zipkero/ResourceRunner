//
//  ApplicationIconCacheTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/21/26.
//

import AppKit
import Combine
import Observation
import SwiftUI
import Testing
@testable import ResourceRunner

/// 호출 횟수를 세는 가짜 아이콘 로더. 캐시가 시스템 호출을 실제로 몇 번 냈는지는
/// 이 기록으로만 관찰할 수 있습니다(task-009 검증 조건).
@MainActor
final class RecordingIconLoader {
    private(set) var requestedKeys: [ApplicationKey] = []
    private let result: (ApplicationKey) -> NSImage?

    init(result: @escaping (ApplicationKey) -> NSImage?) {
        self.result = result
    }

    var callCount: Int { requestedKeys.count }

    func load(_ key: ApplicationKey) -> NSImage? {
        requestedKeys.append(key)
        return result(key)
    }
}

@MainActor
struct ApplicationIconCacheTests {

    private static func key(_ value: String) -> ApplicationKey {
        ApplicationKey(value: "/Applications/\(value).app")
    }

    /// 원본 시스템 아이콘 대신 쓸 큰 이미지. 축소가 실제로 일어났는지 재려면 표시 크기보다 훨씬 커야 합니다.
    private static func makeImage(pointSize: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
    }

    @Test func loadsOnceForRepeatedLookupsOfTheSameKey() throws {
        let loader = RecordingIconLoader { _ in Self.makeImage(pointSize: 512) }
        let cache = ApplicationIconCache(load: loader.load)
        let key = Self.key("Safari")

        let first = cache.icon(for: key)
        let second = cache.icon(for: key)
        let third = cache.icon(for: key)

        #expect(loader.callCount == 1)
        #expect(loader.requestedKeys == [key])
        let cached = try #require(first)
        #expect(second === cached)
        #expect(third === cached)
    }

    /// 부정 결과 캐시. 이것이 없으면 아이콘을 얻지 못한 앱이 갱신 주기마다 다시 시스템을 부릅니다
    /// (ANALYSIS §5 DP11).
    @Test func remembersThatAnIconCouldNotBeObtained() {
        let loader = RecordingIconLoader { _ in nil }
        let cache = ApplicationIconCache(load: loader.load)
        let key = Self.key("Unknown")

        let results = [cache.icon(for: key), cache.icon(for: key), cache.icon(for: key)]

        #expect(loader.callCount == 1)
        #expect(results.allSatisfy { $0 == nil })
        #expect(cache.cachedKeyCount == 1)
    }

    /// 서로 다른 키가 상한을 넘어 들어와도 기억 항목 수가 상한에 머뭅니다.
    @Test func neverRemembersMoreKeysThanTheCapacity() {
        let loader = RecordingIconLoader { _ in Self.makeImage(pointSize: 512) }
        let cache = ApplicationIconCache(capacity: 8, load: loader.load)

        for index in 0..<40 {
            _ = cache.icon(for: Self.key("App\(index)"))
        }

        #expect(cache.cachedKeyCount == 8)
        #expect(loader.callCount == 40)
    }

    /// 축출 순서. 가장 오래전에 쓰인 키가 먼저 버려지고, 최근에 다시 쓰인 키는 나중에 들어온 키보다 오래 남습니다.
    /// 재조회에서 로더가 다시 불리는지로 어느 키가 버려졌는지를 관찰합니다.
    @Test func evictsTheLeastRecentlyUsedKeyFirst() {
        let loader = RecordingIconLoader { _ in Self.makeImage(pointSize: 512) }
        let cache = ApplicationIconCache(capacity: 3, load: loader.load)
        let first = Self.key("First")
        let second = Self.key("Second")
        let third = Self.key("Third")
        let fourth = Self.key("Fourth")

        _ = cache.icon(for: first)
        _ = cache.icon(for: second)
        _ = cache.icon(for: third)
        #expect(loader.callCount == 3)

        // 가장 오래된 항목을 다시 써서 최신으로 끌어올립니다.
        _ = cache.icon(for: first)
        #expect(loader.callCount == 3)

        // 상한을 넘겨 축출을 일으킵니다. 이 시점의 최장 미사용 항목은 `second`입니다.
        _ = cache.icon(for: fourth)
        #expect(loader.callCount == 4)
        #expect(cache.cachedKeyCount == 3)

        // 살아남은 키는 로더를 다시 부르지 않습니다.
        _ = cache.icon(for: first)
        _ = cache.icon(for: third)
        _ = cache.icon(for: fourth)
        #expect(loader.callCount == 4)

        // 버려진 키만 로더를 다시 부릅니다.
        _ = cache.icon(for: second)
        #expect(loader.callCount == 5)
        #expect(loader.requestedKeys == [first, second, third, fourth, second])
    }

    /// 상한 기본값. `ApplicationIdentityResolver`와 같은 규모로 두어 정상 상태에서 축출이 반복되지 않게 합니다.
    @Test func defaultCapacityIsFixed() {
        #expect(ApplicationIconCache.defaultCapacity == 512)
    }

    /// 캐시에 담기는 이미지는 원본이 아니라 표시 크기로 축소한 것입니다(ANALYSIS §5 DP11).
    @Test func cachesAnImageDownscaledToTheDisplaySize() throws {
        let source = Self.makeImage(pointSize: 512)
        let loader = RecordingIconLoader { _ in source }
        let cache = ApplicationIconCache(load: loader.load)

        let icon = try #require(cache.icon(for: Self.key("Safari")))

        #expect(icon !== source)
        #expect(icon.size == NSSize(width: 16, height: 16))
        let representations = icon.representations
        try #require(representations.count == 1)
        #expect(representations[0].pixelsWide == 32)
        #expect(representations[0].pixelsHigh == 32)
    }

    /// 캐시는 관찰 가능 객체가 아닙니다. 조회가 갱신 알림을 내면 목록 전체가 매 조회마다 다시 무효화됩니다
    /// (ANALYSIS §5 DP11).
    @Test func isNotAnObservableObject() {
        let cache: Any = ApplicationIconCache(load: { _ in nil })

        #expect(!(cache is any ObservableObject))
        #expect(!(cache is any Observable))
    }

    // MARK: - production 로더

    /// 아이콘을 얻지 못한 행에 중립 기호를 두기로 한 결정(ANALYSIS §5 DP12)이 화면에서 성립하려면
    /// production 로더가 실제로 `nil`을 낼 수 있어야 합니다.
    /// `NSWorkspace.shared.icon(forFile:)`는 없는 경로에도 일반 문서 아이콘을 돌려주므로
    /// 로더의 경로 존재 확인을 지우는 mutation이 이 단언에서 실패합니다.
    @Test func productionLoaderReturnsNoIconForAPathThatDoesNotExist() {
        let missingPaths = [
            "/Applications/DefinitelyNotInstalled-\(UUID().uuidString).app",
            "/nonexistent/abcdef",
            "",
            "not a path at all"
        ]

        for path in missingPaths {
            let icon = ApplicationIconCache.loadSystemIcon(for: ApplicationKey(value: path))
            #expect(icon == nil, "없는 경로 \"\(path)\"에서 아이콘이 돌아왔습니다")
        }
    }

    /// 존재 확인이 정상 경로까지 막아 모든 행이 중립 기호가 되면 SPEC §5.7이 무너집니다.
    /// 경로 존재 확인을 항상 실패로 바꾸는 mutation이 이 단언에서 실패합니다.
    @Test func productionLoaderReturnsAnIconForAPathThatExists() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("Existing.app")
        try Data().write(to: file)

        let icon = ApplicationIconCache.loadSystemIcon(for: ApplicationKey(value: file.path))

        #expect(icon != nil, "존재하는 경로 \(file.path)에서 아이콘을 얻지 못했습니다")
    }
}

/// 정상 상태에서 tick마다 같은 앱 키 집합이 다시 그려질 때 아이콘 로더가 다시 불리지 않는지 확인합니다.
/// 이 앱 자신이 리소스 모니터라 반복 비용이 그대로 자기 CPU 사용량이 됩니다(SPEC §5.9, ANALYSIS §5 DP11).
///
/// 캐시를 직접 두드리는 `ApplicationIconCacheTests`가 이미 「같은 키 재조회에서 로더 호출 1」을 고정하고 있어
/// 여기서 다시 세는 것은 캐시 내부가 아니라 **캐시를 누가 얼마나 오래 들고 있는가**입니다 —
/// 캐시가 tick마다 새로 만들어지는 형태(뷰가 주입받는 대신 자기 것을 만드는 경우)는 캐시 단독 테스트로는
/// 관찰할 수 없고, 실제 카드 뷰를 tick마다 렌더링해 주입한 로더가 계속 불리는지 세야 드러납니다.
@MainActor
struct ApplicationIconRepeatedLookupTests {

    /// 한 tick에 두 카드가 함께 보여주는 앱 집합. 카드 순위 정원과 같은 크기로 두어 정상 상태의 화면과 같게 만듭니다.
    private static let applicationCount = 5

    private static let baseInstant = ContinuousClock().now

    private static func entries() -> [ApplicationRankingEntry] {
        (0..<applicationCount).map { index in
            ApplicationRankingEntry(
                key: ApplicationKey(value: "/Applications/App\(index).app"),
                displayName: "App\(index)",
                value: Double(applicationCount - index)
            )
        }
    }

    /// 아이콘을 얻을 수 있는 앱과 얻지 못하는 앱을 섞습니다.
    /// 얻지 못하는 앱이 없으면 부정 결과 캐시를 지우는 mutation이 이 테스트에 걸리지 않습니다.
    private static func hasIcon(_ key: ApplicationKey) -> Bool {
        key.value.hasSuffix("0.app") || key.value.hasSuffix("2.app") || key.value.hasSuffix("4.app")
    }

    private static func cpuMetrics() -> CPUSystemMetrics {
        CPUSystemMetrics(
            overallUsage: 42,
            userRatio: 30,
            systemRatio: 12,
            idleRatio: 58,
            coreUsages: [42],
            loadAverage: LoadAverage(oneMinute: 0, fiveMinutes: 0, fifteenMinutes: 0)
        )
    }

    private static func memoryMetrics() -> MemorySystemMetrics {
        MemorySystemMetrics(
            totalPhysicalBytes: 16 * 1024 * 1024 * 1024,
            usedBytes: 8 * 1024 * 1024 * 1024,
            appBytes: 4 * 1024 * 1024 * 1024,
            wiredBytes: 2 * 1024 * 1024 * 1024,
            compressedBytes: 2 * 1024 * 1024 * 1024,
            cachedBytes: 1024 * 1024 * 1024,
            swapUsedBytes: 0,
            pressureLevel: .normal
        )
    }

    /// tick 한 번에 그려지는 화면. 두 카드가 **같은** 앱 집합을 각각 한 줄씩 그리므로
    /// 「여러 행이 같은 키를 조회하는」 경우가 이 한 번의 렌더 안에 들어 있습니다.
    private static func renderOneTick(entries: [ApplicationRankingEntry], iconProvider: any ApplicationIconProviding) {
        let cpu = ResourceCardState.normal(
            CPUCardPresentation.assemble(
                cpu: cpuMetrics(),
                history: [],
                topApplications: entries,
                currentTimestamp: baseInstant
            ),
            timestamp: baseInstant
        )
        let memory = ResourceCardState.normal(
            MemoryCardPresentation.assemble(
                memory: memoryMetrics(),
                history: [],
                topApplications: entries,
                currentTimestamp: baseInstant
            ),
            timestamp: baseInstant
        )

        render(CPUCardView(state: cpu, iconProvider: iconProvider))
        render(MemoryCardView(state: memory, iconProvider: iconProvider))
    }

    /// 뷰 본문을 실제로 평가시키는 유일한 수단입니다. production과 같은 카드 너비(280 − 32)로 잽니다.
    private static func render(_ view: some View) {
        _ = NSHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: 280 - 32, height: CGFloat.greatestFiniteMagnitude))
    }

    /// task-013 자동 부분: 캐시가 채워진 뒤 추가 조회에서 로더 호출이 0으로 유지되어야 합니다.
    ///
    /// 다음 mutation이 이 단언에서 실패하는 것을 확인했습니다 —
    /// 부정 결과 캐시를 지우면 아이콘을 얻지 못하는 두 앱이 tick마다 다시 로더를 부르고,
    /// 조회 앞에 캐시 비우기를 넣으면 다섯 앱 전부가 tick마다 다시 불립니다.
    /// 카드 뷰가 주입받은 제공자 대신 tick마다 자기 캐시를 만들면 주입한 로더가 한 번도 불리지 않아
    /// 첫 tick 단언에서 걸립니다 — 이 셋 중 마지막은 캐시를 직접 두드리는 위 테스트들이 잡지 못합니다.
    @Test func repeatedTicksNeverLoadAnIconMoreThanOnce() throws {
        let entries = Self.entries()
        try #require(
            entries.contains { !Self.hasIcon($0.key) },
            "아이콘을 얻지 못하는 앱이 하나도 없으면 부정 결과 캐시가 이 테스트에 걸리지 않습니다"
        )

        let loader = RecordingIconLoader { key in
            Self.hasIcon(key) ? NSImage(size: NSSize(width: 512, height: 512)) : nil
        }
        let cache = ApplicationIconCache(load: loader.load)

        Self.renderOneTick(entries: entries, iconProvider: cache)
        let afterFirstTick = loader.callCount
        try #require(
            afterFirstTick > 0,
            "카드 뷰가 주입된 아이콘 제공자를 조회하지 않았습니다 — 뷰가 자기 캐시를 만들면 반복 비용을 여기서 잴 수 없습니다"
        )
        #expect(
            afterFirstTick == 5,
            "두 카드가 같은 앱 다섯 개를 그리는 첫 tick에서 로더가 \(afterFirstTick)번 불렸습니다"
        )

        for _ in 0..<9 {
            Self.renderOneTick(entries: entries, iconProvider: cache)
        }

        let additionalCalls = loader.callCount - afterFirstTick
        #expect(additionalCalls == 0, "첫 tick 뒤 아홉 tick에서 로더가 \(additionalCalls)번 더 불렸습니다")
        #expect(
            Set(loader.requestedKeys).count == loader.requestedKeys.count,
            "같은 앱 키가 두 번 이상 로더에 도달했습니다: \(loader.requestedKeys.map(\.value))"
        )
    }
}
