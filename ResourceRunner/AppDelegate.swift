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
        if ProcessInfo.processInfo.environment["RR_NETWORK_COMPARISON_PROBE"] == "1" {
            Task { @MainActor [weak self] in
                guard let self, let coordinator = self.coordinator,
                      let caches = FileManager.default.urls(for: .cachesDirectory,
                          in: .userDomainMask).first else { return }
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "NetworkComparison")
                let output = caches.appending(path: "Task016NetworkComparison")
                try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                let samplesURL = output.appending(path: "app-samples.tsv")
                FileManager.default.createFile(atPath: samplesURL.path, contents: nil)
                guard let samples = try? FileHandle(forWritingTo: samplesURL) else { return }
                defer { try? samples.close() }
                let markerURL = output.appending(path: "phase.txt")
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                func row(_ fields: [String]) {
                    let line = fields.map { $0.replacingOccurrences(of: "\t", with: " ")
                        .replacingOccurrences(of: "\n", with: " ") }.joined(separator: "\t") + "\n"
                    samples.write(Data(line.utf8))
                }
                row(["record", "wallUTC", "uptimeSeconds", "phase", "readAt", "epoch",
                     "generation", "request", "boundary", "topologyRevision", "rateSegment",
                     "statusOrKind", "identity", "rxBytes", "txBytes", "rxBps", "txBps",
                     "completeOrPartial", "extra"])
                try? await Task.sleep(for: .seconds(2))
                coordinator.statusBarController.togglePopover()
                try? await Task.sleep(for: .milliseconds(500))
                coordinator.dashboardPresentationStore.selectCard(.network)
                try? await Task.sleep(for: .milliseconds(500))
                try? "ready".write(to: output.appending(path: "ready.txt"),
                    atomically: true, encoding: .utf8)
                logger.notice("ready pid=\(getpid()) output=\(output.path, privacy: .public) popover=\(coordinator.statusBarController.popover.isShown) selection=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public)")
                var priorPhase = ""
                var captureAt: Date?
                for _ in 0..<155 {
                    let phase = (try? String(contentsOf: markerURL, encoding: .utf8))?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unmarked"
                    if phase == "done" { break }
                    let wall = iso.string(from: Date())
                    let uptime = String(ProcessInfo.processInfo.systemUptime)
                    let latest = await coordinator.collectionPipelines.networkStore
                        .snapshot(at: ContinuousClock().now).latest
                    let delivered = coordinator.collectionDeliveryStore.networkActivity?.latest
                    let card = coordinator.dashboardPresentationStore.networkCard
                    if let latest {
                        let sample = latest.value
                        let context = latest.context
                        let common = [wall, uptime, phase, String(describing: sample.readAt),
                                      String(latest.collectionEpoch),
                                      String(context?.generation ?? -1),
                                      String(context?.requestSequence ?? -1),
                                      String(context?.boundarySequence ?? -1),
                                      String(sample.topologyRevision), String(sample.rateSegment)]
                        row(["sample"] + common + [String(describing: sample.status), "knownPhysical",
                            "", "", String(sample.knownPhysicalRates?.receivedBytesPerSecond ?? -1),
                            String(sample.knownPhysicalRates?.sentBytesPerSecond ?? -1),
                            String(sample.physicalTotalsComplete),
                            "representativeRX=\(sample.representative?.receivedBytesPerSecond ?? -1);representativeTX=\(sample.representative?.sentBytesPerSecond ?? -1)"])
                        for item in sample.interfaces {
                            let identity = "\(item.key.name)#\(item.key.index)#\(item.key.registryID.map(String.init) ?? "nil")#\(item.key.lifetime)"
                            row(["interface"] + common + [item.kind.rawValue, identity,
                                String(item.receivedBytes), String(item.sentBytes),
                                String(item.rate?.receivedBytesPerSecond ?? -1),
                                String(item.rate?.sentBytesPerSecond ?? -1),
                                String(describing: item.linkActive), item.classificationReason])
                        }
                        row(["delivery"] + common + ["delivered", "networkActivity", "", "", "", "",
                            "", "sameReadAt=\(delivered?.value.readAt == sample.readAt)"])
                    }
                    row(["card", wall, uptime, phase,
                        String(describing: card.latestReadAt), "", "", "", "",
                        String(card.topologyRevision ?? 0), "", String(describing: card.phase),
                        "NetworkCard", "", "",
                        String(card.currentRate?.receivedBytesPerSecond ?? -1),
                        String(card.currentRate?.sentBytesPerSecond ?? -1),
                        String(card.currentRateIsPartial), card.accessibilityLabel])
                    if phase != priorPhase {
                        logger.notice("phase=\(phase, privacy: .public) wall=\(wall, privacy: .public)")
                        priorPhase = phase
                        captureAt = Date().addingTimeInterval(8)
                    }
                    if let deadline = captureAt, Date() >= deadline {
                        if let body = coordinator.statusBarController.popover.contentViewController?.view.window {
                            Self.writeProbeImage(window: body,
                                path: output.appending(path: "\(phase)-card.png").path, logger: logger)
                        }
                        if let detail = coordinator.statusBarController.viewport?.detailWindow {
                            if let content = detail.contentView,
                               let scroll = Self.firstScrollView(in: content) {
                                scroll.contentView.scroll(to: NSPoint(x: 0, y: 2_500))
                                scroll.reflectScrolledClipView(scroll.contentView)
                            }
                            Self.writeProbeImage(window: detail,
                                path: output.appending(path: "\(phase)-detail.png").path, logger: logger)
                        }
                        Self.logNetworkAccessibility(logger: logger)
                        captureAt = nil
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
                logger.notice("finished output=\(output.path, privacy: .public)")
            }
        }
        if ProcessInfo.processInfo.environment["RR_DISK_COMPARISON_PROBE"] == "1" {
            Task { @MainActor [weak self] in
                guard let self, let coordinator = self.coordinator,
                      let caches = FileManager.default.urls(for: .cachesDirectory,
                          in: .userDomainMask).first else { return }
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "DiskComparison")
                let output = caches.appending(path: "Task017DiskComparison")
                try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                let samplesURL = output.appending(path: "app-samples.tsv")
                FileManager.default.createFile(atPath: samplesURL.path, contents: nil)
                guard let samples = try? FileHandle(forWritingTo: samplesURL) else { return }
                defer { try? samples.close() }
                let markerURL = output.appending(path: "phase.txt")
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                func row(_ fields: [String]) {
                    let line = fields.map { $0.replacingOccurrences(of: "\t", with: " ")
                        .replacingOccurrences(of: "\n", with: " ") }.joined(separator: "\t") + "\n"
                    samples.write(Data(line.utf8))
                }
                row(["record", "wallUTC", "uptimeSeconds", "phase", "readAt", "epoch",
                     "generation", "request", "boundary", "topologyRevision", "rateSegment",
                     "statusOrKind", "identity", "bsdNames", "readBytes", "writeBytes",
                     "readBps", "writeBps", "readOps", "writeOps", "completeOrPartial", "extra"])
                try? await Task.sleep(for: .seconds(2))
                coordinator.statusBarController.togglePopover()
                try? await Task.sleep(for: .milliseconds(500))
                coordinator.dashboardPresentationStore.selectCard(.disk)
                try? await Task.sleep(for: .milliseconds(500))
                try? "ready".write(to: output.appending(path: "ready.txt"),
                    atomically: true, encoding: .utf8)
                logger.notice("ready pid=\(getpid()) output=\(output.path, privacy: .public) popover=\(coordinator.statusBarController.popover.isShown) selection=\(String(describing: coordinator.dashboardPresentationStore.selection), privacy: .public)")
                var priorPhase = ""
                var captureAt: Date?
                for _ in 0..<155 {
                    let phase = (try? String(contentsOf: markerURL, encoding: .utf8))?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unmarked"
                    if phase == "done" { break }
                    let wall = iso.string(from: Date())
                    let uptime = String(ProcessInfo.processInfo.systemUptime)
                    let latest = await coordinator.collectionPipelines.diskStore
                        .snapshot(at: ContinuousClock().now).latest
                    let delivered = coordinator.collectionDeliveryStore.diskActivity?.latest
                    let card = coordinator.dashboardPresentationStore.diskCard
                    if let latest {
                        let sample = latest.value
                        let context = latest.context
                        let common = [wall, uptime, phase, String(describing: sample.readAt),
                                      String(latest.collectionEpoch), String(context?.generation ?? -1),
                                      String(context?.requestSequence ?? -1),
                                      String(context?.boundarySequence ?? -1),
                                      String(sample.topologyRevision), String(sample.rateSegment)]
                        row(["sample"] + common + [String(describing: sample.status), "knownPhysical",
                            "", "", "", String(sample.knownPhysicalRates?.receivedBytesPerSecond ?? -1),
                            String(sample.knownPhysicalRates?.sentBytesPerSecond ?? -1), "", "",
                            String(sample.physicalTotalsComplete),
                            "representativeRead=\(sample.representative?.receivedBytesPerSecond ?? -1);representativeWrite=\(sample.representative?.sentBytesPerSecond ?? -1)"])
                        for item in sample.devices {
                            row(["device"] + common + [item.kind.rawValue, String(item.registryID),
                                item.bsdNames.sorted().joined(separator: ","),
                                item.readBytes.map(String.init) ?? "nil",
                                item.writtenBytes.map(String.init) ?? "nil",
                                String(item.rate?.receivedBytesPerSecond ?? -1),
                                String(item.rate?.sentBytesPerSecond ?? -1),
                                item.readOperations.map(String.init) ?? "nil",
                                item.writeOperations.map(String.init) ?? "nil",
                                String(sample.physicalTotalsComplete),
                                "bytesReason=\(item.bytesReason);operationsReason=\(item.operationsReason)"])
                        }
                        row(["delivery"] + common + ["delivered", "diskActivity", "", "", "",
                            "", "", "", "", "", "sameReadAt=\(delivered?.value.readAt == sample.readAt)"])
                    }
                    row(["card", wall, uptime, phase,
                        String(describing: card.latestReadAt), "", "", "", "",
                        String(card.topologyRevision ?? 0), "", String(describing: card.phase),
                        "DiskCard", "", "", "",
                        String(card.currentRate?.receivedBytesPerSecond ?? -1),
                        String(card.currentRate?.sentBytesPerSecond ?? -1), "", "",
                        String(card.currentRateIsPartial), card.accessibilityLabel])
                    if phase != priorPhase {
                        logger.notice("phase=\(phase, privacy: .public) wall=\(wall, privacy: .public)")
                        priorPhase = phase
                        captureAt = Date().addingTimeInterval(8)
                    }
                    if let deadline = captureAt, Date() >= deadline {
                        if let body = coordinator.statusBarController.popover.contentViewController?.view.window {
                            Self.writeProbeImage(window: body,
                                path: output.appending(path: "\(phase)-card.png").path, logger: logger)
                        }
                        if let detail = coordinator.statusBarController.viewport?.detailWindow {
                            if let content = detail.contentView,
                               let scroll = Self.firstScrollView(in: content) {
                                scroll.contentView.scroll(to: NSPoint(x: 0, y: 900))
                                scroll.reflectScrolledClipView(scroll.contentView)
                            }
                            Self.writeProbeImage(window: detail,
                                path: output.appending(path: "\(phase)-detail.png").path, logger: logger)
                        }
                        Self.logDiskAccessibility(logger: logger)
                        captureAt = nil
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
                logger.notice("finished output=\(output.path, privacy: .public)")
            }
        }
        if ProcessInfo.processInfo.environment["RR_KEYBOARD_PROBE"] == "1" {
            Task { @MainActor [weak self] in
                guard let self, let coordinator = self.coordinator else { return }
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "KeyboardProbe")
                let status = coordinator.statusBarController
                let store = coordinator.dashboardPresentationStore
                logger.notice("keyboardMode=\(UserDefaults.standard.object(forKey: "AppleKeyboardUIMode") as? Int ?? -1) screen=\(String(describing: NSScreen.main?.visibleFrame), privacy: .public) scale=\(NSScreen.main?.backingScaleFactor ?? 0)")
                try? await Task.sleep(for: .seconds(4))
                status.togglePopover()
                try? await Task.sleep(for: .milliseconds(600))
                guard let body = status.popover.contentViewController?.view.window else { return }
                logger.notice("body=\(String(describing: body.frame), privacy: .public) noScroll=\(Self.firstScrollView(in: body.contentView ?? NSView()) == nil)")
                @MainActor func send(_ keyCode: UInt16, _ characters: String, command: Bool = false,
                          window: NSWindow? = nil, delay: Int = 180) async {
                    let target = window ?? status.viewport?.detailWindow ?? body
                    guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
                        modifierFlags: command ? .command : [], timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: target.windowNumber, context: nil,
                        characters: characters, charactersIgnoringModifiers: characters,
                        isARepeat: false, keyCode: keyCode) else { return }
                    NSApp.sendEvent(event)
                    try? await Task.sleep(for: .milliseconds(delay))
                    logger.notice("key code=\(keyCode) command=\(command) target=\(target.windowNumber) selection=\(String(describing: store.selection), privacy: .public) generation=\(store.selectionGeneration) keyWindow=\(String(describing: NSApp.keyWindow?.windowNumber), privacy: .public) focused=\(Self.probeFocusedIdentifier() ?? "none", privacy: .public) detail=\(String(describing: status.viewport?.detailWindow?.frame), privacy: .public)")
                }
                await send(18, "1", command: true, window: body)
                await send(19, "2", command: true)
                await send(20, "3", command: true)
                await send(18, "1", command: true)
                await send(18, "1", command: true)
                for (key, code, card, cardID, closeID) in [
                    ("1", UInt16(18), DashboardSelection.cpu, "CPUCard", "CPUDetailClose"),
                    ("2", UInt16(19), .memory, "MemoryCard", "MemoryDetailClose"),
                    ("3", UInt16(20), .network, "NetworkCard", "NetworkDetailClose"),
                    ("4", UInt16(21), .disk, "DiskCard", "DiskDetailClose")
                ] {
                    await send(code, key, command: true, window: body)
                    let child = status.viewport?.detailWindow
                    logger.notice("opened card=\(String(describing: card), privacy: .public) owned=\(status.viewport?.detailSelection == card) childKey=\(NSApp.keyWindow === child) cardAX=\(String(describing: Self.probeAXFrame(identifier: cardID)), privacy: .public) closeAX=\(Self.probeAXElement(identifier: closeID) != nil)")
                    if card == .network || card == .disk {
                        Self.logKeyboardAccessibility(logger: logger)
                    }
                    if let child, let content = child.contentView,
                       let scroll = Self.firstScrollView(in: content) {
                        let clip = scroll.contentView
                        let documentHeight = scroll.documentView?.frame.height ?? 0
                        let pages = min(100, Int(ceil(documentHeight / max(1, clip.bounds.height))) + 1)
                        let start = clip.bounds.minY
                        for _ in 0..<pages { await send(121, "", window: body, delay: 15) }
                        logger.notice("pageEnd card=\(String(describing: card), privacy: .public) pages=\(pages) start=\(start) document=\(documentHeight) clip=\(String(describing: clip.bounds), privacy: .public) expectedEnd=\(max(0, documentHeight - clip.bounds.height))")
                        if card == .network || card == .disk {
                            Self.logKeyboardAccessibility(logger: logger)
                        }
                        await send(116, "", window: body, delay: 40)
                        logger.notice("pageUp card=\(String(describing: card), privacy: .public) clip=\(String(describing: clip.bounds), privacy: .public)")
                    }
                    if let close = Self.probeAXElement(identifier: closeID) {
                        let result = AXUIElementPerformAction(close, kAXPressAction as CFString)
                        try? await Task.sleep(for: .milliseconds(220))
                        logger.notice("AXClose card=\(String(describing: card), privacy: .public) result=\(result.rawValue) selection=\(String(describing: store.selection), privacy: .public) keyWindow=\(String(describing: NSApp.keyWindow?.windowNumber), privacy: .public) responder=\(String(describing: NSApp.keyWindow?.firstResponder), privacy: .public) focused=\(Self.probeFocusedIdentifier() ?? "none", privacy: .public)")
                    }
                    await send(code, key, command: true, window: body)
                    await send(53, "", window: body)
                    logger.notice("escape card=\(String(describing: card), privacy: .public) selection=\(String(describing: store.selection), privacy: .public) bodyShown=\(status.popover.isShown) focused=\(Self.probeFocusedIdentifier() ?? "none", privacy: .public)")
                    await send(code, key, command: true, window: body)
                    await send(code, key, command: true, window: body)
                }
                Self.logIntegratedAccessibility(logger: logger)
                status.togglePopover()
            }
        }
        if ProcessInfo.processInfo.environment["RR_VIEWPORT_PROBE"] == "1" {
            Task { @MainActor [weak self] in
                guard let self, let coordinator = self.coordinator else { return }
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "ViewportProbe")
                let status = coordinator.statusBarController
                let store = coordinator.dashboardPresentationStore
                for (index, screen) in NSScreen.screens.enumerated() {
                    logger.notice("screen index=\(index) frame=\(String(describing: screen.frame), privacy: .public) visible=\(String(describing: screen.visibleFrame), privacy: .public) scale=\(screen.backingScaleFactor, privacy: .public)")
                }
                try? await Task.sleep(for: .seconds(4))
                status.togglePopover()
                try? await Task.sleep(for: .milliseconds(700))
                guard let body = status.popover.contentViewController?.view.window,
                      let screen = status.statusItem.button?.window?.screen ?? NSScreen.main else {
                    logger.error("body or screen missing")
                    return
                }
                logger.notice("body frame=\(String(describing: body.frame), privacy: .public) visible=\(String(describing: screen.visibleFrame), privacy: .public) inside8=\(DashboardViewportPolicy.contains(body.frame, visibleFrame: screen.visibleFrame)) bodyScroll=\(Self.firstScrollView(in: body.contentView ?? NSView()) != nil)")
                if ProcessInfo.processInfo.environment["RR_VIEWPORT_LONG_MEMORY"] == "1" {
                    let injected = store.injectLongMemoryForViewportProbe()
                    try? await Task.sleep(for: .milliseconds(350))
                    logger.notice("longMemory injected=\(injected) body=\(String(describing: body.frame), privacy: .public) memoryCard=\(String(describing: Self.probeAXFrame(identifier: "MemoryCard")), privacy: .public) detailSize=\(String(describing: status.viewport?.detailSize), privacy: .public)")
                    if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                        let output = caches.appending(path: "Task012ViewportProbe")
                        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                        Self.writeProbeImage(window: body, path: output.appending(path: "long-memory-body.png").path, logger: logger)
                    }
                    store.selectCard(.disk)
                    try? await Task.sleep(for: .milliseconds(650))
                    let detail = status.viewport?.detailWindow
                    logger.notice("longMemoryDisk body=\(String(describing: body.frame), privacy: .public) diskCard=\(String(describing: Self.probeAXFrame(identifier: "DiskCard")), privacy: .public) detail=\(String(describing: detail?.frame), privacy: .public) inside8=\(detail.map { DashboardViewportPolicy.contains($0.frame, visibleFrame: $0.screen?.visibleFrame ?? screen.visibleFrame) } ?? false)")
                    store.selectCard(.disk)
                    status.togglePopover()
                    return
                }
                Self.logIntegratedAccessibility(logger: logger)
                guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
                let output = caches.appending(path: "Task012ViewportProbe")
                try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                Self.writeProbeImage(window: body, path: output.appending(path: "body.png").path, logger: logger)
                for selection in [DashboardSelection.cpu, .memory, .network, .disk] {
                    store.selectCard(selection)
                    try? await Task.sleep(for: .milliseconds(650))
                    let detail = status.viewport?.detailWindow
                    let identifier: String = switch selection {
                    case .cpu: "CPUCard"
                    case .memory: "MemoryCard"
                    case .network: "NetworkCard"
                    case .disk: "DiskCard"
                    case .none: "DashboardContainer"
                    }
                    let card = Self.probeAXFrame(identifier: identifier)
                    let detailScreen = detail?.screen ?? screen
                    let detailFrame = detail?.frame
                    logger.notice("selection=\(String(describing: selection), privacy: .public) owned=\(status.viewport?.detailSelection == selection) cardAX=\(String(describing: card), privacy: .public) detail=\(String(describing: detailFrame), privacy: .public) inside8=\(detailFrame.map { DashboardViewportPolicy.contains($0, visibleFrame: detailScreen.visibleFrame) } ?? false) body=\(String(describing: body.frame), privacy: .public)")
                    Self.logIntegratedAccessibility(logger: logger)
                    if let detail {
                        Self.writeProbeImage(window: detail,
                            path: output.appending(path: "\(selection)-detail.png").path, logger: logger)
                        if let content = detail.contentView,
                           let scroll = Self.firstScrollView(in: content) {
                            let last = max(0, (scroll.documentView?.frame.height ?? 0) - scroll.contentView.bounds.height)
                            scroll.contentView.scroll(to: NSPoint(x: 0, y: last))
                            scroll.reflectScrolledClipView(scroll.contentView)
                            try? await Task.sleep(for: .milliseconds(120))
                            logger.notice("detailEnd selection=\(String(describing: selection), privacy: .public) document=\(String(describing: scroll.documentView?.frame), privacy: .public) clip=\(String(describing: scroll.contentView.bounds), privacy: .public)")
                        }
                    }
                    store.selectCard(selection)
                    try? await Task.sleep(for: .milliseconds(180))
                    logger.notice("closed selection=\(String(describing: store.selection), privacy: .public) body=\(String(describing: body.frame), privacy: .public)")
                }
                status.togglePopover()
            }
        }
        if ProcessInfo.processInfo.environment["RR_INTEGRATED_UI_PROBE"] == "1" {
            Task { @MainActor [weak self] in
                guard let self, let coordinator = self.coordinator else { return }
                let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "IntegratedUIProbe")
                let status = coordinator.statusBarController
                let store = coordinator.dashboardPresentationStore
                let screen = status.statusItem.button?.window?.screen ?? NSScreen.main
                logger.notice("screen visibleFrame=\(String(describing: screen?.visibleFrame), privacy: .public) frame=\(String(describing: screen?.frame), privacy: .public) scale=\(screen?.backingScaleFactor ?? 0)")
                logger.notice("launch cpuState=\(String(describing: store.cpuCard), privacy: .public) memoryState=\(String(describing: store.memoryCard), privacy: .public)")
                try? await Task.sleep(for: .seconds(4))
                status.togglePopover()
                try? await Task.sleep(for: .seconds(1))
                logger.notice("opened selection=\(String(describing: store.selection), privacy: .public) cpuState=\(String(describing: store.cpuCard), privacy: .public) memoryState=\(String(describing: store.memoryCard), privacy: .public)")
                Self.logIntegratedAccessibility(logger: logger)
                guard let body = status.popover.contentViewController?.view,
                      let parent = body.window else { logger.error("body window missing"); return }
                let hasBodyScroll = Self.firstScrollView(in: body) != nil
                logger.notice("body frame=\(String(describing: parent.frame), privacy: .public) contentFrame=\(String(describing: body.frame), privacy: .public) bodyScroll=\(hasBodyScroll)")
                Self.logIntegratedAccessibility(logger: logger)
                guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
                let output = caches.appending(path: "Task011ReadableIntegrated")
                try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                Self.writeProbeImage(window: parent, path: output.appending(path: "actual-all-cards.png").path, logger: logger)

                for selection in [DashboardSelection.memory, .disk] {
                    store.selectCard(selection)
                    try? await Task.sleep(for: .milliseconds(450))
                    let detail = NSApp.windows.first { $0 !== parent && $0.isVisible && $0.frame.width >= 350 }
                    logger.notice("detail selection=\(String(describing: selection), privacy: .public) frame=\(String(describing: detail?.frame), privacy: .public) bodyFrame=\(String(describing: parent.frame), privacy: .public)")
                    Self.logIntegratedAccessibility(logger: logger)
                    if let detail {
                        Self.writeProbeImage(window: detail, path: output.appending(path: "actual-\(selection)-detail.png").path, logger: logger)
                    }
                    if selection == .disk, let close = Self.findNetworkAX("DiskDetailClose") {
                        let result = AXUIElementPerformAction(close, kAXPressAction as CFString)
                        logger.notice("Disk AXPress close result=\(result.rawValue)")
                    } else {
                        store.selectCard(selection)
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                    logger.notice("closed selection=\(String(describing: store.selection), privacy: .public) bodyFrame=\(String(describing: parent.frame), privacy: .public)")
                }
                status.togglePopover()
            }
        }
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
                    let output = caches.appending(path: "Task010CadenceProbe")
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
                    let lastOrigin = max(0, (scroll.documentView?.frame.height ?? 0) -
                        scroll.contentView.bounds.height)
                    scroll.contentView.scroll(to: NSPoint(x: 0, y: lastOrigin))
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
    @MainActor private static func probeAXElement(identifier: String) -> AXUIElement? {
        let root = AXUIElementCreateApplication(getpid())
        func search(_ element: AXUIElement, depth: Int) -> AXUIElement? {
            guard depth < 18 else { return nil }
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
               value as? String == identifier { return element }
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
                  let children = value as? [AXUIElement] else { return nil }
            for child in children {
                if let found = search(child, depth: depth + 1) { return found }
            }
            return nil
        }
        return search(root, depth: 0)
    }

    @MainActor private static func probeFocusedIdentifier() -> String? {
        let root = AXUIElementCreateApplication(getpid())
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString,
            &focused) == .success, let element = focused as! AXUIElement? else { return nil }
        var identifier: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString,
            &identifier) == .success else { return nil }
        return identifier as? String
    }

    @MainActor private static func logKeyboardAccessibility(logger: Logger) {
        let root = AXUIElementCreateApplication(getpid())
        var visited = 0
        func walk(_ element: AXUIElement, depth: Int) {
            guard depth < 20, visited < 2000 else { return }
            visited += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString,
                &value) == .success, let identifier = value as? String,
               identifier.hasPrefix("NetworkInterface-")
                || identifier.hasPrefix("DiskVolume-")
                || identifier.hasPrefix("DiskDevice-")
                || ["CPUCard", "MemoryCard", "NetworkCard", "DiskCard", "NetworkUpdateCadence",
                    "NetworkDetail", "DiskSummary", "DiskDetail", "DiskMiniGraph"].contains(identifier) {
                var description: CFTypeRef?
                var title: CFTypeRef?
                var axValue: CFTypeRef?
                var frame: CFTypeRef?
                var size: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString,
                    &description)
                _ = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
                _ = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &axValue)
                _ = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &frame)
                _ = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
                var point = CGPoint.zero
                var dimensions = CGSize.zero
                if let frame { _ = AXValueGetValue(frame as! AXValue, .cgPoint, &point) }
                if let size { _ = AXValueGetValue(size as! AXValue, .cgSize, &dimensions) }
                logger.notice("detailAX id=\(identifier, privacy: .public) description=\(String(describing: description), privacy: .public) title=\(String(describing: title), privacy: .public) value=\(String(describing: axValue), privacy: .public) frame=\(String(describing: CGRect(origin: point, size: dimensions)), privacy: .public)")
            }
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString,
                &value) == .success, let children = value as? [AXUIElement] else { return }
            for child in children { walk(child, depth: depth + 1) }
        }
        walk(root, depth: 0)
        logger.notice("detailAX visited=\(visited)")
    }

    /// probe에서 카드 AX frame을 읽어 자식 창이 선택 카드 옆에 남는지 확인합니다.
    @MainActor private static func probeAXFrame(identifier: String) -> CGRect? {
        let root = AXUIElementCreateApplication(getpid())
        func search(_ element: AXUIElement, depth: Int) -> CGRect? {
            guard depth < 16 else { return nil }
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
               value as? String == identifier {
                var position: CFTypeRef?
                var size: CFTypeRef?
                guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
                      AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
                      let position, let size else { return nil }
                var point = CGPoint.zero
                var dimensions = CGSize.zero
                guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
                      AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
                return CGRect(origin: point, size: dimensions)
            }
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
                  let children = value as? [AXUIElement] else { return nil }
            for child in children {
                if let found = search(child, depth: depth + 1) { return found }
            }
            return nil
        }
        return search(root, depth: 0)
    }

    /// 실제 팝오버의 네 카드 위치와 접근성 이름을 함께 남겨 본체 무스크롤 배치를 확인합니다.
    @MainActor private static func logIntegratedAccessibility(logger: Logger) {
        let root = AXUIElementCreateApplication(getpid())
        let wanted: Set<String> = ["DashboardContainer", "CPUCard", "MemoryCard", "NetworkCard", "DiskCard", "DashboardDetail", "DiskDetailClose"]
        var visited = 0
        func walk(_ element: AXUIElement, depth: Int) {
            guard depth < 16, visited < 1500 else { return }
            visited += 1
            var identifier: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier) == .success,
               let name = identifier as? String, wanted.contains(name) {
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
        logger.notice("integrated AX traversal visited=\(visited)")
    }

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
               name == "NetworkDetailClose" || name == "NetworkUpdateCadence" ||
               name.hasPrefix("NetworkInterface-") {
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
               content.contains("Network 인터페이스") || content.contains("원시 누적 RX") ||
               content.contains("별도 느린 주기") {
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
