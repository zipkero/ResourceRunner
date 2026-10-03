import Foundation
import Testing
@testable import ResourceRunner

@MainActor
private final class ControlledLoginItemService: LoginItemServing {
    var currentStatus: LoginItemStatus = .notRegistered
    var calls: [String] = []
    var readCount = 0
    var activeMutations = 0
    var maximumMutations = 0
    var pauseMutations = false
    private var continuations: [CheckedContinuation<Void, Error>] = []

    func status() -> LoginItemStatus {
        readCount += 1
        calls.append("status")
        return currentStatus
    }

    func register() async throws { try await mutate("register") }
    func unregister() async throws { try await mutate("unregister") }

    private func mutate(_ name: String) async throws {
        calls.append(name)
        activeMutations += 1
        maximumMutations = max(maximumMutations, activeMutations)
        defer { activeMutations -= 1 }
        if pauseMutations {
            try await withCheckedThrowingContinuation { continuations.append($0) }
        }
    }

    func finish(_ result: Result<Void, Error> = .success(())) {
        continuations.removeFirst().resume(with: result)
    }

    func openSystemSettingsLoginItems() { calls.append("openSettings") }
}

@MainActor
private final class RestoreStorage: PreferencesStorage {
    var writes = 0
    func read() -> Any? { nil }
    func write(_ dictionary: [String: Any]) { writes += 1 }
}

@MainActor
private func eventually(_ condition: @MainActor () -> Bool) async {
    for _ in 0..<1_000 where !condition() { await Task.yield() }
    #expect(condition())
}

@MainActor
struct LoginItemControllerTests {
    @Test func initialAndRefreshOnlyReadActualState() {
        let service = ControlledLoginItemService()
        let controller = LoginItemController(service: service)
        #expect(controller.actualStatus == .notRegistered)
        #expect(service.calls == ["status"])

        for status: LoginItemStatus in [.enabled, .requiresApproval, .notFound, .unknown(99), .notRegistered] {
            service.currentStatus = status
            #expect(controller.refresh() == status)
            #expect(controller.actualStatus == status)
        }
        #expect(service.calls.allSatisfy { $0 == "status" })
        controller.openSystemSettingsLoginItems()
        #expect(service.calls.last == "openSettings")
    }

