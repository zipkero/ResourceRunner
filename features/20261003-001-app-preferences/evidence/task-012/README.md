# task-012 구현 근거

- 기준: HEAD `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`, 작업 트리의 `AppPreferences.swift`·`PreferencesStore.swift`·`PreferencesStoreTests.swift` 변경. 다른 작업의 미커밋 변경은 이 패치에 포함하지 않았습니다.
- 변경: 기존 `preferences.v1`/schema1과 9개 키를 유지하고 시스템 프로세스 포함, 상세 정원, 팝오버 자동 닫기를 추가했습니다. enum에서 10/20/50을 유도합니다. 누락·잘못된 새 필드는 각각 기본값으로 복구하며 초기 읽기는 저장하지 않습니다.
- 검증: 프로젝트 루트에서 `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -derivedDataPath /tmp/ResourceRunner-task012-derived -resultBundlePath /tmp/ResourceRunner-task012-final.xcresult -only-testing:ResourceRunnerTests/PreferencesStoreTests CODE_SIGNING_ALLOWED=YES` 실행. 10개 통과, 실패 0, skip 0. `/tmp/ResourceRunner-task012-final.xcresult`의 요약은 [unit-summary.json](./unit-summary.json), 원문은 [unit.log](./unit.log)입니다.
- `ResourceRunner.app`와 내장 `ResourceRunnerTests.xctest`는 arm64 ad-hoc 서명입니다. 실제 앱 UI·수집·로그인 상태는 이 Task의 검증 범위가 아니며 후속 Task가 맡습니다.
- 변경 내용은 [changes.patch](./changes.patch), 소스 해시는 [source-sha256.txt](./source-sha256.txt)에 기록했습니다. `git diff --check` 통과.
