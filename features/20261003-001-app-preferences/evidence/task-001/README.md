# task-001 근거

- 기준 HEAD: cf9bc683a213be61173bbfc48a218c74df7dd87a.
- cwd: /Users/zipkero/XcodeProjects/ResourceRunner.
- 제품/검증 변경: AppPreferences.swift, PreferencesStore.swift, PreferencesStoreTests.swift. main의 진행 문서는 이 패치에 포함하지 않습니다.
- [패치](./change.patch)·[해시](./sha256.txt)로 검증 당시 소스를 고정합니다.

명령: `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -derivedDataPath /tmp/rr-m4-task001-unit -resultBundlePath /tmp/rr-m4-task001-unit2.xcresult '-only-testing:ResourceRunnerTests/PreferencesStoreTests' test`.

[실행 로그](./unit.log)와 [xcresult 요약](./unit-summary.json)은 전용 테스트5/5, 실패0·skip0을 기록합니다. 초기 test helper의 actor 격리 컴파일 오류를 worker가 수정한 뒤 이 최종 소스로 재실행했습니다. 이 내부 수정은 verify reject나 loop 재시도가 아닙니다.

초기 읽기 무쓰기·손상 schema/dictionary·필드 복구·숫자/문자열 Bool 거부·변경/복원 단일 저장과 revision·격리 UserDefaults round-trip 및 설정 필드만 저장을 확인했습니다. 실제 초기 화면/일정 배선과 로그인 동작은 후속 Task이며 이 근거로 완료 처리하지 않습니다.

독립 verifier는 지원 기본값·복구·초기 무쓰기/단일 게시·설정 외 저장 없음·소스 해시/xcresult 대응을 모두 충족으로 판정했습니다. main이 task-001 approved를 확정했습니다. 후속 매핑이 남아 SPEC 전체 조건의 새 완료 판정은 없습니다. loop 구현 재시도0, 근거 재검증0입니다.
