# Network·Disk 확장 리소스 모니터링

## 개요

Network·Disk의 현재 속도, 최근 10분 그래프와 인터페이스·장치·볼륨 정보를 추가합니다.
CPU·Memory와 함께 네 카드를 지원 화면에서 일관되게 사용할 수 있도록 본체 배치와 수집 경계를 확장합니다.

## 상태

- [x] SPEC
- [x] DESIGN
- [ ] IMPLEMENT

## 문서

- [spec.md](./spec.md)
- [design.md](./design.md)
- [implement.md](./implement.md)

## 이력

- 2026-08-17: SPEC 작성. 물리 인터페이스 합계·VPN 터널 상세 전용, 프로세스별 Disk I/O 제외를 확정했습니다.
- 2026-10-01: M2 core-resource-monitoring 완료 후 기존 디렉터리에서 SPEC을 갱신했습니다. 완료 조건 §5.1~§5.15의 번호를 보존하고, 작은 화면의 네 카드 접근(§5.16), 최신 공통 그래프 판 규칙(§5.17), 조건부 연결 속도·IOPS(§5.18)를 추가했습니다. 수집 중지 경계·느린 보조 조회·실패·연결 상태의 의미도 현재 선행 계약에 맞췄습니다. 오래된 카드 넷의 세로 공간 설명을 현재 ROADMAP·원본 기준으로 대체하고 `ANALYSIS`를 `DESIGN` 상태로 옮겼습니다. 확정된 범위·제약과 VPN 합산·Disk 제외 결정을 유지하므로 SPEC `[x]`를 유지합니다. 기존 DESIGN·IMPLEMENT 승인과 Task 문서는 없어 취소할 하위 승인은 없으며, 두 상태는 `[ ]`입니다. 이번 요청 범위는 SPEC 갱신까지입니다.
- 2026-10-01: analyzer의 전체 설계 후보를 현재 SPEC·원본과 대조해 적용했습니다. 완료 조건 §5.1~§5.18을 모두 매핑하고 DP1~DP7을 채택해 DESIGN `[x]`로 전환했습니다. Network·Disk 활동과 메타데이터의 네 독립 수집 축, 물리 대상 집계와 중복 제거, 중지 경계·늦은 결과 차단, 두 계열 그래프와 단일 열 세로 스크롤을 확정했습니다. SPEC 변경과 미채택 결정은 없으며 기존 M3 Task·IMPLEMENT 승인이 없어 취소 대상도 없습니다. 제품 코드와 기존 M2·표시 개선 계약은 변경하지 않아 해당 승인을 유지합니다. 구현 단계에서는 CPU·Memory 회귀 검증과 실제 Sandbox·VPN·외장 장치·작은 화면 관문을 수행해야 합니다. SDK 조사와 Sandbox 밖 읽기 전용 probe는 실제 배포 조건 검증을 대신하지 않습니다. IMPLEMENT는 `[ ]`이며 이번 요청 범위는 DESIGN까지입니다.

- 2026-10-01: `implement-init`에서 analyzer의 전체 후보를 현재 SPEC·DESIGN·원본과 대조해 신규 implement.md에 적용했습니다. task-001~task-018의 목적·접근·결과·확인·참조와 SPEC §5.1~§5.18의 전체 매핑을 작성했습니다. 실제 Sandbox native adapter 관문을 앞에 두고 수집 경계·일정·리소스 수집·배선·표시·그래프·카드·화면·접근성·실제 전환·시스템 도구 비교·회귀 순서를 고정했습니다. SPEC·DESIGN 의미 변경이나 기존 Task·승인 취소는 없습니다. 선행 SPEC·DESIGN과 기존 M2 승인을 유지하고 신규 Task 18개와 IMPLEMENT는 모두 `[ ]`로 둡니다. 제품 코드·실행 검증은 수행하지 않았으며 이번 요청 범위는 Task 문서 작성까지입니다.

- 2026-10-01: `implement-loop M3`의 task-001 구현 완료 후보와 테스트 6개 통과 근거를 인수했습니다. 초기 XCTest 호스트의 임시 Sandbox 예외를 발견해 테스트와 분리한 build-only 앱으로 관문을 재확인했습니다. 최종 앱에는 새 예외가 없고 물리 Wi-Fi 카운터·주소·provider·Link Active를 확인했으며 미확정 대상·불완전성은 보존합니다. 그러나 독립 verifier 호출이 `agent thread limit reached`로 반복 실패해 최종 판정 전 중단했습니다. SPEC·DESIGN 승인을 유지하고 task-001~018 및 IMPLEMENT는 `[ ]`이며 승인 취소나 최종 reject는 없습니다. 사용자의 Task별 승인 후 커밋 지시에 따라 아직 커밋하지 않았습니다. 재개 지점은 현재 코드·evidence/task-001의 독립 verify이며, 승인되면 커밋 후 task-002로 진행합니다.

- 2026-10-01: 새 세션에서 task-001 독립 verify 호출이 성공했고 main이 approved로 확정했습니다. 현재 소스 해시와 테스트 6개·임시 예외 없는 build-only Sandbox 실행 원자료를 대조했습니다. task-001만 `[x]`로 전환하며 SPEC·DESIGN 승인과 나머지 Task를 유지합니다. 완료 조건의 마지막 매핑 Task는 없어 IMPLEMENT는 `[ ]`입니다. 선행 문서와 task-001을 첫 커밋에 포함한 뒤 task-002를 진행합니다.

- 2026-10-01: task-002 독립 verify approved를 확정했습니다. 필수 물리 Disk 바이트·Operations·시스템 용량·APFS 관계의 실제 Sandbox 근거, 결정적 Disk 7개·Network 6개 테스트와 현재 소스 해시를 확인했습니다. Network 격리 선언 보완의 영향은 verifier의 같은 빌드 probe 재실행으로 회귀 없음을 확인해 task-001 승인을 유지합니다. task-002만 `[x]`, 나머지 Task와 IMPLEMENT는 `[ ]`로 유지하며 커밋 후 task-003으로 진행합니다. 요구사항·설계·완료 기준 변경과 승인 취소는 없습니다.
