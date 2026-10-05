# Context

저장: 2026-10-05 (ROADMAP 마일스톤 체크리스트 반영)

## 현재 목표

설정 화면(task-009)·Disk 수정은 main에 분리 커밋·푸시 완료했다(3af86df/1180810). 현재 요청의 ROADMAP 체크박스와 승인된 완료 항목을 반영했다. 후속 구현은 진행 요청에 따라 재개하며 이번 문서 변경으로 Task 상태를 바꾸지 않는다.

## 현재 상태

- branch main, 검증 기준 HEAD df90292a0ae1cac69cc642f60f05fc1a4d555ff7, 설정창 커밋3af86df. Disk 승인 기록과 코드는 커밋1180810으로 origin/main에 반영했다. M4 SPEC/DESIGN [x], IMPLEMENT [ ]; task001~009 승인,010/011 미착수.
- task009 main approved. 현재9파일 SHA/patch 대응과 기존 signed 단위46/46·Debug UI18/18·격리 Release UI1/1·Release build를 확인했다. 키보드는 native 컨트롤과 동일값 순환 버튼/단축키 경로로 검증했고 실제 OS mutation은 하지 않았다. 근거는 evidence/task-009. loop 재시도0·근거 재검증0; 이번에 신규 SPEC 전체 완료 없음.
- 별도 Disk Per-Request 9파일 구현/기존 단위48/48·Sandbox UI1/1·Release build·독립 approved 후보와 현재 소스 대응을 확인했다. main 최종 approved를 확정하고 승인 기록을 남겼다. 근거는 evidence/disk-capacity-20261004/README.md. 테스트 재실행은 없었다.
- M3 용량 개정으로 취소된 task002/006/008/011/013/018은 개별 승인 복구 기록이 아직 없다. 독립 Disk 판정의 영향 분석은 확보돼 있다. 나머지 승인·task009 철회·task014/015 사용자 보류는 유지한다.
- 내장 verifier thread 제한으로 동일 gpt-6-sol/high 읽기 전용 역할을 로컬 Codex CLI로 수행했고 main이 최종 판정했다. 과거 loop correctness 보완은002/007 각1회, 근거 재검증0이며 현재 reject는 없다.
- 임시 앱/테스트 러너 종료 완료. rr-m4-*와 rr-macos-capacity*281항목을 정리해 약4.92GB 확보했다. 원본 xcresult/실패 이력은 로컬 .git/codex-cleanup/20261004-m4/verification-evidence.tar.gz(4.09GB)에 보존하며 Git 추적/푸시하지 않는다. 과거 /tmp 경로는 현재 존재하지 않는다. 필요한 원본만 임시 경로로 추출하며 통과한 전체 suite를 재실행하지 않는다.

## 현재 작업 문서

- [M4 상태](./features/20261003-001-app-preferences/README.md)
- [SPEC](./features/20261003-001-app-preferences/spec.md), [DESIGN](./features/20261003-001-app-preferences/design.md), [구현 계획](./features/20261003-001-app-preferences/implement.md)
- [설정창 근거](./features/20261003-001-app-preferences/evidence/task-009/README.md)
- [Disk 승인 근거](./features/20261003-001-app-preferences/evidence/disk-capacity-20261004/README.md)

## 확정된 결정

- 기본 무스크롤/가독성·Memory 자연높이·Network 그래프 없음·Disk 미니 그래프·TOP5 여백을 유지한다.
- Disk 저장 공간만1000 기반+important-usage available(회수 가능한 공간 포함). 다른 지표 단위는 유지한다. 승인된 현재 정의는 M4 DESIGN §3.6.
- 기존 검증은 현재 소스 대응 범위에서 재사용하고 새/실패 영향 사례만 실행한다. 새 넓은 영향 근거 없이는 전체 suite를 반복하지 않는다. 테스트 종료 후 소유 앱 잔존을 확인한다.
- 실제 mainApp 등록·해제·다음 로그인은011. 안정 경로/동일 bundleID/서명 근거가 필요하며 로그아웃·재부팅은 당시 별도 승인 범위에서만 수행한다. mock/status/수동 실행으로 대체하지 않는다.
- 기존 Task012 stash0ef806c85321a92c7a07226de4b0080a7cc1eb48은 구치수라 전체 적용하지 않는다.

## 미확정 판단

두 변경의 최종 판정과 승인 기록은 확정했다.010 통합과011 실제 로그인 근거, M3 취소6개Task 개별 복구는 미완료다.

## 다음 작업

- 작업: 후속 진행 요청에 따라 task010의 미확인 통합 경계를 진행한다. Disk 근거와 독립 영향 분석으로 M3 취소6개Task를 각각 검토·승인 기록한다.
- 완료 기준: 기존 통과 결과를 현재 소스 대응 범위에서 재사용하고 설정 변경→재실행 최초 적용→복원의 미확인 경계만 새로 확인한다. 실제 native 로그인·세션 영향과 M3 보류 검증은 별도 관문을 유지한다. 설정·Disk 승인/커밋 요청과 이번 ROADMAP 체크리스트 요청은 완료했다.

## 먼저 읽을 파일

- M4 spec.md/design.md/implement.md와 두 evidence 폴더의 README/patch/SHA/독립 판정.
- ~/.codex/skills/verify/SKILL.md, ~/.codex/docs/phased-state.md, ~/.codex/skills/context-save/SKILL.md.

- ROADMAP 현재 상태에 M1~M5 체크박스와 완료/잔여 항목을 추가했다. M1 전체만 체크했고 M2~M4의 승인된 하위 항목을 체크했다. SPEC/DESIGN/Task 승인 의미·전체 미완료·보류는 유지하며 새 테스트를 실행하지 않았다.

## 문서 반영 필요

제품 전체 통합 후 상위 docs/product.md·docs/design.md의 현재 구현 설명을 task010 단계에서 갱신한다. 승인된 feature 원본이 현재 정의를 소유한다.
