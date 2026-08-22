//
//  DashboardColorPalette.swift
//  ResourceRunner
//
//  Created by zipkero on 8/19/26.
//

import AppKit
import SwiftUI

/// 카드 그래프 계열 색상을 모아 두는 자리. 색맹 시뮬레이션·명도대비 검증기를 통과한 값을 그대로 쓰므로
/// 여기 값을 바꿀 때는 다시 검증을 거쳐야 합니다(SPEC §5.5, ANALYSIS §5 DP9).
///
/// 다크 모드는 SwiftUI의 자동 반전이 아니라 라이트·다크 각각 따로 확정한 값을 씁니다 — 검증기가 통과시킨 것은
/// 이 두 값의 조합이지 한쪽에서 유도한 반전 값이 아니기 때문입니다.
enum DashboardColorPalette {
    /// CPU 그래프 아래 밴드(User)와 요약 줄 스와치 색.
    static let cpuUser = dynamicColor(light: 0x2a78d6, dark: 0x3987e5)
    /// CPU 그래프 위 밴드(System)와 요약 줄 스와치 색.
    static let cpuSystem = dynamicColor(light: 0xeb6834, dark: 0xd95926)

    /// CPU 그래프 기준선 격자 색(task-005). 계열 색과 달리 다른 색과 구분할 필요가 없는 배경 대비 요소라
    /// 색맹 시뮬레이션 대상이 아니며, 시스템이 라이트·다크에 맞춰 이미 조정하는 구분선 색을 그대로 씁니다.
    static let cpuGridline = Color(NSColor.separatorColor)

    /// Memory 구성 바·도넛의 구간 색(SPEC §5.3). App·Wired는 CPU 계열과 값이 같지만,
    /// 검증기가 통과시킨 것은 이 네 색을 App → Wired → Compressed → Cached 순서로 함께 돌린 결과이므로
    /// CPU 상수를 재사용하지 않고 이 집합을 따로 둡니다 — 인접쌍 색 분리 검증이 이 순서 기준입니다.
    ///
    /// 라이트 모드에서 Wired·Compressed·Cached는 배경 대비가 3:1 아래라 검증기가
    /// `relief required (visible labels or table view)`를 통과 조건으로 걸었습니다.
    /// 범례가 각 스와치 옆에 항목 이름을 항상 보여주는 것이 그 조건이므로, 이름을 지우고 색만 남기거나
    /// 이름을 Hover로 옮기면 이 색 선택이 성립하지 않습니다.
    static func memoryComposition(_ category: MemoryCompositionCategory) -> Color {
        switch category {
        case .app: return memoryCompositionApp
        case .wired: return memoryCompositionWired
        case .compressed: return memoryCompositionCompressed
        case .cached: return memoryCompositionCached
        }
    }

    /// 구성 바의 트랙(전체 물리 메모리). 구간이 아니라 눈금이라 색 구분 대상이 아니며,
    /// 시스템이 라이트·다크에 맞춰 이미 조정하는 색을 그대로 씁니다.
    static let memoryCompositionTrack = Color(NSColor.quaternaryLabelColor)

    private static let memoryCompositionApp = dynamicColor(light: 0x2a78d6, dark: 0x3987e5)
    private static let memoryCompositionWired = dynamicColor(light: 0xeb6834, dark: 0xd95926)
    private static let memoryCompositionCompressed = dynamicColor(light: 0x1baf7a, dark: 0x199e70)
    private static let memoryCompositionCached = dynamicColor(light: 0xeda100, dark: 0xc98500)

    private static func dynamicColor(light: UInt32, dark: UInt32) -> Color {
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(rgbHex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(rgbHex hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
