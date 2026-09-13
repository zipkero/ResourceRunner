# 대시보드 시각 언어 재정립 구현

- [x] task-001: 글자 역할을 크기로 가르고 구역 여백을 한 단계 올린다
  - 목적: 대시보드를 훑을 때 초점 값·본문 값·라벨·머리글이 크기만으로 갈리고,
    카드 안의 제목 묶음·그래프 묶음·순위 묶음이 서로 떨어진 덩어리로 읽힌다.
    값이 커져도 순위 행의 숫자가 두 줄로 접히지 않아 행 높이가 값에 따라 달라지지 않는다.
  - 접근: 네 타이포 역할이 가리키는 글꼴을 서로 다른 의미 글꼴로 바꾸고 `pointSize` 필드를 그 글꼴의 실제 pt로 맞춘다.
    같은 역할로 다시 잰 값 열 여섯 폭을 갈아 끼우고, 카드 안 구역 사이 간격을 `betweenGroups`에서 `betweenSections`로 올린다.
    Memory 제목 묶음을 design.md §5 DP1이 정한 「머리글 줄 + 초점 줄」로 나누고 전체 용량을 초점 역할에서 본문 값 역할로 내린다.
    순위 행에는 숨긴 본문 값 한 글자를 줄 높이 앵커로 두어 값이 있는 줄과 자리표시 줄의 높이를 15pt로 맞춘다.
  - 검증 조건:
    - 결과: 네 역할이 focus `.largeTitle.weight(.semibold).monospacedDigit()`(pt 26 / 렌더 줄 높이 31),
      value `.callout.monospacedDigit()`(12 / 15), label `.subheadline`(11 / 14), heading `.caption.weight(.semibold)`(10 / 13)이다.
      네 pt가 서로 다르고, pt 비 26 / 12 = 2.17과 렌더 높이 비 31 / 15 = 2.07이 둘 다 2를 넘는다.
      네 역할의 `pointSize` 필드가 `NSFont.preferredFont(forTextStyle:)`의 실측 pt와 같다 — 착수 전 `.caption` 선언값 11 / 실측 10의 어긋남이 남지 않는다.
      값 열 여섯 폭이 `percentNumberWidth` 31 · `byteNumberWidth` 45 · `signedByteNumberWidth` 53 ·
      `compactUnitWidth` 14 · `byteUnitWidth` 21 · `processPercentUnitWidth` 67이고,
      각 값이 「`"9999"` 31 / `"1,024.0"` 45 / `"+1,024.0"` 53 / `" %"` 14 / `" MB"` 21 / `" % (코어 합산)"` 67」의 이상적 폭을 담는다.
      여백 단계 집합은 2 / 4 / 8 / 16 그대로이고 새 단계를 더하지 않는다.
      카드 안 구역 사이가 16이라 착수 전 8보다 크고, 카드 사이 간격 16과 `CardSurface.contentPadding` 8과 코어 칸 간격 8은 그대로다.
      카드 높이가 CPU **329**(16 + 제목 63 + 16 + 그래프 118 + 16 + 순위 100) · Memory **224**(16 + 46 + 16 + 30 + 16 + 100)이고,
      수집 중·정상·실패·중지 네 상태에서 카드마다 하나의 높이다.
      그래프 슬롯이 판 100 + 간격 4 + 축 라벨 줄 14 = **118**이고 라벨 줄 높이가 `label` 역할 실측 줄 높이에서 유도된다.
      순위 행 높이가 15pt 한 줄이고 정원 5줄이 유지된다.
      코어 막대는 아직 18pt이므로 격자 아래끝은 design.md 실측표의 18행 값인 14코어 **172** · 56코어 **462**이고,
      20pt로 올리는 것과 176 / 476은 뒤 Task가 한다.
      본체 고정 높이 상수와 팝오버 프레임 값은 이 Task에서 바꾸지 않는다 — 그 재확정은 레이아웃 변경이 모두 끝난 뒤 task-009가 실측으로 한다.
    - 확인:
      - `DashboardCardLayoutTests`의 `focusRoleIsTallerThanEveryOtherCardTypographyRole`이 그대로 통과한다.
      - 같은 파일의 `headingRoleUsesBodySizeWithDistinctWeightAndForeground`는 `heading.pointSize == value.pointSize`를 단언해
        `SPEC §5.1`이 요구한 「네 역할이 서로 다른 크기」와 정면으로 어긋나므로, 「네 역할의 `pointSize`가 서로 다르다」와
        「heading은 value와 굵기·전경 역할이 다르다」 두 단언으로 다시 쓴다. 굵기·전경 단언은 약화하지 않는다.
      - 같은 파일에 「네 역할의 `pointSize`가 `NSFont.preferredFont(forTextStyle:)` 실측 pt와 같다」와
        「focus의 pt와 렌더 줄 높이가 각각 value의 2배 이상이다」 두 단언을 두고 통과시킨다. 앞 단언이 선언값과 실측의 어긋남을 잡는다.
      - `headingWeightDoesNotChangeTheIdealWidthOfSectionTitles`가 통과한다.
        heading과 label의 pt가 갈렸으므로 비교 대상 역할을 같은 pt끼리 두거나 허용 오차의 근거를 새 역할 관계로 다시 쓰되, 폭 흔들림 상한 단언 자체는 남긴다.
      - `DashboardValueColumnTests`의 `각 값 종류의 전체 숫자 후보 중 최댓값이 고정 숫자 열 안에 든다`와
        `실제 전체 바이트 단위 집합 중 최댓값이 고정 단위 열 안에 든다`가 새 역할로 다시 재서 통과한다 — 리터럴 비교가 아니라 유도형 그대로다.
      - 같은 파일의 `카드 순위 행의 숫자 오른쪽 끝과 단위 시작이 같다`·`상세 앱 목록 행 …`·`상세 범례 행 …`·`상세 증가량 순위 행 …` 넷이 통과한다.
      - `DashboardCardLayoutTests`의 `CardHeightBaseline` cpu를 329로, memory를 224로 갱신하고
        `cpuCardHeightIsSameAcrossAllFourStates`·`memoryCardHeightIsSameAcrossAllFourStates`·
        `cardHeightsMatchBaselinesAcrossEveryStateWithNewElements`·`cpuCardHeightIsSameRegardlessOfTopApplicationsCount`·
        `memoryCardHeightIsSameRegardlessOfTopApplicationsCount`·`cpuCardHeightIsSameWhenProcessSurveyFails`·
        `memoryCardHeightIsSameWhenProcessSurveyFails`·`cpuCardHeightIsSameRegardlessOfUserSystemBandValues`·
        `memoryCardHeightIsSameWithLongestPressureSwapLineContent`·`cardHeightIsSameRegardlessOfRowIconAvailability`가 통과한다.
      - `borderOnlySurfaceKeepsPreSurfaceChangeCardHeights`의 `previousMemoryUpperBound`(181) 단언은
        `SPEC §5.6`이 여백 확대를 요구하면서 대상을 잃으므로 남기지 않고, 그 자리를 카드 높이 기준값 224와 아래 M3 예산 단언이 메운다.
        `previousCPUHeight`(231) 하한 단언은 그대로 성립하므로 남긴다.
      - 같은 파일의 M3 예산 상한 단언은 새 리터럴을 만들지 말고 DESIGN §5 DP12의 모델 1 식
        「콘텐츠 `703 + 3S`, `S = 118`일 때 1057, 프레임 1083 ≤ 기준 기기 1084」에서 유도해 다시 쓴다.
      - 픽셀 영역 리터럴 `cpuPlaceholderSummary`·`cpuPlaceholderGraph`·`cpuFirstRankingIcon`을 새 조립에서 다시 잡는다 —
        그래프 판은 카드 안쪽 패딩 8 + 제목 묶음 63 + 구역 간격 16 = 87에서 시작해 187에서 끝나고,
        첫 순위 행은 87 + 118 + 16 + 머리글 13 + 4 = 238에서 시작한다. 임의 조정이 아니라 이 산술을 따른다.
        `everyValuelessStateRendersEveryNewDisplayElement`·`cpuSeriesPlaceholderKeepsBothSwatchesWithoutInventingZeroValues`·
        `cardRankingRowActuallyRendersProvidedIconInItsSlot`·`everyValuelessCardRankingRowReservesTheSameIconSlot`·
        `everyFilledCardRankingRowReservesTheSameIconSlot`이 새 영역에서 통과한다.
      - `spacingScaleKeepsCardHierarchyConsistent`가 통과하고, 「카드 안 구역 간격 > 착수 전 8pt」를 잡는 단언을 둔다.
      - `cardRankingHeadingFitsTheCardContentWidth`(머리글 이상적 폭 ≤ 232)와
        `memoryFocusLineLeavesRoomForCompositionBarAcrossWorstCaseStates`가 통과한다 —
        뒤 단언이 초점 역할 26pt에서도 128GB 최악 입력의 초점 줄 115 + 6 + 62 = 183이 카드 콘텐츠 폭 232 안이고 구성 누적 바에 폭이 남는 것을 잡는다.
      - `DashboardPresentationTests`의 `graphSlotHeightIsDerivedFromPlotAxisSpacingAndLabelHeight`가 통과하고
        슬롯 118이 판 100 + 간격 4 + 라벨 줄 14의 합에서 유도되며 리터럴이 두 자리에 복제되지 않았음을 코드로 확인한다.
        `graphPlotIsTallerAndLessHorizontallyCompressedThanBefore`도 그대로 통과한다.
      - `CPUCoreGridVerticalBudgetTests`의 14코어 아래끝을 172로, 56코어를 462로 갱신하고
        `논리 코어 56개가 첫 화면에 들어가는 마지막 코어 수다`·`코어 57개 이상에서는 격자 아래끝이 첫 화면을 벗어난다`가 통과한다.
      - `CPUCoreUsageGridTests`의 `칸의 이상적 폭이 화면 수치를 담은 조립과 같다`·
        `코어 칸 수치의 %가 칸마다 같은 오른쪽 자리에 놓인다`·`최대 코어 수치가 8열 칸과 스크롤러로 좁아진 칸 안에 든다`·
        `격자 높이가 task-001이 정한 행 수만큼만 쌓인다`가 새 역할 폭에서 통과한다.
      - `DetailPopoverValuelessStateTests`의 `확정 후보 400×480의 폭에 가장 넓은 상세 조립이 들어간다`와
        `CPU·Memory 상세 콘텐츠의 프레임은 네 상태 모두 재확정한 400×480이다`가 통과한다.
      - `ApplicationProcessRowLayoutTests`의 `production CPU 값과 긴 이름이 각 줄에서 360pt 안에 들어간다`와 하위 행 네 경계 단언이 통과한다.
      - 테스트 실행은 `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -only-testing:ResourceRunnerTests`로 단위 스위트만 돌린다.
  - 참조: SPEC §5.1, §5.6, §5.13 / DESIGN §5 DP1, DP2, DP15

