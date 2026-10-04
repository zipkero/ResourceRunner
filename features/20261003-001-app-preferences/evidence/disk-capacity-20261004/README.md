# macOS 기준 Disk 용량 수정 승인 근거

2026-10-04 main 최종 판정: **approved**. 사용자 선택 「macOS 기준으로 맞추기 — 회수 가능한 공간 포함」과 M4 DESIGN §3.6·SPEC §5.13을 기준으로 지정 9파일을 승인했습니다. 검증 기준 HEAD `df90292`, 설정창 분리 커밋 `3af86df`의 변경과 겹치지 않습니다. 현재9파일 SHA-256과 patch 역방향 검사, 실제 로그·summary 및 독립 판정을 대조했습니다.

| 승인 기준 | 근거 | 결과 |
| --- | --- | --- |
| 저장 공간만1000 기반, 속도·누적량·Memory 단위 유지 | ResourceQuantityFormatter·단위/로케일 경계 사례·changes.patch | 충족 |
| root/로컬 볼륨의 important-usage available·엄격 검증·기존 실패/과거 캐시 | DiskNativeAdapter·관련48case·실제 Sandbox UI | 충족 |
| 카드/상세/AX 정의·값 일치,112pt/noScroll/상세 복귀frame | ui.log / ui-summary.json의 새 단일 UI1/1 | 충족 |
| privacy manifest 번들 포함·권한/Helper/export 변화 없음 | PrivacyInfo·두 Release 빌드와 독립 판정·patch | 충족 |

기존 signed 관련 단위48/48·실제 Sandbox UI1/1은 실패/skip0, Release build는 성공했습니다. 관찰 시각의 `/` 원시 전체994662584320·important available818551316339는994.7GB/818.6GB로 표시됐습니다. 같은 시각 raw available808559210496와 구분되며, 이전 사용자 스크린샷의 사용 가능 값과 정확히 같을 것을 요구하지 않습니다. 사용 중은 전체−사용 가능이며 실제 파일 점유량·APFS 볼륨별 독점 사용량으로 주장하지 않습니다.

[독립 판정과 M3 영향 분석](./verifier-result.md), [소스 해시](./source-sha256.txt), [patch](./changes.patch), [단위 summary](./unit-summary.json), [UI summary](./ui-summary.json). 단위 명령은 unit.log, UI 명령은 ui.log, Release 명령은 release-final.log에 기록됐습니다. 승인 기록 과정에서 suite·UI·빌드를 재실행하지 않았습니다.

이 Per-Request 승인은 M3의 취소6개 Task를 자동 복구하지 않습니다. 기존 독립 영향 분석과 이 현재 근거를 사용한 개별 승인 기록이 남아 있습니다. M4 task010은 이 용량 근거를 인수하며 실제 다음로그인·M3 보류 검증을 완료 처리하지 않습니다.

사용자 요청으로 임시 앱과 빌드는 정리했습니다. 원본 xcresult·실패 이력은 로컬 `.git/codex-cleanup/20261004-m4/verification-evidence.tar.gz`, 요약·최종 로그·patch/판정은 이 폴더에 보존합니다. 과거 `/tmp` 경로는 실행 당시 경로입니다.
