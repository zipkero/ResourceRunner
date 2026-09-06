# 그래프 가독성과 색감 회복 구현

- [x] task-001: 그래프 판을 키우고 영역 경계와 시간 축을 둔다
  - 목적: CPU 카드의 그래프가 변경 전보다 높은 면으로 그려지고, 판의 네 변이 화면에서 그래프 영역의 경계로 읽히며,
    판 아래 축 라벨 줄과 판 안 세로 눈금으로 창이 얼마나 긴지 알 수 있다.
    값이 없는 자리표시 상태에서도 같은 자리에 같은 크기로 같은 경계와 눈금이 나타난다.
  - 접근: 그래프 판 높이와 판–축 라벨 줄 간격을 뷰 밖 순수 상수로 꺼내 값 있음·값 없음 두 경로가 같은 값을 참조하게 하고 판 높이를 100pt로 올린다.
    격자 자리에 창을 다섯 등분하는 세로 눈금과 닫힌 사각 판 테두리를 레이어로 더하고, 판 아래에 세 슬롯 축 라벨 줄을 둔다.
  - 검증 조건:
    - 결과: 그래프 슬롯이 판 100 + 라벨과 대상 사이 간격 4 + 축 라벨 줄 13 = 117pt이고, 값 있음 경로와 자리표시 경로가 같은 슬롯 높이를 쓴다.
      판의 가로세로 비가 232 : 100 = 2.32 : 1로 변경 전 약 3.9 : 1보다 낮고, 판 높이가 변경 전 60pt보다 크다.
      기준선 25·50·75% 세 줄과 User·System 두 계열 구분(채움 밀도 차, 아래 점선·위 실선 경계)은 그대로다.
      축 라벨 줄은 왼쪽 「10분 전」·오른쪽 「지금」이고 가운데는 같은 높이의 빈 슬롯이라 문자열이 없어도 줄 높이가 갈리지 않는다.
      세로 눈금은 창을 다섯 등분하는 네 줄이고 등분 수가 고정이며 간격이 창 길이에서 유도된다.
      눈금 색·두께·그리기 레이어는 가로 기준선과 같다.
      판 테두리는 격자와 같은 시스템 구분선 색이고 그리기 순서가 맨 마지막이라 값이 100%에 닿는 구간에서도 위 변이 밴드 채움에 덮이지 않는다.
      자리표시 경로는 격자·세로 눈금·판 테두리를 같은 좌표에 그리고 점도 선도 그리지 않는다.
      선 두께 1.0pt와 다운샘플 버킷 수는 그대로다.
    - 확인:
      - 그래프 슬롯 높이를 판 높이·간격·라벨 줄 높이의 합으로 유도해 단언하고, 값 있음 경로와 자리표시 경로의 슬롯 높이가 같음을 단언한다.
        리터럴 117을 두 자리에 복제하지 않는다.
      - 「판 높이 > 변경 전 60pt」와 「가로세로 비 < 3.9 : 1」을 판 폭·높이 상수에서 유도해 단언한다.
      - `DashboardPresentationTests`의 `HistoryGraphViewDrawOrderTests`와 `HistoryGraphGridlinePlaceholderDrawOrderTests`의 배열 단언을
        세로 눈금·판 테두리가 들어간 새 목록으로 갱신하고, 테두리가 두 목록 모두에서 마지막임을 단언한다.
      - 세로 눈금의 정규화 x 위치 목록이 네 개이고 창을 다섯 등분함을 단언하며, 창 길이를 바꿔도 등분 수가 유지됨을 단언한다.
      - `DashboardCardLayoutTests`의 `CardHeightBaseline.cpu`(231.0)를 새 조립의 실측값으로 갱신하고,
        `previousCPUUpperBound`(243.0)는 지우지 않고 「변경 전 카드 높이 231.0 이상」이라는 하한 단언으로 다시 쓴 뒤
        DESIGN §5 DP1 예산에서 나온 새 상한을 함께 둔다.
      - 같은 파일의 픽셀 영역 리터럴 `cpuPlaceholderGraph`(y 65..<129)·`cpuPlaceholderSummary`(y 45..<60)·`cpuFirstRankingIcon`(y 136..<148)을
        새 슬롯 순서에서 다시 계산해 갱신하고, 각 영역이 무엇을 보는지 주석으로 남긴다.
        `cpuFirstRankingIcon`은 그래프 슬롯이 길어진 만큼 아래로 밀린다.
      - `NewDisplayElement.cpu`의 「CPU 그래프 격자 픽셀 > 0」 판정이 새 영역 좌표에서 그대로 통과한다.
      - `cpuGraphPlaceholderDoesNotRenderInventedZeroValues`의 「채도 0.35 초과 픽셀 0」이 그대로 통과한다.
        세로 눈금과 판 테두리를 격자와 같은 시스템 구분선 색으로 두어야 이 판정이 성립하므로, 그 색을 유채색으로 바꾸지 않는다.
      - `cpuCardHeightIsSameAcrossAllFourStates`·`memoryCardHeightIsSameAcrossAllFourStates`·`cardHeightsMatchBaselinesAcrossEveryStateWithNewElements`의
        여섯 상태 높이 동일 단언이 그대로 통과한다.
      - `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsCaption`의 기준선 문구와 두 계열 문구가 그대로 통과한다.
      - 본체 고정 높이를 산술 예상값으로 잠정 갱신해 콘텐츠가 잘리지 않게 하고, `ResourceRunnerUITests`의 팝오버 프레임 리터럴 473도 같은 잠정값으로 옮긴다.
        최종 확정은 task-007에서 실측으로 한다.
      - 테스트 실행은 `ResourceRunnerTests` 전체와 UI 스위트 `ResourceRunnerUITests`만 돌린다.
        전체 스킴은 이 Task에서 돌리지 않는다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 0이 아니면 잔류 인스턴스를 정리한 뒤 다시 돌린다.
        잔류 인스턴스가 메뉴바를 채우면 status item을 찾지 못해 본문에 닿기 전에 전부 실패한다.
        화면 잠금이 풀린 상태에서 실행한다.
      - 수동 확인: 팝오버를 연 화면에서 그래프가 가로에 눌린 띠가 아니라 값을 읽는 면으로 보이고 판의 테두리가 기준선과 다른 형태로 읽히는지 —
        비율·픽셀 단언으로 대체되지 않는 잔여 판단이다.
  - 참조: SPEC §5.1, §5.2, §5.8, §5.13 / DESIGN §5 DP2, DP3, DP4, DP12

