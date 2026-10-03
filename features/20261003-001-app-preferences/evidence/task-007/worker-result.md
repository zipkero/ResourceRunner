<!-- prowl-workflow: v1 implement -->
Status: blocked (제품 구현 완료, 필수 signed UI 검증 환경 차단)
Target: M4 task-007 at HEAD ccee0f6bf60435ce52739bf7cf268e2142528e95, cwd /Users/zipkero/XcodeProjects/ResourceRunner

Changed files (10; 456 insertions, 89 deletions):
- ResourceRunner/DashboardPresentation.swift: four-card visibility/order and conditional TOP5 AX labels.
- ResourceRunner/DashboardPresentationStore.swift: hidden selected card clears before snapshot publication, generation advances, hidden entry rejected.
- ResourceRunner/DashboardView.swift: conditional four cards/two ranking slots, natural collapse, all-off Settings callback seam, visible-only focus restoration.
- ResourceRunner/AppDelegate.swift, ApplicationCoordinator.swift, StatusBarController.swift: only DEBUG plus explicit --dashboard-preferences-ui-test fixture uses process-local PreferencesStorage and debug card toggle. Normal/Release path unchanged; no UserDefaults.standard write and no native login OS mutation introduced.
- ResourceRunnerTests/DashboardPresentationTests.swift, DashboardCardLayoutTests.swift, DashboardPreferencesVisibilityTests.swift: AX, 64 actual ImageRenderer combinations, height collapse, default dimensions, selected-card race/late-close tests.
- ResourceRunnerUITests/DashboardPreferencesVisibilityUITests.swift: signed UI all-off/AX and live hide/detail/re-show scenarios; compiled but test body could not run.

Validation:
- `git diff --check`: passed.
- `git apply --check --reverse /tmp/rr-m4-task007.patch`: passed, patch includes new files.
- Exact final unit command: `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:ResourceRunnerTests/DashboardPreferencesVisibilityTests -only-testing:ResourceRunnerTests/DashboardCardHeightTests -only-testing:ResourceRunnerTests/CPUCardAccessibilityLabelTests -only-testing:ResourceRunnerTests/MemoryCardAccessibilityLabelTests -only-testing:ResourceRunnerTests/DashboardSelectionTests -only-testing:ResourceRunnerTests/IntegratedDashboardSummaryTests -derivedDataPath /tmp/rr-m4-task007-derived -resultBundlePath /tmp/rr-m4-task007-unit.xcresult CODE_SIGNING_ALLOWED=YES` in cwd above: 40 passed, 0 failed/skipped, 6 suites. `/tmp/rr-m4-task007-unit.log` and `.xcresult` correspond to final source hashes.
- First 64-combination unit run had 44 assertion issues because test expectation used 32pt body padding rather than actual 16pt. Corrected expectation and reran; final 40/40 passed. Prior result retained `/tmp/rr-m4-task007-unit-initial.xcresult`.
- Exact UI command: `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:ResourceRunnerUITests/DashboardPreferencesVisibilityUITests -derivedDataPath /tmp/rr-m4-task007-derived -resultBundlePath /tmp/rr-m4-task007-ui.xcresult CODE_SIGNING_ALLOWED=YES` in cwd above: twice failed before any test body. XCTest runner error `com.apple.LocalAuthentication Code=-4, System authentication is running`; final run 0 passed, 1 runner failure, 0 skipped. First bundle `/tmp/rr-m4-task007-ui-initial.xcresult` and extracted summary `/tmp/rr-m4-task007-ui-initial-summary.log`; first xcodebuild stdout log was overwritten by retry. Second run `/tmp/rr-m4-task007-ui.log`, `.xcresult`. No TCC/authentication/system process changes attempted.

Evidence: `/tmp/rr-m4-task007.patch`, `/tmp/rr-m4-task007-source-sha256.txt`, `/tmp/rr-m4-task007-unit.log`, `/tmp/rr-m4-task007-unit.xcresult`, `/tmp/rr-m4-task007-ui.log`, `/tmp/rr-m4-task007-ui.xcresult`.

Limits/residual risk: actual UI AX tree, live hide/re-show, all-off button/frame could not execute because runner authorization was blocked independently of test code. Retry signed UI test only after system authentication completes; maintain no native login mutation. Settings button is a callback seam for task-009 and production wiring/window is intentionally pending.
