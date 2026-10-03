# 사용자 설정과 로그인 시 실행

## 개요

M4의 첫 범위로 카드·TOP 5 표시, 그래프 시간 범위, 갱신 4단계,
로그인 자동 실행과 기본값 복원을 제공합니다. 설정은 즉시 반영되고 재실행 후 유지됩니다.
사용자가 권장 범위를 선택했으며 추가 표시·일반 설정과 캐릭터·애니메이션은 후속 범위입니다.

## 상태

- [x] SPEC
- [x] DESIGN
- [ ] IMPLEMENT

## 문서

- [spec.md](./spec.md)
- [design.md](./design.md)
- [implement.md](./implement.md)

## 이력

- 2026-10-03: 사용자 `$spec-init m4`와 “권장” 범위 선택을 반영해 SPEC을 작성했습니다.
  ROADMAP·제품 정의·기술 설계와 HEAD0b01a9b의 현재 원본을 입력으로 사용했고,
  SPEC §5.1~§5.13을 부여했습니다. SPEC [x], DESIGN/IMPLEMENT [ ]이며 제품 코드·실행 검증은 수행하지 않았습니다.
  M3의 보류 task014/015는 M4 착수를 막지 않는 예외로 기록하며 기존 승인·미완료 상태를 유지합니다.
  새 기능 문서이므로 취소할 하위 승인은 없습니다. 이번 요청은 SPEC까지만입니다.
- 2026-10-03: 사용자 `$design-init M4`에 따라 analyzer의 읽기 전용 후보를 main이
  승인된 SPEC·HEAD e78af7f의 원본·로컬 공개 SDK에 대조해 설계를 확정했습니다.
  SPEC §5.1~§5.13의 책임·흐름·인터페이스·검증 관문과 내부 결정 DP1~DP8을 연결했습니다.
  단일 설정창, 일반 설정/실제 로그인 상태 분리, 프로필·저전력 병합,
  실제 단일 조회 실행권, 당시 주기에 따른 허용 간격과 1203개 이력,
  표시 숨김의 자연 높이·현재 앵커를 채택했습니다. 미채택 결정은 없습니다.
  SPEC [x], DESIGN [x], IMPLEMENT [ ]입니다. SPEC 의미와 기존 M3 승인은 유지하며
  신규 설계이므로 취소할 하위 승인은 없습니다. 제품 코드·실행 앱·로그인 등록은 변경하지 않았습니다.
  문서 형식·SPEC 연결·로컬 링크·변경 범위를 확인했고 구현·실제 로그인 검증은 후속 관문입니다.
  이번 요청은 DESIGN까지만입니다.
- 2026-10-03: 사용자 `$implement-init M4`에 따라 analyzer의 읽기 전용 후보를 main이
  승인된 SPEC·DESIGN과 HEAD3f8f075의 원본·기존 검증 파일에 대조해 구현 계획을 확정했습니다.
  task-001~task-011의 목적·접근·선행 의존·검증 결과/확인·참조를 작성하고
  SPEC §5.1~§5.13과 DESIGN 내부 결정 DP1~DP8을 연결했습니다.
  실제 mainApp 등록·해제·다음 로그인은 마지막 독립 관문이며 환경·권한·증거가 없으면 승인하지 않습니다.
  계획만 작성했으므로 모든 Task와 IMPLEMENT는 [ ]입니다. SPEC/DESIGN [x]와 기존 M3 승인은 유지합니다.
  신규 Task이므로 취소할 Task 승인이나 이전 reject는 없습니다. 상위 계약의 추가 결정은 필요하지 않습니다.
  Task 순서·참조·조건 매핑·문서 링크·변경 범위를 확인했고 제품 코드·실행 앱·OS 상태는 변경하지 않았습니다.
  이번 요청은 구현 계획까지만입니다.
