<!-- prowl-workflow: v1 implement -->
Status: completed
Target: task-005
Changed files:
- ResourceRunner/AppDelegate.swift
- ResourceRunner/ApplicationCoordinator.swift
- ResourceRunner/DashboardPresentationStore.swift
- ResourceRunner/PreferencesStore.swift
- ResourceRunnerTests/ApplicationCoordinatorTests.swift
- ResourceRunnerTests/CollectionPipelinesTests.swift
- ResourceRunnerTests/DashboardPresentationTests.swift
- ResourceRunnerTests/PreferencesStoreTests.swift
Validation:
- cwd: /Users/zipkero/XcodeProjects/ResourceRunner
- HEAD: d119c73a9755f91141ca71e06122636c2581dd62
- Relevant uncommitted diff: 8 modified files, 1 patch at /tmp/rr-m4-task005.patch; source hashes at /tmp/rr-m4-task005-source-sha256.txt.
- Final signed command: `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:ResourceRunnerTests/ApplicationCoordinatorTests -only-testing:ResourceRunnerTests/CollectionPipelinesTests -only-testing:ResourceRunnerTests/CollectionAdmissionTests -only-testing:ResourceRunnerTests/DashboardPresentationTests -only-testing:ResourceRunnerTests/DashboardPreferencesBoundaryTests -only-testing:ResourceRunnerTests/ResourceActivityPresentationTests -only-testing:ResourceRunnerTests/PreferencesStoreTests -derivedDataPath /tmp/rr-m4-task005-derived -resultBundlePath /tmp/rr-m4-task005-unit.xcresult CODE_SIGNING_ALLOWED=YES`.
- Final xcresult: 42 unique tests passed, 0 failed, 0 skipped on macOS 26.6.2 arm64. Log /tmp/rr-m4-task005-unit.log; result /tmp/rr-m4-task005-unit.xcresult. xcodebuild interleaves and repeats suite/test output from multiple test processes; xcresult summary is the reported count. No failure/retry marker appears in final run. Earlier test runs correspond to intermediate source changes, not counted as final evidence; no task-005 compile failure occurred.
- `git diff --check` and `git apply --check --cached /tmp/rr-m4-task005.patch` passed. Product code compiled in the signed test build. Native LoginItemService registration, unregister, and System Settings opening were not invoked.
Approach difference:
- Task approach says reassemble current delivery and maximum history on each display choice. Current dashboard card models already retain full 600-second history, ranking and detail without applying display choices. This implementation publishes the current PreferencesSnapshot on DashboardPresentationStore with revision rejection and leaves those full models intact. Subsequent view tasks 006/007 select from that current snapshot; sample delivery never carries an older preference copy. The boundary test covers pending/late sample, failure, stopped last-known, stale snapshot and history preservation. Profile is forwarded to lifecycle only when it changes, after initial system state, with the latest preference revision.
Residual risk:
- Visible graph-range and card/TOP5 filtering are task-006/007, settings UI task-009, actual native login observation task-011. Those are not asserted as complete here.