- [x] task-002: 팝오버 바탕과 카드 면을 세우고 카드 테두리를 걷어낸다
  - 목적: 라이트와 다크 모두에서 카드가 바탕보다 밝은 면으로 떠올라, 테두리 선 없이도 어디까지가 한 카드인지 화면에서 갈린다.
    상세 팝업의 바탕이 카드 면과 같은 면이라 두 화면의 색이 같은 기준면 위에 놓인다.
  - 접근: 팔레트에 팝오버 바탕과 카드 면 두 값을 라이트·다크 각각 확정해 두고,
    본체 루트·두 카드·상세 루트가 그 값을 깔게 한다.
    카드 표면 상수에서 테두리 관련 값을 없애고 채울 색을 두며, 대비 검증이 배경 리터럴 대신 팔레트의 면 값을 appearance별로 풀어 쓰게 바꾼다.
  - 검증 조건:
    - 결과: 팝오버 바탕이 라이트 `#ECECEC`(`L*` 93.4) · 다크 `#1E1E1E`(11.3)이고,
      카드 면과 상세 바탕이 라이트 `#FFFFFF`(100.0) · 다크 `#2E2E2E`(18.9)다.
      바탕–카드 대비가 라이트 1.18(`ΔL*` 6.6) · 다크 1.23(`ΔL*` 7.7)이고 **두 모드 모두 카드가 바탕보다 밝다** — 한쪽에서만 가라앉는 방향이 아니다.
      카드 표면 상수에 `borderWidth`·`borderColor`가 남지 않고, `cornerRadius` 8 · `contentPadding` 8 · 탭 영역 모양은 그대로다.
      카드 높이 329 / 224가 면 도입 전후로 같다 — 배경 수정자가 레이아웃에 참여하지 않는다.
      팔레트의 모든 색이 실제로 놓이는 면(카드 면) 기준 3:1 이상이다 —
      CPU 램프 라이트 11.53 / 7.84 / 5.33 / 3.63, 다크 9.71 / 6.89 / 4.73 / 3.13,
      Memory 구성 라이트 7.45 / 3.89 / 7.47 / 3.89, 다크 3.74 / 7.08 / 3.74 / 7.11.
      대비 검증의 기준면이 테스트 안 리터럴이 아니라 팔레트의 면 값 한 자리에서 나온다.
      새 타이머·새 관찰자·그림자 합성이 없다 — 면은 뷰 배경이라 갱신 주기마다 다시 계산되지 않는다.
    - 확인:
      - `DashboardColorPaletteTests`의 배경 리터럴 `0xececec` / `0x2e2e2e`를 팔레트 카드 면 값의 `resolvedSRGB` 결과로 바꾸고,
        `allSixteenColorsMeetContrastAndKeepTheSameStepMeaning`·`memoryCategoryColorsMeetBackgroundContrastInBothAppearances`가
        그 기준면에서 통과한다. 리터럴을 새 숫자로 갈아 끼우는 형태로 두지 않는다.
      - 같은 파일에 「팝오버 바탕과 카드 면이 라이트·다크 각각 서로 다르고, 두 모드 모두 카드 면의 `L*`가 바탕보다 크다」 단언을 두고 통과시킨다.
        이 단언이 `SPEC §5.5`의 「두 모드에서 같은 방향」과 `SPEC §5.11`의 「바탕과 카드 면 자체도 갈린다」를 함께 잠근다.
      - `memoryCategoriesSplitIntoTwoHuesWithTheDarkerCategoryFirst`·`adjacentMemoryCategoriesDifferInLightness`·
        `cpuBandsAndCoreEntryUseTheCPUResourceRamp`·`cpuBandCompositeLightnessDifferenceImprovesInBothAppearances`가
        기준면만 바뀐 채 그대로 통과한다.
      - `DashboardCardLayoutTests`의 `cardSurfacesRenderOnlyBorderInkWithoutOpaqueInteriorFill`은
        `SPEC §5.5`가 테두리를 없애라고 요구해 「테두리 잉크 > 0」이 대상을 잃으므로,
        「카드 면 잉크 > 0이고 그 면 색이 팝오버 바탕과 다르다」로 방향을 뒤집어 다시 쓴다.
        「카드 안쪽에 불투명 채움이 없다」는 면을 까는 결정이 철회한 요구이므로 남기지 않는다.
      - `cardSurfaceConstantsKeepTheApprovedSlot`의 `borderWidth == 1` 단언은 대상을 잃으므로 지우고,
        `cornerRadius == 8`과 `contentPadding == 8` 단언은 남긴다.
      - `borderOnlySurfaceKeepsPreSurfaceChangeCardHeights`가 새 기준값 329 / 224로 통과해 면 도입이 높이를 움직이지 않음을 잡는다.
      - `cpuGraphPlaceholderDoesNotRenderInventedZeroValues`의 「채도 0.35 초과 픽셀 0」이 통과한다 — 두 면은 무채색이라 이 판정을 깨지 않는다.
      - `memoryCompositionPlaceholderTrackIsActuallyRendered`·`cardDrawsCompositionSegments`가 통과한다.
      - `DetailPopoverValuelessStateTests`의 `production 전수 목록의 아홉 요소는 정상에만 있고 요소별 감도 점검을 통과한다`가 통과한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`만 돌린다. 이 Task는 접근성 이름·식별자·프레임을 건드리지 않는다.
  - 참조: SPEC §5.5, §5.11, §5.13 / DESIGN §5 DP3, DP4, DP14, DP15

- [x] task-003: 그래프 판에 가로 기준선 하나만 남긴다
  - 목적: CPU 카드의 그래프 판이 세로 눈금과 판 테두리로 여러 칸으로 갈라져 보이지 않고 가로선 하나만 남으며,
    값의 높이를 어림하는 일은 그 한 줄로 계속 된다. 값이 없는 자리표시도 같은 자리에 같은 한 줄만 그린다.
  - 접근: 눈금 값 집합 `[25, 50, 75]`는 코어 단계 경계의 출처로 남기고,
    실제로 그리는 기준선을 그 배열의 가운데 값 하나에서 유도하는 별도 값으로 나눈다.
    세로 눈금 진입점과 판 테두리 그리기를 없애고 두 그리기 순서 목록에서 그 레이어를 뺀다.
    카드 접근성 이름의 기준선 문구를 화면과 같은 하나로 맞춘다.
  - 검증 조건:
    - 결과: 눈금 값 집합은 `[25, 50, 75]` 그대로이고 `CPUCoreUsageStep`의 경계가 계속 그 배열에서 유도된다.
      화면에 그리는 기준선은 50% 하나뿐이며 그 값이 눈금 값 집합의 가운데 값에서 나오고 새 리터럴 50이 생기지 않는다.
      세로 눈금 진입점(등분 수와 정규화 x 위치)과 판 테두리 그리기가 남지 않는다.
      값 있음 경로의 그리기 순서가 기준선 → 밴드 채움 둘 → 밴드 경계선 둘 다섯 레이어이고, 기준선이 맨 처음이라 반투명 밴드 사이로 비친다.
      자리표시 경로가 같은 기준선 레이어 하나를 같은 좌표에 그리고 점도 선도 그리지 않는다.
      판 높이 100pt와 슬롯 118pt, 선 두께 1.0pt, 밴드 채움 0.60 / 0.15와 아래 점선·위 실선 경계, 다운샘플 버킷 수가 그대로다.
      카드 접근성 이름의 기준선 항목이 「기준선 50%」로 화면과 같아지고, 나머지 항목(초점 수치·상태·두 계열·순위 안내·시간 창·수집 진행·단축키)은 하나도 빠지지 않는다.
    - 확인:
      - `DashboardPresentationTests`의 `baselineValuesAreExactlyTwentyFiveFiftySeventyFive`가 그대로 통과한다.
      - 같은 파일에 「그리는 기준선이 정확히 하나이고 그 값이 눈금 값 집합의 가운데 값이다」 단언을 두고 통과시킨다.
      - `fourVerticalTicksDivideAnyPositiveTimeRangeIntoFifths`는 `SPEC §5.2`가 세로 눈금 요구를 철회해 대상을 잃으므로 지운다.
        그 자리를 위 단언이 메우며, 다른 단언을 함께 지우거나 완화하지 않는다.
      - `drawOrderIsGridlinesThenFillsBoundariesAndGraphBorder`와 `placeholderDrawOrderContainsGridlinesUncollectedRegionThenGraphBorder`를
        판 테두리가 빠진 새 배열로 다시 쓰고, 두 목록의 첫 항목이 같은 기준선 레이어임을 배열 단언이 잡는다.
      - `gridlinesAreDrawnBeforeBandFillsAndBoundaries`·`bandFillOpacitiesAreTranslucentSoGridlinesShowThrough`·
        `lowerBoundaryIsDashedAndUpperBoundaryIsSolid`·`zeroPercentIsAtTheBottomAndHundredPercentIsAtTheTop`·
        `yPositionScalesWithHeight`·`yPositionsAreFifteenPointsApartAtSixtyPointHeight`가 통과한다.
      - `CPUCoreUsageGridTests`의 `코어 단계가 그래프 기준선에서 유도되고 기준선 변경을 따라간다`와
        `각 그래프 기준선의 바로 아래와 바로 위에서 코어 단계가 갈린다`가 통과해 단계 경계 25 / 50 / 75가 움직이지 않음을 잡는다.
      - `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsHeading`을 기준선 문구 「50%」로 갱신하고,
        착수 전 접근성 이름 항목이 항목별 단언으로 모두 남아 있음을 확인한다.
        `valuelessFailureAndStoppedStatesKeepTheTimeWindowAndCollectionProgress`·`collectingStateIncludesSelectionShortcut`도 통과한다.
      - `DashboardCardLayoutTests`의 `everyValuelessStateRendersEveryNewDisplayElement`에서 CPU 그래프 격자 잉크 > 0이 기준선 하나로도 통과하고,
        카드 높이 기준값 329 / 224가 움직이지 않음을 확인한다.
      - `cpuGraphPlaceholderDoesNotRenderInventedZeroValues`의 「채도 0.35 초과 픽셀 0」이 통과한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`만 돌린다.
  - 참조: SPEC §5.2, §5.12, §5.13 / DESIGN §5 DP5, DP6, DP15

