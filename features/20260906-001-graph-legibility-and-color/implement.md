# 그래프 가독성과 색감 회복 구현

- [ ] task-001: 그래프 판을 키우고 영역 경계와 시간 축을 둔다
  - 목적: CPU 카드의 그래프가 착수 전보다 높은 면으로 그려지고, 판의 네 변이 화면에서 그래프 영역의 경계로 읽히며,
    판 아래 축 라벨 줄과 판 안 세로 눈금으로 창이 얼마나 긴지 알 수 있다.
    값이 없는 자리표시 상태에서도 같은 자리에 같은 크기로 같은 경계와 눈금이 나타난다.
  - 접근: 이 동작은 이미 코드에 들어 있으므로 처음부터 다시 만들지 않는다.
    판 높이·슬롯 높이 상수, 세로 눈금과 판 테두리 레이어, 축 라벨 줄 조립이 아래 결과와 맞는지 먼저 확인하고 어긋난 자리만 고친다.
  - 검증 조건:
    - 결과: 그래프 슬롯이 판 100 + 라벨과 대상 사이 간격 4 + 축 라벨 줄 13 = 117pt이고, 값 있음 경로와 자리표시 경로가 같은 슬롯 높이를 쓴다.
      판의 가로세로 비가 232 : 100 = 2.32 : 1로 착수 전 약 3.9 : 1보다 낮고, 판 높이가 착수 전 60pt보다 크다.
      기준선 25·50·75% 세 줄과 User·System 두 계열 구분(채움 밀도 차, 아래 점선·위 실선 경계)이 그대로다.
      축 라벨 줄은 왼쪽 「10분 전」·오른쪽 「지금」이고 가운데는 같은 높이의 슬롯이라 문자열이 없어도 줄 높이가 갈리지 않는다.
      세로 눈금은 창을 다섯 등분하는 네 줄이고 등분 수가 고정이며 간격이 창 길이에서 유도된다.
      눈금 색·두께·그리기 레이어는 가로 기준선과 같다.
      판 테두리는 격자와 같은 시스템 구분선 색이고 그리기 순서가 맨 마지막이라 값이 100%에 닿는 구간에서도 위 변이 밴드 채움에 덮이지 않는다.
      자리표시 경로는 격자·세로 눈금·판 테두리를 같은 좌표에 그리고 점도 선도 그리지 않는다.
      선 두께 1.0pt와 다운샘플 버킷 수는 그대로다.
      어긋난 자리가 없으면 코드를 고치지 않는다.
    - 확인:
      - `DashboardPresentationTests`의 `graphSlotHeightIsDerivedFromPlotAxisSpacingAndLabelHeight`가 통과하고,
        슬롯 높이가 판 높이·간격·라벨 줄 높이의 합에서 유도되며 리터럴 117이 두 자리에 복제되지 않았음을 코드로 확인한다.
      - 같은 파일의 `graphPlotIsTallerAndLessHorizontallyCompressedThanBefore`(판 높이 > 60pt, 가로세로 비 < 3.9 : 1)가 통과한다.
      - `drawOrderIsGridlinesThenFillsBoundariesAndGraphBorder`와 `placeholderDrawOrderContainsGridlinesUncollectedRegionThenGraphBorder`의
        배열 단언이 통과하고, 판 테두리가 두 목록 모두에서 마지막임을 단언이 잡는다.
      - `fourVerticalTicksDivideAnyPositiveTimeRangeIntoFifths`가 통과하고, 창 길이를 바꿔도 등분 수가 넷으로 유지됨을 단언이 잡는다.
      - `baselineValuesAreExactlyTwentyFiveFiftySeventyFive`·`zeroPercentIsAtTheBottomAndHundredPercentIsAtTheTop`·`yPositionScalesWithHeight`가 통과한다.
      - `DashboardCardLayoutTests`의 카드 높이 기준값과 상한, 픽셀 영역 리터럴
        `cpuPlaceholderSummary`·`cpuPlaceholderGraph`·`cpuFirstRankingIcon`이 현재 값 그대로 통과한다.
      - `cpuGraphPlaceholderDoesNotRenderInventedZeroValues`의 「채도 0.35 초과 픽셀 0」이 통과한다.
        세로 눈금과 판 테두리가 격자와 같은 시스템 구분선 색이어야 이 판정이 성립하므로 그 색을 유채색으로 바꾸지 않는다.
      - `everyValuelessStateRendersEveryNewDisplayElement`의 「CPU 그래프 격자 픽셀 > 0」 판정이 통과한다.
      - `cpuCardHeightIsSameAcrossAllFourStates`·`memoryCardHeightIsSameAcrossAllFourStates`·`cardHeightsMatchBaselinesAcrossEveryStateWithNewElements`의
        상태별 카드 높이 동일 단언이 통과한다.
      - `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsHeading`의 기준선 문구와 두 계열 문구가 통과한다.
      - 테스트 실행은 `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -only-testing:ResourceRunnerTests`로 단위 스위트만 돌린다.
        전체 스킴은 이 Task에서 돌리지 않는다.
  - 참조: SPEC §5.1, §5.2, §5.8, §5.13 / DESIGN §5 DP2, DP3, DP4, DP13

