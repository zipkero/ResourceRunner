# Context

저장: 2026-10-03 (Task018 최종 승인)

## 현재 목표

사용자 지시로 M3 잔여 작업을 진행했고, 보류 범위를 제외한 검증·정리를 완료했다. main 스테이징·커밋·푸시 승인이 유지된다.

## 현재 상태

- 프로젝트 /Users/zipkero/XcodeProjects/ResourceRunner, branch main. Task018 구현 커밋4757b28을 origin/main에 푸시하고 clean·원격 동기화를 확인했다. worker FINAL completed와 독립 verifier FINAL approved를 main이 인수·확정했다. Task012(54a89e1),013(1b15966),016(5aedfa4·CSV 원본 보정4487c94),017(32189a5)도 푸시 완료했다.
- SPEC·DESIGN [x], IMPLEMENT [ ]. Tasks001~008/010~013/016~018 승인,009철회,014/015 미완료. task014의 VPN·외장 디스크와 task015의 잠금·수면·화면 수면·사용자 전환은 사용자 보류다. Ethernet 전환 장비도 미확보이며 연결 없음/복귀는 실행하지 않았다.
- Task018 unit614/614·Debug/Release 통과. 서명 UI 전체29/30 뒤 유일 실패인 NetworkUpdateCadence의 AXLabel 단독 단언을 label+value로 보완한 해당1/1이 통과했다. 단일 실행30/30 성공을 주장하지 않는다. 글로벌 보안/TCC 설정은 변경하지 않았다.
- 임시 DEBUG probe·긴 Memory/저전력 주입 경로를 제거했다. Collector·일정·baseline·저장·표시·키보드의 production 동작은 유지했다. 최종 소스/Debug stub·실제 Swift dylib/Release 해시10개가 일치한다.
- 정상 서명 Sandbox 앱 PID95172(/private/tmp/rr-task018-debug/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner) 하나에서 네 카드·상세·끝 페이지와 CPU18~19%→실제 부하93~95%→회복18~20%, 메뉴바 낮음→매우 높음→낮음을 확인했다. 부하 자식은 종료했고 정상 앱 하나를 실행 중으로 남겼다. Release는 빌드 확인용 미서명이며 실제 관찰은 서명 Debug다.
- 이번018 승인으로 SPEC §5.1·§5.2·§5.10·§5.12·§5.14·§5.16을 충족했다. 016/017로 §5.6도 충족했다. 나머지 조건과 M3/IMPLEMENT 전체를 완료로 표시하지 않는다.

## 현재 작업 문서

- [기능 상태](./features/20260817-001-extended-resource-monitoring/README.md)
- [SPEC](./features/20260817-001-extended-resource-monitoring/spec.md)
- [DESIGN](./features/20260817-001-extended-resource-monitoring/design.md)
- [IMPLEMENT](./features/20260817-001-extended-resource-monitoring/implement.md)
- [Task018 통합 근거](./features/20260817-001-extended-resource-monitoring/evidence/task-018/README.md)
- [Task016 Network 비교](./features/20260817-001-extended-resource-monitoring/evidence/task-016/README.md), [Task017 Disk 비교](./features/20260817-001-extended-resource-monitoring/evidence/task-017/README.md)
- [Task012 실제 화면](./features/20260817-001-extended-resource-monitoring/evidence/task-012/README.md), [Task013 키보드·접근성](./features/20260817-001-extended-resource-monitoring/evidence/task-013/README.md)
- [Task014 환경·미실행 기록](./features/20260817-001-extended-resource-monitoring/evidence/task-014/README.md)

## 확정된 결정

본체 스크롤 없이 네 카드가 한 화면에 보여야 하며 글씨를 과도하게 줄이지 않는다. Memory는 예약 하단 공백 없이 자연 높이를 사용한다. Network 그래프·Network/Disk 하단 측정 안내를 제거하고 Disk 수치 옆 미니 그래프와 CPU 그래프·Memory 구성·TOP 5 아래 여백을 유지한다. 상세 정보와 내부 스크롤은 보존한다.

현재 실제 화면1728×1117(visible1084)/scale2에서 본체280×668·외곽306×694와 네 상세400×480을 확인했다. task012는 실제1168×755(visible729) 모드와 긴 Memory 자연 높이까지 검증했고018 cleanup의 production geometry 경로는 불변이다. 전체 화면 정책과 구체 치수는 최신 feature 문서를 따른다.

Network는 unknown 대상 때문에 부분 합계이며 완전한 대표 합계로 주장하지 않는다. 동일한 확인된 물리 집합의 시간 차분·변화 방향만 비교했다. Disk는 내장 disk0의 실제 F_NOCACHE 합성 부하를 iostat Read+Write 합계와 비교했고 방향은 raw driver 바이트로 확인했다.

## 미확정 판단

Task014/015를 mock이나 통합 결과로 대체하지 않는다. 외부 물리 화면은 없었고 본체와 chrome가 들어가지 않는 더 작은 화면의 정책은 미확정이다. 이전 Task012 stash0ef806c85321a92c7a07226de4b0080a7cc1eb48은 구치수이므로 전체 적용하지 않는다.

## 다음 작업

- 작업: 현재 승인 범위의 남은 작업은 없다. 보류014/015는 사용자가 재개하고 필요한 환경을 확보할 때만 진행한다.
- 완료 기준: M3 전체 완료는 보류 Task의 실제 관문이 충족된 뒤 판단한다. 현재 결과·문서·CONTEXT와 main 커밋·푸시는 완료했다.

## 먼저 읽을 파일

- [IMPLEMENT](./features/20260817-001-extended-resource-monitoring/implement.md)
- [Task018 근거](./features/20260817-001-extended-resource-monitoring/evidence/task-018/README.md)
- [AppDelegate.swift](./ResourceRunner/AppDelegate.swift), [ApplicationCoordinator.swift](./ResourceRunner/ApplicationCoordinator.swift)
- [DashboardViewport.swift](./ResourceRunner/DashboardViewport.swift), [DashboardView.swift](./ResourceRunner/DashboardView.swift)
- ~/.codex/skills/implement-loop/SKILL.md, implement/SKILL.md, verify/SKILL.md, context-save/SKILL.md, ~/.codex/docs/phased-state.md

## 문서 반영 필요

없음. 현재 구현 설명·ROADMAP·feature 승인 상태를 main이 반영했다.