- [x] task-002: 아직 수집되지 않은 구간을 빗금과 수집 진행 문구로 드러낸다
  - 목적: 앱을 켠 직후처럼 10분 창의 대부분이 비어 있을 때 그 구간이 값 0이 아니라 아직 수집되지 않은 구간으로 화면에서 구분되고,
    얼마나 모였는지가 그래프 아래 문구와 카드 접근성 이름에서 읽힌다.
  - 접근: 점 목록·그리는 시점의 시각·시간 창을 받아 축 양끝 라벨과 수집 진행 문구, 미수집 구간의 정규화 비율을 내놓는 순수 계산 자리를 두고,
    그 비율만큼을 판 왼쪽에 무채색 대각 빗금으로 그린다.
    축 라벨 줄 가운데 슬롯과 카드 접근성 이름이 같은 진행 문구를 쓴다.
  - 검증 조건:
    - 결과: 미수집 구간은 창 왼쪽 끝부터 첫 표본 시각까지이고, 표본이 하나도 없으면 창 전체다.
      중지·실패로 생긴 중간 공백은 이 판정의 대상이 아니며 지금처럼 선이 끊기는 것으로만 표현된다.
      진행 문구는 `docs/product.md`가 적어 둔 「데이터 수집 중 · 00:42 / 10:00」 형태이고, 창이 다 차면 문자열이 비지만 줄은 남아 카드 높이가 갈리지 않는다.
      빗금은 색이 아니라 패턴이고 무채색이라 색을 지운 화면에서도 미수집 구간이 구분되며, 점도 선도 그리지 않아 값을 지어내지 않는다.
      값이 하나도 없는 자리표시 상태에서는 판 전체에 빗금이 깔린다.
      카드 접근성 이름에 시간 창 길이와 수집 진행이 더해지고, 기존 항목(초점 수치·상태·두 계열·기준선·순위 안내·단축키)은 하나도 빠지지 않는다.
    - 확인:
      - 표본 0개 / 창 중간에서 시작 / 창이 다 찬 세 입력에서 미수집 비율이 각각 1 / 첫 표본 시각에서 유도한 값 / 0임을 단언한다.
      - 중간 공백이 있는 입력에서 비율이 여전히 첫 표본 시각 기준임을 단언해 중간 공백이 미수집으로 판정되지 않음을 잡는다.
      - 진행 문구가 창이 차기 전에는 경과·전체를 담고 창이 찬 뒤에는 없음이 되며, 그 전이에서 슬롯 높이가 바뀌지 않음을 단언한다.
      - `HistoryGraphGridlinePlaceholderDrawOrderTests`의 배열 단언에 미수집 구간이 들어가고, 순서가 격자·세로 눈금 다음이며 판 테두리 앞임을 잡는다.
      - `cpuGraphPlaceholderDoesNotRenderInventedZeroValues`의 「채도 0.35 초과 픽셀 0」이 그대로 통과한다(빗금이 무채색이다).
      - `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsCaption`을 새 문구까지 포함하도록 갱신하되,
        변경 전에 들어 있던 항목이 모두 남아 있음을 항목별로 단언한다.
      - 새 절을 카드 접근성 이름의 기존 값 구간 안쪽에 끼워 넣지 않는다.
        `DashboardCPUCardUITests`가 `User [0-9]+%`·`System [0-9]+%` 정규식으로 라벨을 훑으므로, 새 문구는 별도 절로 붙여야 그 매칭이 유지된다.
      - 테스트 실행은 `ResourceRunnerTests` 전체와 UI 스위트 `DashboardCPUCardUITests`만 돌린다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.2, §5.9 / DESIGN §5 DP4, DP5, DP13