- [ ] task-002: 아직 수집되지 않은 구간을 빗금과 수집 진행 문구로 드러낸다
  - 목적: 앱을 켠 직후처럼 10분 창의 대부분이 비어 있을 때 그 구간이 값 0이 아니라 아직 수집되지 않은 구간으로 화면에서 구분되고,
    얼마나 모였는지가 그래프 아래 문구와 카드 접근성 이름에서 읽힌다.
  - 접근: 이 동작은 이미 코드에 들어 있으므로 처음부터 다시 만들지 않는다.
    미수집 비율·축 문자열을 내놓는 순수 계산 자리와 빗금 레이어, 축 라벨 줄 가운데 슬롯, 카드 접근성 이름이 아래 결과와 맞는지 확인하고 어긋난 자리만 고친다.
  - 검증 조건:
    - 결과: 미수집 구간은 창 왼쪽 끝부터 첫 표본 시각까지이고, 표본이 하나도 없으면 창 전체다.
      중지·실패로 생긴 중간 공백은 이 판정의 대상이 아니며 지금처럼 선이 끊기는 것으로만 표현된다.
      진행 문구는 「데이터 수집 중 · mm:ss / 10:00」 형태이고, 창이 다 차면 문자열이 비지만 줄은 남아 카드 높이가 갈리지 않는다.
      빗금은 색이 아니라 패턴이고 무채색이라 색을 지운 화면에서도 미수집 구간이 구분되며, 점도 선도 그리지 않아 값을 지어내지 않는다.
      값이 하나도 없는 자리표시 상태에서는 판 전체에 빗금이 깔리고, 창이 찬 뒤에는 빗금 선분이 0개가 된다.
      카드 접근성 이름에 시간 창 길이와 수집 진행이 들어 있고, 착수 전 항목(초점 수치·상태·두 계열·기준선·순위 안내·단축키)이 하나도 빠지지 않는다.
      어긋난 자리가 없으면 코드를 고치지 않는다.
    - 확인:
      - `emptyPointsMarkTheWholeWindowAsUncollected`·`firstPointInTheMiddleDeterminesTheUncollectedWidth`·
        `fullWindowHasNoCollectionProgressTextButKeepsTheSameSlotHeight`가 통과해 세 입력의 미수집 비율과 슬롯 높이 불변을 잡는다.
      - `middleGapDoesNotChangeTheFirstPointBasedUncollectedWidth`가 통과해 중간 공백이 미수집으로 판정되지 않음을 잡는다.
      - `collectionProgressUsesElapsedAndTotalDurations`와 `fullWindowDrawsNoUncollectedHatchSegments`가 통과한다.
      - `placeholderDrawOrderContainsGridlinesUncollectedRegionThenGraphBorder`에서 미수집 구간이 격자·세로 눈금 다음이고 판 테두리 앞임이 통과한다.
      - `cpuGraphPlaceholderDoesNotRenderInventedZeroValues`의 「채도 0.35 초과 픽셀 0」이 통과한다(빗금이 무채색이다).
      - `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsHeading`과
        `valuelessFailureAndStoppedStatesKeepTheTimeWindowAndCollectionProgress`가 통과하고,
        착수 전 접근성 이름 항목이 항목별 단언으로 남아 있음을 확인한다.
      - 수집 진행 절이 카드 접근성 이름의 기존 값 구간 안쪽에 끼어 있지 않음을 확인한다.
        `DashboardCPUCardUITests`가 `User [0-9]+%`·`System [0-9]+%` 정규식으로 라벨을 훑으므로, 문구가 별도 절로 붙어 있어야 그 매칭이 유지된다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와 `-only-testing:ResourceRunnerUITests/DashboardCPUCardUITests`만 돌린다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 0이 아니면 잔류 인스턴스를 정리한 뒤 다시 돌린다.
        잔류 인스턴스가 메뉴바를 채우면 status item을 찾지 못해 본문에 닿기 전에 전부 실패한다.
        화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.2, §5.9 / DESIGN §5 DP4, DP5, DP14

