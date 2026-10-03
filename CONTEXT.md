# Context

저장: 2026-10-03 (M4 SPEC 완료)

## 현재 목표

사용자 `$spec-init m4` 요청과 “권장” 범위 선택에 따라 M4 첫 명세를 완료했다. 이번 요청은 SPEC까지만이며 DESIGN·IMPLEMENT에는 자동 진입하지 않는다. main 스테이징·커밋·푸시 승인은 유지된다.

## 현재 상태

- 프로젝트 /Users/zipkero/XcodeProjects/ResourceRunner, branch main. 명세 작성 기준 HEAD는 0b01a9b다. 신규 feature는 features/20261003-001-app-preferences/이다.
- main이 승인된 기본 범위로 spec.md·README.md를 작성했다. SPEC [x], DESIGN/IMPLEMENT [ ]. 완료 조건은 SPEC §5.1~§5.13이다. 제품 코드·빌드 설정·실행 중인 앱을 변경하지 않았다.
- ROADMAP에 M4 착수에서 M3 보류 task014/015를 선행 조건의 예외로 두는 결정을 기록했다. 제품 정의에도 이번 첫 범위와 후속 설정을 구분했다. 기존 M3 SPEC·DESIGN/승인된 Task·IMPLEMENT 미완료 상태는 유지된다.
- M3의 마지막 구현 커밋은4757b28, 완료 인수인계는0b01a9b로 origin/main에 푸시했다. M3 Tasks001~008/010~013/016~018 승인,009철회,014/015 미완료다. VPN·외장 디스크와 잠금·절전 복귀는 사용자 보류이고 Ethernet 전환 장비도 미확보다.
- 이전 M3 근거: 단위614/614, 서명 UI 전체29/30 뒤 유일한 AXLabel 단언 보완 후 해당1/1 통과, Debug/Release 빌드·정상 Sandbox 네 카드/상세/CPU 부하 메뉴바 반응·최종 해시 확인. 이 결과는 M4 구현 검증으로 간주하지 않는다.

## 현재 작업 문서

- [M4 상태](./features/20261003-001-app-preferences/README.md)
- [M4 SPEC](./features/20261003-001-app-preferences/spec.md)
- [ROADMAP](./ROADMAP.md), [제품 정의](./docs/product.md), [기술 설계](./docs/design.md)
- 선행 [M3 상태](./features/20260817-001-extended-resource-monitoring/README.md), [M3 통합 근거](./features/20260817-001-extended-resource-monitoring/evidence/task-018/README.md)

## 확정된 결정

- M4 첫 범위는 카드별 표시·CPU/Memory TOP 5 표시, 그래프1/5/10분, 갱신4단계, 로그인 자동 실행, 기본값 복원이다. 기본 표시를 유지하며 시스템 프로세스 필터·상세 정원·팝오버 자동 닫기 옵션과 캐릭터/애니메이션 설정·업데이트 확인은 후속 범위다.
- 기존 수집 자동 감속·중지·기준점·속도 정의·메모리 이력과 부분 합계 의미를 보존한다. 설정값만 저장하고 수집값·순위·그래프를 영속화하지 않는다. 로그인 상태는 macOS 실제 상태를 기준으로 한다.
- 본체 스크롤 없는 읽을 수 있는 네 카드, Memory 자연 높이·예약 공백 제거, Network 그래프 없음·Disk 미니 그래프·TOP 5 여백과 상세/접근성을 유지한다. 작은 화면 정책 경계를 임의 변경하지 않는다.
- M3 보류 관문은 M4 착수를 막지 않지만 M3 전체 완료로 처리하지 않는다. 이전 Task012 stash0ef806c85321a92c7a07226de4b0080a7cc1eb48은 구치수이므로 전체 적용하지 않는다.

## 미확정 판단

SPEC 요구사항의 미확정 항목은 없다. API·설정 화면 배치·저장 키·저전력/닫힘/프로필의 구체적인 일정 병합은 DESIGN에서 확정할 설계 사항이다. 이 단계에서는 design.md·implement.md를 생성하지 않았다.

## 다음 작업

- 작업: 사용자가 DESIGN을 요청하면 design-init으로 M4의 승인된 SPEC과 현재 원본을 조사해 설계한다.
- 완료 기준: SPEC §5.1~§5.13을 빠짐없이 설계에 연결하고, 기존 수집 경계·표시·로그인 실제 상태와 설정 저장의 책임을 설명한다. 보류한 M3 검증은 별도 재개 지시와 환경 확보 후 진행한다.

## 먼저 읽을 파일

- [M4 SPEC](./features/20261003-001-app-preferences/spec.md), [상태](./features/20261003-001-app-preferences/README.md)
- [ResourceRunnerApp.swift](./ResourceRunner/ResourceRunnerApp.swift), [ApplicationCoordinator.swift](./ResourceRunner/ApplicationCoordinator.swift)
- [MonitoringLifecycle.swift](./ResourceRunner/MonitoringLifecycle.swift)
- [DashboardPresentationStore.swift](./ResourceRunner/DashboardPresentationStore.swift), [DashboardView.swift](./ResourceRunner/DashboardView.swift), [DashboardViewport.swift](./ResourceRunner/DashboardViewport.swift)
- [MonitoringSampleStore.swift](./ResourceRunner/MonitoringSampleStore.swift), [ResourceRateGraph.swift](./ResourceRunner/ResourceRateGraph.swift), [ApplicationRanking.swift](./ResourceRunner/ApplicationRanking.swift)
- ~/.codex/skills/design-init/SKILL.md, ~/.codex/docs/phased-state.md

## 문서 반영 필요

없음. 사용자 선택과 M4 착수 예외를 SPEC·ROADMAP·제품 정의에 반영했다.