- [x] task-004: 아직 수집되지 않은 구간에서 빗금을 걷어낸다
  - 목적: 앱을 켠 직후처럼 10분 창의 대부분이 비어 있어도 그 구간이 자기 경계를 가진 면으로 보이지 않고,
    아직 수집 중이라는 사실과 얼마나 모였는지는 축 아래 문구로 그대로 확인된다.
    창이 다 찬 뒤에는 그 자리에 아무 표시도 남지 않는다.
  - 접근: 미수집 구간을 덮던 대각 빗금 패턴과 그 그리기, 두 그리기 순서 목록의 미수집 항목을 없앤다.
    미수집 비율 계산은 수집 진행 문구를 만드는 자리로 남긴다.
  - 검증 조건:
    - 결과: 미수집 구간에 그리는 레이어가 없어 그 구간에 점도 선도 면도 없고, 데이터가 시작하는 자리는 밴드 채움의 왼쪽 끝으로만 드러난다.
      수집 시작 지점을 나타내는 세로선을 새로 긋지 않는다.
      진행 문구는 「데이터 수집 중 · mm:ss / 10:00」 그대로이고, 창이 차면 문자열이 비지만 줄은 남아 슬롯 높이 118이 갈리지 않는다.
      미수집 비율 계산은 남아 있으며 표본이 없으면 창 전체, 첫 표본이 가운데면 그 지점까지, 중간 공백은 미수집으로 치지 않는다.
      값 있음 경로와 자리표시 경로의 그리기 순서 목록에 미수집 항목이 남지 않는다.
      갱신 주기마다 그리던 최대 41선분이 사라진다.
    - 확인:
      - `DashboardPresentationTests`의 `emptyPointsMarkTheWholeWindowAsUncollected`·
        `firstPointInTheMiddleDeterminesTheUncollectedWidth`·`middleGapDoesNotChangeTheFirstPointBasedUncollectedWidth`·
        `collectionProgressUsesElapsedAndTotalDurations`·`fullWindowHasNoCollectionProgressTextButKeepsTheSameSlotHeight`가 통과한다.
        이 다섯이 「수집 중이라는 사실과 진행이 축 아래 문구로 계속 확인된다」의 잠금이므로 지우거나 완화하지 않는다.
      - `fullWindowDrawsNoUncollectedHatchSegments`는 빗금 자체가 사라져 대상을 잃으므로 지우고,
        그 자리를 「두 그리기 순서 목록에 미수집 레이어가 없다」 단언이 메운다.
      - `drawOrderIsGridlinesThenFillsBoundariesAndGraphBorder`와
        `placeholderDrawOrderContainsGridlinesUncollectedRegionThenGraphBorder`를 미수집 항목이 빠진 배열로 다시 쓰고,
        두 목록이 기준선 하나로 시작하는 것을 배열 단언이 잡는다.
      - `DashboardCardLayoutTests`의 `cpuGraphPlaceholderDoesNotRenderInventedZeroValues`가 통과하고,
        `everyValuelessStateRendersEveryNewDisplayElement`가 빗금 없는 자리표시에서도 통과한다.
      - 카드 높이 기준값 329 / 224와 그래프 슬롯 118이 움직이지 않음을 확인한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`만 돌린다.
  - 참조: SPEC §5.3, §5.13 / DESIGN §5 DP7, DP15

- [x] task-005: 상세 두 화면을 본체 카드와 같은 역할·구역 규칙으로 옮긴다
  - 목적: CPU 상세와 Memory 상세의 글자가 본체 카드와 같은 네 역할만 쓰고, 두 화면의 구역 머리글이 같은 방식으로 붙는다.
    상세에만 남아 있던 별도 글꼴 규칙이 사라진다.
  - 접근: 구역 머리글의 역할·머리글과 내용 사이 간격·구역 사이 간격 세 값을 `DashboardStyle` 안 한 자리(`Section`)에 모으고,
    카드 순위 묶음과 상세의 코어 격자·증가량 순위·앱 목록 구역이 그 자리를 참조하게 한다.
    상세에 남은 직접 글꼴 지정 아홉 자리를 네 역할로 바꾼다.
  - 검증 조건:
    - 결과: 구역 머리글 세 값(머리글 역할 = heading, 머리글과 내용 사이 = 4, 구역 사이 = 16)이 한 자리에 있고,
      카드 순위 묶음·상세 코어 격자·상세 증가량 순위·상세 앱 목록 네 자리가 모두 그 자리를 참조한다.
      표시 계층에 `.caption`·`.caption2`·`.caption.bold()` 직접 지정이 남지 않는다 —
      상세 앱 목록 행과 캡션, 두 상세의 값 없음 문구, 코어 번호, 도넛 센터 라벨과 값, 도넛 범례 행, 앱 행, 하위 프로세스 행 아홉 자리가 모두 역할을 쓴다.
      도넛 센터 값은 `focus`가 아니라 `value` 역할이다 — 초점 역할 31pt는 지름 140pt 도넛 안에 들지 않는다.
      코어 번호는 `heading` 역할이고 렌더 줄 높이가 13으로 같아 격자 아래끝(막대 18 기준 14코어 172 · 56코어 462)이 움직이지 않는다.
      상세 프레임이 400×480 그대로이고 가장 넓은 상세 조립이 콘텐츠 폭 368pt 안에 든다.
      하위 프로세스 행의 `AppRow-<앱 키>` 식별자와 그 아래 정확히 두 개의 정적 텍스트,
      코어 칸의 하위 무시 + 정적 텍스트 + 이름 + 값 + 식별자 계약, 상세 콘텐츠의 `DashboardDetail` 식별자가 그대로다.
    - 확인:
      - `grep -rn --include='*.swift' -e '\.caption2' -e '\.caption\b' -e '\.caption\.bold' ResourceRunner/`로 표시 계층을 훑어
        직접 글꼴 지정이 남지 않았음을 출력으로 확인한다.
      - 구역 머리글 세 값을 네 소비 자리가 모두 참조함을 확인하는 단언을 `DashboardCardLayoutTests`에 두고 통과시킨다 —
        「카드 순위 묶음의 머리글 역할·간격이 상세 구역의 값과 같다」가 `SPEC §5.9`의 실행 가능한 근거다.
      - `DetailPopoverValuelessStateTests`의 `확정 후보 400×480의 폭에 가장 넓은 상세 조립이 들어간다`·
        `CPU·Memory 상세 콘텐츠의 프레임은 네 상태 모두 재확정한 400×480이다`·
        `수집 중·실패·중지는 같은 안내 문구 하나만 그린다`·
        `production 전수 목록의 아홉 요소는 정상에만 있고 요소별 감도 점검을 통과한다`가 통과한다.
      - `CPUCoreUsageGridTests`의 `칸이 위에서부터 막대 · 수치 · 번호 세 띠로 그려진다`·
        `칸의 이상적 폭이 화면 수치를 담은 조립과 같다`·`0%와 1%가 같은 칸의 화면 수치로 갈린다`가 통과한다.
      - `CPUCoreGridVerticalBudgetTests`의 14코어 172 · 56코어 462가 움직이지 않음을 확인한다.
      - `MemoryCompositionDetailTests`의 `rowsContainNamesAndDetailedByteValuesInDonutOrder`·
        `unavailableValuesUseDashWithoutDroppingLegendRows`·`compositionTotalAndUsedBytesHaveDistinctLabelsAndPositions`가 통과한다.
      - `ApplicationProcessRowLayoutTests`의 `CPU와 Memory 모두 같은 두 줄 높이와 시작선 규칙을 쓴다`·
        `이름은 부모 앱 이름과 같고 값은 아이콘 한 칸 더 들어간다`·`production CPU 값과 긴 이름이 각 줄에서 360pt 안에 들어간다`가 통과한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와
        `-only-testing:ResourceRunnerUITests/DashboardProcessListDisplayUITests`·`-only-testing:ResourceRunnerUITests/CPUCoreAccessibilityUITests`를 돌린다.
        앞은 하위 행 아래 정적 텍스트가 정확히 둘인지를, 뒤는 코어 칸이 하나의 접근성 노드로 남고 하위 요소가 0인지를 잡는다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 0이 아니면 잔류 인스턴스를 정리한 뒤 다시 돌린다.
        잔류 인스턴스가 메뉴바를 채우면 status item을 찾지 못해 본문에 닿기 전에 전부 실패한다. 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.9, §5.12, §5.13 / DESIGN §5 DP13, DP15

- [x] task-006: 코어 격자를 세 색으로 칠하고 막대를 20pt로 키운다
  - 목적: CPU 상세의 코어 격자에서 75% 이상인 코어만 다른 색조로 떠오르고 나머지는 서로 비슷한 톤으로 가라앉아,
    바쁜 코어를 찾는 데 값을 하나씩 읽을 필요가 없다.
    색을 지워도 칸마다 찍히는 정수 퍼센트와 값에 비례하는 채움 높이로 어느 코어가 얼마나 바쁜지 그대로 읽힌다.
  - 접근: 코어 막대 채움을 CPU 램프에서 떼어 내 자기 색 집합으로 두고,
    단계를 받아 세 값 중 하나를 돌려주는 진입점 하나만 공개한다.
    막대 높이를 18에서 20으로 올린다.
  - 검증 조건:
    - 결과: 색 집합이 라이트 `quiet` `#7d869e` · `elevated` `#576482` · `busy` `#c77036`,
      다크 `quiet` `#7b849c` · `elevated` `#9faccc` · `busy` `#f29c66`이고 라이트·다크를 각각 따로 둔다.
      단계 배정은 25% 미만과 25~50%가 `quiet`, 50~75%가 `elevated`, 75% 이상이 `busy`이며 단계 경계 25 / 50 / 75와 단계 수 넷은 그대로다.
      카드 면 기준 대비가 라이트 3.64 / 5.91 / 3.62, 다크 3.64 / 5.98 / 6.29으로 여섯 값 모두 3:1을 넘는다.
      `busy`의 색조(h 57)가 나머지 둘(h 278)과 갈리고, `quiet`·`elevated`의 채도(`C*` 14.0 / 18.5 · 14.1 / 17.9)가 `busy`(54.8 / 49.3)보다 낮다.
      라이트에서 `quiet`와 `busy`의 `L*`가 56으로 같아 회색조에서 갈리지 않는 것은 허용된 상태이며, 그 자리는 칸 안 정수 퍼센트와 채움 높이가 맡는다.
      `cpuCoreFill`이 CPU 램프 값을 그대로 돌려주지 않고, CPU 램프는 두 밴드와 요약 줄 스와치 전용으로 네 단계를 유지한다.
      트랙은 시스템 색 그대로다.
      막대 높이가 20pt이고 칸은 막대 20 + 2 + 값 줄 15 + 2 + 코어 번호 13이며,
      격자 아래끝이 14코어 **176** · 56코어 **476**으로 상세 첫 화면 480pt 안이고 57코어는 536으로 넘친다 — 56코어 상한이 그대로다.
      열 상한 8과 칸 간격 8, 행·열 분할 규칙이 그대로다.
      코어 칸의 접근성 계약(하위 무시 + 정적 텍스트 + 「코어 N」 라벨 + 「N%」 값 + `CPUCore-N` 식별자 + 하위 요소 0)이 그대로다.
      tick마다 칸 하나가 하는 일은 정수 비교 최대 세 번과 이미 확정된 상수 선택뿐이고 색 보간이 없다.
    - 확인:
      - `DashboardColorPaletteTests`의 `cpuBandsAndCoreEntryUseTheCPUResourceRamp` 안
        `cpuCoreFill(step) == cpu(step)` 단언은 코어 채움이 자기 집합을 갖게 되어 대상을 잃으므로 지운다.
        `cpuUser == cpu(.step3)`·`cpuSystem == cpu(.step1)`은 그대로 남긴다.
      - 같은 파일에 코어 채움 세 단언을 두고 통과시킨다 —
        「세 값이 라이트·다크 모두 카드 면 대비 3:1 이상」,
        「`busy`의 색조가 나머지 둘과 갈린다」,
        「`quiet`·`elevated`의 채도가 `busy`보다 낮다」.
        이 셋이 앞 단언이 잠그던 자리를 메우며 `SPEC §5.7`의 실행 가능한 근거다.
      - `CPUCoreUsageGridTests`의 `단계가 갈리는 두 코어 사용률은 서로 다른 채움 색을 쓴다`를
        색이 실제로 갈리는 경계 50과 75의 앞뒤로 다시 쓰고, 25 경계에서는 같은 색임을 함께 단언한다.
      - 같은 파일의 `코어 단계가 그래프 기준선에서 유도되고 기준선 변경을 따라간다`·
        `각 그래프 기준선의 바로 아래와 바로 위에서 코어 단계가 갈린다`·
        `칸의 채움 높이가 그 코어의 값을 따라 커진다`·`막대 트랙 높이가 값과 무관하게 같다`·
        `칸이 위에서부터 막대 · 수치 · 번호 세 띠로 그려진다`·`0%와 1%가 같은 칸의 화면 수치로 갈린다`·
        `격자 높이가 task-001이 정한 행 수만큼만 쌓인다`가 통과한다.
        가운데 두 단언이 「색을 지워도 읽힌다」의 잠금이므로 지우거나 완화하지 않는다.
      - `CPUCoreGridVerticalBudgetTests`의 14코어 아래끝을 176으로, 56코어를 476으로 갱신하고
        `논리 코어 56개가 첫 화면에 들어가는 마지막 코어 수다`·`코어 57개 이상에서는 격자 아래끝이 첫 화면을 벗어난다`·
        `코어 수가 달라져도 격자 아래끝이 첫 화면 안이다`가 통과한다.
      - `DetailPopoverValuelessStateTests`의 기준 코어 칸 조립이 새 채움 진입점을 쓰고
        `production 전수 목록의 아홉 요소는 정상에만 있고 요소별 감도 점검을 통과한다`가 통과한다.
      - `CPUCoreUsageGridTests`의 `코어 수가 늘어난 만큼 CPU 상세 높이가 격자 높이만큼 늘어난다`와
        `값 분포만 다른 두 입력의 격자 그림이 서로 다르다`가 통과한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와 `-only-testing:ResourceRunnerUITests/CPUCoreAccessibilityUITests`를 돌린다.
        `testCoreCellIsOneReachableElementWithLabelValueAndIdentifier`가 코어 칸 접근성 계약을 잡는다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.7, §5.8, §5.11, §5.12 / DESIGN §5 DP8, DP9, DP15

