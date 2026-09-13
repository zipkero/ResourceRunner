//
//  ApplicationIconCache.swift
//  ResourceRunner
//
//  Created by zipkero on 8/21/26.
//

import AppKit

/// 앱 키에 대응하는 표시용 아이콘을 돌려주는 최소 계약.
/// 순위·목록 행은 이 계약에만 묻고 시스템을 직접 부르지 않습니다(ANALYSIS §1 「아이콘 경계」, §5 DP11).
///
/// 조회가 캐시를 갱신하므로 참조 타입 계약입니다 — 뷰가 값 복사본을 들고 있으면 같은 키의 첫 조회가
/// 화면마다 따로 일어납니다.
@MainActor
protocol ApplicationIconProviding: AnyObject {
    /// 아이콘을 얻지 못하면 `nil`. 호출부는 그 자리에 같은 크기의 중립 기호를 그립니다(ANALYSIS §5 DP12).
    func icon(for key: ApplicationKey) -> NSImage?
}

/// 앱 키를 키로 하는 고정 상한 LRU 아이콘 캐시.
/// 시스템 호출은 주입되는 로더 하나에만 있고, 조회 결과는 아이콘을 얻지 못한 경우까지 함께 기억합니다 —
/// 부정 결과를 기억하지 않으면 아이콘을 얻을 수 없는 앱이 갱신 주기마다 다시 디스크를 두드려
/// 자기 CPU 사용량 요구(SPEC §5.9)가 무너집니다(ANALYSIS §5 DP11).
///
/// 관찰 가능 객체가 아닙니다. 조회가 갱신 알림을 내면 목록 전체가 매 조회마다 다시 무효화되어
/// 캐시로 아끼려던 비용이 그대로 돌아옵니다.
@MainActor
final class ApplicationIconCache: ApplicationIconProviding {
    /// 시스템 아이콘 획득 경로. 이 클로저 하나가 표시 계층에서 시스템을 부르는 유일한 자리이고,
    /// 테스트는 여기에 가짜를 주입해 호출 횟수를 셉니다.
    typealias Loader = @MainActor (ApplicationKey) -> NSImage?

    /// 상한. 정원 통합으로 실제로 조회되는 키가 수십 개로 줄어들어 정상 상태에서는 축출이 일어나지 않으며,
    /// `ApplicationIdentityResolver`가 같은 자리에서 쓰는 상한과 같은 규모입니다(ANALYSIS §5 DP11).
    /// 생성자 기본값에서 참조되므로 actor 격리에서 뺍니다 — 기본 인자 자리는 nonisolated 문맥입니다.
    nonisolated static let defaultCapacity = 512

    /// 캐시에 담는 이미지의 한 변 크기(pt). 아이콘이 그려지는 가장 큰 자리(상세 목록 행) 기준이고,
    /// 그보다 작은 카드 순위 행은 같은 이미지를 줄여 그립니다(ANALYSIS §5 DP12).
    static let displayPointSize: CGFloat = 16
    /// 축소 이미지의 픽셀 배율. Retina 화면에서 흐려지지 않을 만큼만 담고 원본의 나머지 해상도 표현은 버립니다.
    static let displayScaleFactor: CGFloat = 2

    /// 값이 `nil`인 항목은 「로더가 아이콘을 돌려주지 못했음」을 기억하는 항목입니다.
    /// 항목 자체의 유무와 값의 유무가 서로 다른 뜻이라 값 타입이 이중 optional입니다.
    private var cache: [ApplicationKey: NSImage?] = [:]
    /// 가장 오래전에 쓰인 것부터 순서대로 담는 앱 키 목록. 캐시 적중 때마다 맨 뒤로 옮깁니다.
    private var recencyOrder: [ApplicationKey] = []
    private let capacity: Int
    private let load: Loader

    init(
        capacity: Int = ApplicationIconCache.defaultCapacity,
        load: @escaping Loader = ApplicationIconCache.loadSystemIcon(for:)
    ) {
        precondition(capacity > 0, "용량은 1 이상이어야 합니다.")
        self.capacity = capacity
        self.load = load
    }

