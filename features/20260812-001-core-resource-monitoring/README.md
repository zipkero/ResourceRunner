# CPU·Memory 핵심 리소스 모니터링

## 요약

실제 CPU와 Memory 데이터를 수집해 대시보드 팝오버의 두 카드로 설명하고, 앱 단위 TOP 5와 최근 10분 그래프를 제공합니다.
메뉴바 표시 상태도 주입값 대신 실제 CPU 부하를 따르게 합니다.

## 상태

- [x] SPEC
- [x] DESIGN
- [ ] IMPLEMENT

## 문서

- [spec.md](./spec.md)
- [design.md](./design.md) (현재 DESIGN 계약)
- [analyze.md](./analyze.md) (기존 ANALYSIS 승인·조사 이력과 참조 보존)
- [implement.md](./implement.md) (IMPLEMENT 단계에서 생성)

## 작업 히스토리

- 2026-08-12: SPEC 작성
- 2026-08-12: ANALYSIS 작성
- 2026-08-13: IMPLEMENT 체크리스트 작성
- 2026-08-15: task-012 실기기 관찰 완료.
  화면 잠금과 디스플레이 슬립 각각에서 두 축의 일정 중지·재개, 중지 구간의 누적 샘플 불변,
  재개 첫 tick의 기준점 전용 갱신, 짧은 중지 6회 반복 재개, 그래프 빈 구간을 확인했습니다.
  **빠른 사용자 전환은 둘째 사용자 계정이 없어 확인하지 못했습니다** — 사용자 판단으로 이 항목만 미확인으로 남기고 완료 처리했습니다.
- 2026-08-15: task-014 완료. 프로세스 조사 축을 production에 배선하고 자리표시 심볼을 제거했습니다.
  Task 순서는 사용자 승인을 받아 task-013보다 먼저 진행했습니다 — task-013이 비교할 프로세스 순위를 task-014가 배선하기 때문입니다.
  실기기 한 세션에서 두 카드 TOP 5 표시, 카드 선택과 복귀, 부하에 따른 메뉴바 이름 전환, 팝오버 개폐에 따른 주기 변경을 함께 관찰했습니다.
  잔여 항목을 기록합니다 — 프로세스 조사 실패가 표시 계층에 도달할 통로가 설계에 없어
  `topApplicationsFailed`가 production에서 항상 `false`입니다(수정 소유 단계 `analyze-init`).
  (Memory TOP 5의 `2.1.233` 표시를 앱 키 유도 결함으로 적었으나 오기였습니다 —
  실행 파일 경로가 `~/.local/share/claude/versions/2.1.233`이라 `.app` 밖 실행 파일 이름을 그대로 쓰는 규칙대로 동작한 것입니다.)
- 2026-08-15: task-004 결함 수정 후 재검증(approved). 실기기에서 CPU TOP 5가 전부 `0%`로 나오는 것을 사용자가 발견했습니다.
  원인은 `proc_pidinfo(PROC_PIDTASKINFO)`의 `pti_total_user`·`pti_total_system`이 나노초가 아니라 mach absolute time tick인데
  `HostProcessSurveyReader`가 나노초로 오인한 것이었습니다. Apple silicon의 timebase가 125/3이라 사용률이 실제의 1/41.67로 축소됐습니다.
  변환을 어댑터 경계에서 한 번 적용하도록 고쳤고 상위 계층은 손대지 않았습니다.
  이 결함이 새어 나간 이유는 테스트 경계가 `ProcessSurveying` 프로토콜에 있어 실제 어댑터가 한 번도 검증되지 않았기 때문이며,
  실기기 회귀 테스트 `realSurveyReportsCPUTimeInNanoseconds()`로 그 구간을 덮었습니다.
  이 수정으로 task-005의 "두 코어를 완전히 쓰는 프로세스가 200%" 조건이 실기기에서 처음 성립했습니다(실측 199.91%).
- 2026-08-15: task-001 결함 수정 후 재검증(approved). task-013 비교에서 Memory 「사용 중」이 Activity Monitor와 10.8% 어긋났습니다.
  Activity Monitor의 공식을 역어셈블로 확정한 결과 구성 항목 넷·스왑·물리 메모리는 앱과 공식이 동일했고,
  「사용 중」만 정의가 달랐습니다(앱은 `app + wired + compressed`, AM은 `total − (free − speculative) − external`).
  사용자 결정으로 AM 공식에 맞췄습니다. 동시 관측에서 일곱 항목 전부 편차 0으로 일치합니다.
  부수 효과로 "사용 중 메모리가 전체 물리 메모리를 넘지 않습니다"가 saturating 뺄셈으로 구조적 보장이 됐습니다 — 옛 합산식에는 상한이 없었습니다.
  관측됐던 와이어드 13.6% 차이는 결함이 아니라 `wire_count`가 초 단위로 0.45 GB 흔들리는 촬영 시점 차이였습니다.
  기록해 둘 위험 — 실기기 단언 `usedBytes > app + wired + compressed`는 불변식이 아니며,
  compressor가 약 4.33 GB를 넘으면 코드가 옳아도 실패할 수 있습니다(정확한 식은 원시값 주입 테스트가 고정).
- 2026-08-15: task-013 시나리오 2(논리 코어 14개 `yes` 부하) 3회 관측 완료.
  부하 프로세스 표시값 1337·1340·1359%로 100%를 넘고, 같은 시점 시스템 전체는 99.73~99.80% vs 앱 100%로 100%를 넘지 않습니다.
  앱의 `yes` 앱 단위 합산이 Activity Monitor의 14개 프로세스 합과 0.2~0.43% 차이로 일치합니다.
  **편차로 기록하는 항목** — 「프로세스 순위 상위 3개 집합이 `top`과 일치」에서 1위(`yes`)는 3/3 일치하나 2·3위는 확정하지 못했습니다.
  `yes`를 뺀 나머지가 0.1~12% 구간에 뭉쳐 있고 세 도구의 표본 창이 서로 달라(앱은 최근 세 샘플 평균,
  Activity Monitor는 자체 주기, `top -l 2`는 1초 표본) 같은 순간에도 값이 10배까지 벌어지기 때문입니다.
  앱의 평활화는 task-006이 「순간값으로 순위를 만들지 않는다」로 요구한 동작이라 결함이 아니며, 관측을 늘려도 수렴하지 않습니다.
  참고 — `/usr/bin/top`은 setuid root라 유효 uid가 0이므로 앱이 시스템 프로세스로 제외하는 것이 정상입니다.
- 2026-08-15: task-013 완료. 세 시나리오 × 3회 관측을 마쳤습니다. IMPLEMENT 단계 종료.
  유휴 — 전체 CPU 차이 0.41~0.89%p(허용 5%p), 상위 3개 집합 3/3 일치, Memory 일곱 항목 편차 0~0.02 GB.
  부하(논리 코어 14개 `yes`) — 표시값 1337·1340·1359%로 100% 초과, 같은 시점 시스템 전체는 99.60~99.80%로 100% 미초과.
  메모리 할당(4 GB) — 사용 중 편차 0~0.03 GB, 두 도구가 같은 방향·같은 폭으로 이동(사용 중 +2.87, 캐시된 −3.44).
  전체 물리 메모리는 전 회차 36 GB로 정확히 일치했고 Swap은 전 회차 0입니다.
  앱 단위 묶음이 실기기에서 확인됐습니다 — `lldb-rpc-server` 3.51 GB와 `python3` 4.01 GB가 모두 Xcode 앱 키로 접혔고
  (`python3`의 실체가 `/Applications/Xcode.app/Contents/Developer/usr/bin/python3`), `yes` 14개가 한 항목으로 합산됐습니다.
  미충족 항목은 부하 시나리오의 상위 3개 집합 2·3위 하나뿐이며 사유와 함께 위 항목에 기록했습니다.