- [x] task-007: Memory 상세 도넛 범례를 한 줄로 정렬한다
  - 목적: Memory 상세에서 네 구간의 이름·값·단위가 한 줄로 묶여 읽히고,
    도넛을 보지 않고 범례만 읽어도 네 구간의 크기를 비교할 수 있다.
  - 접근: 이름 열 폭을 네 구간 이름의 이상적 폭 최댓값에서 유도하고, 값 열을 그 바로 뒤에 붙인다.
    남는 폭은 행의 오른쪽에 남겨 도넛과 범례의 세로 중앙 정렬을 그대로 둔다.
  - 검증 조건:
    - 결과: 이름 열 폭이 네 이름(App 22 · Wired 31 · Compressed 67 · Cached 40)의 최댓값 **67**에서 유도되고 리터럴로 박히지 않는다.
      네 행의 이름이 같은 왼쪽 시작선에서 시작하고 값 열의 숫자 오른쪽 끝과 단위 시작선이 네 행에서 같은 가로 위치다.
      이름과 값이 행의 양끝으로 벌어지지 않는다 — 남는 폭은 값 열 오른쪽에 남는다.
      행 조립이 도넛 140 + 구역 간격 16 + (스와치 + 이름 열 + 값 열) 안에 들어 상세 콘텐츠 폭 368pt를 넘지 않는다.
      범례 줄 수는 수집 상태와 무관하게 넷이고 값이 없으면 대시로 표시되며 줄이 빠지지 않는다.
      한 줄 고정(`lineLimit` 1)과 도넛 순서가 그대로다.
    - 확인:
      - `MemoryCompositionDetailTests`에 「네 이름의 이상적 폭 최댓값이 이름 열 폭 안에 든다」 단언을 두고 통과시킨다 —
        `ValueColumn`이 쓰는 유도형과 같은 형태이고 리터럴 67을 비교 대상으로 두지 않는다.
      - 같은 파일에 「네 범례 행의 값 열 시작 x가 서로 같다」 단언을 두고 통과시킨다. 이 단언이 `SPEC §5.10`의 「한 줄에 정렬」 잠금이다.
      - `rowsContainNamesAndDetailedByteValuesInDonutOrder`·`unavailableValuesUseDashWithoutDroppingLegendRows`·
        `detailUsesTheExactCardCompositionLayout`·`compositionTotalAndUsedBytesHaveDistinctLabelsAndPositions`가 통과한다.
      - `MemoryCompositionTests`의 `legendFollowsBarSegmentOrderWithNames`와 `maximumLineCountIsOne`이 통과한다.
        앞 단언은 네 구간이 회색조에서 두 쌍으로 붙는 것을 허용하는 근거이므로 그대로 유지한다.
      - `DashboardValueColumnTests`의 `상세 범례 행의 숫자 오른쪽 끝과 단위 시작이 같다`가 통과한다.
      - `DetailPopoverValuelessStateTests`의 `확정 후보 400×480의 폭에 가장 넓은 상세 조립이 들어간다`와
        `CPU·Memory 상세 콘텐츠의 프레임은 네 상태 모두 재확정한 400×480이다`가 통과한다.
      - `DashboardPresentationTests`의 `detailDonutAccessibilityLabelIncludesEveryCompositionValueTotalAndPhysicalMemory`가 통과해
        도넛 접근성 이름의 항목이 줄지 않음을 잡는다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와 `-only-testing:ResourceRunnerUITests/DashboardMemoryCardUITests`를 돌린다.
        `testMemoryDetailDonutIsOneAccessibilityNodeWithCompleteCompositionLabel`이 도넛이 접근성 노드 하나로 남는지를 잡는다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.10, §5.13 / DESIGN §5 DP11

