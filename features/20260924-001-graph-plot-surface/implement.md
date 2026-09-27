# 그래프 판의 영역 표시 구현

- [x] task-001: 팔레트에 그래프 판 면과 판 기준선 값을 두고 둘의 관계를 잠근다
  - 목적: 그래프 판을 그리는 자리가 팔레트에서 라이트·다크 각각 따로 확정된 무채색 판 면 색과 판 기준선 색을 CPU 접두 없는 이름으로 얻는다.
    판 면은 두 모드 모두 팝오버 바탕과 카드 면 사이에 가라앉아 있고, 두 밴드 색이 그 위에서 3:1 이상으로 읽힌다.
    기준선은 판 면보다 한 단 어두운 선으로 판 가장자리 단차보다 약하게 보이고, 두 밴드 채움 위에 겹쳐도 보이면서 그 채움보다 약하다.
  - 접근: 이미 있는 `graphPlotSurface`(`#f5f5f5` / `#262626`)와 그 판 면 단언들은 그대로 두고, `cpuGridline`(`separatorColor`)을 라이트 검정 α 0.038 / 다크 검정 α 0.18의 `graphPlotGridline`으로 바꾼다.
    팔레트 안에 알파를 받는 `dynamicColor`와 같은 형태의 생성 경로를 두고, `drawCPUGraphGridlines`의 색 참조를 새 이름으로 바꾼다.
    대비 테스트는 기준선 합성 helper를 새 색으로 옮기고, 요구가 빠진 `gridlineOnGraphPlotSurfaceStaysAsVisibleAsOnCardSurface`를 판 기준선 불변형으로 바꾸며, `graphPlotEdgeIsWeakerThanGridlineAndUpperBandFill`의 기준선 쪽 절반을 뒤집는다.
  - 검증 조건:
    - 결과: `graphPlotSurface`가 라이트 `#f5f5f5` · 다크 `#262626` 그대로이고, 두 모드 모두 `바탕 L* < 판 면 L* < 카드 L*`이며 판–카드 `ΔL*` 3.46 / 3.78이 바탕–카드 `ΔL*` 6.60 / 7.67보다 작다.
      `popoverBackground`·`cardSurface`·`cpuUser`·`cpuSystem`·`cpuCoreTrack`·`memoryCompositionTrack`의 값이 바뀌지 않아, 카드가 바탕보다 떠오르는 관계와 스와치·코어 격자·Memory 트랙의 색이 변경 전과 같다.
      `cpuUser`·`cpuSystem`의 판 면 대비가 라이트 4.89 / 10.57 · 다크 5.27 / 10.82로 네 값 모두 3:1 이상이고, 두 밴드를 판 면에 합성한 `ΔL*` 20.6 / 17.3이 하한 10.5를 넘으며 두 채움 불투명도의 차 0.45가 그대로다.
      `cpuGridline`이라는 이름이 production과 테스트 코드에 남지 않고, `graphPlotGridline`이 시스템 색이나 다른 팔레트 값을 참조하지 않는 라이트 검정 α 0.038 · 다크 검정 α 0.18 두 리터럴이다.
      기준선 색은 두 모드 모두 R = G = B인 무채색이다.
      판 면 위에 합성한 기준선은 판 면보다 어둡고, 그 `ΔL*`(3.25 / 3.32)가 2.3보다 크고 판–카드 `ΔL*`보다 작으며, 8비트로 `#ececec` / `#1f1f1f`가 된다.
      판–카드 `ΔL*`는 위 채움의 판 면 합성 `ΔL*`(10.31 / 12.35)보다 작아, 판 면 위 요소의 세기가 `밴드 > 판 가장자리 > 기준선` 순서다.
      두 채움 합성색 각각 위에 기준선을 합성한 `ΔL*`(아래 채움 2.29 / 7.89, 위 채움 2.93 / 5.23)가 판 면 위 기준선 `ΔL*`의 3분의 2 이상이고, 기준선을 그 채움 아래에 깔았을 때의 값보다 크며, 그 채움 자체의 판 면 대비 `ΔL*`(30.95 / 29.70, 10.31 / 12.35)보다 작다.
      이 Task에서 `ResourceRunner/DashboardView.swift`의 변경은 `drawCPUGraphGridlines`의 색 참조 한 자리뿐이다.
      기준선이 약해진 뒤에도 값 없음 카드의 「CPU 그래프 격자」 탐침과 판 면 렌더 테스트의 기준선 잉크 단언이 기준선 픽셀을 잉크로 센다.
    - 확인:
      - `DashboardColorPaletteTests`의 기준선 합성 helper가 `graphPlotGridline`을 appearance별로 풀어 그 알파 그대로 판 면과 두 채움 합성색에 합성하게 바꾼다.
        채움 합성색은 테스트 안 리터럴이 아니라 `HistoryGraphView.fillOpacity(for:)`와 두 밴드 색에서 유도한다.
      - `gridlineOnGraphPlotSurfaceStaysAsVisibleAsOnCardSurface`를 지우고, 두 모드에서 아래 단언을 두어 통과시킨다.
        「판 면 위 기준선 합성 `L*` < 판 면 `L*`이고 `2.3 < ΔL* < 판–카드 ΔL*`」,
        「두 채움 위 기준선 `ΔL*`가 판 면 위 기준선 `ΔL*`의 3분의 2 이상이고, 채움 아래에 깔았을 때보다 크고, 그 채움의 판 면 대비 `ΔL*`보다 작다」,
        「기준선 색의 R·G·B가 같다」.
      - `graphPlotEdgeIsWeakerThanGridlineAndUpperBandFill`은 「판 가장자리 < 기준선」을 「판 면 위 기준선 < 판 가장자리」로 뒤집고 「판 가장자리 < 위 채움」을 그대로 둔 채 통과한다.
        테스트 이름과 설명 주석의 세기 순서도 `밴드 > 판 가장자리 > 기준선`으로 따라간다.
      - `graphPlotSurfaceSitsBetweenPopoverBackgroundAndCardSurfaceInBothAppearances`·`graphPlotSurfaceIsAchromaticInBothAppearances`·`cpuBandColorsMeetGraphPlotSurfaceContrastInBothAppearances`·`cpuBandCompositeLightnessDifferenceImprovesInBothAppearances`가 바뀌지 않은 채 통과한다.
      - `popoverBackgroundAndCardSurfaceLiftTheCardInBothAppearances`·`allSixteenColorsMeetContrastAndKeepTheSameStepMeaning`·`cpuBandsUseTheCPUResourceRamp`가 바뀌지 않은 채 통과한다.
      - `DashboardCardLayoutTests`의 `everyValuelessStateRendersEveryNewDisplayElement`(「CPU 그래프 격자」 탐침)와 `plotSurfaceCoversTheWholeWindowWhenDataFillsOnlyTheRightEnd`(기준선 잉크 단언)가 테스트를 바꾸지 않은 채 통과한다.
      - `git diff`로 위 여섯 색 값이 바뀌지 않았고 `graphPlotGridline`의 두 리터럴이 검정 α 0.038 / 0.18임을 확인한다.
        8비트 결과는 그 리터럴로 계산해 확인한다 — 라이트 245 × 0.962 = 235.69 → 236(`0xec`), 다크 38 × 0.82 = 31.16 → 31(`0x1f`).
      - `grep -rn cpuGridline ResourceRunner ResourceRunnerTests ResourceRunnerUITests` 출력이 비어 있음을 확인한다.
      - 테스트 실행은 `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -only-testing:ResourceRunnerTests`로 단위 스위트만 돌린다.
  - 참조: SPEC §5.2, §5.4, §5.5 / DESIGN §1 색 경계, §3, §4, §5 DP1, DP4, DP5, DP7, DP10