- 2026-08-16: 경미 지적 네 건 정리. 이력 링이 10분 창을 1초 못 미치던 off-by-one,
  `mach_host_self()` 참조 미해제 세 곳, task-001 문서-코드 불일치("허용 배수" → "허용 간격"),
  M1 시절 Task 번호를 가리키던 주석 네 곳입니다.
- 2026-08-16: task-014가 잔여 항목으로 남긴 `topApplicationsFailed` 결함 수정.
  프로세스 조사 실패가 표시 계층에 도달할 통로가 없어 production에서 항상 `false`였고,
  조사가 실패해도 낡은 TOP 5가 정상인 것처럼 계속 표시됐습니다.
  `수정 소유 단계`를 `analyze-init`으로 적어 뒀으나, 필요한 동작은 `SPEC §5.10`과
  analyze.md §2 「실패 경로」가 이미 요구하고 있어 새 요구사항이 아니라 결함으로 다뤘습니다.
  세 선택지 중 「조사 실패를 값으로 바꾸기」를 택했습니다 — 시스템 지표 축이 이미 쓰는 규칙이고,
  두 축이 공유하는 `MonitoringScheduler`와 M1 계약을 건드리지 않으며,
  새 임계값 없이 실패와 중지가 섞이지 않습니다.
  `ProcessSurveySample`이 `Result<ProcessSurveyReport, CollectorFailure>`를 담고 source가 던지지 않습니다.
  실패한 조사는 `ProcessHistoryStore`의 이력을 건드리지 않습니다 —
  관찰된 정체성이 없는 것으로 처리하면 제거 규칙이 이력 전체를 지워 기준점이 모두 사라집니다.
  analyze.md §3 계약 서술을 실제 구조에 맞췄습니다.
- 2026-08-17: SPEC 재작성으로 구현 승인 상태 초기화.
  `docs/product.md` §공통 정보 구조가 두 곳 개정된 것을 반영했습니다 —
  카드 상세가 하단 고정 영역에서 카드 옆 팝업으로 바뀌었고(§5.2),
  레이아웃 안정성이 값 변화뿐 아니라 상태 전이까지 덮도록 확장돼 자리표시 요구가 새로 생겼습니다(§5.15).
  팝오버를 연 직후 첫 수집이 도착하면 카드가 부풀어 아래 내용을 밀어내는 것이 관찰된 것이 계기입니다.
  카드 옆 팝업은 SPEC 수정 전에 실행 환경에서 확인했습니다 —
  `.transient` 부모 팝오버가 닫히지 않고 두 팝오버가 공존하며,
  자식 팝업이 접근성 계층에서 부모의 하위 노드로 들어가 내용에 도달됩니다.
  analyze.md §5 DP14 재확정과 구현·테스트 변경이 이어집니다.
- 2026-08-17: SPEC 재작성에 맞춰 ANALYSIS 재작성.
  DP14를 카드 앵커 자식 팝오버로 다시 확정하고, DP15의 근거를 새 배치에 맞췄으며,
  자리표시(DP17)·상세 팝업 크기(DP18)·프로세스 조사 실패 경로(DP19)를 새로 등록했습니다.
  DP1~DP16의 번호와 주제는 implement.md 참조를 보존하기 위해 그대로 유지했습니다.
  승인 전 확인 두 건은 채택안대로 확정했습니다 — 본체 팝오버 높이를 두 카드에 맞게 줄이고,
  상세 팝업은 두 카드 공통 고정 크기에 내부 스크롤을 둡니다.
- 2026-08-17: IMPLEMENT 체크리스트 작성.
  task-001~014의 ID를 모두 보존하고 task-015(상태와 무관한 카드 높이)·task-016(팝업 고정 크기와 키보드·접근성)을 더해 16개입니다.
  task-010은 같은 ID 자리에서 「카드 선택과 카드 옆 상세 팝업」으로 전면 재작성했습니다.
  `SPEC §5.1`~`§5.15` 15개 조건이 모두 매핑돼 미매핑 기준은 없습니다.
- 2026-08-17: task-016 완료(재작업 후 approved).
  상세 팝업을 두 카드 공통 고정 크기 400×480에 내부 스크롤로 두고, 단축키 등록을 본체 한 자리로 모았습니다.
  처음 구현한 「본체·팝업 양쪽 등록」은 전제가 반증돼 폐기했습니다 —
  자식 팝오버는 key window를 가져가지 않아(다섯 시점의 접근성 덤프에서 `Keyboard Focused`가 매번 부모 팝오버)
  팝업 쪽 등록이 키 이벤트를 받지 못하는 죽은 코드였고, 그 동작을 반대로 뒤집어도 전체 테스트가 통과했습니다.
  단축키 표시 문자열을 `selectionShortcutKey` 하나에서 유도해 정의와 표시가 갈라질 자리를 없앴습니다.
  첫 verify는 `style/minor`로 반려됐습니다 — 폐기된 접근을 전제한 주석·테스트 이름이 남아 코드와 어긋났고,
  「내용이 넘치면 팝업 안에서만 스크롤」에 회귀 그물이 없어 `.scrollDisabled(true)` mutation이 UI 테스트 9개를 모두 통과했습니다.
  재작업에서 주석·이름을 현재 구조에 맞추고 `testDetailContentScrollsWithinFixedPopoverFrame`으로 그 자리를 메웠습니다.
  실측 기록 — `NSPopover` 여백 26pt가 본체(306×514 = 280+26, 488+26)와 자식(426×506 = 400+26, 480+26) 양쪽에서 독립 확인됐습니다.
  잔여 위험 — 새 스크롤 테스트는 프로세스 조사 결과 도착에 의존해(10초 재시도) 고부하 환경에서 불안정할 수 있고,
  스크롤 중 카드·본체 프레임 불변은 단언되지 않았으며(상세 개폐 기준으로는 task-010이 덮음),
  macOS·SwiftUI가 팝오버 key window 처리를 바꾸는 회귀를 잡을 그물은 없습니다(DP15가 받아들인 대가).
  Memory 팝오버 setter 미덮임은 그대로입니다.
- 2026-08-17: CPU 그래프 다운샘플링(결함 수정). 사용자가 "그래프가 너무 조밀조밀함"으로 보고한 문제입니다.
  10분 창 601점을 렌더 폭 248pt에 그대로 그려 점 간격 0.41pt인데 `lineWidth`가 1.5pt였습니다 —
  선 두께가 점 간격의 3.6배라 값이 뭉개져 `SPEC §5.1`의 「최근 그래프」가 읽히지 않았습니다.
  새 요구사항이 아니라 이미 승인된 조건의 미충족이라 결함으로 다뤘고, 시간 창은 10분 그대로 뒀습니다.
  `connectedSegments`로 빈 구간을 먼저 끊고 각 세그먼트 안에서만 버킷 묶음을 합니다 —
  순서를 뒤집으면 인접 간격 판정이 오염돼 중지 구간이 사라집니다(task-012가 실기기로 확인한 동작).
  버킷 폭 4pt(248pt에서 62개), 버킷마다 min·max를 실제 시각 순서로 남기고 `lineWidth`는 1.0으로 줄였습니다.
  첫 구현은 반려됐습니다 — main이 준 검증 조건 「모든 인접 점 간격 > lineWidth」가 틀린 조건이었고,
  그것을 맞추려 넣은 그리디 필터가 순간 피크를 버렸습니다.
  실측 — 5% 평탄에 단일 100% 스파이크를 심으면 601개 위치 중 372곳에서 스파이크가 완전히 사라졌고,
  살아남는 쪽이 극단값이 아니라 시각이 먼저인 후보였습니다. 손실을 기대값으로 못박은 테스트 2개가 올바른 수정을 막고 있었습니다.
  틀린 이유 — min·max를 실제 시각 x에 그리는 한 같은 버킷의 두 점이나 버킷 경계에 걸친 두 점이
  원본 표본 간격까지 붙는 것은 구조적으로 정상이고, 붙은 두 점은 세로 스트로크로 그 구간의 급변을 정확히 나타냅니다.
  원래 증상은 601점이 전 구간에 균일하게 깔려 뭉개진 것이지 124점에서 일부 쌍이 붙는 것이 아닙니다.
  그리디 필터를 제거하고 스파이크·dip 전수 보존(0~600 전 위치)을 회귀 테스트로 고정해 601/601이 됐습니다.
  잔여 위험 — `downsampledBucketCount(forRenderWidth:)`의 `Int(width / 4)`는 폭이 NaN·무한이면 trap하는데 방어가 없습니다.
  버킷 폭 4pt는 상수 비교로만 고정돼 화면 밀도 자체는 단위 테스트로 잡히지 않습니다.
  100 스파이크 옆 2차 피크(90)는 600위치 중 539곳에서 사라집니다(min·max 방식에 내재, 수정 전보다 나빠진 것은 아님).
  새 표본 하나가 들어올 때 대표점 신원 교체율이 랜덤워크 22.6%·매끄러운 패턴 50%로 남아 매초 선이 흔들립니다 —
  근본 해결은 버킷 경계를 배열 인덱스가 아니라 절대 시각 격자로 양자화하는 것이고 그래프 전면 개편 몫으로 미뤘습니다.
  실기기 화면의 601점 조밀도는 확인하지 못했습니다(오프라인 CoreGraphics 렌더로 대체 확인).
