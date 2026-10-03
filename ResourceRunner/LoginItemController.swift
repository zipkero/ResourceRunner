import Foundation
import Observation

nonisolated enum LoginItemRequestOutcome: Equatable, Sendable {
    case succeeded
    case alreadySatisfied
    case requiresApproval
    case unconfirmed
    case failed(String)
}

nonisolated struct LoginItemRequestResult: Equatable, Sendable {
    let operationID: UInt64
    let requestedEnabled: Bool
    let actualStatus: LoginItemStatus
    let outcome: LoginItemRequestOutcome
}

nonisolated struct PreferencesRestoreResult: Equatable, Sendable {
    let preferences: PreferencesSnapshot
    let loginOperationID: UInt64
}

@Observable
@MainActor
final class LoginItemController {
    private let service: any LoginItemServing
    private var nextOperationID: UInt64 = 0
    private var pending: (id: UInt64, enabled: Bool)?
    private var mutationInFlight = false

    private(set) var actualStatus: LoginItemStatus
    private(set) var activeOperationID: UInt64?
    private(set) var lastResult: LoginItemRequestResult?

    convenience init() {
        self.init(service: MainAppLoginItemService())
    }

    init(service: any LoginItemServing) {
        self.service = service
        actualStatus = service.status()
    }

    @discardableResult
    func refresh() -> LoginItemStatus {
        let status = service.status()
        actualStatus = status
        return status
    }

    @discardableResult
    func requestEnabled(_ enabled: Bool) -> UInt64 {
        if activeOperationID != nil, pending == nil, mutationInFlight,
           activeIntent == enabled {
            return activeOperationID!
        }
        if let pending, pending.enabled == enabled {
            return pending.id
        }

        nextOperationID &+= 1
        let id = nextOperationID
        activeOperationID = id
        lastResult = nil
        pending = (id, enabled)
        if !mutationInFlight {
            Task { await drainRequests() }
        }
        return id
    }

    @discardableResult
    func restoreDefaults(in preferencesStore: PreferencesStore) -> PreferencesRestoreResult {
        preferencesStore.restoreDefaults()
        let id = requestEnabled(false)
        return PreferencesRestoreResult(preferences: preferencesStore.current, loginOperationID: id)
    }

    func openSystemSettingsLoginItems() {
        service.openSystemSettingsLoginItems()
    }

    private var activeIntent: Bool? {
        running?.enabled
    }

    private var running: (id: UInt64, enabled: Bool)?

    private func drainRequests() async {
        guard !mutationInFlight else { return }
        mutationInFlight = true
        defer { mutationInFlight = false }

        while let request = pending {
            pending = nil
            running = request
            let before = service.status()
            var failure: String?
            var attempted = false

            if request.enabled {
                if before != .enabled && before != .requiresApproval {
                    attempted = true
                    do { try await service.register() }
                    catch { failure = error.localizedDescription }
                }
            } else if before != .notRegistered {
                attempted = true
                do { try await service.unregister() }
                catch { failure = error.localizedDescription }
            }

            // 진행 중 새 의도가 생겨도 실제 호출이 끝난 뒤에만 다음 호출을 시작합니다.
            let after = service.status()
            running = nil
            guard activeOperationID == request.id else { continue }
            actualStatus = after
            let outcome: LoginItemRequestOutcome
            if let failure {
                outcome = .failed(failure)
            } else if request.enabled && after == .requiresApproval {
                outcome = .requiresApproval
            } else if after.isEnabled == request.enabled &&
                        (after == .enabled || after == .notRegistered) {
                outcome = attempted ? .succeeded : .alreadySatisfied
            } else {
                outcome = .unconfirmed
            }
            lastResult = LoginItemRequestResult(
                operationID: request.id, requestedEnabled: request.enabled,
                actualStatus: after, outcome: outcome
            )
            activeOperationID = nil
        }
    }
}
