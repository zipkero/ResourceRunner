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
        /// 이 글꼴이 macOS에서 실제로 갖는 pt. 선언값이 아니라 `NSFont.preferredFont(forTextStyle:)`의 실측값과 같아야 하며,
        /// 어긋나면 역할 사이 크기 위계를 재는 단언이 거짓을 지키게 됩니다.
        let pointSize: CGFloat
        let weight: Weight
        let foregroundRole: ForegroundRole
    }

    enum TypographyRole {
        static let focus = Typography(
            font: .largeTitle.weight(.semibold).monospacedDigit(),
            foregroundColor: .primary,
            pointSize: 26,
            weight: .semibold,
            foregroundRole: .primary
        )
        static let value = Typography(
            font: .callout.monospacedDigit(),
            foregroundColor: .primary,
            pointSize: 12,
            weight: .regular,
            foregroundRole: .primary
        )
        static let label = Typography(
            font: .subheadline,
            foregroundColor: .secondary,
            pointSize: 11,
            weight: .regular,
            foregroundRole: .secondary
        )
        static let heading = Typography(
            font: .caption.weight(.semibold),
            foregroundColor: .secondary,
            pointSize: 10,
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

    /// 구역 머리글을 붙이는 방식. 본체 카드와 두 상세가 이 세 값을 함께 참조하므로,
    /// 한쪽이 자기 값을 따로 두면 두 화면의 구역 머리글이 갈립니다.
    enum Section {
        static let headingRole = TypographyRole.heading
        /// 머리글과 그 아래 내용 사이 간격. 머리글이 내용에 딸린 이름으로 읽히도록 구역 사이보다 좁습니다.
        nonisolated static let headingToContent = Spacing.labelToContent
        /// 구역과 구역 사이 간격.
        nonisolated static let betweenSections = Spacing.betweenSections
    }

    /// 카드 경계를 만드는 수단은 선이 아니라 면입니다. 테두리 상수를 두지 않으므로
    /// 테두리를 되살리려면 새 상수를 만들어야 하고, 그 변경은 조용히 지나가지 않습니다.
    enum CardSurface {
        static let contentPadding = Spacing.betweenGroups
        static let cornerRadius: CGFloat = 8
        static let fillColor = DashboardColorPalette.cardSurface
    }

    /// 값 종류별 최장 표기를 실측해 잡은 두 열 폭입니다.
    ///
    /// 숫자 열은 오른쪽, 단위 열은 왼쪽에 맞춰 같은 목록의 소수점과 단위 시작선을 고정합니다.
    /// 단위 열 폭에는 숫자와 단위 사이의 한 칸도 포함됩니다.
    enum ValueColumn {
        nonisolated static let percentNumberWidth: CGFloat = 31
        nonisolated static let byteNumberWidth: CGFloat = 45
        nonisolated static let signedByteNumberWidth: CGFloat = 53
        nonisolated static let compactUnitWidth: CGFloat = 14
        nonisolated static let byteUnitWidth: CGFloat = 21
        nonisolated static let processPercentUnitWidth: CGFloat = 67
    }
}

extension Text {
    /// 이어 붙인 `Text` 조각도 역할별 글꼴과 색을 잃지 않게 합니다.
    func dashboardTypography(_ typography: DashboardStyle.Typography) -> Text {
        font(typography.font).foregroundColor(typography.foregroundColor)
    }
}

extension View {
    /// `Text` 하나가 아니라 행·목록 조립 전체에 역할을 거는 자리에서 씁니다.
    func dashboardTypography(_ typography: DashboardStyle.Typography) -> some View {
        font(typography.font).foregroundColor(typography.foregroundColor)
    }
}
