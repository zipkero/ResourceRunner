<!-- prowl-workflow: v1 implement -->
Status: completed
Target: task-004
Changed files:
- ResourceRunner/LoginItemService.swift
- ResourceRunner/LoginItemController.swift
- ResourceRunnerTests/LoginItemControllerTests.swift
Validation:
- cwd: /Users/zipkero/XcodeProjects/ResourceRunner
- HEAD: ccb1bf812c2b3c3d3ed00fdaf1df84dba70f6003
- Relevant uncommitted diff: three new files only; /tmp/rr-m4-task004-patch includes all three; source hashes in /tmp/rr-m4-task004-source-sha256.txt.
- `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:ResourceRunnerTests/LoginItemControllerTests -derivedDataPath /tmp/rr-m4-task004-derived -resultBundlePath /tmp/rr-m4-task004-unit.xcresult CODE_SIGNING_ALLOWED=YES`: succeeded, 7 tests passed, 0 failed, 0 skipped on macOS 26.6.2 arm64. Log: /tmp/rr-m4-task004-unit.log; result: /tmp/rr-m4-task004-unit.xcresult. Earlier attempts had compile errors fixed before final run.
- `git diff --check`: clean. Native adapter compiled, but this task did not invoke actual SMAppService register/unregister or open System Settings. No app wiring or next-login observation (task-005/009/011).
Residual risk:
- Actual macOS registration and next-login behavior remain task-011 validation gates.