- [ ] task-003: Memory 구성 색을 두 색조 각 두 단계로 되돌린다
  - 목적: Memory 카드의 구성 누적 바와 상세 도넛에서 App·Wired·Compressed·Cached 네 구간이 파랑 둘·주황 둘로 갈려 표시되고,
    바 위에서 이웃한 두 구간은 색을 지워도 밝기로 갈리며 어느 구간인지는 스와치 옆 범례 이름으로 확인된다.
    CPU 두 밴드의 색과 색 외 구분은 그대로 남는다.
  - 접근: 팔레트의 Memory 자리만 주황 한 색조 네 단계 램프에서 두 색조 각 두 단계 상수 여덟 개로 바꾸고,
    카테고리를 직접 받는 진입점 하나만 남겨 단계를 밖으로 내놓는 진입점을 없앤다.
    CPU 램프·트랙·격자 상수와 production 소비 지점 조립은 건드리지 않는다.
  - 검증 조건:
    - 결과: 라이트가 App `#165698` · Wired `#4b82d0` · Compressed `#83441d` · Cached `#ba6e41`,
      다크가 App `#5287d5` · Wired `#a1bbf5` · Compressed `#c07345` · Cached `#ecae8c`이고 라이트·다크를 각각 따로 둔다.
      App·Wired가 한 색조, Compressed·Cached가 다른 색조이며 각 색조 안에서 앞 항목이 더 어둡다.
      표시 순서 App → Wired → Compressed → Cached에서 이웃한 두 구간의 `L*`가 서로 다르다.
      네 값이 회색조에서 두 쌍(App≈Compressed, Wired≈Cached)으로 붙는 것은 허용되며, 스와치 옆 범례 이름이 항상 보여 네 구간을 이름으로 가린다.
      여덟 값이 모두 배경 대비 3:1 이상이라 relief 조건에 기대는 구간이 없다.
      구성 바·도넛·카드 범례·상세 범례 네 자리가 모두 카테고리를 받는 같은 진입점을 지나가고, 단계를 받는 Memory 진입점은 남지 않는다.
      CPU 램프 여덟 값, `cpuUser`·`cpuSystem`의 단계 배정, 밴드 채움 0.60 / 0.15와 아래 점선·위 실선 경계,
      `cpuGridline`·`cpuCoreTrack`·`memoryCompositionTrack`의 시스템 색이 모두 그대로다.
    - 확인:
      - `DashboardColorPaletteTests`에 Memory 네 색을 보는 단언 셋을 두고 통과시킨다 —
        「네 색이 두 색조로 갈리고 각 색조 안에서 앞 항목이 더 어둡다」,
        「네 색 모두 라이트·다크 배경 근사(`#ECECEC` / `#2E2E2E`)에서 대비 3:1 이상」,
        「표시 순서에서 이웃한 두 구간의 `L*`가 서로 다르다」.
        마지막 항목이 회색조 구분의 최소선을 잠근다.
      - 같은 파일의 `memoryCategoriesUseAllFourStepsInOrder`(카테고리 색 == 램프 네 단계, 네 `L*`가 모두 다름)를 위 새 형태로 다시 쓴다.
        네 `L*`가 모두 다르다는 단언은 요구가 바뀌었으므로 남기지 않고, 그 자리를 위 세 단언이 메운다.
      - `allSixteenColorsMeetContrastAndKeepTheSameStepMeaning`이 순회하는 램프에서 Memory를 빼고 CPU 여덟 색 단언은 그대로 통과시킨다.
      - `cpuAndMemoryKeepDistinctResourceHues`(CPU와 Memory의 색조 거리 > 0.1)는 그 요구가 SPEC §3에서 철회돼 대상을 잃었으므로 지운다.
        요구가 남아 있는 단언을 지우는 것과 다른 자리임을 근거로 남기고, 다른 단언을 함께 지우거나 완화하지 않는다.
      - `cpuBandsAndCoreEntryUseTheCPUResourceRamp`·`cpuBandCompositeLightnessDifferenceImprovesInBothAppearances`(합성 ΔL\* > 10.5, 밀도 차 0.45)가
        손대지 않은 채 통과한다.
      - `DashboardPresentationTests`의 `bandFillOpacitiesAreTranslucentSoGridlinesShowThrough`와
        `lowerBoundaryIsDashedAndUpperBoundaryIsSolid`가 통과한다.
      - `DashboardCardLayoutTests`의 `cpuSeriesSwatchesShareHueAndUseDifferentBrightnessSteps`와
        Memory 범례 폭 조립·`cardDrawsCompositionSegments`·`memoryCardHeightMatchesRefinedAssemblyBaselineAndPreviousUpperBound`가 통과한다.
      - `MemoryCompositionTests`의 `legendFollowsBarSegmentOrderWithNames`(범례 항목 순서가 바 구간 순서와 같고 스와치마다 이름이 붙는다)가 통과한다.
        이 단언이 색 비의존 relief의 잠금이므로 지우거나 완화하지 않는다.
      - `DetailPopoverValuelessStateTests`의 `production 전수 목록의 아홉 요소는 정상에만 있고 요소별 감도 점검을 통과한다`가 통과한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`만 돌린다.
        이 Task는 접근성 이름·식별자·프레임을 건드리지 않고 UI 스위트는 색을 조회하지 않는다.
      - 수동 확인: 라이트·다크 두 모드에서 Memory 구성 바와 상세 도넛의 색이 이 feature 착수 전 상태로 돌아왔는지 —
        지각 판정이라 대비·`L*` 측정으로 대체되지 않는 잔여 판단이다(DESIGN §근거 「추정으로 남는 것」).
  - 참조: SPEC §5.4, §5.5 / DESIGN §5 DP6, DP7, DP8, DP13

- [ ] task-004: 코어 격자 막대를 사용률 네 단계 색으로 칠한다
  - 목적: CPU 상세의 코어 격자가 무채색으로 죽은 영역이 아니라 사용률에 따라 네 단계의 CPU 색조로 표시되고,
    색을 지운 화면에서 코어 사이 높낮이 비교가 착수 전과 같은 정도로 성립한다.
  - 접근: 이 동작은 이미 코드에 들어 있으므로 처음부터 다시 만들지 않는다.
    단계 함수와 그 경계 유도, 코어 칸 채움 색 경로, 트랙의 무채색 유지가 아래 결과와 맞는지 확인하고 어긋난 자리만 고친다.
  - 검증 조건:
    - 결과: 단계는 넷이고 배정은 사용률 75% 이상 = step 1, 50–75% = step 2, 25–50% = step 3, 25% 미만 = step 4다.
      단계 경계가 그래프 기준선 배열에서 유도되어 새 리터럴이 없고, 카드 그래프의 기준선과 코어 막대의 단계 경계가 같은 값을 가리킨다.
      네 단계 색이 CPU 색조 하나 안의 명도 램프라 상태 신호로 읽히지 않고, 트랙은 무채색으로 남아 채움과 트랙의 경계가 명도로도 갈린다.
      칸 안 세 줄 조립과 칸 크기, 격자 배치 규칙(행·열 분할, 열 상한 8)이 바뀌지 않는다.
      코어 칸의 접근성 계약(하위 무시 + 정적 텍스트 + 라벨 「코어 N」 + 값 「N%」 + `CPUCore-N` 식별자 + 하위 요소 0개)이 그대로다.
      tick마다 칸 하나가 하는 일은 정수 비교 최대 세 번과 이미 확정된 상수 선택뿐이고, 색 보간도 새 이미지 생성도 없다.
      Memory 색을 되돌려도 이 자리의 값·판정이 움직이지 않는다.
      어긋난 자리가 없으면 코드를 고치지 않는다.
    - 확인:
      - `CPUCoreUsageGridTests`의 `코어 단계가 그래프 기준선에서 유도되고 기준선 변경을 따라간다`와
        `각 그래프 기준선의 바로 아래와 바로 위에서 코어 단계가 갈린다`,
        `단계가 갈리는 두 코어 사용률은 서로 다른 채움 색을 쓴다`가 통과한다.
      - 같은 파일의 `칸의 채움 높이가 그 코어의 값을 따라 커진다`·`막대 트랙 높이가 값과 무관하게 같다`·
        `칸이 위에서부터 막대 · 수치 · 번호 세 띠로 그려진다`·`격자 높이가 task-001이 정한 행 수만큼만 쌓인다`가 통과한다.
        앞 두 단언이 색을 지운 화면에서 높낮이 비교가 성립한다는 근거이므로 지우거나 완화하지 않는다.
      - `DashboardColorPaletteTests`에서 CPU 네 단계가 배경 대비 3:1 이상이고 램프 안 색조가 한 갈래임을 잡는 단언이 통과한다.
        이 단언이 「단계 색이 상태 경고로 읽히지 않는다」의 실행 가능한 근거다 — 색조가 갈리지 않고 명도만 움직인다는 사실을 잠근다.
      - `DetailPopoverValuelessStateTests`의 기준 코어 칸 조립이 단계 진입점을 그대로 쓰고,
        `production 전수 목록의 아홉 요소는 정상에만 있고 요소별 감도 점검을 통과한다`가 통과한다.
      - `CPUCoreGridVerticalBudgetTests`의 `논리 코어 14개에서 격자 아래끝이 팝업 첫 화면 안이다`(166),
        `논리 코어 56개가 첫 화면에 들어가는 마지막 코어 수다`(446),
        `코어 57개 이상에서는 격자 아래끝이 첫 화면을 벗어난다`가 움직이지 않음을 확인한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와 `-only-testing:ResourceRunnerUITests/CPUCoreAccessibilityUITests`만 돌린다.
        `testCoreCellIsOneReachableElementWithLabelValueAndIdentifier`가 코어 칸이 하나의 접근성 노드로 남고 하위 요소가 0인지를 잡는다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.4, §5.5, §5.9, §5.11, §5.12 / DESIGN §5 DP9, DP13, DP14

- [ ] task-005: 상세 하위 프로세스 행의 네 경계를 좁힌다
  - 목적: 상세 팝업에서 앱 행을 펼쳤을 때 하위 행 묶음이 차지하는 세로가 착수 전보다 줄고,
    부모–첫 하위·하위끼리·마지막 하위–다음 앱 세 경계가 여전히 서로 같은 간격으로 보이지 않는다.
  - 접근: 이 동작은 이미 코드에 들어 있으므로 처음부터 다시 만들지 않는다.
    네 경계가 리터럴이 아니라 여백 단계 유도식에서 나오는지와 그 값이 아래 결과와 맞는지 확인하고 어긋난 자리만 고친다.
  - 검증 조건:
    - 결과: 네 경계가 2 / 6 / 10 / 14pt이고 펼친 내용 아래 여백이 12pt이며, 펼침 증가분이 `50 + (n − 1) × 34`다.
      네 값은 「하위 행 안 간격 + 라벨과 대상 사이 간격 × k」(k = 0…3)로 유도되어 리터럴이 없고, 새 여백 단계를 만들지 않는다.
      네 값이 모두 다르고 층을 넘을수록 넓어지며, 구분 수단은 들여쓰기와 간격뿐이라 구분선·배경·테두리가 없다.
      가로 들여쓰기 유도식과 두 층의 시작선 정렬이 그대로다.
      어긋난 자리가 없으면 코드를 고치지 않는다.
    - 확인:
      - `ApplicationProcessRowLayoutTests`의 `네 간격은 하위 행 안 간격과 라벨 간격 단계에서 유도된다`가 통과하고 리터럴 비교가 없다.
      - 같은 파일의 `네 간격은 모두 다르고 층을 넘을수록 넓어진다`와
        `하위가 1·2·3개일 때 접힘 대비 50pt에서 34pt씩 늘어나며 변경 전보다 작다`가 통과한다.
        뒤 단언이 「펼침 증가분이 착수 전 공식보다 작다」는 상한을 잡는다.
      - `접힌 앱 행 사이 간격이 변경 전과 같다`·`CPU와 Memory 모두 같은 두 줄 높이와 시작선 규칙을 쓴다`·
        `시작선은 아이콘 크기와 라벨 간격에서 유도된다`·`이름은 부모 앱 이름과 같고 값은 아이콘 한 칸 더 들어간다`가 통과한다.
      - `production CPU 값과 긴 이름이 각 줄에서 360pt 안에 들어간다`가 통과한다.
      - `CPUCoreGridVerticalBudgetTests`의 14코어 격자 아래끝과 56코어 상한이 움직이지 않음을 확인한다.
        하위 행 경계는 격자 아래 영역이라 이 값에 닿지 않는다.
      - `DetailPopoverValuelessStateTests`의 `CPU·Memory 상세 콘텐츠의 프레임은 네 상태 모두 재확정한 400×480이다`가 통과한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와
        `-only-testing:ResourceRunnerUITests/DashboardProcessListDisplayUITests`·`-only-testing:ResourceRunnerUITests/DashboardDetailExpansionUITests`만 돌린다.
        하위 행 아래 정적 텍스트가 정확히 두 개인지와 앱 행 펼침·접힘이 그대로인지가 두 스위트에서 확인된다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.6, §5.9, §5.12 / DESIGN §5 DP10, DP13

- [ ] task-006: 카드 순위 안내를 목록 머리글로 옮긴다
  - 목적: 카드 순위 자리에서 시스템 프로세스 안내가 목록 아래 한 줄을 통째로 차지하지 않고 목록의 이름표가 되며,
    시스템 프로세스가 순위에 포함되지 않는다는 사실을 여전히 카드 화면에서 확인할 수 있다.
  - 접근: 이 동작은 이미 코드에 들어 있으므로 처음부터 다시 만들지 않는다.
    카드용 짧은 머리글 문구가 목록 위 머리글 자리에 있고 상세용 긴 캡션이 따로 남아 있는지 확인하고 어긋난 자리만 고친다.
  - 검증 조건:
    - 결과: 카드 문구는 「앱 TOP 5 · 시스템 프로세스 제외」이고 역할은 머리글 타이포, 머리글과 목록 사이 간격은 4pt다.
      순위 정원 5줄과 아이콘 자리·값 열 규칙이 그대로이고 순위 묶음 높이가 90pt다.
      정원 숫자는 문구에 직접 박히지 않고 카드 정원 상수에서 나온다.
      상세 증가량 순위와 앱 목록은 기존 긴 캡션을 계속 쓴다.
      카드 접근성 이름의 안내 문구가 머리글 문구이고 나머지 항목이 그대로 남아 있다.
      어긋난 자리가 없으면 코드를 고치지 않는다.
    - 확인:
      - `ApplicationRankingTests`의 `headingEmbedsTheGivenCountExactly`가 통과하고, 정원을 바꾸면 문구의 숫자가 따라옴을 단언이 잡는다.
      - 같은 파일의 `captionEmbedsTheGivenCountExactly`·`captionDiffersBetweenCardAndDetailGantries`가 통과한다.
        기존 캡션 함수는 상세가 계속 쓰므로 단언이 대상을 잃지 않는다.
      - `recentIncreaseRankingCaptionMatchesDetailGantryNotCardGantry`와 `detailApplicationsHeadingEmbedsDetailGantry`가 통과한다.
      - `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsHeading`이 통과하고,
        착수 전 접근성 이름 항목이 항목별 단언으로 모두 남아 있음을 확인한다.
      - `DashboardCardLayoutTests`의 `cardRankingHeadingFitsTheCardContentWidth`(머리글 이상적 폭이 카드 콘텐츠 폭 232pt 안)가 통과한다.
      - 같은 파일의 카드 높이 기준값과 `borderOnlySurfaceKeepsPreSurfaceChangeCardHeights`,
        픽셀 영역 리터럴 `cpuFirstRankingIcon`과 `cardRankingRowActuallyRendersProvidedIconInItsSlot`이 통과한다.
      - `cardRankingRowsKeepIconSlotBeforeContent`·`everyValuelessCardRankingRowReservesTheSameIconSlot`·
        `everyFilledCardRankingRowReservesTheSameIconSlot`이 통과하고 5줄 정원이 그대로다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와
        `-only-testing:ResourceRunnerUITests/DashboardCPUCardUITests`·`-only-testing:ResourceRunnerUITests/DashboardMemoryCardUITests`만 돌린다.
        `testOpeningPopoverShowsCPUValueCollectionProgressAndTopApplicationsHeading`이 머리글 문구를 카드 화면에서 잡고,
        Memory 카드는 같은 순위 묶음을 쓰므로 프레임·라벨 단언이 그대로 통과하는지 확인한다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.7, §5.9 / DESIGN §5 DP11, DP13

- [ ] task-007: 본체와 상세의 고정 크기를 다시 확정한다
  - 목적: 커진 카드에 맞춘 본체 팝오버 높이와 상세 크기가 실측과 맞고,
    수집 상태가 바뀌어도 상세를 열고 닫아도 앱 행을 펼치고 접어도 팝오버와 카드의 크기·위치가 변하지 않는다.
    카드가 넷이 된 상태의 세로 합계가 화면 안에 들어간다는 계산이 실측 카드 높이와 어긋나지 않는다.
  - 접근: 고정 크기는 이미 실측으로 확정돼 코드에 들어 있으므로 절차를 처음부터 다시 돌리지 않는다.
    현재 본체 고정 높이 508 / 팝오버 프레임 534와 상세 400×480이 실측과 맞는지 확인하고, 어긋날 때만 제약을 임시로 걷어 다시 재고 값을 고친다.
  - 검증 조건:
    - 결과: 본체 고정 높이 508pt와 팝오버 프레임 534pt가 수집 중 상태와 정상 상태에서 같은 값으로 나오고, 상세는 400×480 그대로다.
      네 상태·상세 열고 닫기·앱 행 펼침과 접힘·스크롤 전후에서 팝오버 프레임과 두 카드 프레임이 같다.
      실측 카드 높이(CPU 290 / Memory 171)를 M3 모델 1 식(본체 = `32 + CPU + 16 + Memory`, M3 = `574 + 3S`)에 넣은 결과가
      기준 기기 `visibleFrame` 1084pt 안에 들고 여유가 남는다.
      임시 계측 코드가 코드에 남아 있지 않다.
      어긋난 자리가 없으면 코드를 고치지 않는다.
    - 확인:
      - `ResourceRunnerUITests`의 `testDashboardPopoverKeepsItsMeasuredHeightFromCollectingToNormal`이 통과하고,
        수집 중·정상 두 상태의 팝오버 프레임이 같은 리터럴로 잡혀 있음을 확인한다.
        두 값이 갈리면 그래프 슬롯이나 축 라벨 줄의 자리표시가 상태별로 다른 높이를 쓰는 것이므로 그 자리를 먼저 고친다.
      - `DetailPopoverValuelessStateTests`의 `확정 후보 400×480의 폭에 가장 넓은 상세 조립이 들어간다`와
        `CPU·Memory 상세 콘텐츠의 프레임은 네 상태 모두 재확정한 400×480이다`가 통과한다.
      - `CPUCoreGridVerticalBudgetTests`의 14코어 격자 아래끝 166이 높이 480 안에 듦이 통과한다.
      - `DashboardDetailPopoverUITests`의 `testCPUAndMemoryDetailPopoverFramesAreTheSameFixedSize`·
        `testCPUDetailFrameRemainsExactlyFixedWhenAppRowExpands`·`testDetailContentScrollsWithinFixedPopoverFrame`이 통과한다.
      - `DashboardCardSelectionUITests`의 `testCardSelectionLifecycleKeepsFramesFixedAndSurvivesSelfDismissal`과
        `DashboardMemoryCardUITests`의 `testMemoryCardFrameStaysSameBeforeAndAfterFirstCollection`,
        `DashboardCPUCardUITests`의 `testCPUCardFrameStaysSameBeforeAndAfterFirstCollection`이 통과한다.
      - `DashboardCardLayoutTests`의 카드 높이 기준값과 M3 예산에서 나온 상한 단언이 통과하고,
        그 상한이 DESIGN §5 DP1의 모델 1 계산과 같은 값에서 나왔음을 확인한다.
      - 임시 계측 코드나 걷어낸 제약이 남아 있지 않음을 `git diff`로 확인한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와 UI 스위트
        `ResourceRunnerUITests`·`DashboardDetailPopoverUITests`·`DashboardCardSelectionUITests`·`DashboardMemoryCardUITests`·`DashboardCPUCardUITests`를
        각각 `-only-testing:`으로 지정해 돌린다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.3, §5.8, §5.12 / DESIGN §5 DP1, DP12, DP13

- [ ] task-008: 동작 줄이기 전제 없음과 자체 부하 비상승 확인
  - 목적: 동작 줄이기와 애니메이션 끄기 설정에서도 이 feature가 더한 표시가 같은 정보를 전달하고,
    팝오버를 열어 둔 채 관찰한 앱 자신의 CPU 사용량이 착수 전과 비교해 지속적으로 오르지 않는다.
  - 접근: 표시 계층 전체에서 애니메이션이 새로 걸린 자리와 갱신 주기마다 늘어나는 작업을 훑어 아래 결과와 맞는지 확인하고,
    어긋난 자리만 고친 뒤 앱 자신의 CPU 사용량을 표본으로 재어 착수 전과 견준다.
  - 검증 조건:
    - 결과: 표시 경로에 `withAnimation`·`transition`·암시적 애니메이션을 새로 건 자리가 없고, 기존 주기적 재그리기 한 곳만 남는다.
      새 타이머·새 관찰자·새 이미지 생성이 없고, 색 해석은 갱신 주기가 아니라 appearance가 바뀔 때만 일어난다.
      Memory 색을 되돌린 변경은 상수 값 교체라 tick마다 하는 일에 닿지 않는다.
      미수집 빗금은 창이 찬 뒤 그리는 선분이 0개가 된다.
      다운샘플 버킷 수는 판 폭 232pt에서 나오므로 판이 높아져도 그대로다.
      App Sandbox가 켜진 채이고 새 entitlement가 없다.
      팝오버를 열어 둔 채 잰 앱 자신의 CPU 사용량이 착수 전 표본과 견줘 지속적으로 상승하지 않는다.
      어긋난 자리가 없으면 코드를 고치지 않는다.
    - 확인:
      - `grep -rn --include='*.swift' -e 'withAnimation' -e '\.transition(' -e '\.animation(' ResourceRunner/`로 표시 계층을 훑어
        이 feature가 새로 더한 애니메이션 자리가 없음을 확인한다.
        애니메이션이 하나도 없으면 동작 줄이기 설정이 표시를 바꾸지 않으므로 이 확인이 SPEC §5.10의 근거가 된다.
      - tick마다 늘어나는 일이 세로 눈금 4선분·판 테두리 1경로·진행 문구 1문자열·코어 칸당 정수 비교 최대 3회뿐임을
        `git diff` 범위에서 확인한다.
      - `fullWindowDrawsNoUncollectedHatchSegments`가 통과해 창이 찬 뒤 빗금 선분이 0개임을 잡는다.
      - `bucketWidthIsFourPixelsPerBucket`·`bucketCountIsAtLeastOneForNarrowWidths`가 통과해 버킷 수가 폭에서만 나옴을 잡는다.
      - entitlements 파일이 착수 전과 같고 App Sandbox 설정이 그대로임을 `git diff`로 확인한다.
      - 앱을 실행해 팝오버를 열어 둔 채 `ps -o %cpu= -p <pid>`를 일정 간격으로 표본화하고,
        같은 절차로 잰 착수 전 표본과 견줘 지속 상승이 없음을 출력으로 확인한다.
      - 단위 스위트와 UI 열 스위트를 각각 `-only-testing:`으로 지정해 모두 돌리고 실패 0으로 통과시킨다.
        앞선 Task들이 돌리지 않은 `StatusItemAccessibilityUITests`·`ResourceRunnerUITestsLaunchTests`도 여기서 함께 확인된다.
        `-only-testing:` 없이 전체 스킴을 한 번에 돌리면 UI 테스트가 본문 실행 전 automation mode 초기화 시간 초과로 끝날 수 있다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.10, §5.11 / DESIGN §5 DP14
