# task-004 제품 변경과 영향 검증

## 수정 범위와 출처

작업 cwd는 `/Users/zipkero/XcodeProjects/ResourceRunner`, HEAD는 `69842e14e920e95da179f525055b22dd75c56b74`다. [`source-manifest.json`](source-manifest.json)은 기존 18pt·CPU 색상·1pt 포커스 미커밋 변경까지 포함한 `/tmp/resourcerunner-task001-frozen`과 현재 제품/테스트 7파일의 SHA256 및 증감을 기록한다. [`product-source.patch`](product-source.patch)는 이 둘의 차이만 담았다. task-003의 확인된 단일 hosting 후보 [`hosting-source.patch`](../task-003/hosting-source.patch)와 실제 열림에서 host 생성·실제 `didClose`에서 해제하는 부분을 대조했다.

실제 화면 열기에서 최신 store를 읽는 `NSHostingController`를 연결하고 실제 닫힘에서 해제한다. 닫힘 때 viewport 보정 작업과 이전 화면의 앵커·상세 창·지연 닫기를 무효화한다. 이전 `AnchorView`의 `dismantleNSView`·`viewDidMoveToWindow(nil)`가 같은 revision의 새 화면에 등록·해제·보정 callback을 전달하지 못하도록 생성 당시 display session을 `registerCard`/`unregisterCard` 경계에서 검사한다. 실제 닫힘은 `ApplicationCoordinator`를 거쳐 store 상세 선택을 동기적으로 해제하고 selection generation을 무효화한다. 원본 앱에서 상세 선택→본체 닫힘→재열림이 `body`였기 때문에 이 의미를 보존했다. 수집, history, epoch/admission, 성공·실패·중지·설정과 메뉴바 전달 경로는 변경하지 않았다.

독립 verify가 이전 anchor 해제 경계 부족을 지적하기 전의 코드·테스트·3쌍 측정은 [`README-iteration-1.md`](README-iteration-1.md), [`aggregate-iteration-1.json`](aggregate-iteration-1.json), `*-iteration-1` patch/manifest 및 [`closed-product-candidate/`](closed-product-candidate/)에 이력으로 보존했다. 아래 수치는 **수정 후 소스**와 Release 산출물을 사용한다.

## 수정 후 코드 검증

`xcodebuild` 영향 8개 suite(`StatusBarControllerTests`, `DashboardViewportTests`, `ApplicationCoordinatorTests`, `DashboardPresentationStoreTests`, `DashboardMemoryPresentationStoreTests`, `DashboardCardFailureIsolationTests`, `DashboardCollectionStoppedTests`, `DashboardPreferencesBoundaryTests`)를 Debug, macOS arm64, `CODE_SIGNING_ALLOWED=NO`, 병렬 테스트 끔으로 실행했다. [`r9 xcresult`](/tmp/resourcerunner-task004-tests-r9.xcresult/Info.plist) 기준 **55 passed, 0 failed, 0 skipped**, `Info.plist` SHA256 `dc29605a134c153d8ad66749ee84828e873562ff3edbf14e4ee152ebeb40b617`이다. 실제 `AnchorView`를 같은 revision으로 닫고 다시 붙이는 테스트는 옛 dismantle·window detach·report가 새 앵커/상세 창을 건드리지 않고 correction을 요청하지 않는지 확인한다. 기존 테스트는 AppKit 실제 delegate·host 해제/재생성·늦은 닫힘 무시·이전 지연 닫기·네 카드의 늦은 상세 callback·store 경계를 확인한다.

Debug와 Release 빌드가 통과했고 Release 실행 파일 SHA256은 `ff3aed071f6381e4e27c1e3aa218805fdbbfbc93ddcb101702e80cd4a0421ddf`다. `git diff --check`도 통과했다. 수정본 진단 복사본 `/tmp/resourcerunner-task004-perf-diagnostic-r3.app` 실행 파일 SHA256은 `cd5c4a1fbfddfa14fcf4c63c613405ce34cf9609cb1f114f4755e39b542d9768`다. 원본과 같은 진단 bundle ID, Info.plist, entitlements, 설정 namespace를 썼고 번들 차이는 실행 파일뿐이며 strict codesign 검증이 통과했다. [`diagnostic-preflight.json`](diagnostic-preflight.json)과 [`repair-readiness.json`](repair-readiness.json)에 원본·제품·도구·설정·빌드 입력을 고정했다.

## 닫힘 상태 제품 대조

