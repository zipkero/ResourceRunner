# 그래프 판의 영역 표시 구현

- [x] task-001: 팔레트에 그래프 판 면 값을 두고 그 면 위의 대비를 잠근다
  - 목적: 그래프 판을 그리는 자리가 팔레트에서 라이트·다크 각각 따로 확정된 무채색 판 면 색 하나를 얻는다.
    그 색은 두 모드 모두 팝오버 바탕과 카드 면 사이에 가라앉아 있고, 두 밴드 색과 50% 기준선이 그 위에서 기존 기준만큼 읽힌다.
  - 접근: 팔레트에 CPU 접두 없는 이름의 판 면 값 하나를 `popoverBackground`·`cardSurface`와 같은 `dynamicColor(light:dark:)` 형태로 라이트 `#f5f5f5` / 다크 `#262626`으로 둔다.
    대비 테스트에 판 면을 appearance별로 풀어 쓰는 기준면을 더하고, 두 밴드 합성 단언의 기준면을 카드 면에서 판 면으로 옮긴다.
  - 검증 조건:
    - 결과: 판 면이 라이트 `#f5f5f5`(`L*` 96.5) · 다크 `#262626`(15.2)이고, 두 값이 각각 리터럴로 확정되어 한쪽에서 반전으로 유도되지 않는다.
      판 면의 R·G·B 세 성분이 두 모드 모두 같아 무채색이다.
      두 모드 모두 `바탕 L* < 판 면 L* < 카드 면 L*`이고, 판–카드 `ΔL*` 3.5 / 3.8이 바탕–카드 `ΔL*` 6.6 / 7.7보다 작다.
      팝오버 바탕 `#ececec` / `#1e1e1e`와 카드 면 `#ffffff` / `#2e2e2e`는 바뀌지 않아 카드가 바탕보다 밝은 관계가 변경 전과 같다.
      `cpuUser`·`cpuSystem`의 판 면 대비가 라이트 4.89 / 10.57 · 다크 5.27 / 10.82로 네 값 모두 3:1 이상이다.
      두 밴드 색의 카드 면 대비(요약 줄 스와치 기준)와 CPU 램프 넷의 카드 면 대비·단조성은 그대로다.
      두 밴드를 판 면에 합성한 `ΔL*`가 라이트 20.6 · 다크 17.3으로 하한 10.5를 넘고, 두 채움 불투명도의 차 0.45는 그대로다.
      기준선(`cpuGridline`)을 판 면에 합성한 결과가 카드 면에 합성한 변경 전과 견줘 대비비 차 0.01 미만, `ΔL*` 감소 1 미만이다 —
      라이트 1.248 → 1.246 · `ΔL*` 8.71 → 8.43, 다크 1.362 → 1.357 · `ΔL*` 9.25 → 9.83.
      판 가장자리 단차(판–카드 `ΔL*` 3.5 / 3.8)가 기준선의 판 면 합성 `ΔL*`(8.43 / 9.83)와 위 밴드 채움의 판 면 합성 차(10.3 / 12.4)보다 작아,
      판 위 요소의 세기가 `밴드 > 기준선 > 판 가장자리` 순서다.
    - 확인:
      - `DashboardColorPaletteTests`에 판 면을 `resolvedSRGB`로 풀어 쓰는 기준면을 두고, 아래 단언을 더해 통과시킨다.
        「두 모드 모두 판 면 ≠ 카드 면이고 `바탕 L* < 판 면 L* < 카드 L*`이며 판–카드 `ΔL*` < 바탕–카드 `ΔL*`」,
        「판 면 위 `cpuUser`·`cpuSystem` 대비 ≥ 3」,
        「판 면의 R·G·B 세 성분이 같다」,
        「기준선의 판 면 합성이 카드 면 합성과 견줘 대비비 차 < 0.01, `ΔL*` 감소 < 1」,
        「판–카드 `ΔL*`가 기준선의 판 면 합성 `ΔL*`와 위 밴드 채움의 판 면 합성 차보다 작다」.
        기준선 색은 테스트 안 리터럴이 아니라 `cpuGridline`을 appearance별로 풀어 알파를 그대로 합성한다.
      - `cpuBandCompositeLightnessDifferenceImprovesInBothAppearances`는 기준면만 판 면으로 옮기고 하한 10.5와 밀도 차 0.45 단언을 그대로 둔 채 통과한다.
      - `popoverBackgroundAndCardSurfaceLiftTheCardInBothAppearances`·`allSixteenColorsMeetContrastAndKeepTheSameStepMeaning`·`cpuBandsUseTheCPUResourceRamp`가 바뀌지 않은 채 통과한다.
      - `git diff`로 `popoverBackground`·`cardSurface`·`cpuUser`·`cpuSystem`·`cpuGridline`의 값이 바뀌지 않았음을 확인한다.
      - 테스트 실행은 `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -only-testing:ResourceRunnerTests`로 단위 스위트만 돌린다.
  - 참조: SPEC §5.4, §5.5 / DESIGN §1 색 경계, §3, §5 DP1, DP4, DP5, DP7