- 2026-08-17: 상세 앱 목록의 비결정 순서 제거(결함 수정). 사용자가 "그냥 나열만 되어 있는 상태"로 보고한 문제입니다.
  `ProcessHistoryStore.snapshot()`이 `[ProcessIdentity: ProcessHistoryEntry]` Dictionary를 그대로 `map`하고
  `groupByApplication`이 그 순회 순서를 보존해, 사용량순도 아니고 상한도 없는 목록이 매 tick 순서가 바뀌었습니다.
  `SPEC §5.6`(상세에서 하위 프로세스 확인)과 `§5.2`가 담당하는 자리이고 순서 비결정성은 결함이라 SPEC은 바꾸지 않았습니다.
  `ApplicationRanking.sortedForDisplay(groups:by:)`를 순수 함수로 두고 `groupByApplication` 시그니처는 보존했습니다.
  정렬은 각 `assemble`에서 합니다 — 코디네이터가 CPU와 Memory에 같은 `processGroups` 배열을 넘기므로
  하나의 순서를 공유하면 한쪽은 반드시 엉뚱한 기준으로 정렬됩니다.
  그룹 정렬 값은 그룹 안 프로세스 값의 합이고, tie-break는 그룹이 앱 키 사전순·프로세스가 pid 오름차순입니다.
  `cpuUsagePercent`가 `nil`인 프로세스는 0으로 채우지 않고 값 있는 것보다 뒤로 보냅니다 —
  0으로 채우면 「읽지 못한 프로세스의 사용량이 추정값으로 채워지지 않습니다」(`SPEC §5.6`)를 어깁니다.
  첫 verify는 Memory 축의 「그룹 값 = 합」이 그물에 비어 있어 반려됐습니다 —
  `.residentMemory` 분기를 최댓값으로 바꿔도 295개 테스트가 전부 통과했고,
  Memory 정렬 테스트가 모두 그룹당 프로세스 1개만 썼기 때문입니다. CPU 축만 덮이고 Memory 축이 빈 형태였습니다.
  둘째 verify는 `SPEC §5.11` 오참조 한 줄로 반려됐고 main이 직접 고쳤습니다.
  성능은 decorate-sort-undecorate로 바꿔 tick당 0.205ms → 0.044ms(200그룹·523프로세스, `swiftc -O`)가 됐습니다 —
  이 앱 자체가 리소스 모니터라 자기 CPU 사용이 제품 제약입니다.
  리팩터링이 정렬 결과를 바꾸지 않은 것은 무작위 입력 40,000쌍 비교(불일치 0)와
  앱 키가 유일한 실제 입력의 62,232개 순열로 확인했습니다.
  **남은 한계 — 정렬 기준이 순간값입니다.** `latestCPUUsagePercent`·`recentValues.last?.residentBytes`를 쓰는데
  카드 TOP 5는 최근 3개 값 평균 합산을 씁니다. 같은 앱들이 카드와 상세에서 다른 순서로 보일 수 있고
  상세 목록 순서가 tick마다 계속 움직입니다.
  `SPEC §5.6`의 「순간값이 아니라 최근 여러 샘플을 반영해 순위가 매 갱신마다 요동치지 않습니다」에 맞춰
  정렬과 표시를 평활화 값으로 통일하는 것이 다음 단계입니다.
  개수 상한(TOP 20)은 신규 요구사항이라 별도 feature 몫이고, 정렬이 결정적이 됐어도 앱이 많으면 여전히 길게 나열됩니다.
  UI 경로 확인은 두 verify 모두 실패했습니다 — 자동화 세션에서 메뉴바 상태 항목 클릭이 팝오버를 열지 못하고,
  HEAD `593a783`에서도 같은 문구로 실패하므로 환경 문제입니다.
  표시 계층까지는 `DashboardPresentationTests`의 두 assemble 테스트가 덮습니다.
  함께 처리한 것 — `downsampledBucketCount(forRenderWidth:)`에 `width.isFinite, width > 0` 가드
  (없으면 `Int(Double.nan)`이 trap), 자동화 권한 승인 전에 쓴 낡은 XCUITest 주석 두 곳,
  저장소에 마지막으로 남아 있던 따라갈 수 없는 `구현 보고` 참조.
- 2026-08-17: 상세 목록의 정렬·표시를 평활화 값으로 통일(결함 수정, 위 항목의 2단계).
  상세는 순간값(`latestCPUUsagePercent`·`recentValues.last`)을, 카드 TOP 5는 최근 여러 값 평균을 써서
  같은 앱들이 두 화면에서 다른 순서로 보일 수 있었고 상세 순서가 tick마다 움직였습니다.
  `SPEC §5.6`이 한 조건 안에서 TOP 5와 상세 하위 프로세스를 함께 다루고
  「순간값이 아니라 최근 여러 샘플을 반영해 순위가 매 갱신마다 요동치지 않습니다」를 요구하므로 결함으로 다뤘습니다.
  `compute`의 평균 계산을 `smoothedRecentValues(for:)`로 뽑아 `groupByApplication`이 같은 함수를 쓰게 했습니다 —
  규칙을 복제하면 나중에 한쪽만 바뀌어 다시 어긋납니다. 호출자는 두 곳뿐이고 계산 자리는 하나입니다.
  카드 TOP 5의 값과 순서는 바뀌지 않았습니다 — HEAD `593a783`의 `compute`와 무작위 4,000건을 bit-exact 비교해 불일치 0입니다.
  부수 효과로 카드의 앱 합계와 상세 프로세스 값의 척도가 처음으로 맞았습니다.
  검증에서 확인한 것 — `ApplicationProcessDetail.residentBytes`가 `UInt64`라 평균을 반올림해 담는데,
  이것이 순서 일치를 깨는 조건은 실기기에서 도달할 수 없습니다.
  `pti_resident_size`를 그대로 쓰므로 값이 항상 페이지 배수이고, 반올림 오차는 프로세스당 0.5바이트 이하인데
  페이지 정렬 값에서 참값의 최소 비영 차이는 `16384/3 ≈ 5461.33`바이트입니다.
  페이지 정렬 20만 시행에서 나온 불일치 70건은 전부 두 앱의 평활화 합이 **정확히 같은** 동률이었고,
  반올림을 없앤 가상 구현은 불일치가 오히려 81건으로 더 많았습니다 — 원인은 반올림이 아니라 동률 처리입니다.
  **남은 위험** — 카드 쪽 `topEntries`가 `sorted { $0.value > $1.value }`로 tie-break 없이 정렬하고
  입력이 Dictionary 유래라, 두 앱의 평활화 합이 정확히 같으면 카드 순서가 임의입니다.
  상세는 앱 키 사전순으로 결정적이라 그 부류에서 두 목록 순서가 갈릴 수 있습니다.
  HEAD부터 있던 카드 측 성질이고 표시 문구로는 구분되지 않지만(`ByteCountFormatter`가 GB/MB로 접음),
  카드에 같은 tie-break를 두면 닫힙니다.
  관찰 — `ProcessHistorySnapshot.latestCPUUsagePercent`가 이번 변경으로 production 소비자가 없는 죽은 필드가 됐습니다
  (선언·대입만 있고 읽는 곳은 전부 테스트).
