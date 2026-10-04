<!-- prowl-workflow: v1 verify -->
1. Status: `approved` — 읽기 전용 verifier 후보
2. Target: `task-009: 단일 설정창과 접근·키보드·AX`
3. Validation:
   - Criterion: task-009 변경과 실행 근거의 대상 경계
     Source: `acceptance.md`, `implement.md` task-009
     Evidence: HEAD `df90292a0ae1cac69cc642f60f05fc1a4d555ff7`; `/tmp/rr-m4-task009.patch`는 대상 9파일만 포함합니다. 역방향 patch 검사와 9파일 SHA 검사가 현재 소스에서 통과했습니다. 동시 Disk 변경은 판정에서 제외했습니다.
     Result: `충족`
   - Criterion: 단일 창 재사용, 접근 경로, 시작·포커스 동작
     Source: `design.md` §1.3·§3.3, `implement.md` task-009
     Evidence: `SettingsWindowController`, `ApplicationCoordinator`, `ResourceRunnerApp`, `StatusBarController`가 우클릭·`⌘,`·전체 숨김 버튼을 `openSettings()`로 연결합니다. 창은 닫은 뒤 재사용되며 명시적 열기에서 활성화됩니다. Debug UI 18/18과 Release 복사본 UI 1/1에서 시작 시 창 없음, 접근·재열기·단일 창·지연 대시보드 포커스 거부를 확인했습니다. `EmptyView`는 허용된 Scene 껍질이며 기본 설정 명령은 교체됐습니다.
     Result: `충족`
   - Criterion: 설정값과 제품 화면
     Source: `spec.md` §5.1~§5.5·§5.12, `PreferencesView.swift`
     Evidence: 네 카드·두 TOP 5·공통 그래프 범위·네 갱신 프로필이 저장 설정에 직접 배선됐습니다. native 토글·Picker와 값 순환 버튼을 UI에서 조작했고, 복원 후 기본값을 확인했습니다. 제품 화면 문구에는 저장 키·generation·축 식별자가 없으며 `Settings…` 형태의 내부 AX 식별자는 화면 문구가 아닙니다.
     Result: `충족`
   - Criterion: 실제 로그인 상태 표시, 재조회, 복원 결과 분리
     Source: `design.md` §2.6, `spec.md` §5.9·§5.11, `LoginItemController.swift`, `PreferencesView.swift`
     Evidence: 시작·창 열기/재활성화·앱 활성화·명시적 새로고침·요청 완료 후 실제 상태를 읽는 경로가 있습니다. 진행·승인 대기·실패·시스템 설정·등록 해제·일반 복원 결과를 분리했습니다. 주입 adapter의 단위 46/46 및 Debug UI에서 성공·실패·승인·재조작을 확인했습니다.
     Result: `충족`
   - Criterion: 키보드·AX 및 기존 상태막대 동작
     Source: `spec.md` §5.12, `implement.md` task-009, `StatusBarController.swift`
     Evidence: UI 로그에서 단축키, Tab 후 Return/Space, AX 토글·Picker·상태·오류·버튼 조작이 통과했습니다. 기본 Tab 순회에서 Picker를 직접 선택하는 근거 대신 인접 값 순환 버튼의 키보드 경로를 확인했습니다. 기존 좌클릭·transient·상태 설명과 task-007/008 회귀가 관련 단위·UI suite에서 통과했습니다.
     Result: `충족`
   - Criterion: 서명된 빌드와 실행 결과의 현재 코드 대응
     Source: `/tmp/rr-m4-task009-{unit,ui,release,release-ui}.log` 및 세 `xcresult`
     Evidence: 기록된 `xcodebuild test` 단위 46/46, Debug UI 18/18, Release `build` 성공, Release 대상 `test-without-building` UI 1/1이며 실패·skip은 없습니다. 최종 단축키 변경은 후속 UI·Release 빌드에 포함됐습니다. Release 복사본은 별도 bundle ID로 재서명됐고 원본과 arm64 Mach-O UUID가 같습니다. 각 실행은 기존 결과를 읽어 확인했으며 suite를 재실행하지 않았습니다.
     Result: `충족`
4. Completed requirements: 없음
6. Explanation: task-009 범위의 승인 후보입니다. 로그인 UI 시험은 메모리 adapter를 사용했으며 Release 시험은 설정 접근만 확인했습니다. 실제 `SMAppService` 등록·해제와 다음 로그인 실행은 task-011, 전체 통합은 task-010의 판정 범위입니다. 최종 승인과 상태 변경은 main이 수행합니다.