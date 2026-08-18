# CPU·Memory 핵심 리소스 모니터링

## 요약

실제 CPU와 Memory 데이터를 수집해 대시보드 팝오버의 두 카드로 설명하고, 앱 단위 TOP 5와 최근 10분 그래프를 제공합니다.
메뉴바 표시 상태도 주입값 대신 실제 CPU 부하를 따르게 합니다.

## 상태

- [x] SPEC
- [x] ANALYSIS
- [ ] IMPLEMENT

## 문서

- [spec.md](./spec.md)
- [analyze.md](./analyze.md) (ANALYSIS 단계에서 생성)
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
