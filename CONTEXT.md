# Context

저장: 2026-10-03 (M4 DESIGN 완료)

## 현재 목표

사용자 `$design-init M4` 요청에 따라 승인된 M4 첫 범위의 설계를 완료했다. 이번 요청은 DESIGN까지만이며 IMPLEMENT 계획·구현에는 자동 진입하지 않는다. main 스테이징·커밋·푸시 승인은 유지된다.

## 현재 상태

- 프로젝트 /Users/zipkero/XcodeProjects/ResourceRunner, branch main. SPEC 작성 기준 HEAD는 0b01a9b, DESIGN 조사 기준 HEAD는 e78af7f다. 신규 feature는 features/20261003-001-app-preferences/이다.
- analyzer의 읽기 전용 후보를 main이 승인된 SPEC·현재 원본·로컬 SDK에 대조해 design.md에 적용했다. SPEC/DESIGN [x], IMPLEMENT [ ]. SPEC §5.1~§5.13과 내부 결정 DP1~DP8이 연결됐고 미채택 결정은 없다. 제품 코드·빌드 설정·실행 앱·로그인 등록은 변경하지 않았다.
- 이번 변경은 M4 design.md·README.md와 ROADMAP·CONTEXT뿐이다. 문서 형식·13개 조건 연결·8개 결정·로컬 링크·언어 검사와 diff 확인을 통과했다. 실제 실행·로그인 검증은 설계에 적은 후속 관문이며 기존 M3 결과를 M4 통과로 사용하지 않는다.
- ROADMAP에 M4 착수에서 M3 보류 task014/015를 선행 조건의 예외로 두는 결정을 기록했다. 제품 정의에도 이번 첫 범위와 후속 설정을 구분했다. 기존 M3 SPEC·DESIGN/승인된 Task·IMPLEMENT 미완료 상태는 유지된다.
- M3의 마지막 구현 커밋은4757b28, 완료 인수인계는0b01a9b로 origin/main에 푸시했다. M3 Tasks001~008/010~013/016~018 승인,009철회,014/015 미완료다. VPN·외장 디스크와 잠금·절전 복귀는 사용자 보류이고 Ethernet 전환 장비도 미확보다.
- 이전 M3 근거: 단위614/614, 서명 UI 전체29/30 뒤 유일한 AXLabel 단언 보완 후 해당1/1 통과, Debug/Release 빌드·정상 Sandbox 네 카드/상세/CPU 부하 메뉴바 반응·최종 해시 확인. 이 결과는 M4 구현 검증으로 간주하지 않는다.

## 현재 작업 문서

- [M4 상태](./features/20261003-001-app-preferences/README.md)
- [M4 SPEC](./features/20261003-001-app-preferences/spec.md)
- [M4 DESIGN](./features/20261003-001-app-preferences/design.md)
- [ROADMAP](./ROADMAP.md), [제품 정의](./docs/product.md), [기술 설계](./docs/design.md)
- 선행 [M3 상태](./features/20260817-001-extended-resource-monitoring/README.md), [M3 통합 근거](./features/20260817-001-extended-resource-monitoring/evidence/task-018/README.md)

## 확정된 결정

- M4 첫 범위는 카드별 표시·CPU/Memory TOP 5 표시, 그래프1/5/10분, 갱신4단계, 로그인 자동 실행, 기본값 복원이다. 기본 표시를 유지하며 시스템 프로세스 필터·상세 정원·팝오버 자동 닫기 옵션과 캐릭터/애니메이션 설정·업데이트 확인은 후속 범위다.
- DESIGN은 단일 AppKit 설정창·동일 설정 snapshot 선적용·UserDefaults 일반 설정/실제 ServiceManagement mainApp 상태 분리·프로필/저전력 max 병합·조회 완료까지 단일 실행권·당시 주기 G=max(10초,2P)·1203개 최대 600초 이력·표시 범위 분리·현재 마지막 카드 앵커를 채택했다.
- 기존 수집 자동 감속·중지·기준점·속도 정의·메모리 이력과 부분 합계 의미를 보존한다. 설정값만 저장하고 수집값·순위·그래프를 영속화하지 않는다. 로그인 상태는 macOS 실제 상태를 기준으로 한다.
- 본체 스크롤 없는 읽을 수 있는 네 카드, Memory 자연 높이·예약 공백 제거, Network 그래프 없음·Disk 미니 그래프·TOP 5 여백과 상세/접근성을 유지한다. 작은 화면 정책 경계를 임의 변경하지 않는다.
- M3 보류 관문은 M4 착수를 막지 않지만 M3 전체 완료로 처리하지 않는다. 이전 Task012 stash0ef806c85321a92c7a07226de4b0080a7cc1eb48은 구치수이므로 전체 적용하지 않는다.

## 미확정 판단

SPEC·DESIGN의 미확정 항목은 없다. implement.md는 아직 없다. 실제 로그인 실행은 서명된 안정된 앱 경로와 운영 접근·사용자 승인 범위가 필요한 후속 검증 관문이다. 관문 환경이 없으면 해당 Task를 승인하지 않는다. M3 보류 항목·아주 작은 화면 정책은 별도이며 이번 설계로 완료·재개하지 않는다.

## 다음 작업

- 작업: 사용자가 IMPLEMENT 계획을 요청하면 implement-init으로 승인된 M4 SPEC·DESIGN에서 Task와 검증 기준을 작성한다.
- 완료 기준: SPEC §5.1~§5.13과 DESIGN의 일정·실행권·이력·표시·설정·실제 로그인 관문을 빠짐없이 Task에 연결하고, 의미 변경 없이 인수 가능한 경계·검증·의존 순서를 확정한다. 보류한 M3 검증은 별도 재개 지시와 환경 확보 후 진행한다.

## 먼저 읽을 파일

- [M4 SPEC](./features/20261003-001-app-preferences/spec.md), [DESIGN](./features/20261003-001-app-preferences/design.md), [상태](./features/20261003-001-app-preferences/README.md)
- [ResourceRunnerApp.swift](./ResourceRunner/ResourceRunnerApp.swift), [ApplicationCoordinator.swift](./ResourceRunner/ApplicationCoordinator.swift)
- [MonitoringLifecycle.swift](./ResourceRunner/MonitoringLifecycle.swift)
- [DashboardPresentationStore.swift](./ResourceRunner/DashboardPresentationStore.swift), [DashboardView.swift](./ResourceRunner/DashboardView.swift), [DashboardViewport.swift](./ResourceRunner/DashboardViewport.swift)
- [MonitoringSampleStore.swift](./ResourceRunner/MonitoringSampleStore.swift), [ResourceRateGraph.swift](./ResourceRunner/ResourceRateGraph.swift), [ApplicationRanking.swift](./ResourceRunner/ApplicationRanking.swift)
- ~/.codex/skills/design-init/SKILL.md, ~/.codex/docs/phased-state.md

## 문서 반영 필요

없음. 내부 결정은 M4 DESIGN에, 단계 상태와 다음 작업은 README·ROADMAP·CONTEXT에 반영했다. 상위 기술 설계의 현재 구현 설명은 제품 구현 후 해당 단계에서 갱신한다.
