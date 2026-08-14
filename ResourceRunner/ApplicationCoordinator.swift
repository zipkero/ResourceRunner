//
//  ApplicationCoordinator.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import AppKit
import OSLog

/// production 시스템 지표 수집 축의 구체 타입.
/// source·scheduler·생명주기 store가 모두 제네릭이라 저장 속성 표기가 길어지므로 여기서 한 번만 묶습니다.
typealias ProductionSystemMetricsSource = SystemMetricsSampleSource<
    CPUSystemMetricsCollector<HostCPUTickReader>,
    MemorySystemMetricsCollector,
    SystemMonotonicClock
>

typealias ProductionSystemMetricsScheduler = MonitoringScheduler<
    SystemMonotonicClock,
    ProductionSystemMetricsSource,
    MonitoringSampleStore
>

/// production 프로세스 조사 축의 구체 타입.
/// 조사 source와 이력 저장소는 task-004·task-005 범위이므로 지금은 자리표시를 끼워 두고,
/// 이 축이 일정·중지·재개를 시스템 지표 축과 독립적으로 태우는 것만 성립시킵니다.
typealias ProductionProcessSurveyScheduler = MonitoringScheduler<
    SystemMonotonicClock,
    PlaceholderScheduledSampleSource,
    PlaceholderMonitoringSampleSink
>

/// 앱 수명 동안 필요한 객체를 한 번만 구성하고 소유하는 경계.
/// 표시 흐름(`StatusBarController`, `CharacterStateSource`)과 생명주기·수집 흐름
/// (`SystemLifecycleObserver`, `MonitoringLifecycleStore`, 두 축의 `MonitoringScheduler`, `MonitoringSampleStore`)을
/// 각각 한 번만 만들어 앱 종료까지 강하게 보유합니다. 두 흐름은 이 타입에서만 만나며,
/// 표시 계층은 수집 actor를 호출하지 않고 수집 actor도 표시 계층을 호출하지 않습니다.
@MainActor
final class ApplicationCoordinator {
    let statusBarController: StatusBarController
    let characterStateSource: CharacterStateSource
    let systemLifecycleObserver: SystemLifecycleObserver
    let monitoringSampleStore: MonitoringSampleStore
    let systemMetricsScheduler: ProductionSystemMetricsScheduler
    let processSurveyScheduler: ProductionProcessSurveyScheduler
    let monitoringLifecycleStore: MonitoringLifecycleStore

    private var characterStateTask: Task<Void, Never>?
    private var monitoringTask: Task<Void, Never>?
    private var cpuActivityTask: Task<Void, Never>?

#if DEBUG
    // task-006에서 AppDelegate에 임시로 둔 관찰용 observer를 여기 단일 observer로 흡수합니다.
    // observer를 둘 만들면 실기기에서 DistributedNotificationCenter 등록이 두 번 일어나므로 하나만 둡니다.
    private static let debugLifecycleLogger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "SystemLifecycle")
    // task-007 실기기 확인: 사용률과 판정 전이를 Console.app에서 관찰하기 위한 로그 경계입니다.
    private static let debugCPUActivityLogger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "CPUActivityState")