- 2026-08-17: 카드 TOP 5 동률 tie-break와 죽은 필드 제거(위 두 항목의 마무리). 트랙 A 종료.
  `topEntries`가 `sorted { $0.value > $1.value }`로 tie-break 없이 정렬해, 두 앱의 값이 정확히 같으면
  카드 순서와 TOP 5 포함 집합이 임의였습니다(입력이 Dictionary 유래).
  상세와 같은 tie-break(앱 키 사전순)를 넣어 둘 다 결정적이 됐습니다 —
  7개 동률 앱 입력 300회에서 현재 코드는 300/300이 같은 결과이고, tie-break를 지우면 포함 집합이 4종으로 흔들립니다.
  값이 다른 경우의 순서는 바뀌지 않았습니다(HEAD `593a783`와 동률 없는 무작위 2,000건 대조, 불일치 0).
  죽은 필드 `latestCPUUsagePercent`를 제거하고 `ProcessHistoryStoreTests`의 7개 단언을
  `recentValues.last?.cpuUsagePercent`로 옮겼습니다 — HEAD의 필드 대입식과 글자 그대로 같은 식이라 잃은 사실이 없고,
  `ProcessHistoryStore` mutation 5종(되감김 guard, `maximumTickGap`, 코어 합산 상한, 정체성, 조사 실패)이 그대로 잡힙니다.
  **동률 그물은 원리상 확률적입니다.** 테스트 하나당 실행당 2%가 우연히 통과하고 스위트 단위 관측 생존율은 약 0.04%입니다.
  mutation 25회 반복에서 25/25 잡혔고 통과 방향 flakiness는 0이지만, 결정적으로 만들 수단은 없습니다 —
  비결정성이 `compute` 안에서 만들어지는 `[ApplicationKey: Double]`에서 나오고 `topEntries`가 `private`이라
  테스트가 입력 순서를 넣을 seam이 없습니다.
  (main이 제안한 「입력 배열 순서를 바꿔 여러 번 계산」은 실측으로 효과가 없었습니다 —
  순서를 바꿔도 mutation 상태에서 12~17종의 서로 다른 출력이 나왔습니다. 그물을 값싸게 강화하려면
  서로 다른 동률 키 집합을 여러 개 돌려 draw를 늘리는 편이 낫습니다.)
  6개 이상 동률에서의 `prefix(5)` 포함 경계는 구현은 결정적이지만 단언되지 않았습니다 —
  같은 tie-break 한 줄이 순서와 포함을 함께 지배해 순서 테스트가 그 제거를 잡습니다.
  **함께 발견된 기존 그물 공백(이번 변경과 무관, task-005·006 몫)** —
  `recentValueCount` 3 → 2 mutation이 301개 테스트를 전부 통과합니다.
  `recentValues.count`나 링 크기를 단언하는 테스트가 하나도 없고 HEAD `593a783`에서도 같습니다.
  그리고 `pidReuseWithDifferentStartTimeDoesNotInheritPreviousCPUBaseline`은 docstring이 주장하는
  「이전 누적 CPU 시간과 차분되어 실패한다」 기전이 아니라 `identity.startTime` 단언으로 mutation을 잡습니다
  (되감김 guard가 먼저 `nil`을 돌려주기 때문이며 HEAD에서도 같습니다).
- 2026-08-17: 상세 목록의 값 표시와 펼침 조작(결함 수정). 사용자가 "CPU 상세 목록은 전혀 나아지지 않았는데?
  지금 어떤 순서인지도 안 나왔고 그냥 나열해두고 목록 열어서 보든가? 하는 느낌"이라고 보고한 것입니다.
  앞선 정렬 수정이 화면에 보이지 않은 이유가 확인됐습니다 — `DisclosureGroup(group.displayName)`이 앱 이름만
  보여주고 값이 없어서 정렬 기준을 알 수 없었고, 하위 행은 `PID 1234`뿐이라 무슨 프로세스인지 알 수 없었습니다.
  정렬 키가 화면에 없으면 정렬은 무의미합니다.
  고친 것 — 앱 행에 그룹 합계를 표시하고(`ApplicationProcessGroup.sortValue`,
  `sortedForDisplay`가 정렬에 쓴 바로 그 값을 버리지 않고 담아 표시가 별도 계산으로 갈라지지 않게 함),
  하위 행을 `실행파일명 (PID N)`으로 바꾸고(`ApplicationIdentityResolver.executableName(from:)`을 새로 두어
  `deriveIdentity`와 규칙 공유), 정렬 기준을 알리는 머리글을 두었습니다.
  펼침 조작 — `AXDisclosureTriangle`의 접근성 프레임은 행 전체 너비인데 실제 반응 영역이 왼쪽 삼각형뿐이라
  라벨을 눌러도 열리지 않았고, 프레임 왼쪽 몇 pt는 `ScrollView` 클립 밖이라 그 자리를 누르면
  부모·자식 팝오버가 통째로 닫혔습니다(팝오버 수 2→0 실측).
  각 행을 `ApplicationProcessGroupRow`로 분리해 `@State`와 `DisclosureGroup(isExpanded:)`를 잇고
  label에 `.contentShape(Rectangle())` + `.onTapGesture`를 줘 행 전체를 대상으로 만들고,
  목록에 `.padding(.leading, 8)`을 줘 삼각형 히트 영역을 클립 경계에서 떼었습니다.
  **반증된 가설** — 「매초 재렌더링이 `@State`를 날린다」는 틀렸습니다. `@State`로도 8초간 펼침이 유지되며
  `ForEach(groups, id: \.key)`의 안정된 `id`가 상태를 보존합니다.
  main이 그 잘못된 추정으로 지시한 store 펼침 보관(`cpuDetailExpandedKeys` 등)은 되돌렸습니다 —
  원인이 아니었고 `@State` 복귀 mutation에서 죽지 않아 검증되지 않는 복잡도였습니다.
  첫 verify는 `correctness`로 반려됐습니다 — **사용자가 보고한 상태 그대로 되돌리는 mutation이
  288개 테스트를 전부 통과**했습니다(머리글 제거 + 앱 행 값 `EmptyView()` + 하위 행 `PID`만).
  모델 쪽 `sortValue`는 덮였지만 그 값을 화면에 쓰는 구간에 단언이 하나도 없었습니다.
  `nil`을 0으로 표시하는 mutation도 통과했습니다(`SPEC §5.6`·`ANALYSIS §5 DP7`이 금지한 동작).
  메운 방법 — `DashboardProcessListDisplayUITests` 3개로 머리글·앱 행 값·하위 행 이름을 라이브 UI에서 단언하고,
  Memory 앱 행이 KB·MB·GB로 표시되는지 봅니다(CPU 사용률처럼 작은 값이 흘러들면 `ByteCountFormatter`가
  「N bytes」로 찍어 실패). 값 서식은 `ApplicationProcessValueFormatting` 순수 함수로 뷰 밖에 내어
  `nil`→`-` 보존을 단위 테스트가 직접 단언합니다.
  목록 순서 안정화 — `ApplicationProcessGroupOrdering.displayedGroups(groups:stableOrder:hasExpandedRow:)`가
  **펼친 행이 있는 동안 순서를 고정**합니다. 매초 재정렬이 사용자 클릭을 다른 앱 행으로 옮기는 것을 막고
  `SPEC §5.6`의 「순위가 매 갱신마다 요동치지 않습니다」와 같은 방향입니다.
  flaky 판정 — verify가 무변경 소스에서 8회 중 1회 실패를 관찰했는데, 순서 고정 후 깨끗한 환경에서
  세 테스트 5회 반복 **12/12 통과**했고 실행 시간도 9.3~9.5·13.7~13.8·10.9~11.4초로 일관됩니다.
  실패한 회차는 `xcodebuild` 3개가 동시에 돌던 시점이라 앱 인스턴스 중복 간섭으로 판단했습니다
  (실패 표본이 하나라 확정이 아니라 정황 판단입니다).
  UI 테스트 회귀도 함께 고쳤습니다 — `app.staticTexts["ResourceRunner"]`가 제목과
  CPU 상세 목록의 「ResourceRunner」(앱 자기 자신) 행에 동시 매칭돼 `Multiple matching elements found`가 났습니다.
  task-016의 `ScrollView`+고정 크기가 전체 목록을 접근성 트리에 노출시켜 조건을 만들고
  이후 정렬·값 표시 변경이 그 행을 노출시킨 것입니다. 제목에 `DashboardTitle` 식별자를 줘 해소했습니다.
  **오래 남아 있던 잔여 위험 해소** — Memory 팝오버 setter 미덮임에
  `testSelfDismissingMemoryChildPopoverStaysClosedAndReselectionReopensIt`를 신설했고,
  `store.dismissDetail(for: .memory)` 제거 mutation에서 실패하는 것을 확인했습니다.
  성능 기록 — `testMemoryProcessListAppRowValuesUseByteUnitsNotRawNumbers`가 처음엔 283초였습니다.
  `allElementsBoundByIndex`로 수백 개 앱 행을 전부 순회한 탓입니다.
  값 서식은 모든 행이 같은 클로저 하나를 지나므로 표본을 앞 3개로 줄여 15.5초가 됐습니다(18배).
