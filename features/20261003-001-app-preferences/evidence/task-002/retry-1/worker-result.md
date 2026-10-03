<!-- prowl-workflow: v1 implement -->

Status: completed  
Target: task-002

Changed files: [MonitoringScheduler.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/MonitoringScheduler.swift), [AuxiliaryCollectionScheduler.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/AuxiliaryCollectionScheduler.swift), [MonitoringLifecycleTests.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunnerTests/MonitoringLifecycleTests.swift), [AuxiliaryCollectionSchedulerTests.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunnerTests/AuxiliaryCollectionSchedulerTests.swift)

두 scheduler가 **적용된 plan revision**을 확인하도록 고쳤습니다. A→B→A에서 C가 먼저 도착하면 같은 schedule이어도 타이머와 실행권을 최신 revision에 다시 연결합니다. 같은 schedule·revision의 반복 적용은 재시작하지 않습니다. 빠른 조회, 보조 캐시 재전달, 진행 중 조회 뒤 pending refresh의 역순 회귀 테스트를 추가했습니다.

Validation: cwd `/Users/zipkero/XcodeProjects/ResourceRunner`, HEAD `1647242fe82d3d6b156a0a27fd53cb27c5876275`. 아래 명령의 최종 소스로 관련 7개 suite **50/50 통과**, `git diff --check` 통과했습니다. 앞선 실행 실패는 admission 없는 기존 경로에 revision 검사를 적용한 문제와 기존 rapid 테스트의 tick 처리 순서 문제를 수정한 뒤 재검증했습니다.

```sh
xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -parallel-testing-enabled NO -derivedDataPath /tmp/rr-m4-task002-retry1-unit -resultBundlePath /tmp/rr-m4-task002-retry1-verified.xcresult -only-testing:ResourceRunnerTests/CollectionSchedulePolicyTests -only-testing:ResourceRunnerTests/MonitoringLifecycleStoreTests -only-testing:ResourceRunnerTests/MonitoringSchedulerTests -only-testing:ResourceRunnerTests/MemorySystemLifecycleSourceIntegrationTests -only-testing:ResourceRunnerTests/CollectionPipelinesTests -only-testing:ResourceRunnerTests/CollectionAdmissionTests -only-testing:ResourceRunnerTests/AuxiliaryCollectionSchedulerTests test
```

최종 [로그](/tmp/rr-m4-task002-retry1-verified.log), [xcresult](/tmp/rr-m4-task002-retry1-verified.xcresult), [HEAD 대비 담당 파일 diff](/tmp/rr-m4-task002-retry1-change.patch), [소스·패치·로그 SHA256](/tmp/rr-m4-task002-retry1-sha256.txt)을 보관했습니다. 전체 프로젝트 suite·UI·실제 OS 상태 변경은 실행하지 않았습니다. 문서 상태와 commit·push는 변경하지 않았습니다.