- [x] task-008: 카드 순위 머리글을 이름표로 줄이고 제외 사실을 두 상세로 옮긴다
  - 목적: 카드의 순위 목록 머리글이 정원과 제외 규칙을 늘어놓지 않고 목록의 이름표만 남으며,
    시스템 프로세스가 순위에서 빠진다는 사실은 CPU 상세와 Memory 상세 두 곳 모두에서 확인된다.
    화면 머리글이 짧아져도 접근성으로 도달하는 정보는 줄지 않는다.
  - 접근: 순위 문구 진입점을 화면용 머리글·접근성용 문구·상세 목록 안내 셋으로 나눈다.
    상세 앱 목록의 기존 머리글 묶음을 「머리글 + 안내」 두 줄로 두고 안내는 이미 있는 상세용 캡션을 그대로 쓴다.
  - 검증 조건:
    - 결과: 카드 화면 머리글이 「상위 앱」이고 정원 숫자도 제외 규칙도 담지 않으며 이상적 폭 29pt가 카드 콘텐츠 폭 232pt 안이다.
      카드 접근성 이름은 정원과 제외 사실을 담은 문구를 그대로 유지한다 — 카드가 하위 무시로 닫혀 있어 이름이 유일한 도달 경로다.
      두 문구가 서로 다른 진입점에서 나오고 한 문자열을 두 자리가 나눠 쓰지 않는다.
      CPU 상세와 Memory 상세의 앱 목록 머리글 아래에 제외 사실 안내 줄이 각각 붙고, 문구는 기존 상세용 캡션 그대로라 새 문자열을 만들지 않는다.
      안내 줄은 기존 구역의 머리글 묶음이 두 줄이 되는 것이지 새 구역이 아니다.
      카드 순위 묶음 높이 100pt와 정원 5줄, 아이콘 자리와 값 열 규칙이 그대로다.
      상세 프레임 400×480과 콘텐츠 폭 368pt가 그대로다.
    - 확인:
      - `ApplicationRankingTests`의 `headingEmbedsTheGivenCountExactly`는 화면 머리글이 정원을 담지 않게 되어 대상을 잃으므로,
        「접근성용 문구가 정원을 그대로 담고 제외 사실을 말한다」와 「화면 머리글에는 정원 숫자와 제외 규칙이 없다」 두 단언으로 다시 쓴다.
      - 같은 파일의 `captionEmbedsTheGivenCountExactly`·`captionDiffersBetweenCardAndDetailGantries`·
        `headingEmbedsTheGivenMetricLabelAndCountExactly`·`headingDiffersBetweenCPUAndMemoryMetricLabels`가 통과한다 —
        상세 목록 머리글과 캡션은 계속 쓰이므로 대상을 잃지 않는다.
      - `DashboardPresentationTests`의 `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsHeading`이 통과하고,
        카드 접근성 이름의 순위 안내가 정원·제외 사실을 유지함을 항목별 단언으로 확인한다.
        `recentIncreaseRankingCaptionMatchesDetailGantryNotCardGantry`·`detailApplicationsHeadingEmbedsDetailGantry`·
        `detailApplicationsHeadingStatesCurrentUsageAndDetailGantry`도 통과한다.
      - CPU 상세에도 제외 안내가 도달함을 확인하는 단언을 두고 통과시킨다 — 착수 전에는 Memory 상세 한 자리에만 있었다.
      - `DashboardCardLayoutTests`의 `cardRankingHeadingFitsTheCardContentWidth`가 「상위 앱」으로 통과하고,
        카드 높이 기준값 329 / 224와 `cardRankingRowsKeepIconSlotBeforeContent`·
        `everyValuelessCardRankingRowReservesTheSameIconSlot`·`everyFilledCardRankingRowReservesTheSameIconSlot`이 통과한다.
      - `DetailPopoverValuelessStateTests`의 `확정 후보 400×480의 폭에 가장 넓은 상세 조립이 들어간다`와
        `CPU·Memory 상세 콘텐츠의 프레임은 네 상태 모두 재확정한 400×480이다`가 안내 줄이 더해진 뒤에도 통과한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와
        `-only-testing:ResourceRunnerUITests/DashboardCPUCardUITests`·`-only-testing:ResourceRunnerUITests/DashboardMemoryCardUITests`를 돌린다.
        `testOpeningPopoverShowsCPUValueCollectionProgressAndTopApplicationsHeading`이 카드 접근성 이름에서 순위 안내를 잡으므로,
        접근성 문구를 유지한 이 변경에서 기대 문자열이 움직이지 않아야 한다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.4, §5.12 / DESIGN §5 DP10

