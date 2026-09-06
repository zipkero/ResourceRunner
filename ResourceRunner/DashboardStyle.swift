//
//  DashboardStyle.swift
//  ResourceRunner
//
//  대시보드 표시 계층이 공유하는 타이포·여백·카드 표면 규칙입니다.
//

import SwiftUI

/// 대시보드 뷰가 공유하는 시각 규칙입니다.
///
/// 뷰 밖의 순수 상수로 두어 조립 코드가 같은 위계에 같은 값을 쓰고, 단위 테스트가 그 결정을 직접 확인할 수 있게 합니다.
enum DashboardStyle {
    struct Typography {
        enum Weight: Equatable {
            case regular
            case semibold
        }

        enum ForegroundRole: Equatable {
            case primary
            case secondary
        }

        let font: Font
        let foregroundColor: Color
        /// SwiftUI 의미 글꼴의 macOS 기준 크기. 역할 간 위계가 크기·굵기 중 무엇에서 오는지 테스트가 직접 확인합니다.
        let pointSize: CGFloat
        let weight: Weight
        let foregroundRole: ForegroundRole
    }

    enum TypographyRole {
        static let focus = Typography(
            font: .title2.weight(.semibold).monospacedDigit(),
            foregroundColor: .primary,
            pointSize: 17,
            weight: .semibold,
            foregroundRole: .primary
        )
        static let value = Typography(
            font: .caption.monospacedDigit(),
            foregroundColor: .primary,
            pointSize: 11,
            weight: .regular,
            foregroundRole: .primary
        )
        static let label = Typography(
            font: .caption,
            foregroundColor: .secondary,
            pointSize: 11,
            weight: .regular,
            foregroundRole: .secondary
        )
        static let heading = Typography(
            font: .caption.weight(.semibold),
            foregroundColor: .secondary,
            pointSize: 11,
            weight: .semibold,
            foregroundRole: .secondary
        )
    }

    /// 2 / 4 / 8 / 16pt 배수 단계. 이름은 각 단계가 맡는 위계를 나타냅니다.
    enum Spacing {
        nonisolated static let withinGroup: CGFloat = 2
        nonisolated static let labelToContent: CGFloat = 4
        nonisolated static let betweenGroups: CGFloat = 8
        nonisolated static let betweenSections: CGFloat = 16
    }

    enum CardSurface {
        static let contentPadding = Spacing.betweenGroups
        static let cornerRadius: CGFloat = 8
        static let borderWidth: CGFloat = 1
        static let borderColor = Color(nsColor: .separatorColor)

    }

    /// 값 종류별 최장 표기를 실측해 잡은 두 열 폭입니다.
    ///
    /// 숫자 열은 오른쪽, 단위 열은 왼쪽에 맞춰 같은 목록의 소수점과 단위 시작선을 고정합니다.
    /// 단위 열 폭에는 숫자와 단위 사이의 한 칸도 포함됩니다.
    enum ValueColumn {
        nonisolated static let percentNumberWidth: CGFloat = 26
        nonisolated static let byteNumberWidth: CGFloat = 39
        nonisolated static let signedByteNumberWidth: CGFloat = 45
        nonisolated static let compactUnitWidth: CGFloat = 13
        nonisolated static let byteUnitWidth: CGFloat = 19
        nonisolated static let processPercentUnitWidth: CGFloat = 61
    }
}

extension Text {
    /// 이어 붙인 `Text` 조각도 역할별 글꼴과 색을 잃지 않게 합니다.
    func dashboardTypography(_ typography: DashboardStyle.Typography) -> Text {
        font(typography.font).foregroundColor(typography.foregroundColor)
    }
}