- 2026-08-21: SPEC 재작성으로 초기화됐던 Task 재검증. task-008·009가 approved로 `[x]`가 됐고 task-014는 rejected입니다.
  셋 다 **코드 변경 0**이었습니다 — 초기화의 원인이 구현 부재가 아니라 상위 문서 재작성이었음이 실사로 확인됐습니다.
  판정 근거는 전부 mutation입니다. task-008은 여섯 결과 항목(간격 판정, 창 끝 시각, 10분 창 필터, `prefix(topCount)`,
  `.success(nil)` → `.collecting`, 접근성 안내 문구)을, task-009는 네 항목(기호 통일, swap 기준점, swap 창 필터,
  접근성 단계 문구)을 각각 흔들어 대응 테스트가 정확히 실패하는 것을 확인했습니다.
  `SPEC §5.5`·`§5.13`이 이 시점에 닫혔습니다. §5.13은 세 절(카드 접근성 이름, 키보드 선택·복귀, 상세 팝업 접근성 도달)이
  한 앱 세션에서 함께 관찰되는지로 판정했고 UI 스위트 22개 210.8초 전부 통과했습니다.
  **task-014 reject 사유** — 「결과」 마지막 항목의 통합 관찰 네 가지 중 둘에 근거가 없습니다.
  「실제 CPU 부하에 따른 메뉴바 접근성 이름 전환」은 실행 앱 근거가 `testStatusItemAccessibilityLabelFollowsInjectedState`뿐인데
  이것이 `debugStateInjector` 경로라 실제 판정 경로를 증명하지 못하고,
  「팝오버 개폐에 따른 수집 주기 변경」은 주입 입력을 쓰는 단위 테스트까지만 있습니다.
  또 `SPEC §5.14`의 앞절 「App Sandbox를 유지한 채 **위 동작이 성립**」은 §5.1~§5.13 전체를 가리키므로
  task-006·007·012·013이 `[ ]`인 동안 판정 자체가 불가능합니다 — **task-014는 그 Task들이 끝난 뒤에 잡아야 합니다.**
  자동 항목은 전부 성립했습니다 — Release 번들 파일 5개에 `Contents/Library` 부재, `app-sandbox = true`에 임시 예외 없음,
  `lipo -archs` arm64 단일, 세 대상 deployment target 26.5, `project.pbxproj`가 M1 baseline(`0dfba14`)과 바이트 동일,
  자리표시 심볼·외부 전송 경로 0건.
  새로 확인된 사실 — 저장소에 `.entitlements` 파일이 없고 pbxproj의 `ENABLE_APP_SANDBOX = YES`만으로
  Xcode 26이 entitlement를 합성합니다. Release 서명 entitlement는 셋입니다(`app-sandbox`,
  `files.user-selected.read-only`, ad-hoc 서명 산물인 `get-task-allow`).
- 2026-08-21: Memory 카드 TOP 5 배선의 그물 공백 해소.
  `ApplicationCoordinator.swift`의 `ranking?.memoryUsage`를 `cpuUsage`로 바꿔도 316개 테스트가 전부 통과했습니다.
  `consumeSystemMetricsDeliversProcessSurveyRankingToBothCards`의 fixture에서 Alpha가 CPU·메모리 양쪽 1위라
  어느 축을 받아도 순서가 같았고, Memory 쪽은 `displayName`만 단언하고 값을 단언하지 않았기 때문입니다(CPU 쪽은 값까지 단언).
  fixture를 두 축의 순위가 어긋나게 바꾸고(Alpha가 CPU 1위·메모리 2위, Bravo가 그 반대) 값 단언을 더해,
  같은 mutation에서 이 테스트 하나만 깨끗하게 실패하는 것을 확인했습니다.
  **잔여 위험 — `MemorySystemMetricsCollector.readPressureLevel()`의 throw를 `?? .normal`로 바꿔도 실패가 0건입니다.**
  앞뒤 링크는 덮여 있고(무효 원시값 → `nil`은 `otherRawValuesAreNotInterpreted`,
  `unsupportedValue` 실패가 임의 단계를 만들지 않음은 `memoryFailureTickBecomesFailureStateKeepingLastKnownValue`)
  비어 있는 것은 사이 3줄뿐인데, 그 자리가 `private` + 실제 `sysctl`이라 주입 지점이 없습니다.
  production에 테스트 전용 seam을 내는 비용이 얻는 것보다 크다고 판단해 사용자 결정으로 열어 둡니다.
- 2026-08-21: 앞선 기록 보완 두 건.
  (1) `96e1ddb`의 「무효 테스트 2건 제거·교체」는 **제거가 아니라 본문 교체**입니다 —
  그 커밋에서 사라진 테스트 함수 이름을 전부 HEAD와 대조한 결과 이름 기준으로 삭제된 것은 하나도 없습니다.
  같은 커밋에서 `recentValueCount` 그물(`ProcessHistoryRecentValueRingTests`)이 추가돼,
  위 `2026-08-17` 항목이 미해소 공백으로 적어 둔 「3 → 2 mutation이 301개 테스트를 전부 통과」는 그 시점 기록이며 지금은 닫혀 있습니다.
  (2) UI 스위트 대량 실패의 원인은 **실행 중 화면 잠금**이었습니다. 코드 결함이 아닙니다 —
  이후 대량 실패를 만나면 이 가능성을 먼저 확인해야 합니다.
