# task-009 승인 근거

2026-10-04 main 최종 판정: **approved**. 기준 HEAD `df90292a0ae1cac69cc642f60f05fc1a4d555ff7`, 프로젝트 루트 `/Users/zipkero/XcodeProjects/ResourceRunner`.

단일 설정창과 우클릭·⌘,·전체 숨김 진입, 명시적 활성화·창 재사용, 네 카드·두 TOP 5·그래프 범위·갱신 프로필, 실제 로그인 상태 표시와 복원 결과 분리, 키보드·AX·설정창 포커스 보호를 승인했습니다. Task 조건과 SPEC/DESIGN 원본을 독립 판정에 대조하고 대상 9파일의 SHA-256 및 patch 역방향 검사를 다시 확인했습니다. 별도 Disk 수정은 이 Task 판정 범위에서 제외합니다.

| 근거 | 기존 실제 결과 | 범위 |
| --- | --- | --- |
| unit-summary.json / unit.log | 46/46, 실패·skip 0 | 창·로그인 adapter·설정·coordinator·status·표시·viewport |
| ui-summary.json / ui.log | 18/18, 실패·skip 0 | 실제 Debug UI의 접근·설정·복원·키보드·AX·포커스 |
| release.log | 서명된 arm64 Release build 성공 | 최종 숫자9 단축키 포함 |
| release-ui-summary.json / release-ui.log | 1/1, 실패·skip 0 | 격리 Release 복사본의 우클릭·단일창·닫힘 |

최종 로그인 단축키 변경은 UI·Release 근거에 포함됐으며, 해당 변경과 무관한 단위 테스트는 반복하지 않았습니다. 기본 macOS Tab 순회의 Picker 직접 조작 대신 같은 값을 선택하는 인접 native 버튼·단축키의 키보드 경로를 확인했습니다. 실제 로그인 mutation은 주입 adapter로 대체했고 OS 등록·다음 로그인 성공을 주장하지 않습니다. Release 복사본은 테스트 전용 bundle ID로 재서명했으며 원본과 같은 실행 파일 UUID/해시 근거를 보존했습니다.

[독립 판정](./verifier-result.md), [worker 결과와 실패 이력](./worker-result.md), [패치](./changes.patch), [소스 해시](./source-sha256.txt). 내장 verifier의 thread 제한에 따라 동일 읽기 전용 역할을 로컬 Codex CLI로 수행했습니다. main이 최종 상태를 확정했으며 구현 재시도0·근거 재검증0입니다. 이번 승인으로 마지막 매핑이 끝나는 SPEC 조건은 없습니다. task-010/011과 IMPLEMENT 전체는 미완료입니다.

임시 리소스는 사용자 요청으로 정리했습니다. 최종 로그·summary·판정은 이 폴더에 있고 원본 xcresult와 실패 이력은 로컬 `.git/codex-cleanup/20261004-m4/verification-evidence.tar.gz`에 압축 보존했습니다. 과거 `/tmp` 경로는 실행 당시 경로입니다. 승인 기록 과정에서 테스트·빌드를 재실행하지 않았습니다.