#endif

    init() {
        statusBarController = StatusBarController(popoverContent: DashboardView())
        characterStateSource = CharacterStateSource()

        // 생명주기·수집 흐름: SystemLifecycleObserver → MonitoringLifecycleStore → 두 MonitoringScheduler →
        // 각 축의 저장 대상. 저장 대상은 구체 타입이 아니라 `MonitoringSampleSink` 계약으로,
        // 수집 축은 `CollectionScheduleTarget` 계약으로 연결되므로 두 축이 서로의 타입에 묶이지 않습니다.
        let clock = SystemMonotonicClock()
        let sampleStore = MonitoringSampleStore()
        let systemScheduler = MonitoringScheduler(
            clock: clock,
            source: SystemMetricsSampleSource(
                cpuCollector: CPUSystemMetricsCollector(reader: HostCPUTickReader()),
                memoryCollector: MemorySystemMetricsCollector(),
                clock: clock
            ),
            sink: sampleStore
        )
        let processScheduler = MonitoringScheduler(
            clock: clock,
            source: PlaceholderScheduledSampleSource(),
            sink: PlaceholderMonitoringSampleSink()
        )
        monitoringSampleStore = sampleStore
        systemMetricsScheduler = systemScheduler
        processSurveyScheduler = processScheduler
        monitoringLifecycleStore = MonitoringLifecycleStore(
            definition: .m2,
            systemMetricsTarget: systemScheduler,
            processSurveyTarget: processScheduler
        )
        systemLifecycleObserver = SystemLifecycleObserver.makeMacOSAdapter()

        // 모든 저장 속성이 준비된 뒤에야 `self`를 다른 객체에 넘길 수 있으므로,
        // delegate 연결과 이후 소비 Task 시작은 여기부터 진행합니다.
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

        monitoringTask = Self.startMonitoring(systemLifecycleObserver, into: monitoringLifecycleStore)
        cpuActivityTask = Self.consumeSystemMetrics(sampleStore, into: characterStateSource)
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

    /// 시스템 지표 소비 지점에서 전체 CPU 사용률로 메뉴바 표시 상태를 판정하고,
    /// 상태가 바뀌었을 때만 `CharacterStateSource.send(_:)`를 호출합니다.
    /// CPU 지표가 실패했거나(`.failure`) 값을 만들지 못한 tick(`.success(nil)`)에서는 판정 자체를 건너뛰어
    /// 마지막 표시 상태를 그대로 유지합니다(ANALYSIS §2 「메뉴바 표시 상태 판정」).
    /// `init`과 테스트가 같은 경로를 통과하도록 이 로직을 별도로 노출합니다.
    static func consumeSystemMetrics(
        _ store: MonitoringSampleStore,
        into characterStateSource: CharacterStateSource
    ) -> Task<Void, Never> {
        let displayValues = store.displayValues
        return Task { @MainActor in
            var state = CPUActivityStateEvaluator.State.initial
            for await displayValue in displayValues {
                guard let latest = displayValue.latest,
                      case .success(let cpu?) = latest.value.cpu else { continue }

                let next = CPUActivityStateEvaluator.evaluate(usage: cpu.overallUsage, timestamp: latest.timestamp, state: state)
                if next.displayedState != state.displayedState {
                    characterStateSource.send(next.displayedState)
                }

#if DEBUG
                debugCPUActivityLogger.notice(
                    "usage=\(cpu.overallUsage, privacy: .public) displayedState=\(String(describing: next.displayedState), privacy: .public)"
                )
#endif
                state = next
            }
        }
    }

    /// `source.start()`로 얻은 system initial snapshot과 초기 `popoverPresented = false`를
    /// store에 적용한 뒤에만 이후 update stream 소비를 시작합니다(DP8, ANALYSIS §2 「앱 시작과 메뉴바 상호작용」).
    /// 이 순서를 지켜야 store가 낮은 revision을 거부하는 방어와 무관하게, Scheduler가 초기 적용 전에
    /// 먼저 시작되는 경우가 생기지 않습니다.
    /// `init`과 테스트가 같은 경로를 통과하도록 이 로직을 별도로 노출합니다.
    static func startMonitoring(
        _ source: SystemLifecycleSource,
        into store: MonitoringLifecycleStore
    ) -> Task<Void, Never> {
        let subscription = source.start()

#if DEBUG
        // task-006 검증 조건: 실제 잠금·해제 반영을 사람이 콘솔 로그로 확인할 수 있어야 합니다.
        // `Logger`의 문자열 보간은 기본이 `.private`이라 명시하지 않으면 값이 가려지고, `.debug` 수준은
        // Console.app 기본 수집 대상이 아니므로 `.notice`와 `privacy: .public`을 씁니다.
        debugLifecycleLogger.notice("initial snapshot: \(String(describing: subscription.initial), privacy: .public)")
#endif

        return Task { @MainActor in
            await store.update(.systemSnapshot(subscription.initial))
            await store.update(.popoverPresented(false))

            for await snapshot in subscription.updates {
#if DEBUG
                debugLifecycleLogger.notice("snapshot changed: \(String(describing: snapshot), privacy: .public)")
#endif
                await store.update(.systemSnapshot(snapshot))
            }
        }
    }
}

extension ApplicationCoordinator: StatusBarControllerOutput {
    func popoverPresented(_ isPresented: Bool) {
        Task { await Self.forwardPopoverPresented(isPresented, to: monitoringLifecycleStore) }
    }

    /// `MonitoringLifecycleStore.update(_:)`는 actor 진입점이라 delegate 콜백에서 직접 await할 수 없으므로,
    /// 전달 로직을 별도로 노출해 `init`과 테스트가 같은 경로를 통과하게 합니다.
    static func forwardPopoverPresented(
        _ isPresented: Bool,
        to store: MonitoringLifecycleStore
    ) async {
        await store.update(.popoverPresented(isPresented))
    }
}
