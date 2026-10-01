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
        if ProcessInfo.processInfo.environment["RR_DISK_PROBE"] == "1" {
            Task.detached {
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "DiskNativeProbe")
                do {
                    let snapshot = try DiskNativeAdapter().read()
                    logger.notice("pid=\(getpid()) driverLookup=\(snapshot.driverLookup, privacy: .public) volumeLookup=\(snapshot.volumeLookup, privacy: .public) physicalComplete=\(snapshot.physicalTotalsComplete) relationshipsComplete=\(snapshot.relationshipsComplete)")
                    for driver in snapshot.drivers {
                        logger.notice("driverID=\(driver.registryID) bsd=\(driver.bsdNames.sorted().joined(separator: ","), privacy: .public) kind=\(driver.kind.rawValue, privacy: .public) kindReason=\(driver.kindReason, privacy: .public) readBytes=\(driver.readBytes) writtenBytes=\(driver.writtenBytes) readOperations=\(driver.readOperations.map(String.init) ?? "unsupported", privacy: .public) writeOperations=\(driver.writeOperations.map(String.init) ?? "unsupported", privacy: .public) operationsReason=\(driver.operationsReason, privacy: .public) external=\(driver.external.rawValue, privacy: .public) externalReason=\(driver.externalReason, privacy: .public) removable=\(driver.removable.map(String.init) ?? "unknown", privacy: .public) ejectable=\(driver.ejectable.map(String.init) ?? "unknown", privacy: .public) connection=\(driver.connection ?? "unknown", privacy: .public)")
                    }
                    for volume in snapshot.volumes {
                        logger.notice("volume=\(volume.identity, privacy: .public) mounts=\(volume.mountPaths.sorted().joined(separator: ","), privacy: .public) bsd=\(volume.bsdName ?? "unknown", privacy: .public) fs=\(volume.fileSystem ?? "unknown", privacy: .public) total=\(volume.totalBytes) available=\(volume.availableBytes) used=\(volume.usedBytes) drivers=\(volume.driverIDs.sorted().map(String.init).joined(separator: ","), privacy: .public) scope=\(volume.scope.rawValue, privacy: .public) sharedCapacity=\(volume.sharedCapacity) relation=\(volume.relationReason, privacy: .public)")
                    }
                } catch {
                    logger.error("pid=\(getpid()) failed=\(String(describing: error), privacy: .public)")
                }
            }
        }
#endif
    }
}