- [x] task-003: 색 램프를 리소스별 한 색조 네 단계로 교체
  - 목적: CPU와 Memory가 서로 다른 색조로 표시되어 어느 카드·어느 상세를 보고 있는지 색으로 알 수 있고,
    Memory 구성 네 구간이 한 색조의 단조 명도 램프로 그려져 색을 지운 화면에서 네 구간이 순서와 명도로 구분된다.
    CPU 두 계열의 색 외 구분도 변경 전보다 강해진다.
  - 접근: 두 색조 × 두 단계 상수를 리소스별 한 색조 × 네 단계 램프로 재구성하고 라이트·다크 각 열여섯 값을 각각 확정해 넣는다.
    CPU 아래 밴드(User)에 step 3, 위 밴드(System)에 step 1을 주고 채움 불투명도를 0.60 / 0.15로 옮긴다.
  - 검증 조건:
    - 결과: 단계의 뜻이 두 모드에서 같다 — step 1이 배경 대비가 가장 크고 step 4가 가장 작으며, 라이트에서 step 1이 가장 어둡고 다크에서 가장 밝다.
      Memory 구성은 App → Wired → Compressed → Cached가 step 1 → 2 → 3 → 4이고, `MemoryCompositionCategory`를 받는 진입점은 그대로다.
      코어 채움은 단계를 받는 진입점이 새로 생기고, `cpuGridline`·`cpuCoreTrack`·`memoryCompositionTrack`은 구분 대상이 아닌 배경 대비 요소라 시스템 색으로 남는다.
      M3의 Network·Disk 자리는 색조 각도만 더해 같은 생성 규칙으로 확장되는 형태로 남는다.
      요약 줄 스와치는 지금처럼 밴드와 같은 유도 함수를 쓰고, 격자 그리기 순서는 그대로다.
    - 확인:
      - sRGB↔CIELAB 변환과 WCAG 명도대비 검증기를 열여섯 값에 실행해,
        배경 근사(라이트 `#ECECEC` / 다크 `#2E2E2E`)에서 열여섯 값이 모두 대비 3:1 이상임을 출력으로 확인한다.
        3:1을 통과하므로 relief 조건에 기대는 자리가 없음을 함께 확인한다.
      - 같은 검증기로 CPU 두 밴드의 합성 후 ΔL\*를 재고, 라이트·다크 두 값의 최솟값이 변경 전(라이트 10.5 / 다크 25.1의 최솟값 10.5)보다 큼을 확인한다.
        채움 밀도 차가 0.35에서 0.45로 벌어짐을 함께 확인한다.
      - 같은 검증기로 격자선이 밴드 안에 남기는 L\* 차이를 재고, 변경 전과 같은 수준이라 기준선이 밴드 아래에서 계속 비침을 확인한다.
      - 같은 검증기로 Memory 네 구간의 인접 계단 ΔL\*를 재고, 네 구간의 L\*가 모두 갈려 회색조에서 어느 구간인지 순서로 좁혀짐을 확인한다.
      - `bandFillOpacitiesAreTranslucentSoGridlinesShowThrough`의 `fillOpacity(.lower) == 0.55` / `(.upper) == 0.20`을 새 값으로 갱신하고,
        두 값이 모두 1.0 미만이라는 단언은 그대로 둔다.
      - 아래 밴드 경계선이 점선이고 위 밴드 경계선이 실선이라는 단언을 새로 더한다.
        현재 `boundaryStyle(for:)`의 반환값을 잠그는 단위 테스트가 없어, 위 밴드 채움이 0.15로 옅어지는 대가를 경계선이 받는다는 근거가 지금은 회귀 보호를 갖지 못한다.
      - `HistoryGraphViewDrawOrderTests`의 레이어 순서 단언이 task-001의 새 목록 그대로 통과한다.
      - `cpuSeriesSwatchesShareHueAndUseDifferentBrightnessSteps`의 밝기 방향 단언(`user.brightness > system.brightness`)을
        「두 스와치의 색조가 같고 램프 단계가 다르다」는 모드에 무관한 형태로 다시 쓰고 통과시킨다.
        새 배정에서 아래가 step 3·위가 step 1이라 그 방향은 다크에서 뒤집힌다.
        단언을 지우거나 완화하지 않는다.
      - 범례 조립(스와치 뒤에 이름이 반드시 따라오는 계약)과 CPU 값 없음 요약 줄의 두 스와치 단언이 그대로 통과한다.
      - 테스트 실행은 `ResourceRunnerTests` 전체만 돌린다.
        이 Task는 접근성 이름·식별자·프레임을 건드리지 않고 UI 스위트는 색을 조회하지 않으므로 UI 스위트를 돌리지 않는다.
      - 수동 확인: 라이트·다크 두 모드에서 CPU 카드의 그래프 밴드와 Memory 카드의 구성 바가 색조로 갈리고 화면에 색감이 돌아왔는지 —
        대비·ΔL\* 측정으로 대체되지 않는 잔여 판단이다.
  - 참조: SPEC §5.4, §5.5 / DESIGN §5 DP6, DP7

