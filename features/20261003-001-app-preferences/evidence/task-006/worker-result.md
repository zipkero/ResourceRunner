<!-- prowl-workflow: v1 implement -->
Status: completed
Target: task-006
Changed files:
- ResourceRunner/DashboardPresentation.swift
- ResourceRunner/DashboardView.swift
- ResourceRunner/DiskDashboardView.swift
- ResourceRunner/ResourceRateGraph.swift
- ResourceRunner/ResourceRateGraphView.swift
- ResourceRunnerTests/DashboardPresentationTests.swift
- ResourceRunnerTests/DiskDashboardViewTests.swift
- ResourceRunnerTests/ResourceRateGraphRenderingTests.swift
- ResourceRunnerTests/ResourceRateGraphTests.swift
Validation:
- cwd: /Users/zipkero/XcodeProjects/ResourceRunner
- HEAD: 8345f5815b61a4cf233592e6fdb4c697fdcd58da
- Relevant uncommitted diff: 9 modified files, 254 insertions and 55 deletions at final `git diff --stat`. Patch /tmp/rr-m4-task006.patch; matching source hashes /tmp/rr-m4-task006-source-sha256.txt. `git diff --check` and `git apply --check --cached /tmp/rr-m4-task006.patch` pass.
- Final signed command: `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:ResourceRunnerTests/CPUSelectedWindowTests -only-testing:ResourceRunnerTests/DashboardPreferencesBoundaryTests -only-testing:ResourceRunnerTests/HistoryPointConnectedSegmentsTests -only-testing:ResourceRunnerTests/HistoryPointDownsamplingTests -only-testing:ResourceRunnerTests/HistoryPointNormalizedXPositionTests -only-testing:ResourceRunnerTests/CPUCardPresentationAssembleTests -only-testing:ResourceRunnerTests/CPUCardAccessibilityLabelTests -only-testing:ResourceRunnerTests/HistoryGraphTimeAxisTests -only-testing:ResourceRunnerTests/HistoryGraphViewDrawOrderTests -only-testing:ResourceRunnerTests/ResourceRateGraphTests -only-testing:ResourceRunnerTests/ResourceRateGraphRenderingTests -only-testing:ResourceRunnerTests/DiskDashboardViewTests -only-testing:ResourceRunnerTests/MemoryCardPresentationAssembleTests -only-testing:ResourceRunnerTests/MemoryCardAccessibilityLabelTests -derivedDataPath /tmp/rr-m4-task006-derived -resultBundlePath /tmp/rr-m4-task006-unit.xcresult CODE_SIGNING_ALLOWED=YES`.
- Final xcresult /tmp/rr-m4-task006-unit.xcresult and log /tmp/rr-m4-task006-unit.log: 86 logical tests passed (90 executions including dynamic cases), 0 failed, 0 skipped on macOS 26.6.2 arm64. App and test targets compiled and signed. First new test run failed one incorrect expectation: the full CPU model deliberately retained a future test point while visible rendering excluded it. Test expectation was corrected from 4 to 5; no product fix was needed. A later parallel rerun after comment edits produced an incomplete xcresult without Info.plist and no completion marker; a serial rerun produced the final complete passing bundle. These earlier attempts are not counted as final success evidence.
- No native login mutation, logout or reboot. Network/Memory time graphs were not added; Memory 600-second calculation and increase ranking text were not edited.
Residual risk:
- Actual settings controls and card visibility are task-009/007; this task provides selected graph rendering from the current preference snapshot. No standalone live app UI observation was performed.
