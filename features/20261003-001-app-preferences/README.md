# 사용자 설정과 로그인 시 실행

현재 상태: 기존001~011과 확장012~016을 모두 독립 승인했습니다. 적용 SPEC16개 조건이 성립하여 IMPLEMENT [x]입니다. task014 카드 AX 설명 결함도 보완·재승인했습니다. 실제 설치 경로에도 최종 Release를 반영했고 새 기본 설정·로그인 허용 상태를 읽기 전용 UI1/1로 확인했습니다. 아래 후보 작성 중 설명은 이전 단계 이력입니다.

- 2026-10-09: 사용자 후속 요청으로 시스템 프로세스 포함·상세10/20/50개·외부 상호작용 자동 닫기 설정을 SPEC §5.14~16에 추가했습니다. 기존 기본값을 보존하고 저장·재실행·이전 payload·복원·키보드/AX를 포함합니다. SPEC [x], 확장 DESIGN 후보 작성 중으로 DESIGN/IMPLEMENT [ ]입니다. 기존001~011 승인과13조건의 기본 계약은 유지하며 새 요구사항의 구현 완료를 주장하지 않습니다. 캐릭터/애니메이션·업데이트는 이번 범위에서 제외합니다.
## 개요

M4의 첫 범위로 카드·TOP 5 표시, 그래프 시간 범위, 갱신 4단계,
로그인 자동 실행과 기본값 복원을 제공합니다. 설정은 즉시 반영되고 재실행 후 유지됩니다.
사용자가 권장 범위를 선택했으며 추가 표시·일반 설정과 캐릭터·애니메이션은 후속 범위입니다.

## 상태

- [x] SPEC
- [x] DESIGN
- [x] IMPLEMENT

## 문서

- [spec.md](./spec.md)
- [design.md](./design.md)
- [implement.md](./implement.md)

## 이력

- 2026-10-09: main이 승인된 최종 Release를 같은 실제 설치 경로에 반영했습니다. 앱 디렉터리 inode·일반 설정 보존, strict 서명·원본검증SHA 대응을 확인하고 실제 설치 앱의 새 기본값0/20/1 및 native 로그인 허용 상태를 읽기 전용 UI1/1로 확인했습니다. 새 PID59351로 실행 중이며, 등록/해제·로그아웃은 수행하지 않았습니다. [실제 반영 근거](./evidence/task-016/installed-release/README.md).

- 2026-10-09: task016 독립 approved를 main이 확정했습니다. 현재SHA/patch·원본690/690·실제UI21/21·fixture1/1·고유Release1/1·서명과 actual9→12키payload로 추가설정과 기존기본계약을 확인했습니다. 적용Task001~016 모두[x], 전체SPEC조건성립으로 IMPLEMENT[x]입니다. task016 구현/근거재검증0회, 별도014 AX보완1회/근거재검증0회 이력 유지. 설치 앱 반영은 main이 별도 기록합니다.

- 2026-10-09: 최종016 실제AX에서 발견한 task014 카드 포함 범위 설명 결함을 수정했습니다. 현재2파일SHA/patch·signed17/17·실패/skip0을 독립 verifier/main이 재승인했습니다. 정상/실패/중지 현재 설명·TOP5고정/숨김을 확인했고 구현 보완1회·근거재검증0회입니다. 실제AX와 최종 Release는016에서 이어갑니다.

- 2026-10-09: task015 독립 approved를 main이 확정했습니다. 현재7파일SHA·단위41/41·고유UI5/5·상세scroll1/1·Release/서명으로 최초/current behavior·stalecallback/identity/delegate/일정·Escape상세우선/명시닫기·키보드/AX/설정key보호를 확인했습니다. 기본Tab의Toggle제외와initialAX childfocus 진단은 실제shortcut·AppKit key원시근거와 구별하며 최종계측제거를 확인했습니다. 구현 재시도0·근거 재검증0. 최종016실제관문 진행·IMPLEMENT[ ].

- 2026-10-09: task014 독립 approved를 main이 확정했습니다. 현재12파일SHA·원본94/94·고유UI8/8+최종설정1/1·Release/서명으로 즉시자료선택·정원·TOP5/하위목록·빈/older/newEpoch/lastKnown 및 키보드/AX를 확인했습니다. 기존 native복귀 펼침 기대값은 유지하고 설정필터/정원만정리합니다. 초기cwd오류·Release테스트타깃실패는 제외이력, 구현 재시도0·근거 재검증0. 015/016 진행·IMPLEMENT[ ].

- 2026-10-09: task013 독립 approved를 main이 확정했습니다. UID소속/단절·필터 후 두순위·실패범위·최신cache/admission/역순과 기본제외20을 현재10파일SHA/patch, 원본집중92/92·격리전체679/679·Release/서명으로 대조했습니다. 구현 재시도0·근거 재검증0, 전체SPEC완료조건 없음. 다음014 즉시표시/두설정UI 진행, IMPLEMENT[ ] 유지.