- [x] task-004: 코어 격자 막대를 사용률 네 단계 색으로 칠한다
  - 목적: CPU 상세의 코어 격자가 무채색으로 죽은 영역이 아니라 사용률에 따라 네 단계의 CPU 색조로 표시되고,
    색을 지운 화면에서 코어 사이 높낮이 비교가 변경 전과 같은 정도로 성립한다.
  - 접근: 사용률을 유한한 단계로 옮기는 순수 함수를 두고 단계 경계를 그래프 기준선 배열에서 유도한다.
    코어 칸의 채움 색이 그 단계로 CPU 램프에서 색을 고르고, 트랙은 무채색 시스템 색으로 남긴다.
  - 검증 조건:
    - 결과: 단계는 넷이고 배정은 사용률 75% 이상 = step 1, 50–75% = step 2, 25–50% = step 3, 25% 미만 = step 4다.
      단계 경계가 `HistoryGraphGridline.baselineValues`에서 유도되어 새 리터럴이 없고, 카드 그래프의 기준선과 코어 막대의 단계 경계가 같은 값을 가리킨다.
      칸 안 세 줄 조립과 칸 크기, 격자 배치 규칙(행·열 분할, 열 상한 8)은 바뀌지 않는다.
      코어 칸의 접근성 계약(`children: .ignore` + `.isStaticText` + 라벨 「코어 N」 + 값 「N%」 + `CPUCore-N` 식별자 + 하위 요소 0개)이 그대로다.
      tick마다 칸 하나가 하는 일은 정수 비교 최대 세 번과 이미 확정된 상수 선택뿐이고, 색 보간도 새 이미지 생성도 없다.
    - 확인:
      - 단계 수가 넷이고 경계값이 기준선 배열에서 유도됨을 단언하며, 기준선 배열을 바꾸면 경계가 따라오는지 단언한다.
      - 각 경계의 바로 아래·바로 위 사용률이 서로 다른 단계로 갈림을 단언하고, 사용률이 다른 두 코어 칸의 채움 색이 그 구간에서 다름을 단언한다.
      - 네 단계 색이 라이트·다크 모두 배경 대비 3:1 이상임을 단언한다.
      - `CPUCoreUsageGridTests`의 채움 잉크 판정 임계값 `coreBarFillAlphaThreshold`는 트랙·채움 두 색의 알파 중간값에서 유도된다.
        채움이 유채색 상수가 되면 이 유도가 뜻을 잃으므로 「채움이 트랙보다 배경 대비가 크다」는 판정으로 바꾸고,
        그 임계값을 쓰는 `fillHeightFollowsCoreUsage`(값 0에서 채움 0줄, 값 100에서 트랙 높이, 채움 높이가 값 순서를 따름)와
        `barTrackHeightIsIndependentOfUsage`(트랙 띠 높이가 값과 무관)가 그대로 통과하게 한다.
        두 단언은 색을 지운 화면에서 높낮이 비교가 성립한다는 근거이므로 지우거나 완화하지 않는다.
      - 같은 파일의 `cellDrawsBarThenValueThenCoreNumber`(잉크 띠 세 개와 막대 → 수치 → 번호 순서)와
        `gridHeightStacksExactlyTheLayoutRowCount`(격자 높이 공식)가 그대로 통과한다.
      - `DetailPopoverValuelessStateTests`의 기준 조립 `ReferenceCoreCell`이 `cpuCoreFill` 상수 대신 새 단계 진입점을 쓰도록 따라가고,
        `everyNewElementExistsOnlyInNormalAndHasSensitivity`의 `.coreBarTrack`·`.coreBarFill` 감도 자기점검이
        production 코어 칸과 픽셀 단위로 일치하며 `DetailPopoverNewDisplayElement` 9개 전수 단언이 그대로 통과한다.
      - `CPUCoreGridVerticalBudgetTests`의 `gridFitsTheFirstScreenOnTheReferenceDevice`(14코어 아래끝 166),
        `fiftySixCoresIsTheLastCountThatFits`(446), `beyondFiftySixCoresTheGridOverflowsTheFirstScreen`(57·65·80·128 넘침)이
        움직이지 않음을 확인한다.
        이 Task가 이 값을 건드리지 않는다는 것 자체가 회귀 방지 단언이다.
      - 테스트 실행은 `ResourceRunnerTests` 전체와 UI 스위트 `CPUCoreAccessibilityUITests`만 돌린다.
        코어 칸에 색 단계를 넣어도 칸이 하나의 접근성 노드로 남고 하위 요소가 0인지가 이 스위트에서 확인된다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
      - 수동 확인: 라이트·다크 두 모드에서 단계 색이 정상·경고·위험 상태 신호로 읽히지 않고 하나의 색조 안 명도 램프로 읽히는지 —
        대비·색조 단언으로 대체되지 않는 잔여 판단이다.
  - 참조: SPEC §5.4, §5.5, §5.9, §5.11, §5.12 / DESIGN §5 DP8, DP12, DP13

