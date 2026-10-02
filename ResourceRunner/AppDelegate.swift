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
        if ProcessInfo.processInfo.environment["RR_NETWORK_UI_PROBE"] == "1" {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "NetworkUIProbe")
                try? await Task.sleep(for: .seconds(4))
                guard let coordinator = self.coordinator else { return }
                let status = coordinator.statusBarController
                status.togglePopover()
                try? await Task.sleep(for: .seconds(1))
                logger.notice("opened=\(status.popover.isShown) bodyFrame=\(String(describing: status.popover.contentViewController?.view.window?.frame), privacy: .public) networkAX=\(coordinator.dashboardPresentationStore.networkCard.accessibilityLabel, privacy: .public)")
                Self.logNetworkAccessibility(logger: logger)
                if let hosting = status.popover.contentViewController?.view,
                   let scroll = Self.firstScrollView(in: hosting) {
                    logger.notice("scrollBefore contentBounds=\(String(describing: scroll.contentView.bounds), privacy: .public) documentFrame=\(String(describing: scroll.documentView?.frame), privacy: .public)")
                    scroll.contentView.scroll(to: NSPoint(x: 0, y: 310))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    try? await Task.sleep(for: .milliseconds(300))
                    logger.notice("scrollAfter contentBounds=\(String(describing: scroll.contentView.bounds), privacy: .public)")
                } else {
                    logger.error("actual ScrollView NSScrollView not found")
                }
                Self.logNetworkAccessibility(logger: logger)
                coordinator.dashboardPresentationStore.selectCard(.network)
                logger.notice("common selectCard called selection=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public)")
                for _ in 0..<10 {
                    if !coordinator.dashboardPresentationStore.networkCard.interfaces.isEmpty { break }
                    try? await Task.sleep(for: .milliseconds(500))
                }
                try? await Task.sleep(for: .milliseconds(500))
                let windowFrames = NSApp.windows.map { String(describing: $0.frame) }.joined(separator: ";")
                logger.notice("selected=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public) interfaceCount=\(coordinator.dashboardPresentationStore.networkCard.interfaces.count) windowFrames=\(windowFrames, privacy: .public)")
                Self.logNetworkAccessibility(logger: logger)
                if ProcessInfo.processInfo.environment["RR_NETWORK_UI_PROBE_OUTPUT"] == "1",
                   let caches = FileManager.default.urls(for: .cachesDirectory,
                       in: .userDomainMask).first {
                    let output = caches.appending(path: "Task010Probe")
                    try? FileManager.default.createDirectory(at: output,
                        withIntermediateDirectories: true)
                    if let parent = status.popover.contentViewController?.view.window {
                        Self.writeProbeImage(window: parent,
                            path: output.appending(path: "actual-dashboard.png").path, logger: logger)
                    }
                    if let detail = NSApp.windows.first(where: { $0.frame.width > 400 && $0.frame.width < 450 }) {
                        Self.writeProbeImage(window: detail,
                            path: output.appending(path: "actual-network-detail.png").path, logger: logger)
                        if let content = detail.contentView,
                           let scroll = Self.firstScrollView(in: content) {
                            logger.notice("detailScroll documentFrame=\(String(describing: scroll.documentView?.frame), privacy: .public)")
                            scroll.contentView.scroll(to: NSPoint(x: 0, y: 2_500))
                            scroll.reflectScrolledClipView(scroll.contentView)
                            try? await Task.sleep(for: .milliseconds(250))
                            Self.writeProbeImage(window: detail,
                                path: output.appending(path: "actual-network-detail-physical.png").path, logger: logger)
                            scroll.contentView.scroll(to: NSPoint(x: 0, y: 3_200))
                            scroll.reflectScrolledClipView(scroll.contentView)
                            try? await Task.sleep(for: .milliseconds(250))
                            Self.writeProbeImage(window: detail,
                                path: output.appending(path: "actual-network-detail-tunnel.png").path, logger: logger)
                        }
                    }
                }
                if let close = Self.findNetworkAX("NetworkDetailClose") {
                    let result = AXUIElementPerformAction(close, kAXPressAction as CFString)
                    logger.notice("close AXPress result=\(result.rawValue)")
                } else { logger.error("close AX element missing") }
                try? await Task.sleep(for: .seconds(1))
                logger.notice("closedSelection=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public) bodyFrame=\(String(describing: status.popover.contentViewController?.view.window?.frame), privacy: .public)")
                Self.logNetworkAccessibility(logger: logger)
                coordinator.dashboardPresentationStore.selectCard(.network)
                try? await Task.sleep(for: .milliseconds(500))
                logger.notice("reselected=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public) windows=\(NSApp.windows.count)")
                coordinator.dashboardPresentationStore.selectCard(.network)
                try? await Task.sleep(for: .seconds(1))
                logger.notice("sameCardClosed=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public) windows=\(NSApp.windows.count)")
                status.togglePopover()
            }
        }
        if ProcessInfo.processInfo.environment["RR_DISK_UI_PROBE"] == "1" {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "DiskUIProbe")
                try? await Task.sleep(for: .seconds(4))
                guard let coordinator = self.coordinator else { return }
                let status = coordinator.statusBarController
                status.togglePopover()
                try? await Task.sleep(for: .seconds(1))
                logger.notice("opened=\(status.popover.isShown) bodyFrame=\(String(describing: status.popover.contentViewController?.view.window?.frame), privacy: .public) diskAX=\(coordinator.dashboardPresentationStore.diskCard.accessibilityLabel, privacy: .public)")
                if let hosting = status.popover.contentViewController?.view,
                   let scroll = Self.firstScrollView(in: hosting) {
                    logger.notice("scrollBefore contentBounds=\(String(describing: scroll.contentView.bounds), privacy: .public) documentFrame=\(String(describing: scroll.documentView?.frame), privacy: .public)")
                    scroll.contentView.scroll(to: NSPoint(x: 0, y: 900))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    try? await Task.sleep(for: .milliseconds(300))
                    logger.notice("scrollAfter contentBounds=\(String(describing: scroll.contentView.bounds), privacy: .public)")
                } else { logger.error("actual dashboard ScrollView not found") }
                Self.logDiskAccessibility(logger: logger)
                coordinator.dashboardPresentationStore.selectCard(.disk)
                logger.notice("common selectCard called selection=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public)")
                for _ in 0..<10 {
                    if coordinator.dashboardPresentationStore.diskCard.supplemental.capacity != nil { break }
                    try? await Task.sleep(for: .milliseconds(500))
                }
                try? await Task.sleep(for: .milliseconds(500))
                logger.notice("selected=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public) diskAX=\(coordinator.dashboardPresentationStore.diskCard.accessibilityLabel, privacy: .public) windows=\(NSApp.windows.map { String(describing: $0.frame) }.joined(separator: ";"), privacy: .public)")
                Self.logDiskAccessibility(logger: logger)
                if let caches = FileManager.default.urls(for: .cachesDirectory,
                    in: .userDomainMask).first {
                    let output = caches.appending(path: "Task011Probe")
                    try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                    if let parent = status.popover.contentViewController?.view.window {
                        Self.writeProbeImage(window: parent,
                            path: output.appending(path: "actual-disk-dashboard.png").path, logger: logger)
                    }
                    if let detail = NSApp.windows.first(where: { $0.frame.width > 400 && $0.frame.width < 450 }) {
                        Self.writeProbeImage(window: detail,
                            path: output.appending(path: "actual-disk-detail-top.png").path, logger: logger)
                        if let content = detail.contentView,
                           let scroll = Self.firstScrollView(in: content) {
                            logger.notice("detailScroll documentFrame=\(String(describing: scroll.documentView?.frame), privacy: .public)")
                            scroll.contentView.scroll(to: NSPoint(x: 0, y: 1_050))
                            scroll.reflectScrolledClipView(scroll.contentView)
                            try? await Task.sleep(for: .milliseconds(250))
                            Self.writeProbeImage(window: detail,
                                path: output.appending(path: "actual-disk-detail-devices.png").path, logger: logger)
                        }
                    } else { logger.error("Disk detail NSWindow not found") }
                }
                if let close = Self.findNetworkAX("DiskDetailClose") {
                    let result = AXUIElementPerformAction(close, kAXPressAction as CFString)
                    logger.notice("close AXPress result=\(result.rawValue)")
                } else { logger.error("Disk close AX element missing") }
                try? await Task.sleep(for: .seconds(1))
                logger.notice("closedSelection=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public) bodyFrame=\(String(describing: status.popover.contentViewController?.view.window?.frame), privacy: .public)")
                coordinator.dashboardPresentationStore.selectCard(.disk)
                try? await Task.sleep(for: .milliseconds(500))
                logger.notice("reselected=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public) windows=\(NSApp.windows.count)")
                coordinator.dashboardPresentationStore.selectCard(.disk)
                try? await Task.sleep(for: .seconds(1))
                logger.notice("sameCardClosed=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public) windows=\(NSApp.windows.count)")
                Self.logDiskAccessibility(logger: logger)
                status.togglePopover()
            }
        }
        if ProcessInfo.processInfo.environment["RR_COLLECTION_PROBE"] == "1" {
            Task { @MainActor [weak self] in
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "CollectionPipeline")
                logger.notice("probe initial actualOSLowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled) popover=false")
                try? await Task.sleep(for: .seconds(3))
                guard let coordinator = self?.coordinator else { return }
                coordinator.systemLifecycleObserver.injectProbeLowPowerMode(true)
                logger.notice("probe injected lifecycleLowPower=true actualOSLowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")
                try? await Task.sleep(for: .seconds(1))
                if !coordinator.statusBarController.popover.isShown {
                    coordinator.statusBarController.togglePopover()
                }
                logger.notice("probe requested actual popover open isShown=\(coordinator.statusBarController.popover.isShown)")
                try? await Task.sleep(for: .seconds(3))
                if coordinator.statusBarController.popover.isShown {
                    coordinator.statusBarController.togglePopover()
                }
                logger.notice("probe requested actual popover closed isShown=\(coordinator.statusBarController.popover.isShown)")
                try? await Task.sleep(for: .seconds(1))
                coordinator.systemLifecycleObserver.injectProbeLowPowerMode(false)
                logger.notice("probe restored lifecycleLowPower=false actualOSLowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")
            }
        }
        if ProcessInfo.processInfo.environment["RR_NETWORK_PROBE"] == "1" {
            Task.detached {
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "NetworkNativeProbe")
                do {
                    let snapshot = try NetworkNativeAdapter().read()
                    logger.notice("pid=\(getpid()) route=\(snapshot.routeLookup, privacy: .public) address=\(snapshot.addressLookup, privacy: .public) config=\(snapshot.configurationLookup, privacy: .public) registry=\(snapshot.registryLookup, privacy: .public) links=\(snapshot.linkLookup, privacy: .public) complete=\(snapshot.physicalTotalsComplete)")
                    for item in snapshot.interfaces {
                        logger.notice("name=\(item.raw.name, privacy: .public) index=\(item.raw.index) flags=\(item.raw.flags) linkType=\(item.raw.linkType) functionalType=\(item.functionalType ?? 999) rx=\(item.raw.receivedBytes) tx=\(item.raw.sentBytes) kind=\(item.kind.rawValue, privacy: .public) registryID=\(item.registryID ?? 0) provider=\(item.providerPath.joined(separator: "/"), privacy: .public) reason=\(item.classificationReason, privacy: .public) IPv4=\(item.ipv4.joined(separator: ","), privacy: .public) IPv6=\(item.ipv6.joined(separator: ","), privacy: .public) status=\(item.status, privacy: .public) speed=\(item.linkSpeed, privacy: .public)")
                    }
                    let fast = try SystemNetworkCounterReader(topology: NetworkTopologyTracker()).read()
                    logger.notice("fastRouteInterfaces=\(fast.interfaces.count) fastRevision=\(fast.topologyRevision) fastReadAt=\(String(describing: fast.readAt), privacy: .public)")
                    let topology = NetworkTopologyTracker()
                    let admission = CollectionAdmission()
                    admission.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
                    _ = admission.advance(.networkMetadata)
                    _ = admission.advance(.networkActivity)
                    let metadataStore = NetworkMetadataStore(admission: admission)
                    let metadataSource = NetworkMetadataSource(reader: SystemNetworkMetadataReader(topology: topology), admission: admission)
                    if let context = admission.issue(.networkMetadata),
                       let value = await metadataSource.sample(context: context) {
                        _ = await metadataStore.append(TimestampedSample(timestamp: ContinuousClock().now,
                            value: value, collectionEpoch: context.epoch, context: context), context: context)
                    }
                    let activitySource = NetworkActivitySource(reader: SystemNetworkCounterReader(topology: topology),
                        metadata: metadataStore, admission: admission)
                    for tick in 0..<2 {
                        if tick > 0 { try await Task.sleep(for: .seconds(1)) }
                        guard let context = admission.issue(.networkActivity),
                              let value = await activitySource.sample(context: context) else { continue }
                        logger.notice("activityTick=\(tick) status=\(String(describing: value.status), privacy: .public) revision=\(value.topologyRevision) knownPhysical=\(String(describing: value.knownPhysicalRates), privacy: .public) representative=\(String(describing: value.representative), privacy: .public) interfaces=\(value.interfaces.count)")
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
                    let fast = try DiskNativeAdapter().readCounters()
                    logger.notice("fastDriverCount=\(fast.count) fastIDs=\(fast.map(\.registryID).map(String.init).joined(separator: ","), privacy: .public)")
                    let topology = DiskTopologyTracker()
                    let admission = CollectionAdmission()
                    admission.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
                    _ = admission.advance(.storageMetadata)
                    _ = admission.advance(.diskActivity)
                    let storageSource = StorageMetadataSource(reader: SystemStorageMetadataReader(topology: topology), admission: admission)
                    let storageStore = StorageMetadataStore(admission: admission, topology: topology)
                    if let context = admission.issue(.storageMetadata),
                       let value = await storageSource.sample(context: context) {
                        _ = await storageStore.append(TimestampedSample(timestamp: ContinuousClock().now,
                            value: value, collectionEpoch: context.epoch, context: context), context: context)
                        switch value {
                        case .available(let metadata):
                            logger.notice("storageRevision=\(metadata.topologyRevision) systemTotal=\(metadata.systemVolume.totalBytes) systemAvailable=\(metadata.systemVolume.availableBytes) volumes=\(metadata.volumes.count) relationsComplete=\(metadata.relationshipsComplete) externalAbsent=\(metadata.externalDevicesAbsent)")
                        case .failure(let reason, _):
                            logger.error("storageFailure=\(reason, privacy: .public)")
                        }
                    }
                    let activitySource = DiskActivitySource(reader: SystemDiskCounterReader(topology: topology), admission: admission)
                    for tick in 0..<2 {
                        if tick > 0 { try await Task.sleep(for: .seconds(1)) }
                        guard let context = admission.issue(.diskActivity),
                              let value = await activitySource.sample(context: context) else { continue }
                        logger.notice("diskActivityTick=\(tick) status=\(String(describing: value.status), privacy: .public) revision=\(value.topologyRevision) knownPhysical=\(String(describing: value.knownPhysicalRates), privacy: .public) representative=\(String(describing: value.representative), privacy: .public) knownIOPS=\(String(describing: value.knownPhysicalOperations), privacy: .public) representativeIOPS=\(String(describing: value.representativeOperations), privacy: .public) devices=\(value.devices.count)")
                    }
                } catch {
                    logger.error("pid=\(getpid()) failed=\(String(describing: error), privacy: .public)")
                }
            }
        }
