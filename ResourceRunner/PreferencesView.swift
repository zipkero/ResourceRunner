import SwiftUI

/// 저장된 일반 설정과 macOS가 보고한 로그인 상태를 각각 표시합니다.
struct PreferencesView: View {
    let preferencesStore: PreferencesStore
    let loginController: LoginItemController
    @State private var restoredLoginOperationID: UInt64?
    @State private var ordinaryRestoreMessage: String?

    private enum SettingsFocus: Hashable {
        case cpu, memory, network, disk, cpuTop, memoryTop, login

        var shortcut: KeyEquivalent {
            switch self {
            case .cpu: "1"
            case .memory: "2"
            case .network: "3"
            case .disk: "4"
            case .cpuTop: "5"
            case .memoryTop: "6"
            case .login: "9"
            }
        }

        var shortcutText: String {
            switch self {
            case .cpu: "1"
            case .memory: "2"
            case .network: "3"
            case .disk: "4"
            case .cpuTop: "5"
            case .memoryTop: "6"
            case .login: "9"
            }
        }
    }

    var body: some View {
        Form {
            Section("대시보드 표시") {
                toggle("CPU", key: "SettingsCPUCard", value: \.showsCPUCard, focus: .cpu)
                toggle("메모리", key: "SettingsMemoryCard", value: \.showsMemoryCard, focus: .memory)
                toggle("네트워크", key: "SettingsNetworkCard", value: \.showsNetworkCard, focus: .network)
                toggle("디스크", key: "SettingsDiskCard", value: \.showsDiskCard, focus: .disk)
                toggle("CPU TOP 5 앱", key: "SettingsCPUTop5", value: \.showsCPUTopApplications, focus: .cpuTop)
                toggle("메모리 TOP 5 앱", key: "SettingsMemoryTop5", value: \.showsMemoryTopApplications, focus: .memoryTop)
            }

            Section("그래프") {
                HStack {
                    Picker("표시 시간", selection: preferenceBinding(\.graphTimeRange)) {
                        Text("최근 1분").tag(GraphTimeRange.oneMinute)
                        Text("최근 5분").tag(GraphTimeRange.fiveMinutes)
                        Text("최근 10분").tag(GraphTimeRange.tenMinutes)
                    }
                    .accessibilityIdentifier("SettingsGraphRange")
                    .accessibilityLabel("표시 시간")
                    Button("다음 시간", action: cycleGraphRange)
                        .keyboardShortcut("7", modifiers: [.command, .option])
                        .help("최근 1분, 5분, 10분을 순서대로 선택합니다. 단축키 ⌘⌥7")
                        .accessibilityIdentifier("SettingsNextGraphRange")
                        .focusable()
                        .onKeyPress(keys: [.space, .return]) { press in
                            guard press.modifiers.isEmpty else { return .ignored }
                            cycleGraphRange()
                            return .handled
                        }
                }
                Text("CPU와 디스크 그래프에 적용됩니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("갱신") {
                HStack {
                    Picker("갱신 속도", selection: preferenceBinding(\.refreshProfile)) {
                        Text("빠름").tag(RefreshProfile.fast)
                        Text("기본").tag(RefreshProfile.standard)
                        Text("절전").tag(RefreshProfile.energySaving)
                        Text("매우 절전").tag(RefreshProfile.maximumEnergySaving)
                    }
                    .accessibilityIdentifier("SettingsRefreshProfile")
                    .accessibilityLabel("갱신 속도")
                    Button("다음 속도", action: cycleRefreshProfile)
                        .keyboardShortcut("8", modifiers: [.command, .option])
                        .help("네 가지 갱신 속도를 순서대로 선택합니다. 단축키 ⌘⌥8")
                        .accessibilityIdentifier("SettingsNextRefreshProfile")
                        .focusable()
                        .onKeyPress(keys: [.space, .return]) { press in
                            guard press.modifiers.isEmpty else { return .ignored }
                            cycleRefreshProfile()
                            return .handled
                        }
                }
                Text("대시보드를 닫거나 저전력 상태 또는 화면 중지 중에는 자동 조절됩니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("로그인 시 실행") {
                let loginBinding = Binding(
                    get: { loginController.actualStatus.isEnabled },
                    set: { loginController.requestEnabled($0) }
                )
                Toggle("로그인 시 실행", isOn: loginBinding)
                .disabled(loginController.activeOperationID != nil)
                .accessibilityIdentifier("SettingsLoginToggle")
                .accessibilityLabel("로그인 시 실행")
                .keyboardShortcut(SettingsFocus.login.shortcut, modifiers: [.command, .option])
                .help("실제 로그인 항목 변경을 요청합니다. 단축키 ⌘⌥9")
                .focusable(interactions: .activate)
                .onKeyPress(keys: [.space, .return]) { press in
                    guard press.modifiers.isEmpty,
                          loginController.activeOperationID == nil else { return .ignored }
                    loginBinding.wrappedValue.toggle()
                    return .handled
                }

                Text(Self.statusDescription(loginController.actualStatus))
                    .accessibilityIdentifier("SettingsLoginStatus")
                if loginController.activeOperationID != nil {
                    ProgressView("로그인 항목 변경 중…")
                        .accessibilityIdentifier("SettingsLoginProgress")
                }
                if let result = loginController.lastResult {
                    Text(Self.resultDescription(result))
                        .accessibilityIdentifier("SettingsLoginResult")
                }
                HStack {
                    Button("다시 확인", action: refreshLogin)
                        .accessibilityIdentifier("SettingsLoginRefresh")
                        .focusable()
                        .onKeyPress(keys: [.space, .return]) { press in
                            guard press.modifiers.isEmpty else { return .ignored }
                            refreshLogin()
                            return .handled
                        }
                    if loginController.actualStatus == .requiresApproval {
                        Button("시스템 설정 열기", action: openSystemLoginSettings)
                            .accessibilityIdentifier("SettingsOpenSystemLoginItems")
                            .focusable()
                            .onKeyPress(keys: [.space, .return]) { press in
                                guard press.modifiers.isEmpty else { return .ignored }
                                openSystemLoginSettings()
                                return .handled
                            }
                        Button("등록 해제", action: unregisterLoginItem)
                            .disabled(loginController.activeOperationID != nil)
                            .accessibilityIdentifier("SettingsUnregisterLoginItem")
                            .focusable()
                            .onKeyPress(keys: [.space, .return]) { press in
                                guard press.modifiers.isEmpty,
                                      loginController.activeOperationID == nil else { return .ignored }
                                unregisterLoginItem()
                                return .handled
                            }
                    }
                }
            }

            Section("기본값 복원") {
                Button("기본값 복원", action: restoreDefaults)
                .accessibilityIdentifier("SettingsRestoreDefaults")
                .focusable()
                .onKeyPress(keys: [.space, .return]) { press in
                    guard press.modifiers.isEmpty else { return .ignored }
                    restoreDefaults()
                    return .handled
                }
                if let ordinaryRestoreMessage {
                    Text(ordinaryRestoreMessage)
                        .accessibilityIdentifier("SettingsOrdinaryRestoreResult")
                }
                if let restoredLoginOperationID {
                    Text(restoreLoginDescription(for: restoredLoginOperationID))
                        .accessibilityIdentifier("SettingsLoginRestoreResult")
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 410, minHeight: 510)
    }

    private func toggle(_ title: String, key: String,
                        value: WritableKeyPath<AppPreferences, Bool>, focus: SettingsFocus) -> some View {
        let binding = preferenceBinding(value)
        return Toggle(title, isOn: binding)
            .accessibilityIdentifier(key)
            .accessibilityLabel(title)
            .keyboardShortcut(focus.shortcut, modifiers: [.command, .option])
            .help("단축키 ⌘⌥\(focus.shortcutText)")
            .focusable(interactions: .activate)
            .onKeyPress(keys: [.space, .return]) { press in
                guard press.modifiers.isEmpty else { return .ignored }
                binding.wrappedValue.toggle()
                return .handled
            }
    }

    private func refreshLogin() { loginController.refresh() }
    private func openSystemLoginSettings() { loginController.openSystemSettingsLoginItems() }
    private func unregisterLoginItem() { loginController.requestEnabled(false) }

    private func cycleGraphRange() {
        let ranges: [GraphTimeRange] = [.oneMinute, .fiveMinutes, .tenMinutes]
        guard let index = ranges.firstIndex(of: preferencesStore.current.preferences.graphTimeRange) else { return }
        preferencesStore.update { $0.graphTimeRange = ranges[(index + 1) % ranges.count] }
    }

    private func cycleRefreshProfile() {
        let profiles: [RefreshProfile] = [.fast, .standard, .energySaving, .maximumEnergySaving]
        guard let index = profiles.firstIndex(of: preferencesStore.current.preferences.refreshProfile) else { return }
        preferencesStore.update { $0.refreshProfile = profiles[(index + 1) % profiles.count] }
    }

    private func restoreDefaults() {
        let result = loginController.restoreDefaults(in: preferencesStore)
        ordinaryRestoreMessage = "일반 설정을 기본값으로 복원했습니다."
        restoredLoginOperationID = result.loginOperationID
    }

    private func preferenceBinding<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { preferencesStore.current.preferences[keyPath: keyPath] },
            set: { value in preferencesStore.update { $0[keyPath: keyPath] = value } }
        )
    }

    private func restoreLoginDescription(for operationID: UInt64) -> String {
        if loginController.activeOperationID == operationID {
            return "로그인 항목 해제를 확인하는 중입니다."
        }
        guard let result = loginController.lastResult,
              result.operationID == operationID else {
            return "로그인 항목 결과는 현재 상태와 다시 확인으로 확인하세요."
        }
        return "로그인 항목: " + Self.resultDescription(result)
    }

    static func statusDescription(_ status: LoginItemStatus) -> String {
        switch status {
        case .enabled: "등록되어 있으며 macOS에서 허용되었습니다."
        case .notRegistered: "등록되지 않았습니다."
        case .requiresApproval: "등록되었지만 macOS 승인이 필요합니다. 시스템 설정에서 승인하거나 등록을 해제할 수 있습니다."
        case .notFound: "로그인 항목 서비스를 찾을 수 없습니다. 다시 확인하거나 등록을 시도하세요."
        case .unknown: "로그인 항목 상태를 확인할 수 없습니다. 다시 확인하세요."
        }
    }

    static func resultDescription(_ result: LoginItemRequestResult) -> String {
        switch result.outcome {
        case .succeeded, .alreadySatisfied:
            return result.actualStatus == .enabled ? "켜기가 확인되었습니다." : "해제가 확인되었습니다."
        case .requiresApproval:
            return "등록 요청 뒤 macOS 승인이 필요합니다. 시스템 설정에서 확인하세요."
        case .unconfirmed:
            return "요청 뒤 상태를 확인할 수 없습니다. 다시 확인하세요."
        case .failed(let reason):
            return "요청에 실패했습니다: \(reason). 현재 상태를 확인하고 다시 시도하세요."
        }
    }
}
