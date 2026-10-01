# M3 task-008 실행 근거

- 실행 cwd: `/Users/zipkero/XcodeProjects/ResourceRunner`
- 기준 HEAD: `c42a0cd5abef392cccb159c8804fc9f2379ba999` (`main`); 구현은 미커밋 상태다. `head.txt`, `status.txt`, `change.patch`, `source-sha256.txt`가 최종 코드 대응을 보존한다.
- 환경: macOS 26.6.2 (25G83), arm64 MacBook Pro, Xcode 26.6 (17F113). 원본 `environment.raw.txt`와 test-summary의 기기 정보를 참조한다.

실행 명령과 결과:

1. `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task008-tests -only-testing:ResourceRunnerTests/ResourceActivityPresentationTests -only-testing:ResourceRunnerTests/CollectionAdmissionTests -only-testing:ResourceRunnerTests/CollectionPipelinesTests test` → exit 0, **23/23**, 실패 0 (`focused-test.log`, `focused-summary.json`).
2. `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task008-tests -only-testing:ResourceRunnerTests test` → exit 0, **588/588**, 실패 0 (`full-unit-test.log`, `full-summary.json`).
3. `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task008-release CODE_SIGNING_ALLOWED=NO build` → exit 0 (`release-build.log`).
4. `git diff --check` → exit 0, 빈 `diff-check.txt`.

전체 unit 통과 뒤 드라이버 Operations 지원값의 표시 단언만 직접 테스트에 추가했고, production 소스는 바꾸지 않았다. 위 집중 23/23은 그 최종 테스트 소스에 대한 재실행 결과다.

검증 연결:

- `ResourceActivityPresentationTests` 9개는 Network/Disk 활동 성공·정상 0·연결/물리 장치 없음·baseline 원시 누적값·필수 부분 실패·보조 선도착/실패·마지막 완전 성공 원본 `readAt`·중지에서 부분 합계 승격 방지·상세 현재 속도 제거·metadata identity/revision 불일치·링크/Operations 미지원 대 조회 실패·APFS 공유 용량·AX 문구를 직접 검증한다. B/s·bit/s·회/s·용량의 독립 formatter, 1024 경계·작은 양수·로케일도 확인했다.
- production 네 소비자와 실제 `CollectionDeliveryStore`/`DashboardPresentationStore`를 연결한 테스트는 보조 조회 실패 중 빠른 Network/Disk 현재 속도가 각각 다음 값으로 갱신되고, 중지 후 과거 값/시각을 보존하며, 재개 뒤 이전 epoch 성공·보조 캐시가 거절되는 것을 확인한다. 구 topology stream 항목을 대기시킨 뒤 `noteChange()`를 적용해 활동·보조 네 축 모두 표시 commit에서 거절하고, 새 revision 결과만 카드에 반영되는 경로를 검증한다. metadata가 새 revision이고 활동이 이전 revision일 때 구 속도를 현재로 재조립하지 않는 모델 조건도 직접 확인한다.
- `CollectionAdmissionTests`는 요청 역순, 중지/재개 및 늦은 sink 반영을, `CollectionPipelinesTests`는 여섯 축의 독립 진행·보조 cache replay·기존 CPU/Memory/메뉴바를 회귀 검증한다. 전체 unit에는 기존 카드 선택·CPU/Memory 실패/재개 테스트가 포함된다.
- task-008은 표시 모델과 production 표시 store 배선까지다. Network/Disk 실제 카드 뷰·그래프는 task-009~011 범위이므로 이번 실행에서 실앱의 새 카드 시각 렌더링을 관측하지 않았다. 새 native API나 entitlement는 추가하지 않았으며 task-001/002/007의 서명 Sandbox 관측을 재사용하지 않고 이번 코드의 native 실측 근거로 주장하지 않는다.
- Release build에 기존 `DashboardView.swift`의 `Text` 결합 deprecated 경고와 `BandRole` Swift 6 격리 경고가 남는다. 변경 파일의 새 컴파일 경고는 관측되지 않았다.
