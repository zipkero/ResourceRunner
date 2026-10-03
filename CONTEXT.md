# Context

저장: 2026-10-03 (Task012 승인 후 M3 잔여 검증)

## 현재 목표

사용자 지시로 M3 잔여 작업을 진행한다. 잠금·절전 복귀와 VPN·외장 디스크 실제 관찰은 사용자 답변으로 보류한다. 읽을 수 있는 스크롤 없는 네 카드와 Memory 자연 높이를 유지한다. main 스테이징·커밋·푸시 승인이 유지된다.

## 현재 상태

- 프로젝트 /Users/zipkero/XcodeProjects/ResourceRunner, branch main, 기준 HEAD43de4d3. 승인 Task012를 main이 커밋·푸시한 뒤 다음 Task로 진행한다.
- SPEC·DESIGN [x], IMPLEMENT [ ]. Tasks001~008/010/011/012 승인,009철회,013~018미완료. task014실장치와015잠금·수면·화면수면·사용자전환은 보류이며 완료/철회로 바꾸지 않는다. Ethernet 전환 장비도 미확보다.
- worker /root/implement_task002의 Task012 FINALcompleted와 verifier /root/verify_compact_task010의 FINALapproved를 main이 인수·확정했다. main만 문서·상태·커밋·푸시를 수행한다.
- Task012 소스9개·Debug실행파일/실제Swift dylib·Release해시 일치, 관련38/38·Release·서명Debug 통과. [근거](./features/20260817-001-extended-resource-monitoring/evidence/task-012/README.md).
- 실제 현재화면1728×1117(visible1084),scale2: 본체280×668/외곽306×694/스크롤없음, 네상세400×480/외곽426×506, 모두8pt·카드앵커·개폐본체불변·끝스크롤 확인(PID4865).
- 추가실제1168×755(visible729)모드: 본체동일/네상세공유400×136/외곽426×162, 모두8pt·앵커·끝스크롤 확인(PID5951). 합성최장Memory fixture PID6563에서169→184/본체668→683으로늘어도상세400×136불변·Disky8. 원문두줄PNG확인. 화면모드복원·관찰앱종료 완료.
- 외부물리화면은없고더낮은지원모드는본문+chrome+16pt가들어가지않는다. 새정책을넣지않았고그모드들의지원성공을주장하지않는다.
- 이전owned Task011일반앱PID34093은정확한실행경로대조후종료했다. 마지막에는일반앱하나만실행한다.

## 현재 작업 문서

- [spec.md](./features/20260817-001-extended-resource-monitoring/spec.md)
- [design.md](./features/20260817-001-extended-resource-monitoring/design.md)
- [implement.md](./features/20260817-001-extended-resource-monitoring/implement.md)
- [README.md](./features/20260817-001-extended-resource-monitoring/README.md)

최신첫머리의실제화면피드백·Memory수정이과거590pt/고정199pt/작은글꼴·본체스크롤설명보다우선한다. Task013/018 관련문장도기존결정에맞게정합화했다.

## 확정된 결정

본체폭280/padding8/gap6, 기본요약10pt이상/대표17.33pt/CPU판66.67pt, TOP5아래3pt. CPU최소241pt/Memory자연높이(기본169·긴184)/Network112/Disk112pt, 기본본체668pt·ScrollView없음. Network그래프·Network/Disk하단안내삭제, Disk수치옆42pt미니그래프. 상세원래글꼴·내부스크롤·정보·수집·단위보존. 많은Network종류는개수요약하고전체이름은상세/AX에보존한다.

Task012는실제Disk·Memory카드NSView좌표/높이와chrome로네상세공유높이를계산한다. Memory긴정보가실제팝오버에서세로압축되지않게고유높이를유지했다. Memory예약공백은재도입하지않는다.

Task011전체610/610근거는 [readable-integrated](./features/20260817-001-extended-resource-monitoring/evidence/task-011/readable-integrated/README.md)에있다. Memory하단수정은관련15/15·실제668pt·서명Debug확인후43de4d3로커밋·푸시했다. 이전Task012 stash 0ef806c85321a92c7a07226de4b0080a7cc1eb48은구치수기준이라전체적용하지않는다.

## 미확정 판단

Task014실장치와015잠금·절전복귀는보류·미완료다. 외부화면/너무작은화면정책경계는Task012근거에남겼다. M3전체완료로보고하지않는다.

## 다음 작업

- 작업: Task012를main에커밋·푸시한뒤worker에게Task013키보드·포커스·실제AX검증을위임한다. 이어016→017→018을진행한다.
- 완료 기준: Task마다worker FINAL/독립verifier FINAL을인수하고main이판정·상태·CONTEXT·커밋을반영한다. 보류한실제전환을mock/통합결과로대체하지않는다.

## 먼저 읽을 파일

- [DashboardViewport.swift](./ResourceRunner/DashboardViewport.swift)
- [DashboardView.swift](./ResourceRunner/DashboardView.swift)
- [DashboardPresentationStore.swift](./ResourceRunner/DashboardPresentationStore.swift)
- [StatusBarController.swift](./ResourceRunner/StatusBarController.swift)
- [AppDelegate.swift](./ResourceRunner/AppDelegate.swift)
- ~/.codex/skills/implement-loop/SKILL.md, implement/SKILL.md, verify/SKILL.md, context-save/SKILL.md, ~/.codex/docs/phased-state.md

## 문서 반영 필요

없음。 미완료Task최종근거·승인은확인후main이반영한다.
