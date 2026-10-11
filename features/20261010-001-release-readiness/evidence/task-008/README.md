# task-008 팝오버 열림 지연 원인 비교 (정지 반환)

2026-10-11 21:30–22:05 KST. HEAD `e02b3b291a5e3254c1df14086868d28d65aacdd3`에 기존 미커밋 변경이 얹힌 현재 작업 트리를 기준으로 했다.
진단 사본에서 한 번에 한 요소만 바꿔 비교했다.
**제품 코드는 바꾸지 않았다.** 이유는 아래 "판정"에 적었다.
이 자료는 원인 비교용 보조 근거이며, 정식 100/200ms 판정이나 task-005 cohort가 아니다.

## 판정

- 재열림에서 가장 큰 앱 쪽 비용은 열 때마다 새로 만드는 hosting의 SwiftUI graph 생성이다.
  V1(hosting 유지)은 `show` 중앙값을 48.0→12.3ms, 첫 픽셀을 103.5→67.6ms, 완전 표시를 174.9→137.6ms로 줄였다.
  하지만 이 경로는 task-004가 채택한 "닫힘 시 hosting 회수"를 바꾼다.
- 완전 표시까지 가장 긴 구간은 NSPopover 열림 애니메이션이다.
  재열림에서 첫 픽셀 뒤 약 70ms가 걸린다.
  V2(`animates=false`)는 완전 표시를 재열림 174.9→91.2ms, 첫 열림 199.3→120.8ms로 줄였다.
  하지만 이는 spec에 정해지지 않은 사용자 가시 변경이다.
- 설계를 바꾸지 않고 측정 가능한 것은 카드 `.keyboardShortcut` 4개의 bridge 비용 하나였다.
  V3는 이를 진단용으로 제거한 것이고, `show` 중앙값은 −7.4ms, 완전 표시는 −3.6ms였다.
  이 차이는 기존 기준 진단(task-005 boundary, 재열림 `show` 중앙 45.6ms)과 오늘 V0(48.0ms) 사이의 실행 간 차이와 같은 크기이고 프레임 간격(8.33ms)보다 작다.
  그래서 원인 확정 경로로 채택하지 않았다.
- 정리하면, 첫 열림과 재열림을 모두 의미 있게 앞당기는 경로는 hosting 유지(설계 결정 변경)와 애니메이션 끄기(사용자 가시 변경) 둘뿐이다.
  두 경로 모두 Task 정지 조건에 해당하므로 구현하지 않고 반환한다.

## 방법

- 기준 V0는 task-005 경계 진단 binary를 그대로 재사용했다(`/private/tmp/resourcerunner-task005-boundary-build/...`, exe SHA `d742c682…`). 그 소스 사본은 현재 원본 127개 파일과 같고, 계측(`variants/v0-instrumentation-from-task005.patch`)과 bundle ID 4줄만 다르다.
  이번에 현재 원본의 `ResourceRunner/` 전체를 cmp로 다시 대조했고, 차이는 계측한 `StatusBarController.swift` 하나였다.
- 변형 V1·V2·V3는 V0 소스를 복사한 뒤 파일 하나만 바꿨다(`variants/*.patch`). `diff -rq`로 확인한 결과 변경 파일 1개 외에는 차이가 없다.
  같은 명령으로 Release를 빌드했고 bundle ID는 `com.zipkero.ResourceRunner.Task005PerfDiagnostic`, 설정 plist가 없는 기본값이다.
  - V1: 열 때 `contentViewController`가 nil일 때만 만들고, `didClose`에서 nil로 두지 않는다.
  - V2: `popover.animates = false`.
  - V3: `DashboardView` 본체 카드 4개의 `.keyboardShortcut`을 제거했다.
    진단 전용이며 단축키 기능은 사라진다.
- 시행은 [`tools/run_variant.py`](tools/run_variant.py)가 한다.
  변형마다 새 프로세스를 `open -n`으로 띄우고 20초 기다린 뒤 첫 열림 1회(AX probe 켬)를 한다.
  이어서 재열림 18회를 하는데, 홀수(A)는 AX를 끄고 짝수(B)는 켠다.
  각 시행은 task-005와 같은 [`tools/boundary_driver.py`](tools/boundary_driver.py)(cmp 동일)와 같은 probe binary로 한다.
  probe는 외부 PID tap, 고정 ROI SCStream 프레임, AX이고, 한 시행은 열기 → 1.5초 → 닫기다.
  앱 진단 기록은 `raw/<variant>/app-events-<pid>.jsonl`에 있다.
  변형끼리 동시에 실행하지 않았다.
