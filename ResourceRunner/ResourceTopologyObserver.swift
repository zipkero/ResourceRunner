import AppKit
import Foundation
import OSLog
import SystemConfiguration

/// 실제 변경 알림은 누적 revision을 먼저 전진시키고, 느린 보조 조회만 요청합니다.
/// SCDynamicStore 구독이 실패해도 기존 보조 scheduler의 주기 조회가 남습니다.
@MainActor
final class ResourceTopologyObserver {
#if DEBUG
    private static let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "TopologyObserver")
#endif
    private let workspaceCenter: NotificationCenter
    private var diskTokens: [NSObjectProtocol] = []
    private let networkObserver: NetworkDynamicStoreObserver?

    init(networkTopology: NetworkTopologyTracker, diskTopology: DiskTopologyTracker,
         lifecycle: MonitoringLifecycleStore,
         workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
         observeNetwork: Bool = true) {
        self.workspaceCenter = workspaceCenter
        networkObserver = observeNetwork ? NetworkDynamicStoreObserver {
            Self.routeNetworkChange(networkTopology, lifecycle: lifecycle)
        } : nil
        diskTokens = [NSWorkspace.didMountNotification,
                      NSWorkspace.willUnmountNotification,
                      NSWorkspace.didUnmountNotification].map { name in
            workspaceCenter.addObserver(forName: name, object: nil, queue: nil) { _ in
                Self.routeDiskChange(diskTopology, lifecycle: lifecycle)
            }
        }
#if DEBUG
        Self.logger.notice("registered network=\(self.networkObserver != nil) workspaceTokens=\(self.diskTokens.count)")
#endif
    }

    nonisolated static func routeNetworkChange(_ topology: NetworkTopologyTracker,
                                               lifecycle: MonitoringLifecycleStore) {
        topology.noteChange()
        Task { await lifecycle.requestAuxiliaryRefresh(.networkMetadata) }
    }

    nonisolated static func routeDiskChange(_ topology: DiskTopologyTracker,
                                            lifecycle: MonitoringLifecycleStore) {
        topology.noteChange()
        Task { await lifecycle.requestAuxiliaryRefresh(.storageMetadata) }
    }

    deinit {
        for token in diskTokens { workspaceCenter.removeObserver(token) }
    }
}

nonisolated private final class NetworkDynamicStoreObserver: @unchecked Sendable {
    private final class CallbackBox {
        let onChange: @Sendable () -> Void
        init(_ onChange: @escaping @Sendable () -> Void) { self.onChange = onChange }
    }

    private let box: CallbackBox
    private let queue = DispatchQueue(label: "com.zipkero.ResourceRunner.networkTopology")
    private let store: SCDynamicStore

    init?(_ onChange: @escaping @Sendable () -> Void) {
        let box = CallbackBox(onChange)
        var context = SCDynamicStoreContext(version: 0,
            info: Unmanaged.passUnretained(box).toOpaque(),
            retain: { info in
                _ = Unmanaged<CallbackBox>.fromOpaque(info).retain()
                return info
            },
            release: { info in
                Unmanaged<CallbackBox>.fromOpaque(info).release()
            }, copyDescription: nil)
        guard let store = SCDynamicStoreCreate(nil,
            "ResourceRunner.NetworkTopology" as CFString,
            { _, _, info in
                guard let info else { return }
                Unmanaged<CallbackBox>.fromOpaque(info).takeUnretainedValue().onChange()
            }, &context) else { return nil }
        let patterns = ["State:/Network/Interface/.*", "Setup:/Network/Service/.*",
                        "State:/Network/Global/.*"] as CFArray
        guard SCDynamicStoreSetNotificationKeys(store, nil, patterns),
              SCDynamicStoreSetDispatchQueue(store, queue) else { return nil }
        self.box = box
        self.store = store
    }

    deinit { _ = SCDynamicStoreSetDispatchQueue(store, nil) }
}
