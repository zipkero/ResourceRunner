# Context

저장: 2026-10-11 16:20 KST

## 현재 목표

M5 첫 범위인 개인 사용 성능 개선을 `implement-loop`로 진행합니다.
현재 요청은 인수인계를 저장하고 이번 변경을 main에 스테이징·커밋·푸시하는 것입니다.

## 현재 상태

- 프로젝트 `/Users/zipkero/XcodeProjects/ResourceRunner`, branch `main`, upstream `origin/main`.
  이번 커밋의 선행 HEAD는 `69842e14e920e95da179f525055b22dd75c56b74`입니다.
  최종 커밋 식별자는 `git log -1`에서 확인합니다. 검증 manifest의 이전 HEAD는 당시 소스·미커밋 diff의 출처이므로 그대로 보존합니다.
- 활성 feature의 SPEC/DESIGN은 승인됐고 IMPLEMENT는 미완료입니다. task-001~004 승인, task-005 `blocked`, task-006/007 미진입입니다.
- 선행 Per-Request: 고양이 애니메이션을 제외하고 정적 18pt CPU 색상·고정 메뉴바 폭·툴팁/접근성 이름·1pt 포커스를 적용했습니다.
  관련 제품 문서와 개인 사용 범위를 갱신했고 당시 단위27/27·UI4/4 및 설치 Release 검증을 완료했습니다.
- task-004: 실제 열림에 hosting 생성, 실제 didClose에 해제합니다. viewport와 store의 session/generation 및 이전 앵커·늦은 콜백·보정 Task 경계를 처리합니다.
  수집·이력·최신 캐시·epoch·설정·그래프 의미를 유지하며 현재 영향56/56·skip0 및 Debug/Release 성공 후 독립 verifier approved를 main이 확정했습니다.
  최초 reject는 이전 AnchorView 해제의 session 검사 누락이었고 해결했습니다. 구현 재시도1·근거 재검증0입니다.
- task-004 최종 새 PID50374의 600초 워밍업·본체5초·닫힘60초·300초×3은 모두 유효301표본입니다.
  닫힘 Footprint 최대는 원본419.27~421.64MB → 제품60.92~61.02MB, CPU는2.52~2.53%로1% 목표 미달입니다.
  제품 patch SHA `410df544ac8e389daaceeecf2aa0834e4b743b2842d4a01dc1be7ed967a651bd`,
  Release SHA `ccab3eb6a5b27ea82555a189043f69fc643a4bc5dc19d17b742ed4e0e423fee2`,
  진단 SHA `281a1e6eba0d0b79e84fd3dc49210d56ee9ba732cef15ac03f2bc9093b891475`입니다.
  정확한 원시·해시·이전 시도 이력은 task-004 evidence가 소유합니다. 드문 late-didClose 중간 순서의 실제 재현은 주장하지 않습니다.
- task-005 worker blocked 결과를 인수했습니다. 제품 코드를 추가 수정하지 않았습니다.
  전체 단위 직렬696/696·skip0, Debug/Release 성공. 최초 병렬 실행의 팝오버3실패는 이력으로 보존하며 간섭 원인은 미확정입니다.
  현재 단위 결과 `/private/tmp/resourcerunner-task005-unit-serial.xcresult`,
  Release SHA `0b6ae93b24a6174aca192a22e754289de68dfcc14329b45ddfe6c907d4872c89`입니다.
- task-005 격리 UI runner가 실제 앱 시작 전에 macOS `Enable UI Automation` 인증을 요구했습니다.
  unsigned suite·signed smoke 모두 대기했고 `ui-automation-mode.log`의 testmanagerd 인증 요구를 확인했습니다.
  사용자에게 인증 절차 진행 여부를 요청했으나 답변/인증 완료는 확인하지 못했습니다. 현재 요청은 저장·커밋·푸시이며 인증 진행 승인이 아닙니다.
  UI·반복·공식100/200ms는 미검증입니다. task-005 verify 미실행, 최근 reject 없음, 구현 재시도0·근거 재검증0입니다.
- 외부 도구 `external_frame_probe.swift`, `target_event_probe.swift`, `target_ax_probe.swift`와 짧은 사전시험2회를 보존했습니다.
  AX/화면 캡처/ListenEvent/PostEvent 권한은 당시 모두 true였지만 UI Automation 인증은 별도입니다.
  PID tap·WindowServer displayTime·후행 창 metadata·AX 응답 완료 시각을 구분해야 합니다.
  사전시험2의198ms 프레임은 애니메이션 중 부분 표시였습니다. 600초 워밍업 없는 도구 시험이므로 공식 실패/통과로 해석하지 않습니다.
  최신 카드·실제 TOP5·그래프가 완전히 표시된 픽셀과 최신 AX의 같은 내용 대응 및 보수적100/200ms 상한 관찰은 아직 보완이 필요합니다.
  fixed ROI fingerprint는 pixel buffer의 BGRA 가정 불일치로 unavailable이었습니다.
- 격리 UI는 동일 소스와 별도 app/runner ID를 쓴 임시 프로젝트로 준비했습니다. 임시 프로젝트·진단·runner·관측 프로세스는 정리했습니다.
  ID diff와 원본127파일 SHA는 task-005 evidence에 있습니다. 기본 `XCUIApplication()`로 production ID 앱을 실행하면 기존 세션이 종료될 수 있으므로 반드시 격리합니다.
  로그인 등록/해제·System Settings 변경 시험은 제외합니다. Release 경로가 필요한 읽기 전용 UI는 별도로 실행해야 합니다.