- [ ] task-002: CPU 그래프 판 전체에 판 면을 깐다
  - 목적: 라이트·다크 모두에서 CPU 카드 그래프 판 전체가 카드 면보다 한 단 가라앉은 면으로 덮인다.
    데이터가 창의 일부에만 있거나 밴드가 몇 pt뿐이어도 면의 위아래 끝이 100%·0%, 좌우 끝이 시간 창의 양끝으로 보이고,
    50% 기준선은 판을 가르는 경계가 아니라 그 면 안의 눈금으로 읽힌다.
    값이 없는 자리표시도 같은 면을 같은 크기·같은 자리에 보이며, 판 위의 선과 접근성으로 도달하는 정보는 변경 전과 같다.
  - 접근: `HistoryGraphSlotView`가 두 경로를 고르는 `Group`에 이미 건 판 틀에 task-001의 판 면을 각진 사각형·윤곽선 없는 배경으로 한 번 깐다.
    두 `Canvas`의 그리기 내용과 두 레이어 배열은 건드리지 않고, 픽셀 탐침의 잉크 판정이 판 면 색도 면으로 빼게 바꾼 뒤 판 면 탐침을 더한다.
  - 검증 조건:
    - 결과: 판 면이 판 틀 232 × 100과 같은 크기·같은 자리, 곧 카드 렌더의 x 8..<240 · y 87..<187을 덮는다.
      틀 바로 밖 줄(y 85·86·187·188)과 칸(x 7·240)은 카드 면이다.
      판 면은 `points`를 읽지 않아 수집 여부와 무관하게 시간 창 전체를 같은 모양으로 덮는다.
      값 없음 세 상태(수집 중·성공 이력 없는 실패·중지)에서 틀 안 픽셀이 기준선 줄을 빼고 모두 판 면이며, 네 모서리 픽셀도 판 면이라 면이 각져 있다.
      값 있음 상태에서 창 오른쪽 일부에만 있는 낮은 부하 점 배열을 그리면, 데이터가 없는 왼쪽 구간과 기준선 위쪽 절반이 기준선 줄을 빼고 판 면이다.
      같은 낮은 부하로 창 전체를 채운 점 배열에서도 기준선 위쪽 절반과 틀 밖 줄·칸이 같은 판 면·카드 면이라, 수집 초기와 창이 다 찬 뒤의 판 모양이 같다.
      데이터가 없는 구간의 면 색이 데이터 구간 위쪽의 면 색과 같아, 미수집 구간이 자기 경계를 가진 면으로 갈리지 않는다.
      값 있음과 값 없음 두 경로에서 판 면의 범위(틀 안)와 틀 밖 카드 면의 자리가 같다.
      판 면 가장자리에 윤곽선이 없다 — 틀 안 첫·끝 줄과 칸에서 밴드·기준선이 닿지 않는 픽셀은 판 면 색 그대로이고 선 색이 아니다.
      판 위의 선은 50% 기준선 하나이고, 판 면을 잉크에서 뺀 뒤에도 기준선 탐침이 잉크를 센다.
      `HistoryGraphView.drawOrder`(기준선 → 밴드 채움 둘 → 밴드 경계선 둘)와 `placeholderDrawOrder`(`[.gridlines]`),
      두 밴드 채움 불투명도 0.60 / 0.15와 아래 점선·위 실선 경계가 그대로라 두 밴드는 변경 전과 같은 수단으로 갈린다.
      판 100 · 슬롯 118 · CPU 카드 329가 수집 중·정상·실패·중지 네 상태에서 같고, 카드 안쪽 여백 띠는 여전히 카드 면이며 그 면이 팝오버 바탕과 갈린다.
      카드 넷 세로 예산 단언이 그대로 성립해 판 100pt가 `docs/design.md` 계산의 상한으로 남는다.
      값 없음 판에 채도 0.35 초과 픽셀이 없다.
      판 면에 접근성 수정자가 붙지 않아 카드의 `.accessibilityElement(children: .ignore)` 안쪽에 남고, 카드 접근성 이름과 `CPUCard` 식별자가 그대로다.
    - 확인:
      - `DashboardCardLayoutTests`의 `visibleInk`가 카드 면과 판 면 두 색을 잉크에서 빼게 바꾼다.
        판 면 색 판정은 `RenderedCardSurface`처럼 라이트·다크 두 값을 모두 풀어 둔 후보와 견준다.
        이 교체 뒤 `everyValuelessStateRendersEveryNewDisplayElement`의 「CPU 그래프 격자」 탐침이 기준선 픽셀만으로 통과해야 한다 — 판 면 픽셀만으로 통과하는 형태로 두지 않는다.
      - 같은 파일에 값 없음 세 상태의 판 면 탐침 단언을 두고 통과시킨다 —
        「틀 안이 기준선 줄을 빼고 모두 판 면」, 「네 모서리 픽셀이 판 면」, 「틀 밖 줄 y 85·86·187·188과 칸 x 7·240이 카드 면」.
      - 같은 파일에 값 있음 두 입력의 탐침 단언을 두고 통과시킨다 —
        창 오른쪽 일부에만 있는 낮은 부하 점 배열에서 「데이터 없는 왼쪽 구간과 기준선 위쪽 절반이 기준선 줄을 빼고 판 면」,
        창 전체를 채운 같은 부하 점 배열에서 「기준선 위쪽 절반이 판 면」, 두 입력 모두 「틀 밖 줄과 칸이 카드 면」.
        점 배열의 부하는 밴드 윗끝이 기준선에 닿지 않는 값으로 둔다.
      - `cpuPlaceholderGraph`의 「둘레 경계를 포함」 주석을 판 면과 틀 밖 1pt를 담는 영역이라는 현재 뜻으로 고친다.
      - `DashboardPresentationTests`의 `drawOrderIsGridlinesThenFillsAndBoundaries`·`placeholderDrawOrderContainsOnlyGridlines`·
        `gridlinesAreDrawnBeforeBandFillsAndBoundaries`·`bandFillOpacitiesAreTranslucentSoGridlinesShowThrough`·`lowerBoundaryIsDashedAndUpperBoundaryIsSolid`·
        `exactlyOneBaselineIsDrawnAndItIsTheMiddleTickValue`·`zeroPercentIsAtTheBottomAndHundredPercentIsAtTheTop`·
        `pointAtWindowStartIsAtLeftEdge`·`pointAtCurrentTimestampIsAtRightEdge`·
        `graphSlotHeightIsDerivedFromPlotAxisSpacingAndLabelHeight`가 바뀌지 않은 채 통과한다.
        좌표 변환 단언이 판 틀 네 변과 0%·100%·창 양끝이 겹친다는 것을, 레이어 배열 단언이 판 위의 선이 기준선 하나라는 것을 잡는다.
      - `DashboardCardLayoutTests`의 `cpuCardHeightIsSameAcrossAllFourStates`·`cpuCardHeightIsSameRegardlessOfUserSystemBandValues`·
        `cardHeightsMatchBaselinesAcrossEveryStateWithNewElements`·`borderOnlySurfaceKeepsPreSurfaceChangeCardHeights`·
        `fourCardVerticalBudgetFitsTheReferenceDevice`·`cardSurfacesFillTheirInteriorWithASurfaceDistinctFromThePopoverBackground`·
        `cpuGraphPlaceholderDoesNotRenderInventedZeroValues`가 통과한다.
      - `DashboardPresentationTests`의 `normalStateIncludesGraphSeriesBaselinesAndTopApplicationsHeading`·`collectingStateIncludesSelectionShortcut`·
        `valuelessFailureAndStoppedStatesKeepTheTimeWindowAndCollectionProgress`가 기대 문자열을 바꾸지 않은 채 통과한다.
      - `git diff`로 이 Task의 변경이 판 틀 배경 한 자리와 주석·테스트뿐이고,
        `ResourceRunner/DashboardPresentation.swift`·`ResourceRunner/DashboardStyle.swift`와 두 `Canvas`의 그리기 내용에 변경이 없으며,
        판 면에 `accessibility` 수정자·`overlay`·`stroke`·`border`·모서리 반경이 붙지 않았음을 확인한다.
      - 테스트 실행은 `-only-testing:ResourceRunnerTests`와
        `-only-testing:ResourceRunnerUITests/DashboardCPUCardUITests`·`-only-testing:ResourceRunnerUITests/ResourceRunnerUITests`를 돌린다.
        `testOpeningPopoverShowsCPUValueCollectionProgressAndTopApplicationsHeading`이 카드 접근성 이름의 항목을,
        `testCPUCardFrameStaysSameBeforeAndAfterFirstCollection`과 `testDashboardPopoverKeepsItsMeasuredHeightFromCollectingToNormal`이
        수집 중에서 정상으로 넘어갈 때 카드와 팝오버 프레임이 그대로인지를 잡는다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
      - 수동 확인: 실기기에서 라이트와 다크 각각 앱을 켠 직후(수집 초기, 낮은 부하) 팝오버를 열어,
        판의 위아래·좌우 끝이 면의 가장자리로 읽히는지, 기준선 위쪽 절반이 카드 여백이 아니라 판의 일부로 보여 기준선이 눈금으로 읽히는지,
        판 면이 두 밴드와 기준선보다 먼저 눈에 들어오지 않는지, 판 면이 카드 면과 갈리면서 카드가 바탕 위로 떠오르는 관계가 변경 전과 같은지를 본다.
        범위가 약하게 읽히면 이 Task 안에서 판 면 값을 바꾸지 않고 관찰 결과를 보고한다 — 지각 판정이라 픽셀 탐침으로 대체되지 않는 잔여 판단이다.
  - 참조: SPEC §5.1, §5.2, §5.3, §5.4, §5.5, §5.6, §5.7, §5.8 / DESIGN §1 그래프 판 경계, §2, §3, §5 DP2, DP3, DP7