- [x] task-005: 상세 하위 프로세스 행의 네 경계를 좁힌다
  - 목적: 상세 팝업에서 앱 행을 펼쳤을 때 하위 행 묶음이 차지하는 세로가 변경 전보다 줄고,
    부모–첫 하위·하위끼리·마지막 하위–다음 앱 세 경계가 여전히 서로 같은 간격으로 보이지 않는다.
  - 접근: 네 경계를 리터럴에서 「하위 행 안 간격 + 라벨과 대상 사이 간격 × k」(k = 0…3) 유도식으로 바꿔 2 / 6 / 10 / 14로 내린다.
    행 조립과 가로 들여쓰기는 건드리지 않는다.
  - 검증 조건:
    - 결과: 네 경계가 2 / 6 / 10 / 14pt이고 펼친 내용 아래 여백이 12pt이며, 펼침 증가분이 `50 + (n − 1) × 34`다.
      네 값은 여백 단계 두 개에서 유도되어 리터럴이 사라지고, 새 여백 단계를 만들지 않는다.
      네 값이 모두 다르고 층을 넘을수록 넓어지며, 구분 수단은 들여쓰기와 간격뿐이라 구분선·배경·테두리가 없다.
      `childIndent`·`childValueIndent` 유도식과 두 층의 시작선 정렬은 그대로다.
      하위 3개에서 146 → 118pt, 하위 5개에서 222 → 186pt로 줄어든다.
    - 확인:
      - `boundariesMeasureTwoTenEighteenTwentySix`의 네 값을 여백 단계에서 유도한 형태로 다시 쓰고 리터럴 비교를 쓰지 않는다.
      - `boundariesAreDistinctAndOrdered`의 `within < between < top < bottom`과 네 값이 모두 다르다는 단언이 그대로 통과한다.
      - `expandedHeightFollowsTheFourBoundaries`의 `70 + (n − 1) × 38`을 새 공식으로 갱신하고,
        「펼침 증가분이 변경 전 공식의 값보다 작다」는 상한 단언을 더한다.
      - `bothFormatsUseTheSameRowGeometry`의 하위 2개 증가분 108을 새 공식에서 나온 값으로 갱신하고,
        CPU 상세와 Memory 상세가 같은 행 기하를 쓴다는 성질은 그대로 유지한다.
      - `collapsedRowsKeepTheirPreviousSpacing`의 접힘 행 높이와 `afterLastChild == 24`를 새 값으로 갱신한다.
      - `startsAreDerivedFromTheParentLabelGeometry`·`childLinesHaveDistinctSemanticStarts`의 들여쓰기 유도식과 시작선 단언이 그대로 통과한다.
      - `productionNameAndValueFitOnSeparateLines`의 두 줄 폭이 목록 안쪽 폭 안에 든다는 단언이 그대로 통과한다.
      - `CPUCoreGridVerticalBudgetTests`의 14코어 격자 아래끝 166과 56코어 상한이 움직이지 않음을 확인한다.
        하위 행 경계는 격자 아래 영역이라 이 값에 닿지 않는다.
      - `DetailPopoverValuelessStateTests`의 `framesStayFixedAcrossAllStates`(400×480)가 그대로 통과한다.
      - 테스트 실행은 `ResourceRunnerTests` 전체와 UI 스위트 `DashboardProcessListDisplayUITests`·`DashboardDetailExpansionUITests`만 돌린다.
        하위 행 아래 `StaticText`가 정확히 두 개인지와 앱 행 펼침·접힘이 그대로인지가 두 스위트에서 확인된다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.6, §5.9, §5.12 / DESIGN §5 DP9, DP12