- 2026-10-03: 사용자 `$implement-loop M4`에 따라 task-001을 worker가 구현하고 독립 verifier가 승인 후보를 반환했습니다. main은 엄격한 설정 복구·단일 snapshot 저장/게시·개인정보 경계와 현재 소스/검증 해시 대응을 확인해 승인했습니다. 전용 signed 단위5/5 통과, loop 재시도·근거 재검증0입니다. SPEC/DESIGN [x], IMPLEMENT [ ]; task-002~011 미완료입니다. 상위 계약·M3 승인은 유지됩니다.
- 2026-10-03: task-002의 47개 관련 case와 최종 Scheduler14개는 통과했으나 독립 verifier가 A→B→A target 역순의 최신 revision 미적용을 correctness로 거절했습니다. main이 reject를 확정하고 구현 소유 재시도1을 요청합니다. task-002 [ ]·후속 Task 미착수, 근거 재검증0입니다. 승인된 task-001과 상위 계약·M3 승인은 영향 없어 유지합니다.
- 2026-10-03: task-002 correctness 재시도1에서 두 Scheduler의 적용 plan revision 검사를 보완하고 역순 실행·캐시·pending 회귀3개를 추가했습니다. 독립 verifier의 approved를 main이 확정했습니다. 관련7suite50case(동적56실행)·실패/skip0, 현재 소스·패치·로그 해시 대응 확인. task-001/002 [x], task-003~011 [ ], IMPLEMENT [ ]입니다. 근거 재검증0이며 이전 reject는 이력으로 보존하고 현재 필드에서는 제거했습니다. 상위 계약과 영향 없는 승인은 유지합니다.

- 2026-10-03: task-003의 당시 주기 G·실제 경과 차분·1203개 링과 연속성 표식을 독립 verifier approved 후 main이 승인했습니다. 관련86case(동적94실행)·Memory6case(동적17실행), 실패/skip0과11파일 해시 대응 확인. 구현 재시도0·근거 재검증0. task-001~003 [x], task-004~011 [ ], IMPLEMENT [ ]입니다. 상위 계약·기존 승인은 유지합니다.

- 2026-10-03: task-004의 actual status adapter·단일 mutation/최신 의도·operation ID·일반 복원/로그인 결과 분리를 독립 verifier approved 후 main이 승인했습니다. signed 주입7/7·실패/skip0, 새3파일 해시 대응 확인. 구현 재시도0·근거 재검증0. 실제 OS mutation 없음. task-001~004 [x], task-005~011 [ ], IMPLEMENT [ ]이며 상위 계약·기존 승인은 유지합니다.

- 2026-10-03: task-005의 동일 저장 snapshot 초기 배선·현재 revision 통지·프로필 변경 전달·활성화 status 읽기를 독립 verifier approved 후 main이 승인했습니다. 기존 전체600초/상세 모델을 유지하고 현재 snapshot으로 선별하는 내부 접근 차이를 목적/조건 의미 유지로 판단해 계획에 반영했습니다. signed42case·실패/skip0·8파일 해시 대응 확인. 구현 재시도0·근거 재검증0, task-001~005 [x], task-006~011 [ ], IMPLEMENT [ ]. 영향받은 설정 저장 회귀도 통과했고 기존 승인은 유지합니다.

- 2026-10-03: task-006의 공통1/5/10분 구간/축/진행/AX·당시G/연속성 연결·가시 극값과 기본표현 보존을 독립 verifier approved 후 main이 승인했습니다. 내장 역할 재호출/신규 호출이 agent thread 제한으로 실패해 동일 gpt-6-sol/high 읽기 전용 verifier를 로컬 CLI로 실행했습니다. 최종 signed serial86case(동적90실행)·실패/skip0,9파일 해시/패치 대응 확인. 불완전한 이전 번들은 근거에서 제외했습니다. 구현 재시도0·근거 재검증0. task-001~006 [x], task-007~011 [ ], IMPLEMENT [ ]이며 기존 승인은 유지합니다.

- 2026-10-03: task-007 worker가 카드/TOP5 조건부 표시·자연 높이·선택 정리와 검증10파일을 부분 구현하고 blocked로 반환했습니다. 최종 signed 단위40/40·6suite/64렌더조합 통과, UI는 두 번 모두 본문 전 LocalAuthentication Code=-4 “System authentication is running”으로 차단됐습니다. main은 현재 권한에서 인증/TCC를 조작하지 않고 환경 해소 뒤 같은 UI 실행·독립 verify를 재개 조건으로 기록했습니다. task-007 [ ]·코드 미커밋, task-008~011 미착수, IMPLEMENT [ ]입니다. loop 재시도/근거 재검증0, verifier 판정 없음. 승인001~006·상위 계약·M3 상태는 유지합니다.
