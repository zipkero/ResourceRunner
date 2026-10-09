# Context

저장: 2026-10-09 15:45 KST

## 현재 목표

사용자가 요청한 Disk 기준 변경의 6개 Task 재검증, 잠금·절전 복귀, 시스템 프로세스 포함·상세10/20/50·팝오버 자동 닫기를 완료했습니다. 승인된 최종 Release도 실제 사용 앱에 반영했습니다. 이후 사용자 요청으로 이 변경과 검증 근거를 main에 스테이징·커밋·푸시합니다.

## 현재 상태

- 프로젝트 /Users/zipkero/XcodeProjects/ResourceRunner, branch main, 구현 기준 HEAD5435c7dfdaf91d86c41827a6a521aa31b18dbbf9. 기존 task010/011 및 이번 M3/M4 코드·테스트·문서·근거를 함께 반영합니다. 사용자 main 스테이징·커밋·푸시 요청을 승인 범위로 삼으며, 실행 뒤 최신 SHA와 원격 반영 여부는 git log/status 및 origin/main으로 확인합니다.
- M3 SPEC/DESIGN/IMPLEMENT[x]. Disk task002/006/008/011/013/018 재검증, 실제 Wi-Fi 끊김/자동복구, 잠금12m59·디스플레이4s·SoftwareSleep→DeepIdleWake3s를 독립 승인했습니다. 중지6축 조회/표본0·복귀 첫 기준점/다음 실제 차분·CPU/Disk 그래프 단절을 확인했습니다. Network native partial/대표nil과 실제 en0속도는 구분했고 Memory 시계열 그래프가 있다고 주장하지 않았습니다. 마지막127소스 전체단위674/674·UI48/54/skip6과 별도 Release1/1·기존native로그인5/5 인수 범위는 근거에 기록했습니다.
- M4 app-preferences SPEC/DESIGN/IMPLEMENT[x], task001~016·적용16개조건 모두 독립 승인/main확정. 012 저장10/10,013 소속/두자료 원본92/92·격리679/679,014 즉시표시94/94·UI8/8,015 자동닫기41/41·UI5/5,016 현재전체단위690/690·선택UI21/21·fixture1/1·고유Release1/1 모두 실패/skip0. task014 카드AX static제외 문구 결함을 현재presentation 기반으로 보완하여17/17·독립 재승인했습니다(구현보완1/근거재검증0). task016 formal재시도0/0. 진단 UI 실패들은 통과 근거에서 제외하고 이유를 이력에 보존했습니다.
- task016 실제 AppKit 외부설정창클릭/Finder활성 on닫힘/off유지·열린양방향 전환·Escape 상세/본체·PageUpDown/포커스, fixture CPU/Memory사용량·증가량10/20/50·혼합UID PID/합계/경계/50행스크롤을 확인했습니다. 50그룹은 fixture실제렌더AX이며 native50/rootUID성공은 주장하지 않았습니다. native ownUID runner/하위PID·Memory단위/CPU부하 OneSession은 별도 실측했습니다. actualpayload9키(새키부재)→변경12키 true/fifty/off→복원12키 false/twenty/on, 수집값부재·초기로그인mutation0·일반복원/로그인실패분리와재실행을 확인했습니다. 고유앱/runner·고유suite 정리 완료.
- main은 독립 승인 후 /Users/zipkero/Applications/ResourceRunner.app 에 원본최종Release를 반영했습니다. 기존PID64258은 종료, 현재PID59351로 실행 중입니다. 앱 디렉터리 inode43094210·경로·Sandbox/global preferences.v1 없음 유지, exeSHA be4f5ce7ac7550cd8f205d5e1e598f68784992b99e7ab010a46ef8e0b6066e3f/CDHash37ccc4acddeeac1655e03fe9b526de61ac280498, strict서명/arm64/Sandbox/LSUIElement. 실제설치URL readonlyUI1/1로 새 기본값0/20/1·native로그인토글1/허용·단일설정창·닫기를 확인했습니다. 새binary 다음login을 재시험한 것으로 확대하지 않습니다. 실제 다음login 근거는 기존task01110:31loginwindow/autolaunch·창0·사용자메뉴바만관찰입니다.
- 이전앱백업 /tmp/rr-m4-016-installed-backup/ResourceRunner.app, 최종원본Release /tmp/rr-m4-016-main-final-release/Build/Products/Release/ResourceRunner.app. 원본제품/단위100파일SHA는 빌드전후/설치후 unchanged입니다. 실제등록함수/로그아웃/전원/네트워크 추가변경 없음, Amphetamine64228 유지. sfltool dumpbtm/TCC/SecurityAgent/daemon/비번우회조작 없음.
- 마지막 customreadonly verifier /root/m3_network_verifier approved, main 최종확정. worker /root/m4_integration016_worker completed. active 작업 없음. docs/product/design·ROADMAP·feature 상태/이력 현재화 완료.

## 현재 작업 문서

[M3 완료](./features/20260817-001-extended-resource-monitoring/implement.md), [M4 완료](./features/20261003-001-app-preferences/implement.md), [최종016](./features/20261003-001-app-preferences/evidence/task-016/README.md), [실제설치반영](./features/20261003-001-app-preferences/evidence/task-016/installed-release/README.md).

## 확정된 결정

새 기본값 시스템 포함false/상세20/자동닫기true, 선택10/20/50. 자동닫기는본체의외부클릭/타앱활성정책이며 시간닫기·상세고정 아님. 필터후집계/정렬/펼침안정화후정원, TOP5고정5/하위무절단/현재UID Apple경로포함, 읽기실패추정/새권한없음. 대표지표/시각/상태/그래프/일정 계약 유지. 실제VPN/외장디스크/유선LAN/다른계정전환 시험 사용자제외, M3 task009/§5.17철회 유지. M2캐릭터/자산·M4캐릭터/애니메이션설정·업데이트·M5장기성능/배포정책은 이번 요청범위 밖이며 ROADMAP에 남아 있습니다.

## 미확정 판단

이번 요청범위 없음. 후속마일스톤은 별도 지시가 필요합니다.

## 다음 작업

- 작업: main 커밋·푸시 완료 여부를 Git 원본으로 확인한 뒤 다음 사용자 지시를 기다립니다.
- 완료 기준: 원격 origin/main과 로컬 HEAD 일치, 작업트리 clean. 제품 구현·검증과 실제 앱 반영은 완료됐으며 추가 인증·사용자 승인 대기 없음.

## 먼저 읽을 파일

[ROADMAP](./ROADMAP.md), [M3 상태](./features/20260817-001-extended-resource-monitoring/README.md), [M4 상태](./features/20261003-001-app-preferences/README.md), [실제설치근거](./features/20261003-001-app-preferences/evidence/task-016/installed-release/README.md). Phased 후속 진행은 ~/.codex/skills/implement-loop/SKILL.md·implement/SKILL.md·verify/SKILL.md 및 ~/.codex/docs/phased-state.md를 따릅니다. 승인 상태·문서 적용은 main 소유입니다.

## 문서 반영 필요

없음.