- 2026-10-09: 새task012 독립 approved를 main이확정했습니다.3파일SHA/patch·signed10/10과 이전payload/타입오류/세정원/12키/한snapshot 복원·저장계약충족. 기존001~011승인유지·013~016미승인·IMPLEMENT[ ]. 구현재시도0/근거재검증0.

- 2026-10-09: main이 implement-init analyzer 후보의 새 task012~016을 승인 SPEC/DESIGN에 대조해 적용했습니다. additive 저장→소속/두 자료→즉시 표시/두 UI→자동 닫기→실제 상호작용/재실행 회귀 순서이며 새16조건·DP10~13 매핑과 집중 명령을 확정했습니다. 기존001~011 승인 유지, 신규012~016 미승인으로 IMPLEMENT [ ]. 추가 사용자 결정 없음.

- 2026-10-09: main이 승인 SPEC 확장의 analyzer 후보 DP10~DP13을 현재 원본에 대조해 설계에 적용·승인했습니다. additive 저장·조사 시점 UID 소속·두 표시 자료·즉시 현재 선택·필터 후10/20/50 정원·본체 behavior/Escape와 실제 검증 관문을 확정했습니다. 기존001~011 기본 계약 승인 유지, IMPLEMENT 확장 분해 중입니다. M3 task015도 최신 사용자 지시로 재개하며 다른 계정 전환 실시험만 제외합니다.

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

- 2026-10-04: 사용자 UI 재실행 요청으로 task-007을 재개했습니다. 첫 runner automation timeout 뒤 실제UI2개 중1개에서 전체 숨김 부모 AX식별자 전파가 버튼ID를 가린 것을 발견해 worker가 수정했습니다. 최종 signed UI2/2·단위40/40/6suite·64실제렌더 조합·실패/skip0, 전체10파일 소스/패치/실행 대응을 독립 verifier가 approved로 반환했고 main이 확정했습니다. 내장 verifier agent thread 제한으로 동일 gpt-6-sol/high 읽기 전용 역할을 로컬CLI로 적용했습니다. UI correctness 보완1회·근거 재검증0, 이전 차단/실패 이력 유지. task-001~007 [x], task-008~011 [ ], IMPLEMENT [ ]. SPEC 전체 조건 신규 완료 없음·기존 승인/M3 상태 유지. 이번 요청은 UI 검증·수정·승인까지입니다.

- 2026-10-04: 사용자 “진행해”로 남은 loop를 재개해 task-008을 승인했습니다. 현재 표시 조합의 포커스/고정 단축키/마지막 앵커와 Memory 실제높이 보정, 지연 stale 거부를 구현했습니다. signed 단위46/46·UI17/17·실패/skip0·7파일 SHA/patch 대응을 독립 verifier와 main이 확인했습니다. 동일 읽기 전용 verifier를 thread 제한에 따라 로컬CLI로 수행했습니다. 구현 재시도0·근거 재검증0. task-001~008 [x], task-009~011 [ ], IMPLEMENT [ ]. 신규 SPEC 전체 완료 없음·기존 승인/M3 상태 유지. 다음은 단일 설정창009이며 실제 다음 로그인은011입니다.

- 2026-10-04: 사용자 「macOS 기준으로 맞추기 — 회수 가능한 공간 포함」 선택을 spec-init/읽기 전용 analyzer 후보의 design-init으로 반영했습니다. Disk 저장 공간만1000 기반·important-usage available로 변경하며 다른 지표 단위는 유지합니다. 누락/실패는 기존 보조 실패, privacy reason85F4.1을 선택했습니다. SPEC/DESIGN [x], IMPLEMENT [ ]. task001~008/009 설정 계약은 영향 없어 유지하며 미승인010의 현재회귀 기준에 예외를 연결했습니다. Task 추가/순서/목적 변경 없음. M3 용량 관련002/006/008/011/013/018은 취소 후 새 근거로 개별 verify합니다. 제품 수정/새 용량 검증은 아직 수행하지 않았습니다.

- 2026-10-04: 사용자 “1번하고”에 따라 task-009의 최종 승인 기록을 확정했습니다. 현재9파일 SHA/patch와 기존 signed 단위46/46·Debug UI18/18·격리 Release UI1/1·Release build를 독립 판정에 대조했습니다. 테스트를 다시 실행하지 않았고 로그인 단축키 변경과 무관한 단위 근거는 재사용했습니다. 단일 설정창·모든 접근·현재 설정/로그인 상태·오류/복원·키보드/AX·포커스를 승인했습니다. task001~009 [x],010/011 [ ], IMPLEMENT [ ]; 신규 SPEC 전체 완료 없음. 실제 OS mutation/다음로그인은011입니다. 구현 재시도0·근거 재검증0. 별도 Disk 변경은 다음 분리 커밋의 승인 기록으로 처리합니다.