- [x] task-006: 카드 순위 안내를 목록 머리글로 옮긴다
  - 목적: 카드 순위 자리에서 시스템 프로세스 안내가 목록 아래 한 줄을 통째로 차지하지 않고 목록의 이름표가 되며,
    시스템 프로세스가 순위에 포함되지 않는다는 사실을 여전히 카드 화면에서 확인할 수 있다.
  - 접근: 카드용 짧은 머리글 문구를 만드는 순수 함수를 더하고, 카드 순위 묶음에서 목록 아래 캡션 줄을 지운 뒤 목록 위에 머리글 역할로 그 문구를 둔다.
    기존 캡션 함수는 상세 증가량 순위와 앱 목록이 계속 쓰므로 그대로 남긴다.
  - 검증 조건:
    - 결과: 카드 문구는 `앱 TOP 5 · 시스템 프로세스 제외`이고 역할은 11pt semibold 보조 전경, 머리글과 목록 사이 간격은 4pt다.
      순위 정원 5줄과 아이콘 자리·값 열 규칙은 그대로이고, 순위 묶음 높이가 88 → 90pt가 된다.
      정원 숫자는 문구에 직접 박히지 않고 카드 정원 상수에서 나온다.
      상세 증가량 순위와 앱 목록의 기존 캡션 문구는 그대로다.
      카드 접근성 이름의 안내 문구가 머리글 문구로 바뀌고 나머지 항목은 그대로 남는다.
    - 확인:
      - 새 머리글 문구를 만드는 함수의 단언을 더하고, 정원을 바꾸면 문구의 숫자가 따라옴을 단언한다.
      - `ApplicationRankingTests`의 `captionEmbedsTheGivenCountExactly`·`captionDiffersBetweenCardAndDetailGantries`가 그대로 통과한다.
        기존 캡션 함수는 상세가 계속 쓰므로 단언이 대상을 잃지 않는다.
      - `recentIncreaseRankingCaptionMatchesDetailGantryNotCardGantry`가 그대로 통과한다.
      - `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsCaption`과 Memory 카드 접근성 이름 단언의 안내 문구를 머리글 문구로 갱신하고,
        변경 전에 들어 있던 나머지 항목이 모두 남아 있음을 항목별로 단언한다.
      - 머리글 문구의 이상적 폭이 카드 콘텐츠 폭 232pt 안에 듦을 측정으로 단언한다.
      - `DashboardCardLayoutTests`의 `CardHeightBaseline.cpu`·`CardHeightBaseline.memory`를 새 조립의 실측값으로 갱신하고,
        task-001이 세운 하한·상한 단언과 `borderOnlySurfaceKeepsPreSurfaceChangeCardHeights`가 그대로 통과한다.
      - 같은 파일의 픽셀 영역 리터럴 가운데 순위 자리를 보는 `cpuFirstRankingIcon`을 머리글이 생긴 순서에서 다시 계산해 갱신하고,
        `cardRankingRowActuallyRendersProvidedIconInItsSlot`이 통과한다.
      - 여섯 상태에서 카드 높이가 하나로 같다는 단언과 순위 자리 5줄 정원 단언이 그대로 통과한다.
      - 테스트 실행은 `ResourceRunnerTests` 전체와 UI 스위트 `DashboardCPUCardUITests`·`DashboardMemoryCardUITests`만 돌린다.
        `DashboardCPUCardUITests`의 안내 문구 부분일치 단언을 머리글 문구로 갱신하고, Memory 카드는 같은 순위 묶음을 쓰므로 프레임·라벨 단언이 그대로 통과하는지 확인한다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.7, §5.9 / DESIGN §5 DP10, DP12

