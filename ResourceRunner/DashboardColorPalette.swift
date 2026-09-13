//
//  DashboardColorPalette.swift
//  ResourceRunner
//
//  Created by zipkero on 8/19/26.
//

import AppKit
import SwiftUI

/// 대시보드 리소스 색상을 모아 두는 자리. 명도대비 검증기를 통과한 값을 그대로 쓰므로
/// 여기 값을 바꿀 때는 다시 검증을 거쳐야 합니다.
///
/// 다크 모드는 SwiftUI의 자동 반전이 아니라 라이트·다크 각각 따로 확정한 값을 씁니다 — 검증기가 통과시킨 것은
/// 이 두 값의 조합이지 한쪽에서 유도한 반전 값이 아니기 때문입니다.
enum DashboardColorPalette {
    /// 번호가 낮을수록 배경 대비가 큰 단계입니다.
    nonisolated enum RampStep: CaseIterable, Sendable {
        case step1
        case step2
        case step3
        case step4
    }

    private static let cpuRamp = ColorRamp(
        step1: dynamicColor(light: 0x003a6c, dark: 0xcbdaff),
        step2: dynamicColor(light: 0x005396, dark: 0x95b9ff),
        step3: dynamicColor(light: 0x256cbb, dark: 0x6399ed),
        step4: dynamicColor(light: 0x4d87d9, dark: 0x3c7acb)
    )

    /// CPU 그래프 아래 밴드(User)와 요약 줄 스와치는 세 번째 단계입니다.
    static let cpuUser = cpu(.step3)
    /// CPU 그래프 위 밴드(System)와 요약 줄 스와치는 첫 번째 단계입니다.
    static let cpuSystem = cpu(.step1)

    static func cpu(_ step: RampStep) -> Color {
        cpuRamp[step]
    }

    /// 팝오버 바탕 면. 시스템 창 배경을 그대로 쓰지 않고 라이트에서 흰색 아래 한 단계로 내려,
    /// 라이트·다크 모두에서 카드가 바탕 위로 떠오르는 같은 방향이 되게 합니다.
    static let popoverBackground = dynamicColor(light: 0xececec, dark: 0x1e1e1e)

    /// 카드 면이자 상세 팝업 바탕. 팔레트의 다른 색이 실제로 놓이는 기준면이므로
    /// 이 값을 바꾸면 나머지 색의 대비를 모두 다시 검증해야 합니다.
    static let cardSurface = dynamicColor(light: 0xffffff, dark: 0x2e2e2e)

    /// CPU 그래프 기준선 격자 색(task-005). 계열 색과 달리 다른 색과 구분할 필요가 없는 배경 대비 요소라
    /// 색맹 시뮬레이션 대상이 아니며, 시스템이 라이트·다크에 맞춰 이미 조정하는 구분선 색을 그대로 씁니다.
    static let cpuGridline = Color(NSColor.separatorColor)

    /// 코어 격자 막대 트랙은 채움과 높이 경계를 이루는 무채색 시스템 색으로 남깁니다.
    static let cpuCoreTrack = Color(NSColor.quaternaryLabelColor)

    /// 코어 막대 채움. CPU 램프와 값을 공유하지 않는 자기 색 집합이고, 네 단계를 세 값으로 옮깁니다 —
    /// 50% 미만 두 단계가 같은 색이라 쉬는 코어가 한 톤으로 평평해지고 75% 이상만 다른 색조로 떠오릅니다.
    /// 라이트에서 `quiet`와 `busy`의 `L*`가 같아 회색조에서는 갈리지 않으므로,
    /// 칸 안 정수 퍼센트와 채움 높이를 지우면 바쁜 코어를 가릴 수단이 남지 않습니다.
    static func cpuCoreFill(_ step: RampStep) -> Color {
        switch step {
        case .step1: return coreBusy
        case .step2: return coreElevated
        case .step3, .step4: return coreQuiet
        }
    }

    private static let coreQuiet = dynamicColor(light: 0x7d869e, dark: 0x7b849c)
    private static let coreElevated = dynamicColor(light: 0x576482, dark: 0x9faccc)
    private static let coreBusy = dynamicColor(light: 0xc77036, dark: 0xf29c66)

    /// Memory 구성 바·도넛의 구간 색. App·Wired가 한 색조, Compressed·Cached가 다른 색조이고
    /// 각 색조 안에서 앞 구간이 더 어둡습니다.
    /// 회색조에서는 App≈Compressed, Wired≈Cached로 두 쌍이 붙으므로
    /// 스와치 옆 범례 이름이 네 구간을 가르는 색 비의존 수단으로 계속 필요합니다.
    static func memoryComposition(_ category: MemoryCompositionCategory) -> Color {
        switch category {
        case .app: return memoryApp
        case .wired: return memoryWired
        case .compressed: return memoryCompressed
        case .cached: return memoryCached
        }
    }

    private static let memoryApp = dynamicColor(light: 0x165698, dark: 0x5287d5)
    private static let memoryWired = dynamicColor(light: 0x4b82d0, dark: 0xa1bbf5)
    private static let memoryCompressed = dynamicColor(light: 0x83441d, dark: 0xc07345)
    private static let memoryCached = dynamicColor(light: 0xba6e41, dark: 0xecae8c)

    /// 구성 바의 트랙(전체 물리 메모리). 구간이 아니라 눈금이라 색 구분 대상이 아니며,
    /// 시스템이 라이트·다크에 맞춰 이미 조정하는 색을 그대로 씁니다.
    static let memoryCompositionTrack = Color(NSColor.quaternaryLabelColor)

    private struct ColorRamp {
        let step1: Color
        let step2: Color
        let step3: Color
        let step4: Color

        subscript(step: RampStep) -> Color {
            switch step {
            case .step1: return step1
            case .step2: return step2
            case .step3: return step3
            case .step4: return step4
            }
        }
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
