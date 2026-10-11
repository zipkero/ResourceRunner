# task-004 제품 변경과 영향 검증

## 범위와 소스 출처

- 작업 cwd: `/Users/zipkero/XcodeProjects/ResourceRunner`; HEAD `69842e14e920e95da179f525055b22dd75c56b74`와 기존 미커밋 변경을 보존했다. [`source-manifest.json`](source-manifest.json)은 task-001 동결 소스 `/tmp/resourcerunner-task001-frozen`과 최종 제품/테스트 파일의 SHA256 및 줄 수를 기록한다. [`product-source.patch`](product-source.patch)는 그 두 입력만 비교한 패치다. 이 동결 소스에는 기존 18pt/CPU 색상·1pt 포커스 변경이 들어 있으므로 patch에는 task-004 변경만 들어 있다.
- task-003의 단일 확인 후보 [`hosting-source.patch`](../task-003/hosting-source.patch)(SHA256 `7aa9158fcd8442aa9322a7bde1d64aafa3205630856c6f0418b858aade12efc4`)와 제품 패치의 `StatusBarController` host factory·열림 연결·`didClose` 해제를 대조했다. 후보의 세 쌍 닫힘 Footprint 최대는 422.56~424.54MB → 62.80~62.93MB였다. 현재 제품은 아래의 신규 원본/제품 세 쌍으로 별도 대조했다. 열린 상태 비용은 아직 미확정이다.
- 제품은 실제 열기 경로에서 최신 store를 읽는 새 `NSHostingController`를 연결하고 실제 `didClose`에서 host를 해제한다. viewport 보정은 현재 generation의 표시 중 팝오버에서만 실행하며 닫힐 때 취소한다. viewport의 이전 세션 앵커·상세 창과 지연 닫기 작업을 무효화한다. 원본 진단 앱의 상세 선택→본체 닫기→재열림이 `body`로 돌아오는 것을 [`detail-reopen.jsonl`](closed-product-baseline/detail-reopen.jsonl)로 확인해, 실제 닫힘에서 store 선택을 해제하고 이전 host의 selection generation을 무효화한다. 수집, history, epoch/admission, 성공·실패·중지·설정 값과 메뉴바 표시 경로의 소스는 변경하지 않았다. hidden publication, 그래프 clock, 설정 host, collector 주기는 채택 근거가 없어 변경하지 않았다.

## 검증

- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -derivedDataPath /tmp/resourcerunner-task004-derived -resultBundlePath /tmp/resourcerunner-task004-tests-r6.xcresult -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO`에 `StatusBarControllerTests`, `DashboardViewportTests`, `ApplicationCoordinatorTests`, `DashboardPresentationStoreTests`, `DashboardMemoryPresentationStoreTests`, `DashboardCardFailureIsolationTests`, `DashboardCollectionStoppedTests`, `DashboardPreferencesBoundaryTests`의 `-only-testing` 인수를 주고 `CODE_SIGNING_ALLOWED=NO test`를 실행했다. cwd는 위 프로젝트 루트이며 xcresult 기준 54 passed, 0 failed, 0 skipped다. xcresult `Info.plist` SHA256 `2711c7106819394eca1f60d51a42171efff2d1bedd2308453dbe7487224f7fe0`.
- 테스트는 실제 AppKit 열림/닫힘 delegate 출력, 닫힘 host 해제, 빠른 재열림의 새 host, 늦은 `didClose` 무시, 이전 viewport 세션의 같은 revision 지연 닫기 무효화, 화면 표시 중 behavior·content·delegate 보존을 확인했다. 새 store 테스트는 CPU·Memory·Network·Disk 네 카드에서 이전 host의 늦은 상세 닫힘 callback이 새 선택을 지우지 못함을 확인한다. 기존 store/coordinator 경계 테스트는 최신 성공/실패/중지/새 epoch/설정 및 독립 메뉴바 전달을 확인했다. 화면의 전체 접근성·그래프 시간 흐름·peak/gap은 후속 영향/UI 검증 대상이다.
- Debug 및 Release `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 성공; 최종 Release 실행 파일 `/tmp/resourcerunner-task004-release/Build/Products/Release/ResourceRunner.app/Contents/MacOS/ResourceRunner` SHA256 `7f9090b8eec6ed58e31ae6293ab08b79897dfd000e29558a9f0311c102f44550`. `git diff --check` 통과. 제품 patch SHA256 `40ccbf4a47bd5c7245665f588392cb7eed4384020c35bafa5ad2d064b5008df1`. 수정 전 테스트 r5 53/53와 첫 진단 복사본의 입력은 [`product-source-v1.patch`](product-source-v1.patch)·[`source-manifest-v1.json`](source-manifest-v1.json)·[`diagnostic-preflight-v1.json`](diagnostic-preflight-v1.json)에 이력으로 남겼으며 첫 진단 복사본은 실행하지 않았다.
- 현재 제품의 진단 복사본은 `/tmp/resourcerunner-task004-perf-diagnostic-r2.app`이고 실행 파일 SHA256은 `579e9cb5de13b3b980646e0930d19874f75b9226bcd40415aa40bdc1464c0969`다. 원본과 같은 진단 ID·entitlements·기본 설정 plist를 사용하며 번들 차이는 실행 파일뿐이다. 출처·도구·서명·설정 해시는 [`diagnostic-preflight.json`](diagnostic-preflight.json)에 기록했다. 원본/현재 제품의 새 측정 PID는 각각 `7578`/`45442`이며, 각 앱에서 시작 후 600초 워밍업, 실제 본체 열기·닫기, 60초 정착, 닫힘 상태 300초×3회·1초 간격을 같은 도구 SHA로 실행했다. 원시·AX·이벤트·창 기록과 해시 및 대응 수치는 [`aggregate.json`](aggregate.json)에 있다. 최종 입력·결과 파일별 SHA256은 [`validation-manifest.json`](validation-manifest.json)에 묶었다.
- 기존 설치 `/Users/zipkero/Applications/ResourceRunner.app`의 PID `16136`와 실행 파일 SHA256 `a4073395407599a16cec757957ded1f4ecbdc535a070e7c985647a3f6bd32c80`을 읽기 전용으로 재확인했다. 이 Task에서 설치 앱을 종료·재시작·교체하거나 설정/로그인 상태를 바꾸지 않았다.