- 2026-08-21: 테스트 실행 정책. 기본은 단위 전체(316개 약 4초)와 변경에 걸리는 UI 테스트만 `-only-testing:`으로 돌리고,
  UI 스위트 전체(22개 약 200초)는 Task를 닫을 때나 `SPEC §5.N`이 닫힐 때만 돌립니다.
  전체 338개 중 UI 22개가 시간의 98%를 쓰는데, 원인이 단언 개수가 아니라 테스트마다 붙는 `app.launch()`와 수집 대기 고정비라
  개수를 줄여도 체감이 바뀌지 않기 때문입니다.
- 2026-08-29: UI 테스트 중복 감사 결과 기록. 위 실행 정책의 근거 자료이며 아직 어느 테스트도 지우지 않았습니다.
  UI 스위트 22개 약 200초 중 **약 80초를 단언 손실 없이 줄일 수 있다**는 감사 결과가 대화에만 남아 있었습니다.
  완전 중복 셋 — `testOtherCardShortcutMovesSelectionWhileDetailIsOpen`(8.9초, 같은 단언을 다른 테스트가 이미 함),
  `ResourceRunnerUITests.testMenuBarClickOpensPopover`(4.4초, 같은 경로 중복),
  `ResourceRunnerUITestsLaunchTests.testLaunch`(2.2초, **단언이 하나도 없습니다**).
  병합형 후보는 여섯이고 개별 목록은 정리되지 않았습니다.
  줄이는 효과가 큰 이유는 위 정책이 적은 것과 같습니다 — 시간의 대부분이 테스트마다 붙는
  `app.launch()`와 수집 대기 고정비라 테스트 건수를 줄이는 것이 곧 시간 감소입니다.
  **실행 시점을 정했습니다(사용자 결정)** — 기기 인증 창(`LocalAuthentication Code=-4`)이 풀리고
  resource-visualization task-011·012가 UI 스위트를 요구하는 시점에 함께 처리합니다.
  그 전에는 손대지 않습니다 — 지금은 UI 스위트를 돌릴 수 없어 정리 전후 대조로 「단언 손실 없음」을 확인할 방법이 없습니다.
  착수할 때 병합형 후보 여섯은 목록이 남아 있지 않으므로 재감사가 필요합니다.
- 2026-08-29: **테스트 통과 건수를 baseline으로 쓰지 않기로 했습니다(사용자 결정).**
  기록과 verify 대조의 기준은 「실패 0 + `** TEST SUCCEEDED **`」이고, 통과 건수는 필요할 때
  `Test case … passed` 줄 수를 보조로 덧붙입니다.
  세는 방식이 갈려 값이 섞여 있었기 때문입니다 — 같은 시점의 같은 스위트를 두고
  `Test case … passed` 줄 수 388, 서로 다른 테스트 이름 351개, 앞선 기록 346, worker 보고 352가 나왔습니다.
  갈리는 원인은 확인하지 않았습니다(parameterized test가 인자 조합마다 `passed` 줄을 내는 것으로 **추정**하며 실측하지 않았습니다).
  개수는 Task마다 늘어나는 것이 정상이라 회귀 신호로 약하고, 실제 그물 판정은 mutation 재현이 담당합니다.
  위 실행 정책의 「단위 전체 + 변경에 걸리는 UI만」은 그대로입니다.
- 2026-09-26: 기존 승인된 ANALYSIS를 현재 DESIGN 단계의 `design.md`로 복원했습니다.
  `spec.md` §5.1~§5.15와 DP1~DP19의 채택안·사용자 결정·Task 경계·검증 기준은 유지했습니다.
  `analyze.md`는 기존 `implement.md`, 후속 feature와 코드의 참조 및 승인 이력을 위해 보존했습니다.
  `analyze.md` §2·§4의 단축키 양쪽 등록 문장은 같은 문서 DP15의 최종 실측·채택안에 맞춰 정정했습니다.
  이는 이미 승인된 본체 한 곳 등록 계약의 표현 정리이므로 task-001~011·015·016의 기존 승인을 유지합니다.
  task-012·013·014는 기존대로 `[ ]`이며, task-014의 이전 reject 근거도 그대로 유효합니다.
  문서 복원과 표현 정리로 취소할 Task 승인은 없습니다.
- 2026-09-26: task-012 시도 1/3에서 SPEC §5.11과 DESIGN DP11의 간격 판정 충돌을 발견했습니다.
  약 5초의 실제 중지 뒤에는 10초 간격 허용값 때문에 CPU 차분과 그래프 선 연결이 생길 수 있어, DESIGN 승인을 `[ ]`로 되돌리고 설계 소유 단계로 반환했습니다.
  task-012는 `[ ]`로 유지합니다. 기존 승인 Task의 의존 영향은 DP11 재설계 후보와 함께 판정합니다.
- 2026-09-26: SPEC §5.11의 중지 길이 무관 단절 조건에 맞춰 DESIGN DP11을 다시 확정했습니다.
  명시적 일정 중지마다 수집 epoch를 바꾸고, 재개 첫 CPU 기준점을 비우며 이력 점과 메뉴바 지속 판정까지 경계를 전달합니다. 일반 지연과 중지 없는 주기 변경의 10초 허용 간격은 유지합니다.
  이 의미 변경의 직접·의존 범위인 task-001·002·003·007·008·011의 승인만 `[ ]`로 되돌렸습니다. 기존 승인 근거는 이력으로 남기되 현재 승인 근거로 사용하지 않습니다.
  task-012·013·014는 계속 `[ ]`이고, 나머지 일곱 Task의 승인 결과와 검증 기준은 영향이 없어 유지합니다. DESIGN은 다시 `[x]`입니다.