- [x] task-007: 본체와 상세의 고정 크기를 다시 확정한다
  - 목적: 커진 카드에 맞춰 본체 팝오버 높이가 실측으로 다시 확정되고 상세 크기가 재확인되며,
    수집 상태가 바뀌어도 상세를 열고 닫아도 앱 행을 펼치고 접어도 팝오버와 카드의 크기·위치가 변하지 않는다.
    카드가 넷이 된 상태의 세로 합계가 화면 안에 들어간다는 계산이 실측 카드 높이와 어긋나지 않는다.
  - 접근: 본체 높이 제약을 임시로 걷어 XCUITest로 팝오버 프레임 높이를 수집 중 상태와 정상 상태 둘 다 읽고,
    읽은 값에서 팝오버 자체 여백 26pt를 뺀 값을 고정 높이로 넣은 뒤 제약을 되건다.
    상세 400×480은 같은 절차로 재확인한다.
  - 검증 조건:
    - 결과: 본체 고정 높이와 팝오버 프레임이 실측에서 나온 기준값으로 확정되고, 그 값이 어떤 절차에서 나왔는지가 상수 자리에 함께 남는다.
      수집 중 상태와 정상 상태의 값이 같다.
      상세 크기는 재확인 결과 400×480 그대로다.
      네 상태·상세 열고 닫기·앱 행 펼침과 접힘·스크롤 전후에서 팝오버 프레임과 두 카드 프레임이 같다.
      임시 계측 코드는 남지 않는다.
      실측 카드 높이를 넣은 본체 콘텐츠와 M3 카드 넷 합계가 기준 기기 `visibleFrame` 1084pt 안에 든다.
    - 확인:
      - 높이 제약을 걷은 상태에서 앱 시작 직후 수집 중 상태와 첫 수집이 도착한 정상 상태의 팝오버 프레임 높이가 서로 같음을 확인한다.
        갈리면 그래프 슬롯이나 축 라벨 줄의 자리표시가 상태별로 다른 높이를 쓰는 것이므로 그 자리를 먼저 고친다.
      - 그 값에서 26pt를 뺀 값을 본체 높이 상수에 넣고 제약을 되건 뒤, 팝오버 프레임 높이가 다시 같은 값으로 나오는지 XCUITest로 단언한다.
      - `testDashboardPopoverKeepsItsMeasuredHeightFromCollectingToNormal`의 본체 팝오버 프레임 리터럴(수집 중·정상 두 상태)을 확정값으로 갱신하고,
        두 상태가 같은 값이어야 한다는 단언은 그대로 둔다.
      - 후보 상세 폭에서 CPU 상세 앱 행·Memory 상세 범례 행·코어 격자의 이상적 폭이 콘텐츠 폭 368pt를 넘지 않고,
        14코어 격자 아래끝 166이 높이 480 안에 듦을 단위 테스트로 단언한다.
      - `DashboardDetailPopoverUITests`의 `expectedDetailSize` 리터럴이 재확인 결과와 같음을 확인하고,
        `testCPUDetailFrameRemainsExactlyFixedWhenAppRowExpands`·`testDetailContentScrollsWithinFixedPopoverFrame`이 통과한다.
      - `testCardSelectionLifecycleKeepsFramesFixedAndSurvivesSelfDismissal`의 카드·본체 프레임 불변 단언과
        `testMemoryCardFrameStaysSameBeforeAndAfterFirstCollection`이 통과한다.
      - 실측 카드 높이를 DESIGN §5 DP1의 모델 1 식(본체 = `32 + CPU + 16 + Memory`, M3 = `574 + 3S`)에 넣어
        M3 팝오버 프레임이 1084pt 안에 드는지 다시 계산하고, 산술 예상(CPU 290 / Memory 171 / 콘텐츠 509 / 프레임 535)과의 차를 기록한다.
        어긋나면 실측을 따르고 예산 계산을 실측값으로 다시 쓴다.
      - 카드 높이 상한 단언을 그 예산에서 나온 값으로 두고 통과시킨다.
      - 임시 계측 코드와 걷어냈던 제약이 원래대로 돌아왔음을 diff로 확인한다.
      - 테스트 실행은 `ResourceRunnerTests` 전체와 UI 스위트
        `ResourceRunnerUITests`·`DashboardDetailPopoverUITests`·`DashboardCardSelectionUITests`·`DashboardMemoryCardUITests`만 돌린다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.3, §5.8, §5.12 / DESIGN §5 DP1, DP11, DP12

