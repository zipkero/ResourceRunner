//
//  AppDelegate.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import AppKit
#if DEBUG
import OSLog
#endif

/// 앱 시작 시 단일 `ApplicationCoordinator`를 만들어 종료까지 강하게 보유합니다.
/// 별도 Helper나 추가 실행 대상은 만들지 않습니다.
/// 실제 잠금·해제 관찰 로그는 `ApplicationCoordinator`가 자신이 만드는 단일
/// `SystemLifecycleObserver`에서 남기므로, 여기서 별도 observer를 만들지 않습니다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: ApplicationCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = ApplicationCoordinator()
#if DEBUG
        if ProcessInfo.processInfo.environment["RR_NETWORK_PROBE"] == "1" {
            Task.detached {
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "NetworkNativeProbe")
                do {
                    let snapshot = try NetworkNativeAdapter().read()
                    logger.notice("pid=\(getpid()) route=\(snapshot.routeLookup, privacy: .public) address=\(snapshot.addressLookup, privacy: .public) config=\(snapshot.configurationLookup, privacy: .public) registry=\(snapshot.registryLookup, privacy: .public) links=\(snapshot.linkLookup, privacy: .public) complete=\(snapshot.physicalTotalsComplete)")
                    for item in snapshot.interfaces {
                        logger.notice("name=\(item.raw.name, privacy: .public) index=\(item.raw.index) flags=\(item.raw.flags) linkType=\(item.raw.linkType) functionalType=\(item.functionalType ?? 999) rx=\(item.raw.receivedBytes) tx=\(item.raw.sentBytes) kind=\(item.kind.rawValue, privacy: .public) registryID=\(item.registryID ?? 0) provider=\(item.providerPath.joined(separator: "/"), privacy: .public) reason=\(item.classificationReason, privacy: .public) IPv4=\(item.ipv4.joined(separator: ","), privacy: .public) IPv6=\(item.ipv6.joined(separator: ","), privacy: .public) status=\(item.status, privacy: .public) speed=\(item.linkSpeed, privacy: .public)")
                    }
                } catch {
                    logger.error("pid=\(getpid()) failed=\(String(describing: error), privacy: .public)")
                }
            }
        }
#endif
    }
}