- 2026-10-04: main이 별도 Disk 용량 Per-Request의 독립 approved 후보를 최종 확정했습니다. 사용자 승인 정의에 따라 저장 공간1000 기반·important-usage available·실패/과거캐시·상세/AX·privacy manifest를 승인했고9파일 SHA/patch·기존 단위48/48·실제 Sandbox UI1/1·Release build를 대조했습니다. 테스트를 다시 실행하지 않았습니다. [Disk 승인 근거](./evidence/disk-capacity-20261004/README.md)를010에 연결합니다. task001~009 [x],010/011 [ ], IMPLEMENT [ ]는 유지합니다. M3 취소6개Task의 개별 승인 복구·014/015 보류를 이 Per-Request로 자동 완료하지 않습니다. 이번 요청은 두 변경의 승인 기록·분리 커밋·main 푸시까지입니다.

- 2026-10-09: 사용자 task-010 진행 요청으로 재실행 통합 UI와 최초 일정/apply 횟수 단언을 보강했습니다. signed 관련 단위24/24·UI1/1·Release build 통과 후 독립 verifier가 실제 앱 최초 scheduler apply 관찰 부족을 `evidence`로 반환했고 main이 reject를 확정했습니다. task-010 [ ]·IMPLEMENT [ ], 기존 승인001~009와 M3 상태 유지. 기존 DEBUG 로그의 최종 UI PID·시각·실제 Swift dylib UUID를 대조해 최초 적용 계획을 보완하며 구현 재시도0·근거 재검증1입니다. suite 재실행·native 로그인 mutation 없이 같은 근거로 재판정합니다.

- 2026-10-09: task-010의 실제 scheduler 첫 적용 부족분을 기존 최종UI의 unified log로 보완하고 독립 verifier approved를 main이 최종 확정했습니다. signed 단위24/24·UI1/1·Release build,24소스 SHA/patch, 앱PID·초기 lifecycle·DEBUG dylib UUID/SHA 대응 확인. 저장 매우 절전으로 재실행한 실제 네 scheduler의 첫 apply10초, 복원 후 재실행 기본2초/process5초를 확인했습니다. 상위 docs/product.md·docs/design.md의 설정·Disk·프로필/생명주기·1203링 설명을 현재 승인 정의와 원본으로 동기화했습니다. task001~010 [x],011 [ ], SPEC/DESIGN [x], IMPLEMENT [ ]; 마지막 매핑이 완료된 SPEC §5.1~§5.8 성립. 구현 재시도0·근거 재검증1, 이전 evidence reject 이력 유지/현재 reject 해소. 기존 승인과 M3 취소6개·014/015 보류 유지. 실제 native mutation·다음로그인은 수행하지 않았습니다. 이번 요청은 task-010까지입니다.

- 2026-10-09 task-011: 2026-10-09 독립 verifier `rejected / evidence`를 main이 확정했습니다. 실제 초기 읽기·등록/해제/복원·외부 OS 변경 재조회·다음 로그인 준비와9파일 SHA/고정 Release 서명 대응은 모두 충족입니다. SPEC §5.9·§5.11~§5.13 성립, §5.10은 실제 다음 로그인 자동 실행 관찰이 없어 미확인입니다. 구현 재시도0·근거 재검증0이며 task-011/IMPLEMENT [ ] 유지합니다. 다음 로그인 후 수동 launch 없이 PID·시작 시각·실행 경로·로그인 실행 출처·설정창/대시보드 비자동 열림을 확인해야 재판정할 수 있습니다. 사용자에게 별도 세션 전환 승인 또는 직접 로그아웃/로그인 후 알림을 요청했고 아직 응답 전입니다. `sfltool`의 인증 요구 조회는 더 호출하지 않습니다.

- 2026-10-09: 사용자 명시적 자동 로그아웃 승인 후 재로그인 근거로 task-011을 재검증했습니다. loginwindow의 고정 경로 performAutolaunch·새 console 로그인·PID64258 시작10:31:02·동일 SHA/서명, AX/화면 표시창0과 사용자 메뉴바만 표시 관찰을 독립 verifier와 main이 확인해 approved로 확정했습니다. native UI5/5와 현재9파일 SHA 대응 유지, suite 재실행·제품 코드 변경 없음. 구현 재시도0·근거 재검증1, 최초 evidence reject 이력 유지/현재 reject 해소. task001~011 모두[x], SPEC §5.1~§5.13 성립으로 IMPLEMENT [x]입니다. M4 첫 범위를 완료하며 추가 설정/캐릭터·애니메이션 후속 범위와 M3 취소6개·014/015 보류 상태는 유지합니다. 실제 앱은 등록된 상태로 실행 중이며 커밋·푸시는 수행하지 않았습니다.
