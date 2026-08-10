//
//  CharacterStateSource.swift
//  ResourceRunner
//
//  Created by zipkero on 8/10/26.
//

import Foundation

/// M1이 실제 CPU 값 대신 주입하는 검증용 다섯 상태.
/// M2에서 실제 부하 판정이 들어오기 전까지는 이 다섯 값이 닫힌 집합입니다.
/// 프로젝트 기본 격리가 `MainActor`이지만 이 값은 저장된 상태가 없는 순수 값 타입이라
/// 어느 격리에서도 비교·전달할 수 있어야 하므로 `nonisolated`로 선언합니다.
nonisolated enum CharacterActivityState: Sendable {
    case low
    case moderate
    case high
    case veryHigh
    case sustainedHigh
}

/// 한 상태에 대응하는 메뉴바 접근성 이름 하나를 담는 값.
/// M1에서는 다섯 상태를 구분하는 유일한 수단이 이 이름이며 이미지나 색상 차이는 두지 않습니다.
/// 접근성 값은 담지 않습니다 — 메뉴바 상태 항목의 role인 `Status Menu`에서 VoiceOver가 값을 읽지 않아
/// 값에 담은 상태는 사용자에게 도달하지 않고, 상태 문자열의 자리가 둘로 늘어나면 어긋날 여지만 생깁니다.
struct CharacterPresentation: Equatable, Sendable {
    /// sink가 그대로 반영하는 완성된 접근성 이름. 조합은 아래 매핑에서 끝냅니다.
    let accessibilityLabel: String

    /// 메뉴바에는 여러 앱의 항목이 나란히 놓이므로 상태만으로는 어느 앱의 상태인지 알 수 없습니다.
    /// 앱 이름을 앞에 두고 쉼표로 상태를 잇습니다.
    private static let applicationName = "ResourceRunner"

    /// `CharacterActivityState`에서 접근성 이름을 만드는 순수 매핑.
    static func presenting(_ state: CharacterActivityState) -> CharacterPresentation {
        CharacterPresentation(accessibilityLabel: "\(applicationName), \(state.accessibilityDescription)")
    }
}

private extension CharacterActivityState {
    var accessibilityDescription: String {
        switch self {
        case .low: return "낮음"
        case .moderate: return "보통"
        case .high: return "높음"
        case .veryHigh: return "매우 높음"
        case .sustainedHigh: return "장시간 고부하"
        }
    }
}

/// `CharacterPresentation`을 받아 표시에 반영하는 출력 계약.
/// `StatusBarController`가 구현하며 메뉴바 버튼의 접근성 이름만 갱신합니다.
/// 팝오버 상태와 `SystemLifecycleSnapshot`은 이 계약의 입력이 아닙니다.
@MainActor
protocol CharacterPresentationSink: AnyObject {
    func render(_ presentation: CharacterPresentation)
}

/// 실제 Collector와 분리된 M1 캐릭터 상태 입력.
/// 초기 상태는 `low`이며, `send(_:)`로 이후 상태를 순서와 시점에 관계없이 주입할 수 있습니다.
/// 프로젝트 기본 격리가 `MainActor`이므로 이 타입도 `MainActor`에 격리되며,
/// `send(_:)`를 포함한 모든 멤버는 `MainActor`에서만 호출할 수 있습니다.
final class CharacterStateSource: Sendable {
    let initialState: CharacterActivityState
    /// 이후 상태 변경만 담는 stream. `initialState`는 이 stream으로 다시 전달되지 않습니다.
    let updates: AsyncStream<CharacterActivityState>

    private let continuation: AsyncStream<CharacterActivityState>.Continuation

    init(initialState: CharacterActivityState = .low) {
        self.initialState = initialState

        var continuation: AsyncStream<CharacterActivityState>.Continuation!
        updates = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    /// 다음 상태를 주입합니다.
    func send(_ state: CharacterActivityState) {
        continuation.yield(state)
    }
}