기존 [`closed-product-baseline/`](closed-product-baseline/) 원본 3회는 실행 파일 SHA256 `d549f7fd7ac53cb819419f2b39ed2205aaea3254db67ae19a16530030d4528c0`, 도구·설정·기본 설정·macOS 26.6.2·AC 80%·Dark·설치 앱 PID `16136`·공통 `caffeinate -di -t 9000` 조건이 이번 수정본과 같아 재사용했다. 현재 후보는 새 PID `5757`로 600초 닫힘 워밍업, 실제 본체 열림 약 5초, 닫힘 정착 60초 뒤 300초×3회·1초 간격으로 [`closed-product-candidate-r5/`](closed-product-candidate-r5/)에 기록했다. [`aggregate.json`](aggregate.json)은 각 원시·AX·이벤트 해시와 대응 수치를 보관한다. 세 원본·세 후보 구간 모두 `valid=true`, 무효 사유 없음, 각 301개 표본이며 PID·시작 ticks·실행 파일·설정·닫힘 상태·빈 창 해시가 각 구간에서 일정했다. 최대 일정 지연은 10.17ms 이하였다. MB는 10⁶바이트다.

| 반복 | 원본 Footprint 최대 | 수정본 Footprint 최대 | 감소 | 원본 CPU 평균 | 수정본 CPU 평균 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 419.27 MB | 63.26 MB | 356.01 MB | 6.58% | 2.55% |
| 2 | 420.50 MB | 63.44 MB | 357.06 MB | 6.31% | 2.58% |
| 3 | 421.64 MB | 63.51 MB | 358.14 MB | 6.15% | 2.61% |

원본 Footprint 최대의 실행 간 범위는 2.38 MB로 세 대응 감소 356.01~358.14 MB보다 작다. 확인된 hosting 수명 변경은 닫힘 보유 Footprint 감소의 강한 근거다. 수정본 CPU 2.55~2.61%는 1% 목표를 넘고, 열린 상태 비용과 다른 CPU 원인은 확정하지 않았다. RSS 최대 차이는 0.49~2.97 MB로 Footprint와 구분한다.

정식 구간 전 시도 이력을 숨기지 않는다. 첫 PID `91186`의 측정은 `/tmp` 인수와 실제 `/private/tmp` 실행 경로 문자열 차이로 즉시 무효였고 [`closed-product-candidate-r2/`](closed-product-candidate-r2/)에 오류를 남겼다. 같은 앱을 새 PID `5757`로 시작해 1초 신원 사전 검사(`valid=true`, 2표본, 실제 경로·설정 일치)를 별도 기록했다. 600초 워밍업 직후 첫 5초 본체 열림은 19:42:21~24 KST 창이 닫혀 중단됐다([`closed-product-candidate-r4/`](closed-product-candidate-r4/)); 원인은 확인하지 못했다. 사용자의 “계속 사용하지 않음” 회신 시각과 가까우나 사용자 조작으로 단정하지 않는다. 같은 PID와 완료된 워밍업을 유지해 5초 열림을 다시 수행한 뒤 정식 3회가 유효했다. 따라서 후보에는 원본의 1회보다 추가 본체 열림 이력이 있고, 완전히 동일한 열림 횟수의 대조라고 주장하지 않는다. 정식 세 닫힘 구간의 유효성과 큰 Footprint 차이, 이 사용 이력의 한계를 함께 판단해야 한다. 환경 회신과 잠정 사용상태는 [`environment-events.jsonl`](environment-events.jsonl)에 분리해 남겼다.

양쪽 실제 본체의 접근성 설명에는 네 카드, CPU·Disk 10분 그래프, CPU·Memory TOP5가 들어 있었고 Network 물리 메타데이터는 일부 실패했으나 확인된 rate와 대상 수는 표시됐다. AX 카드 설명만으로 TOP5 각 행이나 그래프 픽셀의 완전한 표시를 입증하지 않는다. Network 본체는 소스상 시간 그래프가 아닌 rate 행이다. 구간 밖 원본과 수정본 모두 CPU 상세→닫힘→재열림이 `body`로 돌아왔다([`원본`](closed-product-baseline/detail-reopen.jsonl), [`수정본`](closed-product-candidate-r5/detail-reopen.jsonl)).

진단 앱·창 관찰기·공통 깨움 프로세스는 모두 종료했고 설치 `/Users/zipkero/Applications/ResourceRunner.app` PID `16136`, 실행 파일 SHA256 `a4073395407599a16cec757957ded1f4ecbdc535a070e7c985647a3f6bd32c80`을 보존했다([`cleanup.json`](cleanup.json)). 전체 픽셀 표시, 그래프 시간 흐름, 포커스/ESC, 반복 수명, 100ms/200ms 반응과 기능 전체 회귀는 task-005/006의 후속 검증 대상이다. hidden publication·그래프 clock·설정 host·collector 주기는 확인된 원인 범위 밖이므로 변경하지 않았다.
