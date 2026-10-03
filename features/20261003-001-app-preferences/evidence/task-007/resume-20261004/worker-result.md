<!-- prowl-workflow: v1 implement -->
Status: completed
Target: task-007 UI 접근성 식별자 수리; cwd /Users/zipkero/XcodeProjects/ResourceRunner; 검증 HEAD cac4ca981caa94d09dcf3c3ff8b2a3857d69751a

Changed files: 이번 재개에서는 ResourceRunner/DashboardView.swift와 ResourceRunnerUITests/DashboardPreferencesVisibilityUITests.swift만 추가 수정. 공유 작업트리의 task-007 전체 미커밋 diff는 10파일, 462 insertions / 89 deletions. 기존 다른 8파일은 보존했습니다.

Cause: 초기 실제 UI 재실행(`...ui-resume-20261004-retry.xcresult`)은 live hide/re-show/detail 1개 통과, all-off 1개 실패. 접근성 진단 실행(`/tmp/rr-m4-task007-ui-axdiagnostic-20261004.log` 940~943행)은 부모 VStack의 `DashboardAllCardsHidden` 식별자가 두 StaticText와 Button 모두에 전파되고, Button의 독립 `DashboardOpenSettings` 식별자를 가린다는 실제 AX 트리를 보여줬습니다. 부모 식별자만 제거했습니다. Settings 버튼 label, hittable, 컨테이너 안 frame, 자연 높이(<100pt), click 가능과 카드 네 개의 AX 부재를 UI 테스트에 보강했습니다. task-009 설정창 자체는 아직 구현하지 않았으므로 click 이후 창 열림은 단언하지 않습니다. 기존 주입 callback 단위 카운터 테스트는 유지됩니다.

Validation:
- `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:ResourceRunnerUITests/DashboardPreferencesVisibilityUITests -derivedDataPath /tmp/rr-m4-task007-derived -resultBundlePath /tmp/rr-m4-task007-ui-repair-20261004.xcresult CODE_SIGNING_ALLOWED=YES` (위 cwd): 2 passed, 0 failed/skipped, `** TEST SUCCEEDED **`. Log `/tmp/rr-m4-task007-ui-repair-20261004.log`.
- `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:ResourceRunnerTests/DashboardPreferencesVisibilityTests -only-testing:ResourceRunnerTests/DashboardCardHeightTests -only-testing:ResourceRunnerTests/CPUCardAccessibilityLabelTests -only-testing:ResourceRunnerTests/MemoryCardAccessibilityLabelTests -only-testing:ResourceRunnerTests/DashboardSelectionTests -only-testing:ResourceRunnerTests/IntegratedDashboardSummaryTests -derivedDataPath /tmp/rr-m4-task007-derived -resultBundlePath /tmp/rr-m4-task007-unit-repair-20261004.xcresult CODE_SIGNING_ALLOWED=YES` (위 cwd): 40 passed, 0 failed/skipped, 6 suites, `** TEST SUCCEEDED **`. Log `/tmp/rr-m4-task007-unit-repair-20261004.log`.
- `git diff --check` and `git apply --check --reverse /tmp/rr-m4-task007-repair-20261004.patch`: passed.
- Evidence patch `/tmp/rr-m4-task007-repair-20261004.patch` includes new files; 10 source hashes `/tmp/rr-m4-task007-repair-20261004-source-sha256.txt` correspond to final tested sources.

Residual risk: task-009가 실제 설정창을 연결해야 하므로 현재 callback 클릭으로 창 열림을 확인할 수 없습니다. 이번 수정은 기존 UI 테스트의 실제 AX 결과로 판정했습니다. native login OS mutation/TCC 변경은 없습니다.