- 2026-09-26: 개정 DESIGN에 맞춘 IMPLEMENT 체크리스트를 갱신했습니다. 기존 16개 Task의 ID·순서와 승인 이력을 유지하고 task-001·002·003·007·008·011·012의 epoch 접근과 검증 기준을 고쳤습니다. SPEC §5.1~§5.15는 모두 Task에 매핑됩니다.
- 2026-09-26: task-001 재구현과 독립 verify 완료. 새 epoch에서 CPU 기준점을 초기화하고 오래된 epoch 호출을 폐기합니다. 첫 verify는 같은 epoch의 5초 → 1초 주기 변경 테스트 부재로 reject됐고, 시도 2/3에서 해당 테스트를 추가해 approved됐습니다. 관련 CPU·Memory·실기기 경로 테스트가 통과했습니다.
- 2026-09-26: task-002 재구현과 독립 verify 완료. `TimestampedSample`에서 유효 이력 점까지 epoch를 보존하고 기준점 전용 tick은 이력에 넣지 않습니다. 짧은 중지, 주기 변경 후 링 보존, 10분 창과 stream 조건의 관련 테스트가 통과했습니다.
- 2026-09-26: task-003 재구현과 독립 verify 완료. Scheduler의 실제 실행→중지 전이만 epoch를 전진시키고 source 호출과 저장 샘플에 전달합니다. 첫 verify에서 정상 주기 변경의 epoch 전달 직접 단언이 빠져 reject됐으나 시도 2/3에서 수동 clock 테스트를 추가해 approved됐습니다. 이전 generation의 늦은 결과 폐기도 확인했습니다.
- 2026-09-26: task-007 시도 1/3은 epoch 변경 뒤 이전 `.sustainedHigh`가 남는 결함과 실기기 접근성 이름 관찰 부족으로 reject됐습니다. 시도 2/3에서 결함을 고치고 관련 suite를 통과시켰습니다. Debug 앱에 `yes` 14개를 75초 걸어 20:47:33 `veryHigh`(99.25%), 20:48:29 `sustainedHigh`(99.96%), 종료 후 20:48:47 `low`(10.68%) 로그를 확인했습니다. 창 없는 메뉴바 앱의 접근성 연결이 시간 초과돼 이름 관찰은 아직 못 했으므로 task-007은 `[ ]`로 유지합니다.
- 2026-09-26: task-007의 실기기 접근성 근거를 보완해 독립 verify approved. 팝오버를 열어 Accessibility Inspector에서 같은 Debug 앱 PID 42257의 상태 항목을 선택했습니다. `yes` 12개를 100초 실행하는 동안 실제 접근성 이름이 `낮음 → 매우 높음 → 장시간 고부하 → 낮음`으로 바뀌었습니다. 문서의 논리 코어 수 14개 조건으로 다시 105초 실행한 로그에서는 60초 연속 사용률 최소 99.93% 뒤 `sustainedHigh` 전환을 확인했습니다. 14개 실행 중 Inspector 새로고침은 CPU 포화로 시간 초과였으나 독립 verifier는 두 실행이 같은 앱·판정 경로를 검증한다고 판단했습니다. 이전 기록의 `[ ]` 보류는 이 승인으로 해소됐습니다.
- 2026-09-26: task-008 재구현과 독립 verify 완료. 그래프 점에 epoch를 전달하고 다른 epoch는 5초 간격이어도 선분을 나눠 다운샘플링합니다. 첫 verify는 현재 코드의 팝오버 첫 조회 UI 근거 부족으로 reject됐습니다. macOS AX가 CPU 카드를 단일 Button 이름으로 노출하는 사실에 맞춰 `implement.md`의 확인 수단을 국소 정정하고 XCUITest를 보강해 시도 2/3에서 approved됐습니다. 실제 짧은 중지의 빈 구간 화면 관찰은 task-012에 남습니다.
- 2026-09-26: task-011 재검증 approved. 5초 중지 뒤 새 epoch의 CPU 기준점 전용 tick에서 CPU 카드는 마지막 값·시각과 중지 상태를 유지하고 Memory만 정상으로 돌아오며, 다음 유효 CPU tick에서 CPU도 정상으로 돌아오는 회귀 테스트가 통과했습니다. 기존 실패 격리·선택 유지 경로도 함께 확인했습니다.
- 2026-09-26: task-012 시도 2/3에서 실기기 관찰용 Debug 로그에 일정·샘플·이력·메뉴바 판정의 epoch 경계를 보강했습니다. Debug build, 전체 ResourceRunnerTests, `git diff --check`가 통과했습니다. Debug 앱 PID 4797과 `/tmp/ResourceRunner-task012-live.log` 수집을 시작해 초기 두 축 일정과 epoch 0의 기준점·첫 유효 점을 확인했습니다. 실제 잠금·해제, 디스플레이 슬립·깨우기, 짧은 중지 5회, 긴 중지의 물리 조작을 기다리는 동안 task-012는 `[ ]`로 유지합니다.
- 2026-09-27: task-014 시도 3/3의 통합 근거를 보완해 독립 verify approved. `/tmp`와 `/private/tmp`의 UI fixture 경로 불일치를 정규화한 뒤 서명된 전체 UI suite가 실패 없이 통과했습니다. `OneSessionMonitoringIntegrationUITests`가 한 앱 실행에서 두 카드·상세 팝업, 실제 `yes` 14개 부하의 메뉴바 접근성 이름 전환과 재개방을 확인했고, 같은 PID 90549의 로그가 팝오버 상태별 수집 주기 전환을 보여 줍니다. Release 단일 arm64 실행 파일과 Sandbox 등 production 구성도 재확인했습니다. task-014는 `[x]`; task-012·013이 남아 SPEC §5.14와 IMPLEMENT는 계속 `[ ]`입니다.
- 2026-09-27: task-013 마지막 시도 3/3은 독립 verify rejected. 서명된 UI 테스트가 새 앱의 팝오버를 연 상태에서 유휴·`yes` 14개·4GB를 각 3회 비교했습니다. 유휴 2회차의 전체 CPU는 앱 18.00% 대 Activity Monitor 11.15%로 6.85%p 차이여서 DP13의 5%p 기준을 넘었습니다. `yes` 합산 1239~1246%와 전체 100% 이하, 4GB 사용 중 메모리의 근접값은 확인했으나, 유휴·4GB의 앱 상위 3개 집합은 `top`과 일부 달랐습니다. 앱 단위 묶음·시스템 프로세스 제외·세 표본 평균과 `top`의 원시 행을 동일하게 비교할 규칙과 충분한 원시 표본도 없습니다. 측정용 helper와 부하는 제거했고 구현 변경은 없습니다. worker 호출 한도 3/3에 도달해 task-013과 SPEC §5.3은 `[ ]`로 유지합니다. 이전 2026-08-15 task-013 승인 이력은 현재 epoch 설계 기준의 승인 근거가 아닙니다.
- 2026-09-27: 사용자 승인으로 DESIGN의 task-012·013 검증 방법을 국소 개정했습니다. task-012는 실기기 디스플레이 슬립 직후 잠금이 이어지는 이 Mac의 제약을 명시하고, 결합된 실제 로그와 단독 신호 주입 테스트를 함께 판정합니다. 짧은 그래프 간격은 실제 epoch 로그와 결정적 선분 테스트로 확인하되, 실기기 약 5초 잠금·해제 5회와 10분 이상 중지 직후의 빈 그래프·오른쪽 채움 화면은 그대로 요구합니다. task-013은 앱과 Activity Monitor의 관측 창을 맞추고 `top`의 전체 PID 표본을 앱과 같은 모집단·세 표본 평균·앱 키로 재집계합니다. 5%p·10%·상위 3개 집합·3회 전부 통과 기준은 유지하며 기존 6.85%p 초과 기록도 실패로 남깁니다. SPEC 동작 조건과 다른 승인 Task의 구현 의미는 바뀌지 않아 SPEC·DESIGN 및 그 Task 승인을 유지하고, task-012·013과 IMPLEMENT는 `[ ]`입니다.
- 2026-09-27: 승인된 DESIGN에 맞춰 `implement.md` task-012·013의 확인 절차를 갱신했습니다. Task ID·순서와 두 Task의 시도 3/3·최근 reject를 보존했습니다. 다른 Task의 결과 조건과 승인은 바꾸지 않았고, SPEC §5.1~§5.15의 기존 Task 매핑도 유지합니다. 새 절차 자체가 기존 미충족 표본을 통과로 바꾸지는 않으므로 IMPLEMENT는 `[ ]`입니다.
- 2026-09-27: task-013 재측정 준비에서 DP13의 `top RSIZE = Resident Memory` 전제가 현재 macOS 26.6.2와 충돌함을 확인했습니다. `top -stats mem,rsize`는 두 열 모두 `MEM`으로 같은 값(OrbStack Helper 약 1.09GB)을 보였고, 같은 PID의 `ps rss`는 약 2.28GB였습니다. 로컬 `man top`은 `mem`을 Physical Footprint, `man ps`는 `rss`를 Resident Set으로 정의합니다. SPEC §5.3의 Resident Memory 요구는 유지하고 DESIGN 승인을 `[ ]`로 돌려 비교 도구 결정을 기다립니다. 직접 영향은 미승인 task-013이며, 다른 Task의 승인과 task-012 상태는 유지합니다.
- 2026-09-27: 사용자가 프로세스 Memory 비교를 `ps rss`로 바꾸는 안을 승인했습니다. DP13 옵션 B의 지표별 분리 원칙은 유지해 시스템 전체 지표는 Activity Monitor, 프로세스 CPU는 `top %CPU`, Resident Memory는 `ps rss`와 비교하도록 `design.md`를 국소 개정했습니다. 5%p·10%·상위 3개 집합·3회 전부 기준은 유지합니다. SPEC과 다른 Task의 구현 의미는 그대로여서 DESIGN을 `[x]`로 되돌리고 task-013만 새 절차의 실측 근거를 기다립니다.
- 2026-09-27: `implement-init`에서 task-013의 접근·결과·확인을 새 DP13에 맞췄습니다. `top`의 전체 PID CPU와 `ps rss`를 같은 관측 창·현재 UID/읽힘 후보·최근 세 표본 평균·앱 키 집계로 맞추고 CPU·Memory 순위를 각각 비교합니다. 시도 3/3과 기존 reject 근거를 보존했으며 새 측정 없이 task-013을 승인하지 않습니다.
- 2026-09-27: 새 4GB 실측에서 앱 PID 4797은 메모리 약 4GB를 `zsh`에 귀속했지만, 같은 PID 45328은 `ps` 25개 표본과 Activity Monitor에서 Python으로 확인됐습니다. `ProcessSurveyCollector`의 PID·시작 시각별 경로 1회 캐시가 `exec` 뒤 예전 경로를 유지할 수 있다는 원인 후보를 확인했습니다. 첫 경로 표본이 없어 인과는 확정하지 않았고 task-013을 계속 미승인으로 둡니다.
- 2026-09-27: 사용자 승인으로 DESIGN DP20을 추가하고 IMPLEMENT task-004·005·006·013·014의 검증 기준을 개정했습니다. 현재 UID의 성공 조사 대상은 매번 실행 경로를 읽고, 같은 정체성에서 경로가 바뀌면 CPU 기준점·최근 순위 값·메모리 증가량 기준점을 다시 시작합니다. 직접 영향 task-004·005·006과 통합 의존 task-014의 승인을 취소했습니다. 기존 승인 근거는 이력이며 현 기준의 승인 근거가 아닙니다. task-013은 기존 `[ ]`, 시도 3/3과 reject를 유지하고 새 구현 후 다시 관측합니다. 다른 Task 승인과 SPEC §5.1~§5.15 매핑은 유지하며 IMPLEMENT는 `[ ]`입니다.
- 2026-09-27: 개정 task-004는 시도 2/3에서 독립 verify approved. 첫 시도에서 매 조사 경로 재조회는 통과했지만 real UID 사용과 낡은 주석 때문에 반려됐고, 두 번째 시도에서 `geteuid()` 경계·다른 UID 주입 테스트·주석을 보완했습니다. 경로 전환·경로 실패 회귀와 실제 어댑터의 CPU 시간 변환도 다시 통과했습니다. 실기기 경로 조회 두 번은 약 6.1/5.2ms, 1,246회 중 실패 26회였습니다. task-005·006·012·013·014와 IMPLEMENT는 아직 `[ ]`입니다.
- 2026-09-27: 개정 task-005는 시도 1/3에서 독립 verify approved. 같은 정체성의 실행 경로 전환에서 CPU·최근 순위 값·메모리 증가량 기준점을 초기화하고, 경로가 유지되면 이력을 이어갑니다. 전환 첫·둘째 조사와 대조 정체성을 단언한 테스트 및 기존 이력 경계 테스트가 통과했습니다. SPEC §5.7의 현재 매핑을 완료했고, task-006·012·013·014와 IMPLEMENT는 `[ ]`입니다.
- 2026-09-27: 개정 task-006은 시도 1/3에서 독립 verify approved. 저장소부터 앱 순위·상세 그룹까지 경로 A→B 전환을 검증했고, 순위 테스트 전체 47개가 통과했습니다. 실제 Collector의 같은 조사에서 Chrome 19개, Orca(Electron) 7개, Xcode 본체를 포함한 10개 프로세스가 각각 바깥 `.app` 한 키로 묶였습니다. task-012·013·014와 IMPLEMENT는 `[ ]`입니다.
- 2026-09-27: 개정 task-014는 독립 verify approved. 현 DP20 산출물의 전체 단위·UI 테스트와 Release 번들·Sandbox·arm64·배포 대상 검사를 통과했습니다. 앱 PID 42078의 한 세션에서 팝오버 개폐별 두 축 일정 전환, 동일 PID 44786의 zsh→Xcode Python 전환 후 CPU·Memory 카드에 Xcode 귀속과 zsh 상위 목록 부재를 확인했습니다. 측정용 임시 UI 소스를 제거하고 `git diff --check`를 확인했습니다. task-012·013과 IMPLEMENT는 `[ ]`이며 SPEC §5.14도 아직 미완료입니다.
- 2026-09-27: task-012의 14분 45초 실제 잠금에서 두 수집 축의 정지·재개와 샘플 수 불변을 확인했으나 해제 직후 팝오버 화면은 확보하지 못했습니다. task-013의 DP20 재측정 9회에서 시스템 CPU·Memory와 Memory 상위 3개 집합은 기준을 충족했으나, CPU 상위 3개 중 memory-2 회차의 외부 `top` 자료는 화면과 달라 독립 검증이 근거 부족으로 판정했습니다. 두 Task와 IMPLEMENT는 `[ ]`입니다.
- 2026-09-27: 사용자 자율 진행 지시에 따라 task-013의 DP13 비교 기준을 권장안으로 국소 개정했습니다. 임의 배경 앱의 CPU 상위 3개 집합 전회차 일치만 필수 조건에서 제외하고, 시스템 수치 9회, Memory 상위 3개 9회, 실제 `yes` PID의 값·경로·방향, 경로 전환과 결정적 CPU 순위 테스트는 유지했습니다. 기존 불일치·reject 원자료는 보존하고 새 기준의 독립 재판정을 시작했습니다. SPEC 문장과 task-004·005·006·014의 승인 기준은 바뀌지 않아 그 승인을 유지합니다. task-013과 IMPLEMENT는 `[ ]`입니다.
- 2026-09-27: 관찰 앱 PID 4797의 19:09:47~19:35:32 약 25분 45초 디스플레이 슬립·잠금에서 시스템·프로세스 두 수집 축의 `appendedTotal`이 각각 12571·5255로 변하지 않고 epoch 20에서 재개됐습니다. 19:46:03~19:50:27의 약 4분 24초 중지도 기록됐습니다. 10분 이상 중지 직후 전 구간 빈 그래프 화면은 확보하지 못했고 화면 제어 도구 연결도 실패해 task-012는 `[ ]`입니다.
- 2026-09-27: 개정 DP13의 task-013을 독립 verify approved로 `[x]` 처리했습니다. 정렬된 9회 원자료를 재계산해 전체 CPU 최대 3.41%p, Memory 구성 최대 1.96%, 물리 36GB·Swap 0, Memory 상위 3개 앱 키 9/9 일치를 확인했습니다. `yes` 14개 PID의 화면·`top` 합산값과 경로·변화 방향, 동일 PID zsh→Xcode Python 전환, 결정적 순위·이력 테스트도 충족했습니다. CPU 임의 배경 앱 집합은 idle-1·memory-1에서 독립 표본 창과 경계 순위 차이를 기록했습니다. SPEC §5.3·§5.6의 매핑 Task가 완료됐고, task-012와 IMPLEMENT는 `[ ]`입니다.
- 2026-09-28: 20:46:24~22:29:07 약 1시간 43분, 22:40:39~23:44:48 약 1시간 4분, 23:55:36~06:47:37 약 6시간 52분 잠금에서도 두 수집 축의 샘플 수가 정지 중 불변이고 해제 뒤 재개됐습니다. 직후 빈 그래프 화면은 확보하지 못해 task-012·IMPLEMENT는 `[ ]`입니다. 사용자 요청으로 관찰 앱과 로그 기록 프로세스를 종료하고 원시 로그를 보존했습니다.
