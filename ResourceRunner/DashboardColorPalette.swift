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
    /// 표시 계열족을 이루는 두 색조의 진한 단계(step 1)와 밝은 단계(step 2).
    /// CPU는 색조 A를 공유하고, Memory는 App·Wired에 A, Compressed·Cached에 B를 씁니다.
    private static let hueA = ColorRamp(
        step1: dynamicColor(light: 0x165698, dark: 0x5287d5),
        step2: dynamicColor(light: 0x4b82d0, dark: 0xa1bbf5)
    )
    private static let hueB = ColorRamp(
        step1: dynamicColor(light: 0x83441d, dark: 0xc07345),
        step2: dynamicColor(light: 0xba6e41, dark: 0xecae8c)
    )

    /// CPU 그래프 아래 밴드(User)와 요약 줄 스와치는 밝은 단계.
    static let cpuUser = hueA.step2
    /// CPU 그래프 위 밴드(System)와 요약 줄 스와치는 진한 단계.
    static let cpuSystem = hueA.step1

    /// CPU 그래프 기준선 격자 색(task-005). 계열 색과 달리 다른 색과 구분할 필요가 없는 배경 대비 요소라
    /// 색맹 시뮬레이션 대상이 아니며, 시스템이 라이트·다크에 맞춰 이미 조정하는 구분선 색을 그대로 씁니다.
    static let cpuGridline = Color(NSColor.separatorColor)

    /// 코어 격자 막대의 트랙과 채움(SPEC §5.3). 막대가 나르는 정보는 채움 높이 하나뿐이라 색이 구분에
    /// 쓰이는 자리가 없고, `cpuGridline`과 같은 이유로 계열 색이 아닌 시스템 색을 씁니다.
    /// 여기에 계열 색을 넣으면 카드의 User 밴드와 같은 색이 코어 합계라는 다른 뜻을 갖게 됩니다.
    static let cpuCoreTrack = Color(NSColor.quaternaryLabelColor)
    static let cpuCoreFill = Color(NSColor.secondaryLabelColor)

    /// Memory 구성 바·도넛의 구간 색(SPEC §5.3). App·Wired는 CPU 계열과 값이 같지만,
    /// 검증기가 통과시킨 것은 이 네 색을 App → Wired → Compressed → Cached 순서로 함께 돌린 결과이므로
    /// CPU 상수를 재사용하지 않고 이 집합을 따로 둡니다 — 인접쌍 색 분리 검증이 이 순서 기준입니다.
    ///
    /// 네 구간은 App → Wired → Compressed → Cached 순서로 진함·밝음을 번갈아 써서
    /// 인접 경계마다 명도 단계가 생깁니다. 범례 이름은 색 비의존 구분 수단으로 계속 유지합니다.
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

    private static let memoryCompositionApp = hueA.step1
    private static let memoryCompositionWired = hueA.step2
    private static let memoryCompositionCompressed = hueB.step1
    private static let memoryCompositionCached = hueB.step2

    private struct ColorRamp {
        let step1: Color
        let step2: Color
    }

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