- [x] task-009: 본체와 상세의 고정 크기를 실측으로 다시 확정한다
  - 목적: 커진 카드에 맞춘 본체 팝오버 높이가 실측과 맞고,
    수집 상태가 바뀌어도 상세를 열고 닫아도 앱 행을 펼치고 접어도 팝오버와 카드의 크기·위치가 변하지 않는다.
    카드가 넷이 된 상태의 세로 합계가 새 카드 높이로 다시 산출되어 기준 기기에서 성립한다.
  - 접근: 본체 고정 높이 제약을 임시로 걷고 XCUITest로 팝오버를 열어 수집 중·정상 두 상태의 프레임 높이를 읽는다.
    읽은 값에서 `NSPopover` chrome 26pt를 뺀 값을 고정 높이에 넣고, 제약을 되건 뒤 같은 값이 다시 나오는지 확인한다.
    상세는 400×480을 유지한 채 새 조립이 그 안에 드는지만 다시 확인한다.
  - 검증 조건:
    - 결과: 수집 중 상태와 정상 상태의 팝오버 프레임 높이가 같은 값으로 나온다 — 두 값이 갈리면 슬롯 고정이 깨진 것이므로 그 자리를 먼저 고친다.
      확정 값은 산술 **601**(콘텐츠) / **627**(프레임)이거나, 직전 feature에서 산술 509가 실측 508로 나온 것과 같은 1pt 차가 재현되면 600 / 626이다.
      둘 중 어느 값인지는 위 절차의 실측이 정하며 산술로 박지 않는다.
      콘텐츠 산술의 근거가 `32 + 329 + 16 + 224`임을 확인한다 — 실측이 이 값에서 1pt를 넘게 벗어나면 앞 Task의 조립이 어긋난 것이다.
      상세는 400×480 그대로이고 56코어 격자 아래끝 476 ≤ 480, 가장 넓은 상세 조립이 콘텐츠 폭 368pt 안이다.
      M3 카드 넷 모델 1의 콘텐츠가 `703 + 3S`이고 `S = 118`에서 **1057**, 프레임 **1083**으로 기준 기기 `visibleFrame` 1084pt 안이다(여유 1pt).
      모델 2는 콘텐츠 1289 / 프레임 1315로 초과하며 직전 판본과 같은 결론이다.
      네 상태·상세 열고 닫기·앱 행 펼침과 접힘·스크롤 전후에서 팝오버 프레임과 두 카드 프레임이 같다.
      임시로 걷은 제약과 계측 코드가 코드에 남아 있지 않다.
    - 확인:
      - `ResourceRunnerUITests`의 `testDashboardPopoverKeepsItsMeasuredHeightFromCollectingToNormal`의 기준값 534를 실측값으로 갱신하고,
        수집 중·정상 두 상태가 같은 리터럴로 잡혀 통과한다.
      - `DashboardCardLayoutTests`의 카드 높이 기준값 329 / 224가 통과하고,
        M3 예산 단언이 모델 1 식 `703 + 3S`와 프레임 1083에서 유도되어 기준 기기 1084 안임을 잡는다.
      - `DetailPopoverValuelessStateTests`의 `확정 후보 400×480의 폭에 가장 넓은 상세 조립이 들어간다`와
        `CPU·Memory 상세 콘텐츠의 프레임은 네 상태 모두 재확정한 400×480이다`가 통과한다.
      - `CPUCoreGridVerticalBudgetTests`의 14코어 176 · 56코어 476이 480 안임이 통과한다.
      - `DashboardDetailPopoverUITests`의 `testCPUAndMemoryDetailPopoverFramesAreTheSameFixedSize`·
        `testCPUDetailFrameRemainsExactlyFixedWhenAppRowExpands`·`testDetailContentScrollsWithinFixedPopoverFrame`이 통과한다.
      - `DashboardCardSelectionUITests`의 `testCardSelectionLifecycleKeepsFramesFixedAndSurvivesSelfDismissal`,
        `DashboardCPUCardUITests`의 `testCPUCardFrameStaysSameBeforeAndAfterFirstCollection`,
        `DashboardMemoryCardUITests`의 `testMemoryCardFrameStaysSameBeforeAndAfterFirstCollection`,
        `DashboardDetailExpansionUITests`의 `testRowCenterClickExpandsAndPersistsAcrossRerenders`·
        `testRowCenterClickTogglesClosedOnSecondClick`이 통과한다.
      - 임시 계측 코드나 걷어낸 제약이 남아 있지 않음을 `git diff`로 확인한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와 UI 스위트
        `ResourceRunnerUITests`·`DashboardDetailPopoverUITests`·`DashboardCardSelectionUITests`·
        `DashboardCPUCardUITests`·`DashboardMemoryCardUITests`·`DashboardDetailExpansionUITests`를 각각 `-only-testing:`으로 지정해 돌린다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.13, §5.14 / DESIGN §5 DP12, DP15

