# task-004 제품 변경과 영향 검증

## 범위와 최종 소스

작업 cwd는 `/Users/zipkero/XcodeProjects/ResourceRunner`, HEAD는 `69842e14e920e95da179f525055b22dd75c56b74`다. [`source-manifest.json`](source-manifest.json)은 기존 미커밋 18pt·CPU 색상·1pt 포커스 변경을 포함한 `/tmp/resourcerunner-task001-frozen`과 현재 제품/테스트 7파일의 SHA256·줄 수를 기록한다. [`product-source.patch`](product-source.patch)는 그 둘의 차이만 담는다. task-003에서 확인된 단일 hosting 후보와 실제 열림에서 host 생성·실제 `didClose`에서 해제하는 부분을 대조했다.

제품은 팝오버를 실제 열 때 최신 store를 읽는 `NSHostingController`를 연결하고 실제 닫힘에서 해제한다. 닫힘은 viewport의 이전 앵커·상세 창·지연 닫기와 store의 상세 선택 generation을 무효화한다. 생성 당시 display session을 앵커 등록·해제 경계에서 검사해 이전 `AnchorView`의 dismantle/window-detach/report callback이 같은 revision의 새 화면을 조작하지 못하게 한다. 새 열림 전에 이전 frame correction task를 취소·해제해 오래된 task handle이 새 보정을 막지 못하게 한다. 실제 `NSPopover`의 `isShown`이 false가 되는 시점과 `didClose` 도착 순서는 AppKit 구현에 따라 달라질 수 있다. 현재 OS에서 늦은 `didClose` 중간 순서를 재현했다고 주장하지 않으며, 새 task handle 경계는 소스에서 직접 확인한다. 수집, history, epoch/admission, 성공·실패·중지·설정, 독립 메뉴바 전달 경로는 변경하지 않았다.

독립 검증에서 발견한 이전 anchor 해제 경계 전 코드는 [`README-iteration-1.md`](README-iteration-1.md)와 `*-iteration-1` patch/manifest·[`closed-product-candidate/`](closed-product-candidate/)에 남겼다. frame correction task 경계 보완 전 코드는 [`README-iteration-2.md`](README-iteration-2.md)와 `*-iteration-2` patch/manifest·[`closed-product-candidate-r5/`](closed-product-candidate-r5/)에 남겼다. 아래 결과는 최종 소스와 Release r6의 신규 진단 복사본을 사용한다.

## 코드·산출물 검증

Debug macOS arm64에서 `CODE_SIGNING_ALLOWED=NO`, 병렬 테스트 끔으로 `StatusBarControllerTests`, `DashboardViewportTests`, `ApplicationCoordinatorTests`, `DashboardPresentationStoreTests`, `DashboardMemoryPresentationStoreTests`, `DashboardCardFailureIsolationTests`, `DashboardCollectionStoppedTests`, `DashboardPreferencesBoundaryTests` 8개 suite를 실행했다. `/tmp/resourcerunner-task004-tests-r12.xcresult`에서 **56 passed, 0 failed, 0 skipped**이며 `Info.plist` SHA256은 `ffc18a66c8f0c3b6dbe03de4705849f7d497525a394f5dacaa622b497f7c9c04`다. 실제 AppKit delegate 열림·닫힘, host 해제/재생성, 늦은 delegate 무시, 같은 revision의 이전 앵커 callback과 지연 닫기, 네 카드의 늦은 상세 callback, 최신 store·설정·메뉴바 전달을 포함한다. 새 테스트는 `isShown`이 처음 false가 되는 즉시 재열어 새 host의 표시·frame 보정·delegate 출력이 유지되는지 확인한다. 첫 r10 테스트의 “close 호출 직후 `isShown=false`” 가정은 실제 AppKit에서 성립하지 않아 실패했고, 상태 전이를 관찰하는 r12 테스트로 고쳤다. 이는 중간 late-`didClose` 순서의 실행 재현 근거가 아니다.

Debug·Release 빌드와 `git diff --check`가 통과했다. Release 실행 파일 SHA256은 `ccab3eb6a5b27ea82555a189043f69fc643a4bc5dc19d17b742ed4e0e423fee2`다. 최종 진단 복사본 `/tmp/resourcerunner-task004-perf-diagnostic-r4.app` 실행 파일 SHA256은 `281a1e6eba0d0b79e84fd3dc49210d56ee9ba732cef15ac03f2bc9093b891475`다. 원본과 같은 진단 bundle ID·Info.plist·entitlements·설정 namespace이며 번들 차이는 실행 파일뿐이다. strict codesign 검증과 파일별 해시는 [`diagnostic-preflight.json`](diagnostic-preflight.json), [`repair-readiness.json`](repair-readiness.json), [`validation-manifest.json`](validation-manifest.json)에 있다.