    func icon(for key: ApplicationKey) -> NSImage? {
        if let cached = cache[key] {
            touch(key)
            return cached
        }

        let loaded = load(key).flatMap(Self.downscaled)
        // 이중 optional 자리에 `nil`을 그대로 담아야 부정 결과가 기억됩니다 —
        // 값이 `nil`이라고 항목을 지우면 다음 조회가 시스템 호출을 다시 하게 됩니다.
        // `[K: V?]`에서 첨자 대입은 리터럴 `nil`을 항목 제거로 해석하므로, 저장 의도를 흐리지 않도록 `updateValue`를 씁니다.
        // (여기 `loaded`는 변수라 첨자 대입도 `.some(loaded)`로 승격돼 동작은 같습니다. 관례로 명시적인 쪽을 씁니다.)
        cache.updateValue(loaded, forKey: key)
        recencyOrder.append(key)
        if recencyOrder.count > capacity {
            let evicted = recencyOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
        return loaded
    }

    /// 캐시가 기억하고 있는 앱 키 수. 상한 검증에 씁니다.
    var cachedKeyCount: Int { cache.count }

    private func touch(_ key: ApplicationKey) {
        guard let index = recencyOrder.firstIndex(of: key) else { return }
        recencyOrder.remove(at: index)
        recencyOrder.append(key)
    }

    /// production 로더. 앱 키는 번들 경로나 실행 파일 경로(`ApplicationIdentityResolver`)이므로,
    /// 번들 경로일 때만 시스템에 묻고, 그 경우에도 경로가 실제로 있는지 먼저 확인합니다.
    ///
    /// 번들이 아닌 실행 파일을 시스템에 물으면 경로가 있는 한 유닉스 실행 파일용 기본 문서 그림이 돌아옵니다.
    /// 그것을 앱 아이콘 자리에 넣으면 그 프로세스의 아이콘인 것처럼 읽히므로, 번들이 아닌 키는 묻지 않고
    /// 중립 기호 자리로 보냅니다.
    ///
    /// 확인이 없으면 「아이콘을 얻지 못한 행」이 화면에 아예 나타나지 않습니다 —
    /// `icon(forFile:)`는 없는 경로에도 일반 문서 아이콘을 돌려주고 `nil`을 내지 않는 것이 이 프로젝트의
    /// 실행 환경에서 확인됐습니다. 그 그림을 앱 아이콘 자리에 넣으면 아이콘을 얻지 못했다는 사실이 드러나기는커녕
    /// 그 앱의 아이콘인 것처럼 읽혀, 중립 기호로 「없음」을 드러내기로 한 결정(ANALYSIS §5 DP12)과
    /// 「없는 값을 지어내지 않는다」(core-resource-monitoring SPEC §5.11)가 함께 무너집니다.
    ///
    /// 확인 비용은 키마다 한 번뿐입니다 — 아이콘을 얻지 못한 결과도 캐시에 남으므로(ANALYSIS §5 DP11)
    /// 같은 키가 갱신 주기마다 다시 파일 시스템을 두드리지 않습니다.
    static func loadSystemIcon(for key: ApplicationKey) -> NSImage? {
        guard key.value.hasSuffix(bundleSuffix) else { return nil }
        guard FileManager.default.fileExists(atPath: key.value) else { return nil }
        return NSWorkspace.shared.icon(forFile: key.value)
    }

    /// `ApplicationIdentityResolver.deriveIdentity`가 번들을 찾았을 때만 키가 이 접미사로 끝납니다.
    private static let bundleSuffix = ".app"

    /// 캐시에 담기 전에 표시 크기로 한 번 축소합니다.
    /// 시스템 아이콘 원본은 여러 해상도 표현을 함께 물고 있어 상한만큼 들고 있으면 메모리가 예측되지 않습니다
    /// (ANALYSIS §5 DP11). 원본을 참조로 붙들지 않도록 표현을 직접 그려 담습니다.
    static func downscaled(_ image: NSImage) -> NSImage? {
        let pointSize = NSSize(width: displayPointSize, height: displayPointSize)
        let pixels = Int((displayPointSize * displayScaleFactor).rounded())
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        representation.size = pointSize

        guard let context = NSGraphicsContext(bitmapImageRep: representation) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: pointSize), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let scaled = NSImage(size: pointSize)
        scaled.addRepresentation(representation)
        return scaled
    }
}