- [x] task-010: 루트 문서의 세로 예산 수치를 새 값으로 갱신한다
  - 목적: 저장소 루트 문서에 적힌 대시보드 세로 예산 수치가 이 feature가 확정한 카드 높이·프레임과 어긋나지 않는다.
    M3를 여는 사람이 문서만 읽고도 카드 넷 배치의 여유가 얼마인지 알 수 있다.
  - 접근: `docs/design.md`의 「대시보드 본체의 세로 예산」과 `ROADMAP.md` M3 전환 기준에 적힌 카드 산술·프레임·판 상한 서술을
    task-009가 확정한 값으로 바꾼다. 서술의 결론(M3가 배치 구조 변경으로 해소한다)은 그대로 둔다.
  - 검증 조건:
    - 결과: `docs/design.md`의 카드 산술이 CPU `173 + S` / Memory `171`에서 CPU `211 + S` / Memory `224`로 바뀐다.
      카드 넷 프레임이 951pt에서 **1083pt**로 바뀌고, 그 값이 기준 기기 `visibleFrame` 1084pt 안이며 여유가 1pt임이 적힌다.
      본체 콘텐츠 식 `32 + 카드 높이 합 + 16 × (카드 수 − 1)`과 `NSPopover` chrome 26pt는 그대로다.
      M3 모델 1 콘텐츠 식이 `703 + 3S`이고 프레임 ≤ 1084를 만족하는 범위가 `S ≤ 118`(판 ≤ 100pt)임이 적힌다 —
      판을 74~98pt로 낮춰야 한다는 착수 전 서술은 새 계산과 어긋나므로 새 값으로 바뀐다.
      `ROADMAP.md` M3 전환 기준의 세로 예산 근거 줄이 이 feature의 design.md를 출처로 가리키고, 날짜와 수치가 새 값이다.
      본체 고정 높이·팝오버 프레임 수치를 문서에 적는 자리가 있으면 task-009의 실측값과 같다.
      배치 구조 변경 의무(세로 스크롤·아코디언·2열)와 「네 카드의 구조가 일관됩니다」 서술은 그대로 남는다.
    - 확인:
      - `grep -n "951\|173 + S\|171\|74~98\|1083\|703 + 3S\|224\|211 + S" ROADMAP.md docs/design.md` 출력으로
        낡은 수치가 남지 않고 새 수치가 두 문서에 들어갔음을 확인한다.
      - 두 문서에 적힌 수치가 `DashboardCardLayoutTests`의 카드 높이 기준값·M3 예산 단언, task-009가 확정한 본체 고정 높이와
        한 값씩 대응함을 `git diff`로 대조한다. 문서에만 있는 수치가 남지 않는다.
      - `-only-testing:ResourceRunnerTests`를 돌려 문서 갱신이 코드 단언과 어긋나지 않음을 확인한다.
  - 참조: SPEC §5.14 / DESIGN §5 DP12