#endif
    }

#if DEBUG
    @MainActor private static func writeProbeImage(window: NSWindow, path: String, logger: Logger) {
        guard let view = window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            logger.error("snapshot unavailable path=\(path, privacy: .public)")
            return
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
        do {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
            logger.notice("snapshot path=\(path, privacy: .public) pixels=\(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
        } catch {
            logger.error("snapshot failed path=\(path, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }

    @MainActor private static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        for child in view.subviews {
            if let scroll = firstScrollView(in: child) { return scroll }
        }
        return nil
    }

    @MainActor private static func findNetworkAX(_ identifier: String) -> AXUIElement? {
        let root = AXUIElementCreateApplication(getpid())
        var visited = 0
        func find(_ element: AXUIElement, depth: Int) -> AXUIElement? {
            guard depth < 14, visited < 1000 else { return nil }
            visited += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
               value as? String == identifier { return element }
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
                  let children = value as? [AXUIElement] else { return nil }
            for child in children {
                if let match = find(child, depth: depth + 1) { return match }
            }
            return nil
        }
        return find(root, depth: 0)
    }

    /// 실제 서명 앱의 카드·볼륨·물리 장치 AX 값과 위치를 원본 그대로 기록합니다.
    @MainActor private static func logDiskAccessibility(logger: Logger) {
        let root = AXUIElementCreateApplication(getpid())
        var visited = 0
        func walk(_ element: AXUIElement, depth: Int) {
            guard depth < 16, visited < 1500 else { return }
            visited += 1
            var identifier: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
            if result == .success, let name = identifier as? String,
               name == "DiskCard" || name == "DiskDetail" || name == "DiskDetailClose" ||
               name == "DiskSummary" || name.hasPrefix("DiskVolume-") || name.hasPrefix("DiskDevice-") {
                var position: CFTypeRef?
                var size: CFTypeRef?
                var label: CFTypeRef?
                let positionResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
                let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
                _ = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &label)
                logger.notice("AX id=\(name, privacy: .public) positionResult=\(positionResult.rawValue) sizeResult=\(sizeResult.rawValue) position=\(String(describing: position), privacy: .public) size=\(String(describing: size), privacy: .public) label=\(String(describing: label), privacy: .public)")
            }
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
                  let children = value as? [AXUIElement] else { return }
            for child in children { walk(child, depth: depth + 1) }
        }
        walk(root, depth: 0)
        logger.notice("Disk AX traversal visited=\(visited)")
    }

    /// UI runner가 automation mode에 진입하지 못한 환경에서 앱 자신의 실제 AX 계층과 frame을 기록합니다.
    @MainActor private static func logNetworkAccessibility(logger: Logger) {
        let root = AXUIElementCreateApplication(getpid())
        var visited = 0
        func walk(_ element: AXUIElement, depth: Int) {
            guard depth < 14, visited < 1000 else { return }
            visited += 1
            var identifier: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
            if result == .success, let name = identifier as? String,
               name == "NetworkCard" || name == "NetworkDetail" ||
               name == "NetworkDetailClose" || name.hasPrefix("NetworkInterface-") {
                var position: CFTypeRef?
                var size: CFTypeRef?
                var label: CFTypeRef?
                let positionResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
                let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
                _ = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &label)
                logger.notice("AX id=\(name, privacy: .public) positionResult=\(positionResult.rawValue) sizeResult=\(sizeResult.rawValue) position=\(String(describing: position), privacy: .public) size=\(String(describing: size), privacy: .public) label=\(String(describing: label), privacy: .public)")
            }
            var valueText: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueText)
            if let content = valueText as? String,
               content.contains("Network 인터페이스") || content.contains("원시 누적 RX") {
                logger.notice("AX text=\(content, privacy: .public)")
            }
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
                  let children = value as? [AXUIElement] else { return }
            for child in children { walk(child, depth: depth + 1) }
        }
        walk(root, depth: 0)
        logger.notice("AX traversal visited=\(visited)")
    }
#endif
}
