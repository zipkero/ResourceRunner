# Context

저장: 2026-10-03 (M4 구현 계획 완료)

## 현재 목표

사용자 `$implement-init M4` 요청에 따라 승인된 M4 설계를 구현 Task와 검증 조건으로 나눴다. 이번 요청은 계획까지만이며 제품 구현에는 자동 진입하지 않는다. main 스테이징·커밋·푸시 승인은 유지된다.

## 현재 상태

- 프로젝트 /Users/zipkero/XcodeProjects/ResourceRunner, branch main. 이번 조사 기준 HEAD는3f8f075이며 SPEC/DESIGN은 승인 상태다.
- analyzer의 읽기 전용 후보를 main이 현재 원본·선행 문서·기존 검증 파일에 대조해 implement.md에 적용했다. task-001~011은 모두 미착수 [ ]이며 SPEC/DESIGN [x], IMPLEMENT [ ]다.
- 이번 변경은 M4 implement.md·README.md와 ROADMAP·CONTEXT뿐이다. 제품 코드·빌드 설정·실행 앱·로그인 등록·OS 세션은 변경하지 않았다. 11개 Task 필드·선행 순서·DESIGN 참조·13개 조건 매핑·8개 결정 연결·로컬 링크·언어·diff 검사를 통과했다. SPEC·DESIGN 해시는 조사 기준과 동일하다.
- 설계 커밋3f8f075와 SPEC 커밋e78af7f는 origin/main에 푸시했다. 상위 계약·기존 M3 승인 의미는 변경하지 않았고 신규 계획이므로 취소할 Task 승인은 없다.
- M3 Tasks001~008/010~013/016~018 승인,009철회,014/015 미완료다. 실제 VPN·외장 디스크·잠금/절전 복귀는 사용자 보류이며 Ethernet 전환 장비도 미확보다. M4 착수 예외가 M3 전체 완료를 뜻하지 않는다.
- 이전 M3 검증은 unit614/614, UI전체29/30 뒤 실패1건 단언 수정·해당1/1 재실행, Debug/Release 빌드·서명 Sandbox 실측이다. 이를 M4 구현 검증으로 사용하지 않는다.

## 현재 작업 문서

- [M4 상태](./features/20261003-001-app-preferences/README.md)
- [M4 SPEC](./features/20261003-001-app-preferences/spec.md)
- [M4 DESIGN](./features/20261003-001-app-preferences/design.md)
- [M4 구현 계획](./features/20261003-001-app-preferences/implement.md)
- [ROADMAP](./ROADMAP.md), [제품 정의](./docs/product.md), [기술 설계](./docs/design.md)
- [M3 상태](./features/20260817-001-extended-resource-monitoring/README.md), [M3 통합 근거](./features/20260817-001-extended-resource-monitoring/evidence/task-018/README.md)

## 확정된 결정

- M4 첫 범위·기본값·정책은 승인된 SPEC·DESIGN이 소유한다. 구현 계획은 저장→일정/실행권→차분/이력→로그인 관리→초기 배선→그래프→표시→포커스/앵커→설정창→통합→실제 로그인 순서다.
- 기본 네 카드의 무스크롤·가독성·Memory 자연 높이·Network 그래프 없음·Disk 미니 그래프·TOP 5 여백·상세/AX를 유지한다. 작은 화면 정책과 M3 보류 항목은 별도다.
- task-011은 실제 서명된 안정 경로 앱의 등록/해제와 다음 로그인 실행을 판정한다. mock·status·수동 실행으로 대체하지 않으며 미래 운영 접근·사용자 승인 범위와 환경이 없으면 미승인으로 남긴다.
- 기존 Task012 stash0ef806c85321a92c7a07226de4b0080a7cc1eb48은 구치수이므로 전체 적용하지 않는다.

## 미확정 판단

계획 작성에 필요한 상위 결정은 부족하지 않다. 실제 구현·실행·UI·로그인 결과는 아직 없다. 향후 실제 세션 전환 권한·환경은 task-011 착수 시 main이 확인한다.

## 다음 작업

- 작업: 사용자가 구현을 요청하면 implement-loop로 남은 M4 Task를 조정하고 task-001부터 구현·verify를 진행한다.
- 완료 기준: Task별 현재 원본·diff·검증 근거로 승인하고 상태·이력을 갱신한다. SPEC §5.1~§5.13의 모든 매핑 Task가 승인되기 전에는 IMPLEMENT를 완료로 표시하지 않는다. 필수 실제 관문 미확인은 남긴다.

## 먼저 읽을 파일

- [M4 구현 계획](./features/20261003-001-app-preferences/implement.md), [SPEC](./features/20261003-001-app-preferences/spec.md), [DESIGN](./features/20261003-001-app-preferences/design.md), [상태](./features/20261003-001-app-preferences/README.md)
- [AppDelegate.swift](./ResourceRunner/AppDelegate.swift), [ApplicationCoordinator.swift](./ResourceRunner/ApplicationCoordinator.swift)
- [MonitoringLifecycle.swift](./ResourceRunner/MonitoringLifecycle.swift), [CollectionPipelines.swift](./ResourceRunner/CollectionPipelines.swift)
- 각 Task에 명시한 원본·기존 검증 파일
- ~/.codex/skills/implement-loop/SKILL.md, ~/.codex/skills/implement/SKILL.md, ~/.codex/skills/verify/SKILL.md, ~/.codex/docs/phased-state.md

## 문서 반영 필요

없음. 구현 계획과 상태를 M4 문서·ROADMAP·CONTEXT에 반영했다. 상위 기술 설계의 현재 구현 설명은 제품 구현 후 해당 단계에서 갱신한다.