## 신규 닫힘 상태 제품 대조

[`closed-product-baseline/`](closed-product-baseline/)의 원본 3회는 원본 실행 파일·계측 도구·canonical 설정·기본 설정·macOS 26.6.2·AC 80%·Dark·설치 앱 PID `16136`·공통 `caffeinate -di -t 9000` 조건이 이번 후보와 같아 원시 그대로 재사용했다. 최종 후보는 새 PID `50374`로 600초 닫힘 워밍업, 실제 본체 열림 약 5초, 닫힘 정착 60초, 300초×3회·1초 간격으로 [`closed-product-candidate-r6/`](closed-product-candidate-r6/)에 기록했다. 워밍업 초기 같은 측정 도구의 1초 신원 사전 검사도 `valid=true`였고 실제 `/private/tmp` 실행 경로·SHA·설정이 인수와 일치했다. 원본과 이번 후보는 각 한 번의 정상 5초 본체 사용 후 정식 구간에 들어갔다. 수정 전 후보와 잘못된 경로·5초 열림 실패 시도는 별도 이력으로 보존하고 이번 결과에 섞지 않았다.

원본·후보의 각 3회는 모두 `valid=true`, 무효 사유 없음, 각각 301개 표본이었다. 각 구간에서 PID·시작 ticks·실행 파일·설정 SHA·닫힘 상태·빈 창 SHA가 일정하고 최대 일정 지연은 10.54ms 이하였다. [`aggregate.json`](aggregate.json)에 원시·AX·이벤트 파일의 SHA256과 대응 수치를 기록했다. MB는 10⁶바이트다.

| 반복 | 원본 Footprint 최대 | 최종 제품 Footprint 최대 | 감소 | 원본 CPU 평균 | 최종 제품 CPU 평균 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 419.27 MB | 60.92 MB | 358.35 MB | 6.58% | 2.52% |
| 2 | 420.50 MB | 61.02 MB | 359.48 MB | 6.31% | 2.53% |
| 3 | 421.64 MB | 60.97 MB | 360.68 MB | 6.15% | 2.52% |

원본 Footprint 최대의 실행 간 범위는 2.38 MB로 세 대응 감소 358.35~360.68 MB보다 작다. 확인된 hosting 수명 변경은 닫힘 보유 Footprint 감소의 근거다. RSS 최대 차이는 3.21~5.83 MB로 Footprint와 구분한다. 최종 제품 CPU 2.52~2.53%는 1% 목표를 넘으며, 열린 상태 비용과 다른 CPU 원인은 확정하지 않았다.

사용자는 19:42 KST에 “계속 사용하지 않음”이라고 회신했고 20:00 KST 이후 Mac 사용을 재개할 수 있다고 안내받았다. 20:08 KST의 선택적 사용 여부 질문에는 회신이 없어 이번 후보 구간의 실제 Mac 사용 상태는 **미확인**이다. 이를 무사용으로 단정하지 않고 원시 창·세션·지연 유효성으로 판정했다. 회신·잠정 상태는 [`environment-events.jsonl`](environment-events.jsonl)와 `launch.json`에 분리해 남겼다. 본체 접근성 설명은 양쪽에서 네 카드, CPU·Disk 10분 그래프, CPU·Memory TOP5를 포함했고 Network 물리 메타데이터 일부 실패와 확인된 rate/대상 수를 같이 표시했다. AX 카드 설명은 TOP5 각 행이나 그래프 픽셀의 완전한 표시 근거가 아니다. Network 본체는 소스상 시간 그래프가 아닌 rate 행이다.

구간 밖 원본과 최종 제품 모두 CPU 상세 선택→본체 닫힘→재열림이 `body`로 돌아왔다([`원본`](closed-product-baseline/detail-reopen.jsonl), [`제품`](closed-product-candidate-r6/detail-reopen.jsonl)). 진단 앱·창 관찰기·공통 깨움 프로세스는 모두 종료했고 설치 `/Users/zipkero/Applications/ResourceRunner.app` PID `16136`와 실행 파일 SHA256 `a4073395407599a16cec757957ded1f4ecbdc535a070e7c985647a3f6bd32c80`을 보존했다([`cleanup.json`](cleanup.json)). 전체 픽셀 표시, 그래프 시간 흐름, 포커스/ESC, 반복 수명, 100ms/200ms 반응과 기능 전체 회귀는 task-005/006 검증 대상이다. hidden publication·그래프 clock·설정 host·collector 주기는 변경하지 않았다.