- [x] task-002: CPU 그래프 판 전체에 판 면을 깔고, 기준선을 두 밴드 채움 위의 눈금으로 긋는다
  - 목적: 라이트·다크 모두에서 CPU 카드 그래프 판 전체가 카드 면보다 한 단 가라앉은 면으로 덮여, 데이터가 창의 일부에만 있거나 밴드가 몇 pt뿐이어도 면의 위아래 끝이 100%·0%, 좌우 끝이 시간 창의 양끝으로 보인다.
    50% 기준선은 판을 가르는 경계가 아니라 그 면 안의 눈금으로 읽히고, 부하가 50%를 넘어 두 밴드가 그 자리를 덮어도 밴드 안에서 보이며, 값을 나타내는 두 경계선은 기준선에 덮이지 않는다.
    값이 없는 자리표시도 같은 면을 같은 크기·같은 자리에 보이며, 판 위의 선 개수·카드와 팝오버의 크기·접근성으로 도달하는 정보는 변경 전과 같다.
  - 접근: 이미 있는 판 틀의 `graphPlotSurface` 배경과 `.clipped()`, `visibleInk`·`RenderedGraphPlotSurface`·`renderedSRGBColor`, `CPUGraphPlotSurfaceRenderingTests`의 네 테스트와 `lowLoadCard`는 유지하고, `lowLoadCard`는 부하 값을 받는 `steadyLoadCard`를 부르도록 둔다.
    `HistoryGraphView.drawOrder`만 `bandFill(.lower) → bandFill(.upper) → gridlines → bandBoundary(.lower) → bandBoundary(.upper)`로 바꾸고 그 설명 주석을 새 순서의 이유로 고친 뒤, 기준선 순서를 잠그던 단언을 새 순서로 바꾸고 기준선 줄 픽셀 단언과 50%를 넘는 부하 입력의 렌더 단언을 더한다.
  - 검증 조건:
    - 결과: 판 면이 판 틀 232 × 100과 같은 크기·같은 자리, 곧 카드 렌더의 x 8..<240 · y 87..<187을 덮고, 틀 바로 밖 줄(y 85·86·187·188)과 칸(x 7·240)은 카드 면이다.
      판 면은 `points`를 읽지 않아 수집 여부와 무관하게 시간 창 전체를 같은 모양으로 덮는다.
      값 없음 세 상태(수집 중·성공 이력 없는 실패·중지)에서 틀 안 픽셀이 기준선 줄을 빼고 모두 판 면이고, 네 모서리 픽셀도 판 면이라 면이 각져 있다.
      낮은 부하(전체 7% · User 4%)로 창 오른쪽 60초만 채운 입력에서 데이터 없는 왼쪽 구간과 기준선 위쪽 절반이 기준선 줄을 빼고 판 면이라, 미수집 구간이 자기 경계를 가진 면으로 갈리지 않는다.
      같은 부하로 창 전체를 채운 입력에서도 기준선 위쪽 절반과 틀 밖 줄·칸이 같은 판 면·카드 면이라, 수집 초기와 창이 다 찬 뒤의 판 모양이 같다.
      창 오른쪽 끝에 점이 있는 입력과 창 시작을 막 벗어난 점이 남은 입력에서 밴드가 틀 밖 카드 면으로 번지지 않는다.
      판 면 가장자리에 윤곽선이 없다 — 틀 안 첫·끝 줄과 칸에서 밴드·기준선이 닿지 않는 픽셀은 판 면 색 그대로다.
      값 없음 세 상태와 낮은 부하 값 있음 입력에서, 기준선 줄의 데이터 없는 칸 픽셀이 판 면보다 어둡고 카드 면 색이 아니다.
      부하가 50%를 넘는 두 입력(User가 50%를 넘는 입력, User는 50% 아래이고 전체가 50%를 넘는 입력)에서, 기준선 줄의 밴드 칸 픽셀이 같은 칸 열의 기준선 밖 같은 채움 픽셀보다 어둡다.
      `HistoryGraphView.drawOrder`가 `bandFill(.lower) → bandFill(.upper) → gridlines → bandBoundary(.lower) → bandBoundary(.upper)`로 다섯 항목이고, `.gridlines`는 하나이며 두 채움보다 뒤·두 경계선보다 앞이다.
      `HistoryGraphGridline.placeholderDrawOrder`는 `[.gridlines]` 그대로이고, 두 경로가 같은 `.gridlines` 레이어와 같은 `drawCPUGraphGridlines`를 쓴다.
      판 위의 선은 50% 기준선 하나이고, `HistoryGraphGridline.lineWidth` 1과 실선 모양이 그대로다.
      두 채움 불투명도 0.60 / 0.15와 아래 점선 `[3, 2]` · 위 실선 경계가 그대로라 두 밴드는 변경 전과 같은 수단으로 갈린다.
      판 100 · 슬롯 118 · CPU 카드 높이가 수집 중·정상·실패·중지 네 상태에서 같고, 카드 안쪽 여백 띠는 카드 면이며 그 면이 팝오버 바탕과 갈린다.
      카드 넷 세로 예산 단언이 그대로 성립해 판 100pt가 `docs/design.md` 계산의 상한으로 남는다.
      값 없음 판에 채도 0.35 초과 픽셀이 없다.
      판 면과 기준선에 접근성 수정자가 붙지 않아 카드의 `.accessibilityElement(children: .ignore)` 안쪽에 남고, 카드 접근성 이름과 `CPUCard` 식별자가 그대로다.
    - 확인:
      - `DashboardPresentationTests`의 `gridlinesAreDrawnBeforeBandFillsAndBoundaries`·`drawOrderIsGridlinesThenFillsAndBoundaries`를 새 순서(배열 전수, 개수 5, `.gridlines` 하나, 두 채움 뒤·두 경계선 앞) 단언으로 바꿔 통과시킨다.
        두 테스트 이름과 `HistoryGraphViewDrawOrderTests` 설명 주석이 가리키는 순서와 이유도 새 순서에 맞게 따라간다.
      - `placeholderDrawOrderContainsOnlyGridlines`의 `HistoryGraphView.drawOrder.first == .gridlines`를 「값 있음 배열에 `.gridlines`가 정확히 하나 있다」로 바꾸고, `[.gridlines]`·개수 1·개수 5 단언은 그대로 둔 채 통과시킨다.
      - `bandFillOpacitiesAreTranslucentSoGridlinesShowThrough`는 0.60 / 0.15와 둘 다 1 미만인 단언을 그대로 두고, 이름과 설명이 가리키는 이유만 새 순서에 맞게 고친 채 통과시킨다.
      - `lowerBoundaryIsDashedAndUpperBoundaryIsSolid`·`exactlyOneBaselineIsDrawnAndItIsTheMiddleTickValue`·`zeroPercentIsAtTheBottomAndHundredPercentIsAtTheTop`·`pointAtWindowStartIsAtLeftEdge`·`pointAtCurrentTimestampIsAtRightEdge`·`graphSlotHeightIsDerivedFromPlotAxisSpacingAndLabelHeight`와 `lineWidth == 1` 단언이 바뀌지 않은 채 통과한다.
        좌표 변환 단언이 판 틀 네 변과 0%·100%·창 양끝이 겹친다는 것을 잡는다.
      - `CPUGraphPlotSurfaceRenderingTests`의 `valuelessStatesCoverTheWholePlotFrameWithTheGraphPlotSurface`·`plotSurfaceCoversTheWholeWindowWhenDataFillsOnlyTheRightEnd`·`plotSurfaceKeepsTheSameShapeWhenDataFillsTheWholeWindow`·`bandsJustOutsideTheWindowStartDoNotSpillPastThePlotFrame`가 바뀌지 않은 채 통과한다.
      - 같은 스위트에 기준선 줄 단언을 더해 통과시킨다 — 값 없음 세 상태와 창 오른쪽 60초 입력의 데이터 없는 칸에서 「기준선 줄 픽셀이 판 면보다 어둡고 카드 면 색이 아니다」.
      - 같은 스위트에 50%를 넘는 두 입력의 렌더 단언을 더해 통과시킨다(예: User 60% · 전체 70%, User 30% · 전체 70%).
        각 입력에서 기준선 줄이 지나는 밴드 칸 픽셀이 같은 칸 열에서 기준선 줄과 경계선을 비켜 둔 같은 채움 픽셀보다 어둡다는 것을 본다.
        입력이 실제로 그 채움으로 50% 자리를 덮었는지(기준선 줄 위아래 픽셀이 판 면이 아님)도 함께 본다.
      - `DashboardCardLayoutTests`의 `cpuCardHeightIsSameAcrossAllFourStates`·`cpuCardHeightIsSameRegardlessOfUserSystemBandValues`·`cardHeightsMatchBaselinesAcrossEveryStateWithNewElements`·`borderOnlySurfaceKeepsPreSurfaceChangeCardHeights`·`fourCardVerticalBudgetFitsTheReferenceDevice`·`cardSurfacesFillTheirInteriorWithASurfaceDistinctFromThePopoverBackground`·`cpuGraphPlaceholderDoesNotRenderInventedZeroValues`·`everyValuelessStateRendersEveryNewDisplayElement`가 통과한다.
      - `DashboardPresentationTests`의 `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsHeading`·`collectingStateIncludesSelectionShortcut`·`valuelessFailureAndStoppedStatesKeepTheTimeWindowAndCollectionProgress`가 기대 문자열을 바꾸지 않은 채 통과한다.
      - `git diff 055784a -- ResourceRunner/`로 이 feature의 production 변경이 팔레트(task-001), 판 틀의 배경·클리핑 한 자리, `HistoryGraphView.drawOrder`의 순서와 그 설명 주석, `drawCPUGraphGridlines`의 색 참조뿐임을 확인한다.
        `ResourceRunner/DashboardPresentation.swift`·`ResourceRunner/DashboardStyle.swift`, 두 `Canvas`의 채움·경계선 그리기 내용, `GraphPlaceholderView`에 변경이 없어야 한다.
        판 틀과 기준선에 `accessibility` 수정자·`overlay`·`stroke`·`border`·모서리 반경·`blendMode`·`drawLayer`가 붙지 않았음도 같은 diff로 확인한다(클리핑은 각진 사각형 틀 경계 하나).
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와 `-only-testing:ResourceRunnerUITests/DashboardCPUCardUITests`·`-only-testing:ResourceRunnerUITests/ResourceRunnerUITests`를 돌린다.
        `testOpeningPopoverShowsCPUValueCollectionProgressAndTopApplicationsHeading`이 카드 접근성 이름의 항목을, `testCPUCardFrameStaysSameBeforeAndAfterFirstCollection`과 `testDashboardPopoverKeepsItsMeasuredHeightFromCollectingToNormal`이 수집 중에서 정상으로 넘어갈 때 카드와 팝오버 프레임이 그대로인지를 잡는다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
      - 수동 확인: 실기기에서 라이트와 다크 각각 아래 두 화면을 보고 관찰을 보고한다 — 지각 판정이라 픽셀 탐침과 수치 불변형으로 대체되지 않는 잔여 판단이다.
        - 낮은 부하 화면: 배경 작업 없이 앱을 켠 직후(수집 초기) 팝오버를 연다.
          판의 위아래·좌우 끝이 면의 가장자리로 읽혀 판 범위가 보이는지, 기준선이 판을 위아래로 가르는 경계가 아니라 판 안의 눈금으로 읽히는지(기준선 위쪽 절반이 카드 여백이 아니라 판의 일부로 보이는지), 그러면서도 50% 높이를 어림할 만큼 보이는지를 본다.
        - 50%를 넘는 부하 화면: `sysctl -n hw.logicalcpu`로 논리 코어 수 N을 확인하고 `for i in $(seq 1 <N의 3분의 2 이상>); do yes > /dev/null & done`으로 전체 CPU를 50% 위로 올려 1–2분 유지한다.
          `yes`는 User 시간이 대부분이라 기준선이 아래 채움(User 밴드) 안을 지나는 화면이 된다.
          위 채움(System 밴드) 안을 보려면 `yes` 수를 N의 3분의 1 안팎으로 줄이고 `dd if=/dev/zero of=/dev/null bs=1 &`처럼 System 시간이 큰 부하를 여러 개 더해, 요약 줄에서 User가 50% 아래이고 전체가 50% 위인지 확인한 뒤 본다.
          그 조건이 만들어지지 않으면 본 밴드만 보고한다.
          두 밴드 안에서 기준선이 보여 높은 값이 50%보다 얼마나 위인지 어림되는지(특히 라이트 User 밴드 안, 설계상 `ΔL*` 약 2.3), 다크에서 판 면 위와 밴드 안의 기준선 세기 차이가 밴드를 위아래로 가르는 인상으로 거슬리지 않는지를 본다.
          끝나면 `pkill -x yes`와 `pkill -f "dd if=/dev/zero of=/dev/null"`로 부하를 정리하고 `pgrep -x yes`·`pgrep -x dd` 출력이 비었는지 확인한다.
        - 범위가 약하게 읽히거나 기준선이 경계로 읽히거나 밴드 안에서 보이지 않으면, 이 Task 안에서 판 면·기준선 값과 순서를 바꾸지 않고 관찰 결과를 보고한다.
  - 참조: SPEC §5.1, §5.2, §5.3, §5.4, §5.5, §5.6, §5.7, §5.8 / DESIGN §1 그래프 판 경계, §1 그리기 순서 경계, §2, §3, §4, §5 DP2, DP3, DP7, DP8, DP9, DP10

