//
//  ApplicationCoordinator.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import AppKit

/// 앱 수명 동안 필요한 객체를 한 번만 구성하고 소유하는 경계.
/// task-001 범위에서 구성한 메뉴바 셸(`StatusBarController`)에 이어
/// task-012에서 캐릭터 상태 입력과 표시 sink 연결을 추가합니다.
/// 생명주기 관찰과 수집 일정은 이후 Task에서 이 타입에 추가됩니다.
@MainActor
final class ApplicationCoordinator {
    let statusBarController: StatusBarController
    let characterStateSource: CharacterStateSource

    private var characterStateTask: Task<Void, Never>?

    init() {
        statusBarController = StatusBarController(popoverContent: DashboardView())
        characterStateSource = CharacterStateSource()
        statusBarController.output = self

#if DEBUG
        // 실제 Collector가 없는 M1에서 사람이 다섯 상태 전환을 직접 확인할 수 있도록
        // 우클릭 디버그 메뉴를 상태 입력에 연결합니다. Release 빌드에는 이 진입점이 없습니다.
        statusBarController.debugStateInjector = { [characterStateSource] state in
            characterStateSource.send(state)
        }
#endif

        let sink: CharacterPresentationSink = statusBarController
        characterStateTask = Self.consume(characterStateSource, into: sink)
    }

    /// 초기 상태를 sink에 전달한 뒤 이후 상태 변경을 소비하는 Task를 시작합니다.
    /// `init`과 테스트가 같은 소비 경로를 실제로 통과하도록 이 로직을 별도로 노출합니다.
    static func consume(_ source: CharacterStateSource, into sink: CharacterPresentationSink) -> Task<Void, Never> {
        // 초기 상태는 stream이 아니라 여기서 직접 sink에 전달합니다.
        // stream(`updates`)은 이후 변경만 담으므로 초기 표현이 두 번 전달되지 않습니다.
        sink.render(.presenting(source.initialState))

        let updates = source.updates
        return Task { @MainActor in
            for await state in updates {
                sink.render(.presenting(state))
            }
        }
    }
}

extension ApplicationCoordinator: StatusBarControllerOutput {
    func popoverPresented(_ isPresented: Bool) {
        // task-009에서 이 값을 MonitoringLifecycleStore의 popoverPresented 입력으로 전달합니다.
        // task-001 범위에는 수집 일정이 없으므로 아직 아무 것도 하지 않습니다.
    }
}
