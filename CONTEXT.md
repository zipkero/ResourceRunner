# Context

저장: 2026-10-03 (축소 UI 승인 반영)

## 현재 목표

사용자가 승인한 280×590pt 축소 샘플을 실제 앱에 적용한다. Network·Disk 하단의 측정/보조 정보/용량 확인 경과 안내를 제거하고 CPU·Memory TOP 5 제목 아래 여백을 추가한다.
현재 실행 범위는 task-010→011→012의 UI 변경이다. 후속 task-013~018은 이번 요청만으로 자동 착수하지 않는다. 이전 사용자의 Task별 독립 승인 후 main 커밋 지시는 유지한다.

## 현재 상태

- 프로젝트 /Users/zipkero/XcodeProjects/ResourceRunner, branch main, 검증 기준 HEAD e63e515(현재 HEAD는 git rev-parse로 확인).
- 최신 SPEC·DESIGN `[x]`, IMPLEMENT `[ ]`. task-001~008 `[x]`, task-009는 체크박스 없는 철회 이력, task-010 `[x]`, task-011~018 `[ ]`.
- main이 승인 샘플·footer 삭제·TOP 5 여백을 SPEC에 반영하고 design-init/implement-init analyzer compact_design_revision 후보를 원본과 대조해 적용했다. 기존 ID18개·적용 Task17개·적용 완료 조건18개. 철회 SPEC §5.17은 보존하고 Disk 미니 그래프는 새 §5.19에 매핑한다.
- task010의갱신주기설명보완후최종독립재verify approved를main이확정했다. 근거evidence/task-010/sample-compact/retry-cadence/와상위패킷. Network집중4/4·Release/서명Debug·실제PID41825 NetworkUpdateCadence AX359×28/카드248×101/상세·닫기/frame·최종해시를확인했다. 전체606/606·최대값직접렌더는상위근거와결합했다. 초기approved철회/rejected/soft reset이력은README에보존,최근reject제거. 상태저장·커밋후task011착수한다.
- 다른 작업자의 기존 미커밋 변경을 보존한다. 제품 diff에는 이전 compact Network/Disk 공유 경계·관련 테스트·DEBUG probe와 최신010 수정이 함께 있다. 문서/CONTEXT 상태와 커밋은 main 소유다.
- 과거 task-009~011 승인은 최신 UI 계약의 승인 근거가 아니며 원자료와 이력으로 유지한다. 수집·일정·모델001~008 승인은 유지한다.
- 제품의 현재 부모 카드 폭은248pt다. 010/011은264×101pt 직접렌더와248×101pt 과도기/실제앱을 확인하고, 본체padding8·최종264pt 실제 네카드590pt 표시/CPU·Memory축소는012에서 확인한다.

## 현재 작업 문서

- [spec.md](./features/20260817-001-extended-resource-monitoring/spec.md): 최신 사용자 요구와 완료 조건. 상세는 이 원본을 따른다.
- [design.md](./features/20260817-001-extended-resource-monitoring/design.md): 축소 치수·요약 전용 타이포·내부 긴값 적응·미니 그래프·실제 화면/chrome 계약.
- [implement.md](./features/20260817-001-extended-resource-monitoring/implement.md): 순차010/011/012 결과와 검증, 후속 관문·완료 조건 매핑.
- [README.md](./features/20260817-001-extended-resource-monitoring/README.md): 현재 상태·승인 이력.
- [승인 샘플](./features/20260817-001-extended-resource-monitoring/evidence/compact-layout-reference/README.md): 예시 값/대체 아이콘의 배치 기준, 실제 앱 검증을 대신하지 않는다. 원본 /tmp/ResourceRunner-compact-preview-20261003/Preview.swift에도 있다.

## 확정된 결정

최신 요구사항·설계·Task 의미는 feature 원본이 소유한다. 네 카드 한 열/전체 축소·Network 그래프 없음·Disk 수치 옆 미니 그래프·footer 삭제·TOP 5 여백은 사용자 승인이다. 실제 아이콘·정보 의미·상세·수집을 유지한다.
과학 표기는 승인되지 않았다. 이전 큰 속도 말줄임은 새 축소 글꼴과 원문 수치의 내부 재배치/필요한 글꼴 축소로 먼저 해결하며 정밀도·단위·그룹 구분을 바꾸지 않는다.

과거 Task012 부분 제품 구현은 git stash `0ef806c85321a92c7a07226de4b0080a7cc1eb48`에 보존한다. 원본 계약과 맞는 부분만012에서 선별 재사용한다. stash 전체를010/011 작업에 적용하지 않는다.
stash에는 DashboardViewport·StatusBarController·DashboardView/Network·Disk 상세·ApplicationCoordinator·AppDelegate viewport probe가 있다. 현재 제품에 DashboardViewport.swift는 없다. 과거 viewport는1221/601·329/224/294/294 기준이며 최신590pt 결과가 아니다.

## 미확정 판단

- task010은갱신주기설명보완후최종독립approved다. 최종264 실제배선은012에서 검증하며 승인된 내부 적응으로도 필수값이 읽히지 않으면 소유 단계로 반환한다.
- 최신011 Disk 극값/미니 판/용량·012 CPU/Memory 상태/긴값/TOP5/실제네카드/화면chrome 근거는 미확보다.
- 실제 네트워크/VPN/외장 전환·OS sleep/wake·전체 키보드/AX·시스템 도구 비교·production 통합 관문013~018은 미완료다. UI 요청 완료를 M3 전체 완료로 보고하지 않는다.

## 다음 작업

- 작업: 최종approved task010 변경을커밋하고같은worker implement_task002에게task011 Disk101pt·미니42pt·footer삭제·극값용량·실제앱검증을맡긴다.
- 완료 기준: 최신Task010의 상태/원문수치/로케일·footer/그래프제거·상세/AX·실제개폐·공유경계가검증돼야한다. 이후011→012를순차완료하고최종실제화면을사용자에게보여준다.

## 먼저 읽을 파일

- [NetworkDashboardView.swift](./ResourceRunner/NetworkDashboardView.swift)
- [DiskDashboardView.swift](./ResourceRunner/DiskDashboardView.swift)
- [DashboardView.swift](./ResourceRunner/DashboardView.swift)
- [DashboardStyle.swift](./ResourceRunner/DashboardStyle.swift)
- [ResourceRateGraphView.swift](./ResourceRunner/ResourceRateGraphView.swift)
- [StatusBarController.swift](./ResourceRunner/StatusBarController.swift)
- [ApplicationCoordinator.swift](./ResourceRunner/ApplicationCoordinator.swift)
- [AppDelegate.swift](./ResourceRunner/AppDelegate.swift)
- [NetworkDashboardViewTests.swift](./ResourceRunnerTests/NetworkDashboardViewTests.swift)
- [DiskDashboardViewTests.swift](./ResourceRunnerTests/DiskDashboardViewTests.swift)
- [DashboardCardLayoutTests.swift](./ResourceRunnerTests/DashboardCardLayoutTests.swift)
- ~/.codex/skills/implement-loop/SKILL.md, implement/SKILL.md, verify/SKILL.md, context-save/SKILL.md 및 ~/.codex/docs/phased-state.md

## 문서 반영 필요

상위 docs/product.md·docs/design.md·README·ROADMAP에 최신 승인 요약치수·그래프정책·진행중 상태를 반영했다. 최종012승인후 ROADMAP·CONTEXT진행상태를맞춘다. 미확정VPN합산/프로세스별Disk I/O목록은featureSPEC의확정결정을다시미확정으로만들지않는다.
