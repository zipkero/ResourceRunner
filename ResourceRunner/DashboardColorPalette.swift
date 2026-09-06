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
    private static let memoryRamp = ColorRamp(
        step1: dynamicColor(light: 0x612800, dark: 0xffd0b7),
        step2: dynamicColor(light: 0x843e10, dark: 0xfba471),
        step3: dynamicColor(light: 0xa35729, dark: 0xd78453),
        step4: dynamicColor(light: 0xc27242, dark: 0xb36536)
    )

    /// CPU 그래프 아래 밴드(User)와 요약 줄 스와치는 세 번째 단계입니다.
    static let cpuUser = cpu(.step3)
    /// CPU 그래프 위 밴드(System)와 요약 줄 스와치는 첫 번째 단계입니다.
    static let cpuSystem = cpu(.step1)

    static func cpu(_ step: RampStep) -> Color {
        cpuRamp[step]
    }

    /// CPU 그래프 기준선 격자 색(task-005). 계열 색과 달리 다른 색과 구분할 필요가 없는 배경 대비 요소라
    /// 색맹 시뮬레이션 대상이 아니며, 시스템이 라이트·다크에 맞춰 이미 조정하는 구분선 색을 그대로 씁니다.
    static let cpuGridline = Color(NSColor.separatorColor)

    /// 코어 격자 막대 트랙은 채움과 높이 경계를 이루는 무채색 시스템 색으로 남깁니다.
    static let cpuCoreTrack = Color(NSColor.quaternaryLabelColor)

    static func cpuCoreFill(_ step: RampStep) -> Color {
        cpu(step)
    }

    /// Memory 구성 바·도넛은 App부터 Cached까지 한 색조의 네 단계를 순서대로 씁니다.
    /// 범례 이름은 색 비의존 구분 수단으로 계속 유지합니다.
    static func memoryComposition(_ category: MemoryCompositionCategory) -> Color {
        switch category {
        case .app: return memory(.step1)
        case .wired: return memory(.step2)
        case .compressed: return memory(.step3)
        case .cached: return memory(.step4)
        }
    }

    static func memory(_ step: RampStep) -> Color {
        memoryRamp[step]
    }

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