- [ ] task-003: 대시보드 그래프 판 공통 규칙을 면 기준으로 고친다
  - 목적: `docs/product.md`를 읽는 사람이 대시보드의 모든 그래프 판이 선이 아니라 면으로 자기 범위를 나타낸다는 규칙을 현재 화면과 같은 내용으로 확인하고,
    M3의 Network·Disk 그래프가 그 규칙을 그대로 참조할 수 있다.
  - 접근: `docs/product.md` §대시보드 §공통 정보 구조의 그래프 판 규칙 문단 앞 두 문장을 design.md §5 DP6의 문구로 바꾸고, 미수집 구간 두 문장은 그대로 잇는다.
  - 검증 조건:
    - 결과: 문단이 「대시보드의 모든 그래프 판은 선이 아니라 면으로 자기 범위를 나타냅니다」로 시작해 적용 범위가 CPU 밖 그래프 판 전체다.
      면의 뜻(위아래 끝이 세로 범위의 양끝, CPU는 100%와 0%, 좌우 끝이 시간 창의 양끝), 세기(카드 면보다 한 단 가라앉은 무채색, 카드와 바탕 사이 단차보다 약함),
      윤곽선 없음, 자리표시의 같은 판 면, 판 위의 선이 가로 기준선 하나라는 것, 세로 눈금·판 테두리 없음과 그 이유가 적힌다.
      세기는 값이 아니라 관계로 적혀 구체 값은 팔레트가 소유한다.
      미수집 구간 두 문장과 §CPU §기본 카드의 기준선 문장은 바뀌지 않는다.
      새 문장마다 task-001·task-002가 잠근 화면 사실과 하나씩 대응하고, 문서에만 있는 주장이 남지 않는다.
      `docs/design.md`와 `ROADMAP.md`는 바뀌지 않는다.
    - 확인:
      - `git diff docs/product.md`가 design.md §5 DP6의 diff와 같은 범위(그래프 판 규칙 문단 앞 두 문장 → 여섯 문장)만 바꿨음을 대조한다.
      - 새 문장 여섯을 task-001·task-002의 단언(판 면이 틀 전체를 덮음, 틀 밖 카드 면, 윤곽선·모서리 반경 없음, 두 경로 공유, 레이어 배열의 기준선 하나, `바탕 < 판 < 카드`와 판–카드 단차 < 바탕–카드 단차)과 문장별로 대조한다.
      - `grep -n "그래프 판\|판 면\|판 테두리" docs/product.md` 출력으로 다른 자리에 옛 규칙과 어긋나는 서술이 남지 않았음을 확인한다.
      - `git diff --stat docs/design.md ROADMAP.md`가 이 Task에서 비어 있음을 확인한다.
  - 참조: SPEC §5.10 / DESIGN §1 문서 경계, §4 문서, §5 DP4, DP6

