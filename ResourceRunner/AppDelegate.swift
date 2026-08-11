//
//  AppDelegate.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import AppKit
import OSLog

/// 앱 시작 시 단일 `ApplicationCoordinator`를 만들어 종료까지 강하게 보유합니다.
/// 별도 Helper나 추가 실행 대상은 만들지 않습니다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: ApplicationCoordinator?

#if DEBUG
    // task-006 검증 조건: 실제 잠금·해제 반영을 사람이 콘솔 로그로 확인할 수 있어야 합니다.
    // MonitoringLifecycleStore·Scheduler 연결(task-010)과는 무관하게, 어댑터가 단독으로 실제 신호를
    // 관찰하는지만 확인하는 임시 수단입니다. 실행한 뒤 Console.app이나 Xcode 콘솔에서
    // "SystemLifecycle" 카테고리로 화면을 잠그고 해제해 locked→unlocked 순서를 확인하면 됩니다.
    private var debugLifecycleObserver: SystemLifecycleObserver?
    private var debugLifecycleLogTask: Task<Void, Never>?
    private let debugLifecycleLogger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "SystemLifecycle")
#endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = ApplicationCoordinator()

#if DEBUG
        startDebugLifecycleLogging()
#endif
    }

#if DEBUG
    private func startDebugLifecycleLogging() {
        let observer = SystemLifecycleObserver.makeMacOSAdapter()
        let subscription = observer.start()
        debugLifecycleObserver = observer

        // `Logger`의 문자열 보간은 기본이 `.private`이라 명시하지 않으면 값이 `<private>`으로 가려지고,
        // `.debug` 수준은 기본 수집 대상이 아니라 Console.app에 나타나지 않습니다.
        // 관찰해야 할 대상이 바로 이 값이므로 수준을 올리고 공개로 표시합니다.
        // 여기에는 잠금 상태와 저전력 여부만 실리며 사용자 식별 정보는 담기지 않습니다.
        debugLifecycleLogger.notice("initial snapshot: \(String(describing: subscription.initial), privacy: .public)")
        debugLifecycleLogTask = Task { @MainActor [debugLifecycleLogger] in
            for await snapshot in subscription.updates {
                debugLifecycleLogger.notice("snapshot changed: \(String(describing: snapshot), privacy: .public)")
            }
        }
    }
#endif
}