## 동일 조건 결과와 남은 판정

원본과 현재 제품의 닫힘 세 구간은 각각 301개 표본, `valid=true`, 무효 사유 없음이었다. 각 구간의 동일 PID·시작 ticks·실행 파일·설정 SHA·닫힘 상태·빈 창 SHA를 원시 표본에서 확인했다. 최대 일정 지연은 양쪽 모두 10.17ms 이하였다. 아래는 대응 반복의 Footprint 최대와 CPU 평균이다. MB는 10⁶바이트다.

| 반복 | 원본 Footprint 최대 | 제품 Footprint 최대 | 차이 | 원본 CPU 평균 | 제품 CPU 평균 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 419.27 MB | 60.67 MB | 358.60 MB | 6.58% | 2.56% |
| 2 | 420.50 MB | 60.77 MB | 359.73 MB | 6.31% | 2.59% |
| 3 | 421.64 MB | 60.82 MB | 360.82 MB | 6.15% | 2.54% |

원본 최대 Footprint의 실행 간 범위 2.38 MB보다 세 대응 차이 358.60~360.82 MB가 훨씬 크다. 따라서 확인된 hosting 수명 변경은 닫힘 보유 Footprint 감소 근거가 있다. CPU는 이 구간에서 함께 낮았지만 제품의 2.54~2.59%는 1% 목표를 넘으며, 수집·표시 등 다른 비용의 독립 원인은 확인하지 않았다. RSS 최대 차이는 4.60~7.26 MB로 Footprint 수치와 구분한다.

양 arm은 macOS 26.6.2, M3 Max 36 GB, AC 전원, Dark appearance, 설치 앱 PID `16136`, 같은 진단 ID·설정 namespace·도구·공통 `caffeinate` 조건을 기록했다. 초기에는 Mac 사용 가능성을 열어 두었고, 사용자는 약 18:27 KST에 “계속 사용하지 않음”이라고 답했다. 이 회신을 [`environment-events.jsonl`](environment-events.jsonl)에 남겼으며 유효성 판단은 원시 창·일정·상태 조건으로 했다. 네트워크는 양 arm에서 물리 대상 식별/속도 일부 실패가 있었지만 확인된 송수신 값과 네 카드가 표시됐다. 실제 본체의 AX 설명은 양 arm에서 CPU·Disk 10분 그래프와 CPU·Memory TOP5를 포함했다. AX의 카드 설명은 TOP5 각 행이나 그래프 픽셀의 완전한 표시를 입증하지 않는다. Network 본체는 source상 rate 행이며 시간 그래프가 없다.

정식 구간 밖에서 원본과 제품 각각 CPU 상세 선택→본체 닫힘→재열림이 `body`로 돌아오는 것을 [`원본 기록`](closed-product-baseline/detail-reopen.jsonl)과 [`제품 기록`](closed-product-candidate/detail-reopen.jsonl)에 남겼다. 진단 앱·창 관찰기·공통 깨움 프로세스를 모두 종료하고 설치 PID/SHA를 재확인한 기록은 [`cleanup.json`](cleanup.json)이다. 실제 UI의 전체 픽셀·그래프 시간 흐름·포커스/ESC, 반복 수명과 100ms/200ms 반응 시간 및 기능 전체 회귀는 task-005/006 검증 대상이다. task-003의 후보 자료는 승인된 변경 선택의 근거이며 이번 제품 수치와 섞지 않았다.