- [ ] task-004: 동작 줄이기 전제 없음과 자체 부하 비상승을 확인한다
  - 목적: 동작 줄이기와 애니메이션 끄기 설정에서도 판 면이 있는 그래프가 같은 모습으로 보이고,
    팝오버를 열어 둔 채 관찰한 앱 자신의 CPU 사용량이 변경 전과 비교해 지속적으로 오르지 않는다.
  - 접근: 이 feature의 변경 범위에서 애니메이션이 새로 걸린 자리와 갱신 주기마다 늘어나는 작업을 훑어 아래 결과와 맞는지 확인하고,
    어긋난 자리만 고친 뒤 앱 자신의 CPU 사용량을 변경 전과 같은 절차로 견준다.
  - 검증 조건:
    - 결과: 판 면은 정적 색 하나이고 `withAnimation`·`transition`·암시적 애니메이션이 걸리지 않아 동작 줄이기 설정이 표시를 바꾸지 않는다.
      새 타이머·새 관찰자·새 이미지 생성·색 보간이 없고, 판 면의 라이트·다크 선택은 다른 팔레트 색과 같이 appearance가 바뀔 때만 일어난다.
      `TimelineView`의 1초 주기와 두 `Canvas`가 매 갱신 그리는 레이어 목록이 변경 전과 같아 갱신 주기마다 하는 일이 늘지 않는다.
      팝오버를 열어 둔 채 잰 앱 자신의 CPU 사용량이 변경 전 표본과 견줘 지속적으로 상승하지 않는다.
    - 확인:
      - `grep -rn --include='*.swift' -e 'withAnimation' -e '\.transition(' -e '\.animation(' ResourceRunner/` 출력과 `git diff`를 견줘 이 feature가 새로 더한 애니메이션 자리가 없음을 확인한다.
        애니메이션이 없으면 동작 줄이기 설정이 표시를 바꾸지 않으므로 이 확인이 동작 줄이기 절의 근거다.
      - 이 feature가 바꾼 production 파일의 `git diff`에서 `Timer`·`TimelineView`·`onReceive`·`NotificationCenter`·`ImageRenderer`·색 보간이 새로 생기지 않았음을 확인한다.
        작업 트리에 이 feature와 무관한 변경이 있으면 그 파일은 대조에서 뺀다.
      - `DashboardPresentationTests`의 `drawOrderIsGridlinesThenFillsAndBoundaries`·`placeholderDrawOrderContainsOnlyGridlines`가 통과해 매 갱신 레이어 목록이 그대로임을 잡는다.
      - 단위 스위트와 UI 스위트를 각각 `-only-testing:`으로 지정해 모두 돌리고 실패 0으로 통과시킨다.
        `-only-testing:` 없이 전체 스킴을 한 번에 돌리면 UI 테스트가 본문 실행 전 automation mode 초기화 시간 초과로 끝날 수 있다.
      - UI 테스트 실행 전과 후에 `ps aux | grep "[R]esourceRunner.app" | wc -l`이 0인지 확인하고, 화면 잠금이 풀린 상태에서 실행한다.
      - 수동 확인: 변경 후와 변경 전(착수 전 커밋) Release 빌드를 각각 실행 11분 경과(10분 창이 다 찬 뒤)·배경 작업 없음 조건으로 띄우고,
        팝오버를 열어 둔 채 `top -l 17 -s 2 -pid <pid> -stats pid,cpu`의 첫 표본을 뺀 16표본을 떠 평균·표준편차와 앞 8·뒤 8 평균을 견준다.
        지속 상승이 없음을 표본 출력으로 남긴다 — 팝오버를 연 실행 중인 앱에서만 얻는 관찰이라 정적 확인으로 대체되지 않는다.
        `ps -o %cpu`는 누적 감쇠 평균이라 순간 부하 비교에 쓰지 않는다.
  - 참조: SPEC §5.9 / DESIGN §2, §5 DP2, DP7