- 2026-10-11 저장 전 설치 앱 PID16136/2026-10-09 16:28:46 시작 및 실행 파일 SHA를 다시 확인했습니다.
  `/Users/zipkero/Applications/ResourceRunner.app` SHA는 `a4073395407599a16cec757957ded1f4ecbdc535a070e7c985647a3f6bd32c80`입니다.
  성능 수정본은 아직 실제 설치에 반영하지 않았습니다. task-006 승인 전 기존 세션을 종료/교체하지 않습니다.
  현재 설정은 상세 ten이고 이전 plist는 `/tmp/resourcerunner-task001-settings.plist`, 설치 백업은 `/tmp/rr-static-color-installed-backup/ResourceRunner.app`입니다.
- 공식 동결 원본은 `/tmp/resourcerunner-task001-frozen`과 task-001 manifest입니다. 설치 바이너리의 소스 대응은 공식 baseline으로 증명되지 않았습니다.
  task-002의7상태21회 baseline과 task-003 원인 조사 및 task-004 최종 비교는 각각의 evidence와 manifest를 따릅니다.
  원본/진단 비교는 동일 진단 ID·기본 설정·도구·환경으로 순차 한 인스턴스만 실행합니다.
  실제 proc 경로는 `/private/tmp/...`이므로 측정 `--exe`의 문자열 대응을 먼저 검사합니다. 입력 오류만 있으면 불필요한 새 PID/600초 재워밍업을 피합니다.

## 현재 작업 문서

[feature 상태](./features/20261010-001-release-readiness/README.md),
[명세](./features/20261010-001-release-readiness/spec.md),
[설계](./features/20261010-001-release-readiness/design.md),
[Task와 승인](./features/20261010-001-release-readiness/implement.md).

[task-004 근거](./features/20261010-001-release-readiness/evidence/task-004/README.md),
[task-005 근거와 재개 조건](./features/20261010-001-release-readiness/evidence/task-005/README.md),
[선행 정적 메뉴바 검증](./docs/verification/20261009-static-menu-bar.md), [ROADMAP](./ROADMAP.md).

## 확정된 결정

- 개인 Mac에서 혼자 사용하는 앱입니다. 외부 배포·공증·패키지 준비를 제외하며 기존 로컬 서명·Sandbox·설정·로그인 실행은 유지합니다.
- CPU 고양이는 항상 정적입니다. 낮음/보통 기본색, 높음 노랑, 매우 높음 주황, 장시간 고부하 빨강입니다. 포커스는1pt·불투명도0.7입니다.
- 기본값은 시스템 제외·상세20·자동닫기 켜짐이며 상세10/20/50을 지원합니다.
- VPN·유선LAN·외장디스크·다른 계정 전환 실시험을 제외합니다. M1~M4는 해당 사용자 범위로 완료했고 M5 전체는 미완료입니다.
- CPU1%/3%, Footprint100,000,000bytes, 실제 외부100/200ms 기준을 임의 완화하지 않습니다.
  일반 Release에 상시 로그를 추가하지 않습니다. 실제 설치는 task-006 사전 승인 뒤 task-007에서만 변경합니다.

## 미확정 판단

- UI Automation 인증 진행 여부와 현재 Mac 사용 여부는 미확인입니다. 과거 무사용 회신을 새 측정의 무사용으로 단정하지 않습니다.
- CPU 잔여 비용의 비중은 미확정입니다. process survey·순위 집계·카드 재조립·최근 이력 변환은 소스상 후보일 뿐 현재 CPU 귀속 증명이 아닙니다.
- CPU 그래프의 반복되는 ‘데이터 수집 중 09:59/10:00’ 문구는 최근600초 첫 표본을 수집 시작처럼 계산하는 경로와 연결됩니다.
  닫힘 중 수집·이력이 계속되는 것은 확인했으나 문구 수정은 하지 않았습니다. 별도 범위 판단이 필요합니다.
- task-005의 최신 전체 표시 관측, 반복 자원 회수, 첫 열림/재열림 반응과 task-006/007 목표 충족은 미검증입니다.

## 다음 작업

- 작업: 사용자가 UI Automation 인증 진행을 승인하면 격리 UI를 다시 시작해 Mac에서 직접 인증하도록 안내하고, task-005 검증을 재개합니다.
- 완료 기준: 같은 소스·artifact의 영향 UI·반복·실제 외부 반응 조건을 확인하고 독립 verify를 인수합니다. 부족/실패를 통과로 대체하지 않습니다.
  긴 GUI 시험 전 현재 Mac 사용 상태와 일정을 안내하며, 측정 중 빌드·테스트·프로파일러를 겹치지 않습니다.

## 먼저 읽을 파일

활성 feature의 README/spec/design/implement와 task-005 evidence README를 먼저 읽습니다.
구현은 `~/.codex/skills/implement-loop/SKILL.md`, `~/.codex/skills/implement/SKILL.md`,
검증은 `~/.codex/skills/verify/SKILL.md`, 상태는 `~/.codex/docs/phased-state.md`를 따릅니다.

## 문서 반영 필요

없음.