- [x] task-008: 동작 줄이기 전제 없음과 자체 부하 비상승 확인
  - 목적: 동작 줄이기와 애니메이션 끄기 설정에서도 새 표시가 같은 정보를 전달하고,
    팝오버를 열어 둔 채 관찰한 앱 자신의 CPU 사용량이 변경 전과 비교해 지속적으로 오르지 않는다.
  - 접근: 이 feature가 더한 표시(세로 눈금, 판 테두리, 미수집 빗금, 축 라벨 줄, 새 색 열여섯, 조정된 여백)에
    애니메이션이 걸리지 않았고 갱신 주기마다 늘어나는 작업이 상시가 아님을 변경 범위 전체에서 확인한 뒤,
    변경 전후 자체 CPU 사용량을 같은 조건에서 관찰해 견준다.
  - 검증 조건:
    - 결과: 표시 경로에 `withAnimation`·`transition`·암시적 애니메이션을 새로 건 자리가 없고, 기존 주기적 재그리기 한 곳만 남는다.
      새 타이머·새 관찰자·새 이미지 생성이 없고, 색 해석은 갱신 주기가 아니라 appearance가 바뀔 때만 일어난다.
      미수집 빗금은 창이 찬 뒤 그리는 선분이 0개가 된다.
      다운샘플 버킷 수는 판 폭 232pt에서 나오므로 판이 높아져도 그대로다.
      App Sandbox가 켜진 채이고 새 entitlement가 없다.
    - 확인:
      - 표시 계층 production 파일에서 애니메이션 사용 자리를 훑어 이 feature가 새로 더한 자리가 없음을 diff로 확인한다.
      - tick마다 늘어나는 일이 세로 눈금 4선분·판 테두리 1경로·진행 문구 1문자열·코어 칸당 정수 비교 최대 3회뿐임을 diff로 확인한다.
      - 빗금이 미수집 구간이 남아 있는 동안에만 그려지고 창이 찬 뒤에는 선분이 0개가 되는 조건을 단위 테스트로 확인한다.
      - entitlements 파일이 변경 전과 같고 App Sandbox 설정이 그대로임을 확인한다.
      - 전체 스킴(`ResourceRunnerTests`와 `ResourceRunnerUITests` 열 스위트 전부)을 돌려 통과시킨다.
        이 feature에서 전체 스킴을 돌리는 자리는 여기 한 번뿐이며,
        앞선 Task들이 돌리지 않은 `StatusItemAccessibilityUITests`·`ResourceRunnerUITestsLaunchTests`도 여기서 함께 확인된다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
      - 수동 확인: 동작 줄이기와 애니메이션 끄기를 켠 환경에서 그래프 판·축 라벨 줄·미수집 빗금·코어 단계 색이 같은 정보를 보이는지,
        그리고 팝오버를 열어 둔 채 앱 자신의 CPU 사용량을 변경 전과 같은 조건으로 관찰해 지속 상승이 없는지 —
        정적 확인으로 대체되지 않는 잔여 판단이다.
  - 참조: SPEC §5.10, §5.11 / DESIGN §5 DP13
