# Context

저장: 2026-10-03 (통합 요약 UI 최종 승인)

## 최신 Per-Request 수정

사용자가 Memory하단공백제거후main스테이징/커밋/푸시를지시했다. Memory최소199pt를제거했고실제내용높이를쓴다(기본169pt/긴정보184pt). 이전고정높이계약보다이사용자수정이우선한다. 관련DashboardCardHeightTests/IntegratedDashboardSummaryTests 15/15·서명Debug빌드통과, 실제PID30987 본체280×668pt/스크롤없음/하단공백제거를확인했다. source/관련테스트·design/implement/상위design에반영했고 Git작업기준HEAD9212400, branchmain, origin/main보다13개선행이었다. 사용자승인범위에따라이번수정을커밋하고기존main커밋과함께origin/main에푸시한다. 최종상태는git status/log로확인한다.

## 현재 목표

현재 사용자 UI 요청을 완료했다. CPU·Memory·Network·Disk 전체를 줄여 스크롤 없이 한눈에 표시하고, 지나치게 작은 글씨를 회복했다. Network·Disk 하단 안내 삭제, Disk 수치 옆 미니 그래프, TOP 5 아래3pt 여백을 반영했다. 추가 요청 없이 후속 M3 검증을 자동 시작하지 않는다.

## 현재 상태

- 루트 `/Users/zipkero/XcodeProjects/ResourceRunner`, branch main. 작업 기준HEAD `11680b5`; 최종 통합 UI 커밋은 `git log -1`로 확인한다.
- SPEC·DESIGN `[x]`, IMPLEMENT `[ ]`. Tasks001~008/010/011 `[x]`,009철회,012~018 `[ ]`.
- 사용자가 CPU·Memory가 그대로인 중간 화면의 스크롤과 작은 Network/Disk 글씨를 반려했다. main이590pt·6.67/7pt 강제 치수를 철회하고 전체 요약 통합 수정 하나를 task011로 지정했다. task012에는 추가 화면/chrome 검증을 남겼다.
- worker implement_task002 최종결과를 main이 인수했고 verifier verify_compact_task010의 FINAL approved를 확정했다. 전체unit610/610·Release/서명Debug빌드·최종source11개/바이너리2개해시/patch가 대응한다.
- 실제signedSandbox PID94070: visibleFrame1728×1084 scale2, content280×698/outer306×724, bodyScroll=false. 네카드AX CPU264×241/Memory264×199/Network·Disk264×112 모두화면안. Memory/Disk상세400×480·개폐후본체불변·DiskAXPress0. native관찰프로세스는종료했다.
- 이전Disk단독sample-compact는사용자반려이력으로보존했다. 초기testselector누락·구픽셀좌표6건은최종전체610/610으로해소했다. 현재승인근거는readable-integrated패킷이다.
- main은문서/상태/커밋소유, worker제품코드/검증, verifier읽기전용. 다른변경을되돌리지않는다.

## 현재 작업 문서

- [spec.md](./features/20260817-001-extended-resource-monitoring/spec.md)
- [design.md](./features/20260817-001-extended-resource-monitoring/design.md)
- [implement.md](./features/20260817-001-extended-resource-monitoring/implement.md)
- [README.md](./features/20260817-001-extended-resource-monitoring/README.md)
- [최종 UI 근거](./features/20260817-001-extended-resource-monitoring/evidence/task-011/readable-integrated/README.md)

각 문서 첫머리의 실제 화면 피드백 기준이 과거 샘플/치수보다 우선한다.

## 확정된 결정

본체폭280/padding8/gap6, 기본요약10pt이상/대표17.33pt/CPU판66.67pt, TOP5아래3pt. 최종CPU241/Memory199/Network112/Disk112로본체698pt, ScrollView없음. 많은Network종류는종류수/활성·미확인수요약, 전체이름은상세/부모AX에보존한다. 상세원래글꼴/스크롤·수집·단위·원문값·실제아이콘을유지한다.

이전Task012 부분구현은stash `0ef806c85321a92c7a07226de4b0080a7cc1eb48`에보존했다. 구치수1221/601기준으로전체적용금지, 필요하면현재계약에맞는부분만선별한다.

## 미확정 판단

추가화면의팝오버외곽chrome·8pt여유는task012, 전체키보드/AX·OS/연결전환·시스템도구비교·production통합은013~018에남는다. 콘텐츠는현재실화면안에있지만NSPopover외곽상단5pt는메뉴바영역에걸치며chrome검증후속관문이다. UI완료를M3전체완료로보고하지않는다.

## 다음 작업

- 작업: 추가요청이없으면자동후속Task를시작하지않는다. 다음재개시task012추가화면/chrome관문을원본에서확인한다.
- 완료 기준: 현재UI요청완료/전체610통과/실제한눈화면을보고한다.

## 먼저 읽을 파일

- [DashboardView.swift](./ResourceRunner/DashboardView.swift)
- [DashboardStyle.swift](./ResourceRunner/DashboardStyle.swift)
- [NetworkDashboardView.swift](./ResourceRunner/NetworkDashboardView.swift)
- [DiskDashboardView.swift](./ResourceRunner/DiskDashboardView.swift)
- [StatusBarController.swift](./ResourceRunner/StatusBarController.swift)
- ~/.codex/skills/implement/SKILL.md, verify/SKILL.md, context-save/SKILL.md, ~/.codex/docs/phased-state.md

## 문서 반영 필요

없음. 최신계약과011/012소유재편을원본 문서및상위design/ROADMAP에반영했다.