- [x] task-011: 동작 줄이기 전제 없음과 자체 부하 비상승을 확인한다
  - 목적: 동작 줄이기와 애니메이션 끄기 설정에서도 이 feature가 바꾼 표시가 같은 정보를 전달하고,
    팝오버를 열어 둔 채 관찰한 앱 자신의 CPU 사용량이 변경 전과 비교해 지속적으로 오르지 않는다.
  - 접근: 표시 계층에서 애니메이션이 새로 걸린 자리와 갱신 주기마다 늘어나는 작업을 훑어 아래 결과와 맞는지 확인하고,
    어긋난 자리만 고친 뒤 앱 자신의 CPU 사용량을 표본으로 재어 변경 전과 견준다.
  - 검증 조건:
    - 결과: 표시 경로에 `withAnimation`·`transition`·암시적 애니메이션을 새로 건 자리가 없고, 기존 주기적 재그리기 한 곳만 남는다.
      새 타이머·새 관찰자·새 이미지 생성·색 보간이 없고, 색 해석은 갱신 주기가 아니라 appearance가 바뀔 때만 일어난다.
      갱신 주기마다 하는 일이 줄어든다 — 없어지는 것은 세로 눈금 4선분·판 테두리 1경로·미수집 빗금 최대 41선분·가로 기준선 2선분이고,
      남거나 새로 드는 것은 가로 기준선 1선분과 코어 칸당 정수 비교 최대 3회·상수 선택뿐이다.
      면 채움 셋은 뷰 배경이라 매 tick 다시 계산되지 않는다.
      다운샘플 버킷 수는 판 폭 232pt에서 나오므로 그리는 선분 수가 늘지 않는다.
      App Sandbox가 켜진 채이고 새 entitlement가 없다.
      팝오버를 열어 둔 채 잰 앱 자신의 CPU 사용량이 변경 전 표본과 견줘 지속적으로 상승하지 않는다.
    - 확인:
      - `grep -rn --include='*.swift' -e 'withAnimation' -e '\.transition(' -e '\.animation(' ResourceRunner/`로 표시 계층을 훑어
        이 feature가 새로 더한 애니메이션 자리가 없음을 확인한다.
        애니메이션이 없으면 동작 줄이기 설정이 표시를 바꾸지 않으므로 이 확인이 `SPEC §5.15` 앞 절의 근거가 된다.
      - tick마다 하는 일이 위 결과의 목록대로 줄었음을 `git diff` 범위에서 확인한다.
      - `DashboardPresentationTests`의 `bucketWidthIsFourPixelsPerBucket`·`bucketCountIsAtLeastOneForNarrowWidths`가 통과해
        버킷 수가 판 폭에서만 나옴을 잡는다.
      - entitlements 파일이 변경 전과 같고 App Sandbox 설정이 그대로임을 `git diff`로 확인한다.
      - 앱을 실행해 팝오버를 열어 둔 채 `ps -o %cpu= -p <pid>`를 일정 간격으로 표본화하고,
        같은 절차로 잰 변경 전(`git stash` 또는 착수 전 커밋 빌드) 표본과 견줘 지속 상승이 없음을 출력으로 확인한다.
      - 단위 스위트와 UI 스위트를 각각 `-only-testing:`으로 지정해 모두 돌리고 실패 0으로 통과시킨다.
        앞선 Task들이 돌리지 않은 `StatusItemAccessibilityUITests`·`ResourceRunnerUITestsLaunchTests`도 여기서 함께 확인된다.
        `-only-testing:` 없이 전체 스킴을 한 번에 돌리면 UI 테스트가 본문 실행 전 automation mode 초기화 시간 초과로 끝날 수 있다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
  - 참조: SPEC §5.15 / DESIGN §5 DP16