- [x] task-003: 대시보드 그래프 판 공통 규칙을 면과 기준선 세기 기준으로 고친다
  - 목적: `docs/product.md`를 읽는 사람이 대시보드의 모든 그래프 판이 선이 아니라 면으로 자기 범위를 나타내고, 기준선은 판 가장자리보다 약한 눈금이며 밴드 안에서도 보인다는 규칙을 현재 화면과 같은 내용으로 확인하고, M3의 Network·Disk 그래프가 그 규칙을 그대로 참조할 수 있다.
  - 접근: `docs/product.md` §대시보드 §공통 정보 구조의 그래프 판 규칙 문단 앞 두 문장을 design.md §5 DP6의 여덟 문장으로 바꾸고, 미수집 구간 두 문장은 그대로 잇는다.
  - 검증 조건:
    - 결과: 문단이 「대시보드의 모든 그래프 판은 선이 아니라 면으로 자기 범위를 나타냅니다」로 시작해 적용 범위가 CPU 밖 그래프 판 전체다.
      면의 뜻(위아래 끝이 세로 범위의 양끝, CPU는 100%와 0%, 좌우 끝이 시간 창의 양끝), 세기(카드 면보다 한 단 가라앉은 무채색, 카드와 바탕 사이 단차보다 약함), 윤곽선 없음, 자리표시의 같은 판 면이 적힌다.
      판 위의 선이 가로 기준선 하나이고 세로 눈금·판 테두리가 없다는 것, 기준선이 판 면보다 한 단 더 가라앉은 무채색 실선으로 판 면 가장자리 단차보다 약하다는 것, 기준선이 밴드 채움 위·밴드 경계선 아래에 그려진다는 것과 그 이유가 적힌다.
      판 면과 기준선의 세기는 값이 아니라 관계로 적혀 구체 값은 팔레트가 소유한다.
      미수집 구간 두 문장과 §CPU §기본 카드의 기준선 문장은 바뀌지 않는다.
      새 문장마다 task-001·task-002가 잠근 화면 사실과 하나씩 대응하고, 문서에만 있는 주장이 남지 않는다.
      `docs/design.md`와 `ROADMAP.md`는 바뀌지 않는다.
    - 확인:
      - `git diff docs/product.md`가 design.md §5 DP6의 diff와 같은 범위(그래프 판 규칙 문단 앞 두 문장 → 여덟 문장)만 바꿨음을 대조한다.
      - 새 문장을 task-001·task-002의 단언과 문장별로 대조한다 — 판 면이 틀 전체를 덮고 틀 밖이 카드 면, 좌표 변환의 네 변 일치, `바탕 < 판 < 카드`와 판–카드 단차 < 바탕–카드 단차, 판 면·기준선 무채색, 윤곽선·모서리 반경 없음, 두 경로의 판 면 공유, 레이어 배열의 기준선 하나와 두 채움 뒤·두 경계선 앞, `lineWidth` 1 실선, 판 면 위 기준선 < 판 가장자리, 50%를 넘는 입력의 밴드 안 기준선.
      - `grep -n "그래프 판\|판 면\|판 테두리\|기준선" docs/product.md` 출력으로 다른 자리에 새 규칙과 어긋나는 서술이 남지 않았음을 확인한다.
      - `git diff --stat docs/design.md ROADMAP.md`가 이 Task에서 비어 있음을 확인한다.
  - 참조: SPEC §5.10 / DESIGN §1 문서 경계, §4 문서, §5 DP4, DP6

