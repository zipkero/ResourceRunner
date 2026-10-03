# task-002 근거

기준 HEAD1647242fe82d3d6b156a0a27fd53cb27c5876275, cwd /Users/zipkero/XcodeProjects/ResourceRunner. [패치](./change.patch)와 [해시](./sha256.txt)는 제품5개·관련 검증4개 파일만 고정하며 main의 ROADMAP 진행 변경은 제외합니다.

## 실행

- [관련 suite 로그](./related-unit.log)·[요약](./related-summary.json): signed Debug의7개 suite, **47개 case 통과**, 동적 parameter를 포함한 실제 실행53회, 실패/skip0입니다. 명령 전체는 로그 첫머리에 있습니다.
- 마지막 주석과 scheduler 테스트 단언 수정 뒤 [최종 scheduler 로그](./final-scheduler.log)·[요약](./final-summary.json):14/14 통과·실패/skip0. 앞선 실행과 중복되는 사례를 더해 새로운 전체 case 수로 표기하지 않습니다.
- 두 실행은 `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -parallel-testing-enabled NO -derivedDataPath /tmp/rr-m4-task002-unit ... test`이며 only-testing·resultBundlePath는 각 원시 로그에 보존했습니다.
- 제품/검증 소스 `git diff --check` 통과. 전체 프로젝트 suite·실제 UI·OS 전환은 미실행입니다.

## 핵심 대응

- `allProfileIntervalsAndUnobservableSignalsMatchApprovedTable`: 네 프로필·열림/닫힘·저전력 표와 화면 중지.
- `profileRevisionAndIntervalPublishAtomicallyWithoutSystemBoundary`: 역순 preference·시스템 boundary 분리·revision/P 원자 대응.
- `rapidProfileChangesKeepLatestPlanAndOneActualSource`: 연속 프로필 변경·최신 계획·취소 무시 source 실행권.
- `waitingSinkHoldsQueryLeaseAcrossSeveralTimerTicks`: source 완료 뒤에도 sink 종료까지 실제 조회 하나.
- `cancellationIgnoringOldNetworkResultFinishesBeforeResumedQuery`: 이전 native 완료 뒤 다음 유효 tick에서 재개하고 stale 결과를 폐기.
- 기존 anchored deadline·보조 refresh/캐시·독립 축/실패 격리 사례를 함께 확인했습니다.

기존 Network 재개 테스트는 이전 native 조회 완료 전 새 조회 시작을 기대했습니다. DESIGN §2.3의 단일 조회 계약으로 기대를 바꾸고, 이전 완료 뒤 재개와 오래된 결과 폐기를 계속 검증합니다. 보조 테스트는 actor의 await 뒤 공유 호출 수를 다시 읽던 값을 호출별로 캡처해 결과 순서 의존을 제거했습니다. worker의 내부 실패 수정은 loop verify reject가 아니며 재시도 횟수에 합치지 않습니다.

저장 프로필의 실제 앱 초기 배선은 task-005, 불변 P의 실제 차분/G 적용은 task-003입니다. 이 근거로 후속 요구사항 전체 완료를 주장하지 않습니다.

## correctness reject와 구현 재시도1

초기 후보는 A→B→A의 target 역순에서 같은 schedule/epoch 조기 반환이 최신 plan revision을 적용하지 않아 영구 수집 정지가 가능하다는 이유로 거절했습니다. 최초 패치·해시는 거절 당시 이력이며 현재 승인 근거가 아닙니다.

재시도는 동일 worker 모델 gpt-6-sol/medium으로 수행했습니다. collaboration worker 재호출·새 호출이 thread limit에 실패했고 이전 worker는 not_found여서, 설치된 로컬 Codex CLI에 같은 worker 계약·파일 소유·권한을 전달해 실행했습니다. 승인되지 않은 코드 직접 수정이나 Task 의미 변경은 없습니다.

[worker 인계](./retry-1/worker-result.md)·[최종 패치](./retry-1/change.patch)·[worker 해시](./retry-1/worker-sha256.txt)·[전체9파일 소스 해시](./retry-1/source-sha256.txt)·[최종 로그](./retry-1/unit.log)·[요약](./retry-1/unit-summary.json)을 보존합니다. 새 회귀는 빠른 역순 실행권, 보조 역순 캐시, 진행 중 조회 뒤 pending refresh입니다. 기존 admission 없는 경로와 tick 처리 테스트 정합성도 보완했습니다. 관련7suite의 최종case50/50·fail/skip0입니다. 초기 실행과 합쳐 전체 새case수로 세지 않습니다.

loop 구현 재시도1·근거 재검증0이며 최종 승인은 main의 독립 재판정 뒤 기록합니다.

main은 독립 재검증 approved를 확정했습니다. 적용 revision·역순 최신 계획·단일 조회·보조 갱신 및 현재 해시 대응이 모두 충족입니다. 최종50case는 동적 개별56실행으로 구분합니다. 이번 Task로 SPEC 전체 완료 조건의 마지막 매핑이 끝나지 않아 새 전체 조건 완료는 없습니다.