- 구간 계산은 task-005와 같은 [`tools/analyze_boundary.py`](tools/analyze_boundary.py)와 `pixel_diff`로 했다.
  tap→`show` 반환, `show` 동기 길이(activate 반환→show 반환), 첫 픽셀(고정 영역 평균 차이 > 0.01)을 낸다.
- 완전 표시 판독은 [`tools/analyze_complete.py`](tools/analyze_complete.py)와 [`tools/content_match.swift`](tools/content_match.swift)로 했다.
  기준은 열기 tap 뒤 프레임 중 다음 두 조건을 처음 함께 만족하는 프레임이다.
  - 팝오버 경계 상자 폭이 최종 프레임(닫기 tap 직전)의 0.60 이상이다.
  - 회색조 표준편차 비가 0.60 이상이다.

  경계 상자는 기준 프레임 대비 차이 > 24인 픽셀로 잡고, y<48인 메뉴바·상태 항목 강조·화살표 영역은 뺐다.
  이 기준은 V0 trial-01·00 프레임을 직접 보고 정했다.
  기준 프레임에서는 네 카드 값, CPU/Memory TOP5 5행, CPU·Disk 그래프가 모두 식별되고, 그 직전 프레임(배율 약 0.57)은 경계 수준이다.
  확인한 프레임은 V0 첫 열림 0034/0035, V1 재열림 0028/0029, V2 첫 열림 0023이다.
  네 변형에 같은 기준을 썼다.
  선택 프레임의 원본 경로와 SHA는 `manifest.json`의 `selectedCompleteFrames`에 있다.
- time profile은 V0 별도 프로세스(PID 78508)에 `xctrace` Time Profiler를 attach해서 40초 동안 기록했다.
  그동안 `gui_state toggle`로 12회 열고 닫았다.
  main thread 표본 가운데 `-[NSPopover showRelativeToRect:ofView:preferredEdge:]`를 포함한 554개를 집계했다([`tools/profile_show.py`](tools/profile_show.py), [`tools/profile_by_open.py`](tools/profile_by_open.py), [`tools/profile_after_show.py`](tools/profile_after_show.py)).

## `show` 동기 비용 분해 (V0 time profile, show 아래 554표본/12회)

| 경로 | 비중 |
|---|---|
| `_makePopoverWindowIfNeeded` → `setContentViewController` → `NSHostingView.viewDidMoveToWindow` → `updateRequiredBridges` (새 SwiftUI graph 첫 평가) | 56.9% |
| `NSWindow layoutIfNeeded` / `updateConstraintsIfNeeded` (SwiftUI layout) | 21.1% |
| `addChildWindow` 순서·first responder | 8.7% |
| `_NSPopoverPositionOnScreen` | 5.4% |
| (교차) `Text.resolve…` | 18.4% |
| (교차) `BindKeyboardShortcutItems.updateValue` | 14.4% |
| (교차) `ApplicationIconCache.icon` | 1.8% |

- 첫 열림(71표본)과 이후 열림 평균(43.9표본)의 차이는 주로 다음 두 가지다([`profile/by-open.txt`](profile/by-open.txt)).
  - `ApplicationIconCache` → `NSWorkspace _iconForURL`(첫 열림 10표본, 이후 0)
  - ForEach 항목 생성
- `show`가 반환된 뒤 40ms 안의 main thread 표본은 열림마다 16–25개이고 대부분 `CA::Transaction::commit`이다([`profile/after-show-40ms.txt`](profile/after-show-40ms.txt)). V1에서도 show 반환→첫 commit은 약 20–30ms로 V0와 비슷했다.
  이 구간은 hosting 재생성과 무관한 새 창 첫 렌더 비용이다.

## 원인 비교 결과 (열기 tap 기준 ms, 중앙값(최소–최대); 첫 열림은 각 1회)

| 변형 | 첫 열림 show | 첫 열림 첫 픽셀 | 첫 열림 완전 표시 | 재열림 show (n=18) | 재열림 첫 픽셀 | 재열림 완전 표시 |
|---|---|---|---|---|---|---|
| V0 기준 | 76.1 | 124.3 | 199.3 | 48.0 (35.1–73.9) | 103.5 (85.5–130.9) | 174.9 (156.6–197.6) |
| V1 hosting 유지 | 72.6 | 116.9 | 200.2 | 12.3 (8.8–27.7) | 67.6 (55.4–92.0) | 137.6 (129.6–161.5) |
| V2 animates=false | 73.0 | 120.8 | 120.8 | 46.3 (35.6–75.8) | 91.2 (72.4–123.3) | 91.2 (72.4–123.3) |
| V3 카드 단축키 제거 | 69.1 | 125.1 | 191.8 | 40.6 (31.5–53.3) | 96.7 (83.9–112.7) | 171.3 (153.1–184.8) |