- [x] task-004: 동작 줄이기 전제 없음과 자체 부하 비상승을 확인한다
  - 목적: 동작 줄이기와 애니메이션 끄기 설정에서도 판 면과 새 기준선이 있는 그래프가 같은 모습으로 보이고, 팝오버를 열어 둔 채 관찰한 앱 자신의 CPU 사용량이 변경 전과 비교해 지속적으로 오르지 않는다.
  - 접근: 이 feature의 변경 범위에서 애니메이션이 새로 걸린 자리와 갱신 주기마다 늘어나는 작업을 훑어 아래 결과와 맞는지 확인하고, 어긋난 자리만 고친 뒤 앱 자신의 CPU 사용량을 변경 전과 같은 절차로 견준다.
  - 검증 조건:
    - 결과: 판 면과 기준선은 정적 색이고 `withAnimation`·`transition`·암시적 애니메이션이 걸리지 않아 동작 줄이기 설정이 표시를 바꾸지 않는다.
      새 타이머·새 관찰자·새 이미지 생성·색 보간이 없고, 판 면과 기준선의 라이트·다크 선택은 다른 팔레트 색과 같이 appearance가 바뀔 때만 일어난다.
      `TimelineView`의 1초 주기가 그대로이고, 두 `Canvas`가 매 갱신 그리는 레이어는 같은 다섯 항목·같은 한 항목이며 순서만 바뀌어 갱신 주기마다 하는 일이 늘지 않는다.
      기준선은 일반 알파 합성으로 한 번 긋고 블렌드 모드·별도 합성 레이어·클리핑 경로를 더하지 않는다.
      팝오버를 열어 둔 채 잰 앱 자신의 CPU 사용량이 변경 전 표본과 견줘 지속적으로 상승하지 않는다.
    - 확인:
      - `grep -rn --include='*.swift' -e 'withAnimation' -e '\.transition(' -e '\.animation(' ResourceRunner/` 출력과 `git diff 055784a -- ResourceRunner/`를 견줘 이 feature가 새로 더한 애니메이션 자리가 없음을 확인한다.
        애니메이션이 없으면 동작 줄이기 설정이 표시를 바꾸지 않으므로 이 확인이 동작 줄이기 절의 근거다.
      - 같은 diff에서 `Timer`·`TimelineView`·`onReceive`·`NotificationCenter`·`ImageRenderer`·색 보간·`blendMode`·`drawLayer`·`clip(`이 새로 생기지 않았음을 확인한다.
        작업 트리에 이 feature와 무관한 변경이 있으면 그 파일은 대조에서 뺀다.
      - task-002에서 새 순서로 바꾼 `DashboardPresentationTests`의 레이어 배열 단언과 `placeholderDrawOrderContainsOnlyGridlines`가 통과해 매 갱신 레이어 목록의 항목 수가 그대로임을 잡는다.
      - 단위 스위트와 UI 스위트를 각각 `-only-testing:ResourceRunnerTests`와 `-only-testing:ResourceRunnerUITests`로 지정해 모두 돌리고 실패 0으로 통과시킨다.
        `-only-testing:` 없이 전체 스킴을 한 번에 돌리면 UI 테스트가 본문 실행 전 automation mode 초기화 시간 초과로 끝날 수 있다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
      - 수동 확인: 변경 후와 변경 전(착수 전 커밋 `055784a`) Release 빌드를 각각 실행 11분 경과(10분 창이 다 찬 뒤)·배경 작업 없음 조건으로 띄운다.
        팝오버를 열어 둔 채 `top -l 17 -s 2 -pid <pid> -stats pid,cpu`의 첫 표본을 뺀 16표본을 떠 평균·표준편차와 앞 8·뒤 8 평균을 견주고, 지속 상승이 없음을 표본 출력으로 남긴다.
        팝오버를 연 실행 중인 앱에서만 얻는 관찰이라 정적 확인으로 대체되지 않는다.
        `ps -o %cpu`는 누적 감쇠 평균이라 순간 부하 비교에 쓰지 않는다.
  - 참조: SPEC §5.9 / DESIGN §2, §5 DP2, DP7, DP10
  - 승인 근거(2026-09-26, HEAD `bf0d186`와 현재 미커밋 production diff): 새 애니메이션·타이머·관찰자·이미지 생성·색 보간·별도 Canvas 합성 경로가 없고, 1초 주기와 값 있음 5개·값 없음 1개 레이어가 유지됨을 확인했다.
    변경 전 `055784a`와 변경 후 Release를 각각 실행 11분 경과·팝오버 열림·단일 앱 프로세스 조건에서 `top` 16표본으로 비교했다. 평균 2.97% / 3.26%, 변경 후 앞 8·뒤 8 평균 모두 3.26%로 지속 상승이 없었다(원시 로그 `/tmp/ResourceRunner-task004-before-clean-top.txt`·`/tmp/ResourceRunner-task004-after-clean-top.txt`).
    단위 924건 통과(`/tmp/ResourceRunner-task004-unit.log`), 잠금 해제와 실행 전후 앱 프로세스 0 조건에서 UI 전체 28건 통과(`/tmp/ResourceRunner-task004-ui-canonical-all.log`, `Test-ResourceRunner-2026.09.26_18-17-10-+0900.xcresult`). verify approved, `SPEC §5.9` 충족.
