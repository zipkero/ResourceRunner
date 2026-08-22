//
//  ApplicationRowIcon.swift
//  ResourceRunner
//
//  Created by zipkero on 8/21/26.
//

import AppKit

/// 순위·목록 행 앞의 아이콘 자리에 그릴 내용.
///
/// 세 경우를 값으로 갈라 두는 이유는 뷰 본문에 「아이콘이 있으면 …, 없으면 …」 판단이 남지 않게 하기 위해서입니다 —
/// 어느 경우에 무엇을 그리는지가 `ApplicationRowIconLayout.content(for:from:)`의 관찰 가능한 결과가 되어
/// 가짜 캐시를 주입한 단위 테스트가 직접 확인할 수 있습니다(ANALYSIS §5 DP15).
nonisolated enum ApplicationRowIconContent: Equatable {
    /// 캐시가 돌려준 그 앱의 아이콘.
    case icon(NSImage)
    /// 앱은 있지만 아이콘을 얻지 못한 행. 같은 크기의 중립 기호를 그립니다(ANALYSIS §5 DP12).
    case missing
    /// 앱이 없는 줄(값 없음·조사 실패). 같은 크기의 자리만 차지하고 아무것도 드러내지 않습니다 —
    /// 앱이 없는 줄에 앱 기호를 보이면 없는 항목을 지어내는 셈이라, 이름·수치를 감추는 자리표시 관례를 그대로 따릅니다.
    case reserved
}

/// 순위·목록 행 아이콘 자리의 크기와 그릴 내용을 정하는 자리.
/// 뷰는 여기서 정한 값을 좌표와 그리기로 옮기기만 합니다(ANALYSIS §5 DP15).
@MainActor
enum ApplicationRowIconLayout {
    /// 카드 순위 행의 자리 크기(pt). 그 줄의 텍스트 높이(`.caption` 한 줄 13.0pt를 실측)를 넘지 않아야
    /// 카드 높이가 아이콘 때문에 늘지 않습니다(SPEC §5.8, ANALYSIS §5 DP4).
    static let cardPointSize: CGFloat = 12

    /// 상세 목록·증가량 순위 행의 자리 크기(pt). 상세 팝업은 크기가 고정이고 내부가 스크롤이라
    /// 카드보다 알아보기 좋은 크기를 쓸 수 있습니다(ANALYSIS §5 DP12).
    /// 캐시가 담고 있는 이미지의 표시 크기와 같게 두어 확대로 흐려지지 않게 합니다.
    static let detailPointSize: CGFloat = ApplicationIconCache.displayPointSize

    /// 아이콘을 얻지 못한 행에 그리는 중립 기호. 실제 앱 아이콘 어느 것으로도 읽히지 않는 빈 앱 윤곽입니다.
    static let missingSymbolName = "app.dashed"

    /// 아이콘을 접근성 계층에서 감출지 여부. 같은 행의 앱 이름이 이미 같은 정보를 주므로 감춥니다 —
    /// 이름을 하나 더 만들면 행마다 중복 낭독이 생깁니다(ANALYSIS §1 「접근성 노출 자리」, §5 DP13).
    ///
    /// 뷰 본문의 `.accessibilityHidden(_:)` 인자를 이 상수로 두는 이유는 감춤 여부를 단위 테스트가 잡을 수
    /// 있는 자리로 끌어내기 위해서입니다 — SwiftUI 접근성 트리는 `NSHostingController` 안에서 실체화되지 않아
    /// 요소 수로는 감춤 여부를 관찰할 수 없고(실측), 요소 수를 관찰하려면 새 UI 테스트가 필요해
    /// `ANALYSIS §5 DP15`와 부딪힙니다.
    static let isHiddenFromAccessibility = true

    /// 카드 순위 자리의 줄별 아이콘 대상. 정원만큼의 줄 **전부**에 자리가 생기도록 언제나 정원 길이로 돌려주고,
    /// 물을 앱이 없는 줄(값 없음·조사 실패)은 `nil`입니다.
    ///
    /// 이 목록을 뷰가 순회하므로 「아이콘이 있는 줄에만 자리를 둔다」는 형태가 뷰 본문에 생길 수 없습니다 —
    /// 줄마다 자리가 있는지는 이 함수의 결과 길이로 관찰됩니다(SPEC §5.7, ANALYSIS §5 DP15).
    nonisolated static func cardRowIconKeys(
        entries: [ApplicationRankingEntry],
        failed: Bool,
        capacity: Int
    ) -> [ApplicationKey?] {
        (0..<capacity).map { index in
            guard !failed, index < entries.count else { return nil }
            return entries[index].key
        }
    }

    /// 행 하나가 그릴 아이콘 자리의 내용을 정합니다.
    /// `key`가 `nil`인 줄(값 없음·조사 실패)은 캐시에 묻지 않습니다 — 물을 앱이 없기 때문입니다.
    static func content(for key: ApplicationKey?, from provider: any ApplicationIconProviding) -> ApplicationRowIconContent {
        guard let key else { return .reserved }
        guard let image = provider.icon(for: key) else { return .missing }
        return .icon(image)
    }
}