A(AX 끔)/B(AX 켬) 묶음별 값은 [`results/summary.json`](results/summary.json)에, 시행별 전체 구간은 `results/<v>-boundary-results.json`과 `results/<v>-complete.json`에 있다.

## 채택·기각

- **V1 hosting 유지: 기각(정지).** 재열림 첫 픽셀·완전 표시가 각각 약 36·37ms 줄어 효과는 가장 확실하다.
  하지만 첫 열림은 줄지 않고, 닫힘 시 hosting 회수(task-004 승인, 닫힘 Footprint 419–422MB→61MB의 근거)를 되돌려야 한다.
  닫힌 동안 hosting을 유지하면 숨김 중 표시 갱신 비용이 다시 생길 수 있으나, 이번에는 닫힘 Footprint/CPU를 측정하지 않았다.
  빈 root view로 hosting만 남기는 등의 중간안은 측정하지 않았고, 이것도 hosting 수명 결정의 변경이다.
- **V2 animates=false: 기각(정지).** 완전 표시를 첫 열림 −78ms, 재열림 −84ms로 가장 크게 줄이고 첫 픽셀도 약 12ms 앞당긴다.
  첫 프레임이 불투명한 완전 크기라서다.
  하지만 사용자에게 보이는 표시 방식 변경이고 spec에 정해진 바가 없다.
- **V3 카드 단축키 bridge: 미채택.** `show`는 −5~−7ms였지만 완전 표시 −3.6ms는 실행 간 차이와 프레임 간격 안이다.
  제품에서 대체하려면 ⌘1–4를 `.keyboardShortcut` 대신 기존 local key monitor 경로로 다시 구현해야 하므로 키보드 계약 회귀 위험이 있다.
  효과가 확정되지 않아 구현하지 않았다.
- **첫 열림 아이콘 로딩(~10ms): 미검증 후보.** 단일 요소 비교를 하지 않았다.
  숨긴 동안 아이콘을 미리 읽으면 닫힘 CPU에 영향이 생길 수 있어 별도 측정이 필요하다.
- 나머지 구간은 앱이 직접 줄일 수 있는 비용으로 분리하지 못했다.
  tap→앱 수신 0.3–12ms, show 반환→첫 commit 약 20–30ms(CA commit·첫 렌더), commit→첫 픽셀 약 15–30ms(WindowServer 합성·애니메이션 첫 프레임)이다.

## 한계

- 변형마다 프로세스 1개다.
  첫 열림은 변형당 1회라 범위가 없다.
  V1·V2의 차이는 재열림 18회 전체 범위가 V0와 거의 겹치지 않을 만큼 크지만, V3 차이는 실행 간 변동과 구분되지 않는다.
- 완전 표시 판독은 배율·대비 대리 지표다.
  선택 프레임 일부만 직접 확인했다.
  최신 값의 정확성(AX 값과 픽셀 값 대응)은 이 판독에 넣지 않았다.
- 합성 클릭(`gui_state toggle`)이라 mouse-down과 mouse-up 사이 간격이 거의 없다.
  실제 사람 클릭과 다르다.
- 시행 중 사용자의 Mac 사용 여부는 확인하지 않았다.
  매 시행 직전 HIDIdleTime은 `raw/*/trial-*/identity.json`에 있다.
- 원시 ROI JPEG에는 관련 없는 화면 내용이 섞여 있어 저장소에 넣지 않았다.
  `/private/tmp/resourcerunner-task008/runs/<variant>-p1/`에 두었다.
  `raw/**/frames/frames.jsonl`은 gzip(-n)했으며, 재계산할 때는 `/private/tmp` 원본 run 디렉터리를 쓴다.
  이번에 네 변형의 `results/*`가 바이트 단위로 같게 재현됨을 확인했다.
- 제품 변경이 없으므로 단위·UI·Release UI 검증, Debug/Release 빌드, 닫힘 Footprint/CPU 측정은 하지 않았다.

## 정리

- 진단 앱 PID 78508(profile), 83766(V0), 이어 V1·V2·V3 프로세스를 모두 종료했다.
  probe·xctrace 잔존 프로세스는 없다.
- container의 진단 기록은 `raw/`에 복사한 뒤 지웠다.
  profile 프로세스 기록은 `/private/tmp/resourcerunner-task008/profile-v0/`로 옮겼다.
- 설치 앱 `/Users/zipkero/Applications/ResourceRunner.app` PID 16136(시작 2026-10-09 16:28:46, exe SHA `a4073395…`)은 유지했다.
- 다음 임시 경로는 `manifest.json`의 재현 입력이라 남겼다: `/private/tmp/resourcerunner-task008/`(변형 소스·빌드·run JPEG·trace).