    @Test func onSucceedsOnlyAfterEnabledStatusAndReadsAfterMutation() async {
        let service = ControlledLoginItemService()
        let controller = LoginItemController(service: service)
        let id = controller.requestEnabled(true)
        await eventually { controller.lastResult != nil }
        #expect(controller.lastResult == LoginItemRequestResult(
            operationID: id, requestedEnabled: true,
            actualStatus: .notRegistered, outcome: .unconfirmed
        ))
        #expect(service.calls == ["status", "status", "register", "status"])

        service.currentStatus = .enabled
        let second = controller.requestEnabled(true)
        await eventually { controller.lastResult?.operationID == second }
        #expect(controller.lastResult?.outcome == .alreadySatisfied)
        #expect(service.calls.filter { $0 == "register" }.count == 1)
    }

    @Test func completedMutationsUseRefreshedStatusForSuccessAndApproval() async {
        let service = ControlledLoginItemService()
        service.pauseMutations = true
        let controller = LoginItemController(service: service)

        let approvalID = controller.requestEnabled(true)
        await eventually { service.activeMutations == 1 }
        service.currentStatus = .requiresApproval
        service.finish()
        await eventually { controller.lastResult?.operationID == approvalID }
        #expect(controller.lastResult?.outcome == .requiresApproval)

        let offID = controller.requestEnabled(false)
        await eventually { service.activeMutations == 1 }
        service.currentStatus = .notRegistered
        service.finish()
        await eventually { controller.lastResult?.operationID == offID }
        #expect(controller.lastResult?.outcome == .succeeded)

        let onID = controller.requestEnabled(true)
        await eventually { service.activeMutations == 1 }
        service.currentStatus = .enabled
        service.finish()
        await eventually { controller.lastResult?.operationID == onID }
        #expect(controller.lastResult?.outcome == .succeeded)
        #expect(service.maximumMutations == 1)
    }

    @Test func approvalFailureAndUnknownRemainDistinctFromActualState() async {
        let service = ControlledLoginItemService()
        service.currentStatus = .requiresApproval
        let controller = LoginItemController(service: service)
        let approvalID = controller.requestEnabled(true)
        await eventually { controller.lastResult?.operationID == approvalID }
        #expect(controller.lastResult?.outcome == .requiresApproval)
        #expect(!controller.actualStatus.isEnabled)
        #expect(!service.calls.contains("register"))

        service.currentStatus = .notFound
        service.pauseMutations = true
        let id = controller.requestEnabled(true)
        await eventually { service.activeMutations == 1 }
        service.currentStatus = .unknown(81)
        service.finish(.failure(NSError(domain: "test", code: 8)))
        await eventually { controller.lastResult?.operationID == id }
        if case .failed(let message) = controller.lastResult?.outcome {
            #expect(!message.isEmpty)
        } else {
            Issue.record("throw 결과가 실패로 분류되지 않았습니다")
        }
        #expect(controller.actualStatus == .unknown(81))
    }

    @Test func offAlreadyNotRegisteredSkipsMutationAndFailedOffDoesNotClaimSuccess() async {
        let service = ControlledLoginItemService()
        let controller = LoginItemController(service: service)
        let first = controller.requestEnabled(false)
        await eventually { controller.lastResult?.operationID == first }
        #expect(controller.lastResult?.outcome == .alreadySatisfied)
        #expect(!service.calls.contains("unregister"))

        service.currentStatus = .enabled
        service.pauseMutations = true
        let second = controller.requestEnabled(false)
        await eventually { service.activeMutations == 1 }
        service.finish(.failure(NSError(domain: "test", code: 9)))
        await eventually { controller.lastResult?.operationID == second }
        #expect(controller.actualStatus == .enabled)
        if case .failed = controller.lastResult?.outcome {} else {
            Issue.record("해제 throw를 성공으로 분류했습니다")
        }
    }

    @Test func latestIntentWaitsForMutationAndStaleCompletionCannotPublish() async {
        let service = ControlledLoginItemService()
        service.pauseMutations = true
        let controller = LoginItemController(service: service)
        let old = controller.requestEnabled(true)
        await eventually { service.activeMutations == 1 }
        #expect(controller.requestEnabled(true) == old)
        let intermediate = controller.requestEnabled(false)
        let latest = controller.requestEnabled(true)
        #expect(intermediate != latest)
        #expect(controller.activeOperationID == latest)
        service.currentStatus = .enabled
        service.finish()
        await eventually { controller.lastResult?.operationID == latest }
        #expect(controller.lastResult?.outcome == .alreadySatisfied)
        #expect(service.calls.filter { $0 == "register" }.count == 1)
        #expect(!service.calls.contains("unregister"))
        #expect(service.maximumMutations == 1)
        #expect(controller.actualStatus == .enabled)
    }

    @Test func restoreWritesOrdinaryPreferencesOnceAndSerializesOffAfterPendingOn() async {
        let service = ControlledLoginItemService()
        service.pauseMutations = true
        let controller = LoginItemController(service: service)
        let storage = RestoreStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.update { $0.showsCPUCard = false }
        let on = controller.requestEnabled(true)
        await eventually { service.activeMutations == 1 }
        let restored = controller.restoreDefaults(in: preferences)
        #expect(storage.writes == 2)
        #expect(restored.preferences.preferences == .defaults)
        #expect(restored.preferences.revision == 2)
        #expect(restored.loginOperationID != on)
        #expect(controller.lastResult == nil)

        service.currentStatus = .enabled
        service.finish()
        await eventually { service.calls.contains("unregister") }
        #expect(controller.lastResult == nil)
        #expect(controller.activeOperationID == restored.loginOperationID)
        #expect(service.maximumMutations == 1)
        service.currentStatus = .notRegistered
        service.finish(.failure(NSError(domain: "test", code: 10)))
        await eventually { controller.lastResult?.operationID == restored.loginOperationID }
        #expect(controller.actualStatus == .notRegistered)
        if case .failed = controller.lastResult?.outcome {} else {
            Issue.record("복원 로그인 실패가 별도 결과로 남지 않았습니다")
        }
        #expect(preferences.current.preferences == .defaults)
        #expect(storage.writes == 2)
    }
}
