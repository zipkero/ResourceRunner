# M3 task-007 실행 근거

- 실행 cwd: `/Users/zipkero/XcodeProjects/ResourceRunner`
- 기준 HEAD: `c61f76e64deebc2cd941fcad0dc2ce880f01a36b` (`main`), 구현은 미커밋 상태.
- 환경: macOS 26.6.2 (25G83), arm64, Xcode 26.6 (17F113), Apple Swift 6.3.3. `environment.raw.txt` 참조.
- 최종 소스별 SHA-256은 `source-sha256.txt`, 변경 patch는 `change.patch`, `git diff --check` 결과는 빈 `diff-check.txt`에 보존했다. 빌드에 대응하는 서명 앱 바이너리 해시는 `sandbox-binary-sha256.txt`다.

실행 명령과 결과:

1. `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task007-tests -parallel-testing-enabled NO -only-testing:ResourceRunnerTests/CollectionPipelinesTests -only-testing:ResourceRunnerTests/SystemLifecycleObserverTests -only-testing:ResourceRunnerTests/ApplicationCoordinatorTests CODE_SIGNING_ALLOWED=NO` → exit 0, 23/23, 실패 0 (`focused-test.log`, `focused-summary.json`). 앞서 전 빌드와 병렬로 실행한 같은 집중 범위에서 기존 `SystemLifecycleObserverTests.multipleCallbacksDuringRegistrationApplyInArrivalOrder`의 `.bufferingNewest(1)` 중간 snapshot 누락으로 한 차례 실패해, 빌드·probe와 분리해 재실행한 최종 결과다. 전체 unit 최종 결과도 통과했다.
2. `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task007-full -parallel-testing-enabled NO -only-testing:ResourceRunnerTests CODE_SIGNING_ALLOWED=NO` → exit 0, 579/579, 실패 0 (`full-unit-test.log`, `full-summary.json`).
3. `xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task007-release CODE_SIGNING_ALLOWED=NO` → exit 0 (`release-build.log`).
4. `xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task007-sandbox` → exit 0 (`sandbox-build.log`). Debug 앱은 ad-hoc 서명 및 `com.apple.security.app-sandbox=true` 상태다 (`sandbox-signature.txt`, `sandbox-entitlements.plist`).
5. `RR_COLLECTION_PROBE=1 /tmp/ResourceRunner-M3-task007-sandbox/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner` → PID 31677, 16초 관찰 후 의도적으로 SIGTERM(143), `ps`에서 종료 확인 (`sandbox-app-process.txt`). 같은 PID의 `/usr/bin/log show --last 4m --style compact --predicate 'subsystem == "com.zipkero.ResourceRunner" AND (category == "CollectionPipeline" OR category == "MonitoringScheduler" OR category == "AuxiliaryScheduler" OR category == "SystemLifecycle" OR category == "CPUActivityState" OR category == "TopologyObserver")'` 출력은 `sandbox-app-unified.log`에 보존했다.

검증 연결:

- `CollectionPipelinesTests`는 production과 동일한 여섯 축 factory에서 initial lifecycle 전 무호출, 독립 실패·원인 유지, 느린 Network metadata 및 process ranking 중 CPU·Memory 카드와 메뉴바 `CharacterPresentationSink` 진행, 호출/저장/전달 시각, 취소를 무시한 이전 Network 결과의 중지·복귀 후 거절, mount/unmount·network 신호의 누적 revision과 refresh, 저전력 주기 전환과 fresh cache의 추가 native 호출 없음, cache replay의 요청 역순/topology/epoch 거절을 확인한다. `NetworkMetadataTests`는 느린 native 실패 도중 및 source→store 사이 topology 변경의 폐기를 확인한다. `AuxiliaryCollectionSchedulerTests`는 기존 일정·single in-flight·refresh 병합 회귀다.
- 실제 앱 로그에서 initial snapshot 이후 4개 fast axis와 두 metadata apply, 두 metadata 즉시 조회·delivery, fast activity의 baseline-only→rate/partial 전달, process 순위 delivery를 확인했다. `TopologyObserver`의 SCDynamicStore 구독 성공(`registered network=true`)과 NSWorkspace 토큰 3개도 관측했다.
- DEBUG probe가 실제 `SystemLifecycleObserver`의 snapshot 생산 경계에 저전력 `true`를 주입해 `snapshot changed revision=1`을 거쳐 동일한 production lifecycle·scheduler에 전달했다. 서명 Sandbox 앱에서 닫힘 **system/network/disk 5초·process 10초·두 metadata 120초**, 실제 popover 열림 **2/4/60초**, 닫힘 **5/10/120초**, 주입 복원 후 정상 닫힘 **2/5/60초**가 여섯 축 모두의 `apply` 로그에 기록됐다. 기존 metadata 캐시도 주기 전환 시 전달됐다. 실제 OS 저전력 상태는 계속 `false`였으며 OS 전력 설정을 바꾸거나 실제 OS `true`를 관측했다고 주장하지 않는다. controlled-clock 통합 테스트는 별도의 단위 근거다.
- 실제 장치 연결·해제와 잠금·절전 전환은 이번 실행에서 관측하지 않았고 해당 알림 배선·중지 경계는 주입 테스트로 검증했다.
- Release 빌드에는 기존 `DashboardView.swift`의 `Text` 결합 deprecated 경고와 `BandRole` Swift 6 격리 경고가 남는다. 이번 변경 파일의 Swift 6 격리 경고는 관측되지 않았다.
