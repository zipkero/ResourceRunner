# task-008 retry-3: 첫 열림 첫 픽셀 교대 측정

2026-10-13 06:54–07:06 KST. HEAD `1eaf32104d50d78be098859bbaec9a42dfcadeb1`이고, 작업 트리의 제품 소스는 retry-1과 같다(`StatusBarController.swift` SHA `c764ecb8…`, 테스트 `cdd89b3d…`).
이번에는 근거만 보강했고 제품 코드·테스트·문서는 바꾸지 않았다.
상위 폴더, retry-1, retry-2의 파일도 바꾸지 않았다.
이 자료는 진단 근거이며, 정식 100/200ms 판정이나 task-005 cohort가 아니다.

## 판정

- 첫 열림 첫 픽셀: 개선 후(B)가 대조군(A)보다 늦지 않다. "개선 전보다 늦어지지 않음"이 성립한다.
  - 팝오버 첫 픽셀 중앙값은 A 131.84ms(130.40–139.72), B 119.16ms(114.31–122.05)다. 차이는 −12.69ms로, 기준 프레임 간격 8.33ms의 약 1.5배다.
  - 두 범위가 겹치지 않는다. B의 최댓값 122.05ms는 A의 어느 시행에서든 팝오버가 아직 없던 직전 프레임(최소 122.07ms)보다 이르다.
    프레임 사이 불확실성을 B에 가장 불리하게 잡아도(B는 첫 픽셀 프레임, A는 직전 빈 프레임) B가 늦은 쌍은 없다(36쌍 중 0쌍).
  - 기존 자동 판독(`analyze_boundary.py`, 아래 "판독 정정" 참고)으로 비교해도 A 123.21ms, B 119.16ms로 B가 늦지 않다.
- 첫 열림 완전 표시: A 204.31ms(198.06–206.70), B 119.16ms(114.31–122.05)로 −85.15ms다.
  B는 여섯 시행 모두 첫 픽셀 프레임이 곧 완전 표시 프레임이다.
- 참고로 `show` 동기 길이는 A 75.29ms(71.74–78.35), B 69.57ms(67.95–79.24)다.

## 판독 정정: 자동 첫 픽셀은 상태 항목 툴팁이 사라진 시점이었다

- 모든 시행에서 열기 전 메뉴바 아래에 진단 앱 상태 항목의 툴팁("ResourceRunner, 닫음")이 떠 있었다.
  이전 시행의 합성 클릭 위치에 포인터가 남아 생기는 툴팁이다.
- 기존 자동 판독은 고정 영역 평균 차이가 처음 0.01을 넘는 프레임을 고르는데, A에서는 이 툴팁이 사라진 프레임이 걸렸다.
  그 프레임에는 팝오버 픽셀이 없고, 팝오버는 다음 저장 프레임부터 작고 반투명하게 나타난다.
  B에서는 툴팁이 사라지는 프레임과 팝오버가 완전 크기로 나타나는 프레임이 같다.
- 그래서 첫 픽셀을 "팝오버 영역에 변화가 처음 생긴 프레임"으로 다시 읽었다.
  - 보조 도구 [`tools/frame_change.swift`](tools/frame_change.swift): 열기 직전 기준 프레임 대비 회색조 차이 > 6인 픽셀을 툴팁 사각형(x 196–327, y 24–51) 안과 밖으로 나눠 센다. 메뉴바 줄(y<24)은 뺀다.
  - 툴팁 밖 변화가 20픽셀 이상인 첫 프레임을 팝오버 첫 픽셀로 잡았다. 결과는 [`results/frame-change-scan-thr6.json`](results/frame-change-scan-thr6.json)에 있다.
  - 이 기준을 모든 시행에 똑같이 적용했다.
- 시행마다 직전 프레임과 첫 픽셀 프레임을 직접 확인했다.
  - 기준 프레임과의 차이를 8배로 키운 이미지를 만들었다([`tools/diff_image.swift`](tools/diff_image.swift)). A의 직전 프레임에는 툴팁 자리만 바뀌고, 첫 픽셀 프레임에는 상태 항목 아래 x≈176–215에 작은 팝오버 윤곽이 보인다.
  - B의 직전 프레임에는 변화가 없다(툴팁이 남아 있다). 첫 픽셀 프레임에는 팝오버 전체가 보인다.
  - 이미지는 화면의 다른 내용이 섞여 있어 저장소에 넣지 않았다. 경로와 SHA는 `manifest.json`의 `inspectionImages`에 있다(`diff-x8-prev-vs-first.jpg`, `firstpixel-zoom-A.jpg`).
- 다른 앱 화면 변화가 판독에 걸린 시행은 측정 시행 중에는 없었다.
  준비 시행 01-warmup-A에서는 자동 판독과 보조 판독이 모두 0.75ms를 냈는데, 배경 문서 화면이 바뀐 것이다. 준비 시행은 통계에 넣지 않는다.
- 같은 툴팁 문제는 상위 폴더의 V0 첫 열림(124.27ms)에도 있다.
  `frame_change`로 다시 보면 V0의 124.27ms 프레임은 툴팁만 사라진 프레임이고, 팝오버 변화는 132.60ms(4픽셀)·140.94ms(255픽셀)부터다. 이 V0 재판독은 프레임 이미지를 직접 보지 않았고 수치만 확인했다.
  retry-1의 V4 첫 열림 131.05ms도 다른 앱 화면 변화 때문에 수동으로 읽은 값이었다. 이번 비교는 이 두 값을 쓰지 않는다.

## 시행 표

열기 tap 기준 ms. "직전"은 첫 픽셀 프레임 바로 앞에 저장된 프레임(팝오버 없음)의 시각이다. HIDIdle은 클릭 직전 driver가 읽은 값이다.
측정 시행 번호는 실행 순서이며, A와 B를 번갈아 돌렸다(무효면 같은 쪽을 바로 다시 돌림).

### A: 대조군(HEAD 진단 사본, 애니메이션 켬)

| 시행 | 유효 | HIDIdle(s) | 직전 프레임 | 첫 픽셀 | 툴팁 사라짐(기존 자동 판독) | 완전 표시(직전) | `show` |
|---|---|---:|---:|---:|---:|---:|---:|
| 03 | 무효: PerfPowerService 50.0% | 37.64 | 122.42 | 130.75 | 122.42 | 197.42 (189.09) | 72.61 |
| 04 | 유효 | 37.56 | 123.66 | 131.99 | 123.66 | 198.66 (190.32) | 71.74 |
| 07 | 유효 | 37.60 | 123.37 | 131.70 | 123.37 | 206.70 (198.36) | 75.41 |
| 09 | 유효 | 37.62 | 123.06 | 139.72 | 123.06 | 198.06 (189.72) | 75.18 |
| 12 | 유효 | 37.60 | 122.07 | 130.40 | 122.07 | 205.40 (197.07) | 76.75 |
| 14 | 유효 | 37.62 | 122.91 | 131.24 | 122.91 | 206.24 (197.90) | 78.35 |
| 16 | 유효 | 37.57 | 128.21 | 136.54 | 128.21 | 203.21 (194.88) | 74.94 |

### B: 개선 후(retry-1 V4 진단, 애니메이션 끔)

| 시행 | 유효 | HIDIdle(s) | 직전 프레임 | 첫 픽셀 = 완전 표시 | `show` |
|---|---|---:|---:|---:|---:|
| 05 | 무효: goland 54.7% | 37.66 | 112.85 | 129.51 | 79.57 |
| 06 | 유효 | 37.64 | 89.31 | 114.31 | 67.95 |
| 08 | 유효 | 37.52 | 113.72 | 122.05 | 79.24 |
| 10 | 무효: mobileassetd 66.7%·deleted 60.6%·mds 55.8%, 전체 28.2% | 37.64 | 104.83 | 121.49 | 69.64 |
| 11 | 유효 | 37.50 | 100.96 | 117.62 | 69.91 |
| 13 | 유효 | 37.53 | 101.17 | 117.84 | 69.24 |
| 15 | 유효 | 37.57 | 95.47 | 120.47 | 70.81 |
| 17 | 유효 | 37.49 | 104.98 | 121.64 | 69.01 |

- 준비 시행 01-warmup-A(A, HIDIdle 206.93s)와 02-warmup-B(B, 37.53s)는 새로 빌드한 실행 파일의 첫 실행 영향을 덜기 위해 먼저 한 번씩 돌렸다. 통계에서 뺐다.
- 무효 시행의 값은 표에만 남겼다. 넣어도 B가 늦지 않다는 결론은 바뀌지 않는다(B 무효 최대 129.51ms < A 유효 최소 130.40ms).
- 프레임 간격: 첫 픽셀 앞뒤 간격은 8.33–25.0ms다(대부분 16.67ms). 재생 빈도의 기준 간격은 8.33ms다.

## 요약 통계(유효 측정 시행, 각 n=6)

| 구간 | A 중앙값(범위) | B 중앙값(범위) | B−A 중앙값 차 |
|---|---|---|---:|
| 첫 픽셀(팝오버) | 131.84 (130.40–139.72) | 119.16 (114.31–122.05) | −12.69 |
| 첫 픽셀 직전 빈 프레임 | 123.21 (122.07–128.21) | 101.06 (89.31–113.72) | −22.15 |
| 기존 자동 판독 | 123.21 (122.07–128.21) | 119.16 (114.31–122.05) | −4.06 |
| 완전 표시 | 204.31 (198.06–206.70) | 119.16 (114.31–122.05) | −85.15 |
| `show` 동기 길이 | 75.29 (71.74–78.35) | 69.57 (67.95–79.24) | −5.72 |

- 첫 픽셀 차이 −12.69ms는 기준 프레임 간격 8.33ms보다 크고, 이 측정에서 흔했던 간격 16.67ms보다는 작다.
  그래서 크기는 약 1프레임 수준으로만 말할 수 있다. 하지만 "늦어지지 않음" 판단은 크기가 아니라 순서에 기대며, 순서는 위 최악 조건 비교로 성립한다.
- 6 대 6이 완전히 갈렸을 때 순위합 검정(양측)의 p는 2/924 ≈ 0.002다(참고 값).
- 시행별 값과 집계는 [`results/summary.json`](results/summary.json)에 있다.

## 방법

### 비교 대상

- A(개선 전): retry-1 진단 사본 `src-diag`(V4)를 복사해 `popover.animates = false`와 그 주석, 2줄만 뺐다([`variants/control-vs-v4.patch`](variants/control-vs-v4.patch)).
  - 이 사본의 `ResourceRunner/`는 상위 폴더 V0 소스(`/private/tmp/resourcerunner-task005-boundary-src/ResourceRunner`)와 `diff -rq`로 같다.
  - 소스 경로는 `/private/tmp/resourcerunner-task008-r3/src-control-diag`다.
  - retry-1과 같은 명령으로 Release 빌드했다(`xcodebuild build -project ResourceRunnerTask005Boundary.xcodeproj -scheme ResourceRunner -configuration Release -destination platform=macOS -derivedDataPath … CODE_SIGNING_ALLOWED=YES`, Xcode 26.6 17F113). 결과는 BUILD SUCCEEDED, exe SHA `851127f1…`다.
  - retry-1에는 계측이 들어간 대조군 빌드가 없어서 새로 빌드했다(`src-control`/`build-control`은 계측이 없는 닫힘 측정용이다).
- B(개선 후): retry-1 V4 빌드를 그대로 썼다. exe SHA `6e60ac74…`로 retry-1 README와 같다.
- 두 쪽의 계측 줄은 같다. 소스 차이는 위 2줄뿐이다.
  bundle ID는 둘 다 `com.zipkero.ResourceRunner.Task005PerfDiagnostic`이고 ad hoc 서명이며, 설정 plist가 없는 기본값이다.

### 시행

- [`tools/alternate_firstopen.py`](tools/alternate_firstopen.py)가 상위 [`../tools/run_variant.py`](../tools/run_variant.py)를 `--reopens 0 --settle 20`으로 부른다.
  매번 `open -n`으로 새 프로세스를 띄우고, 20초 기다린 뒤 첫 열림 1회(AX probe 켬)만 하고 앱을 종료한다. 재열림은 하지 않았다.
- 순서는 준비 A, 준비 B 다음 A,B,A,B…이고, 시행 사이에 8초를 쉬었다.
- 시행 driver·probe·분석 도구는 상위 `tools/`와 task-005 probe binary를 그대로 썼다. SHA가 상위 `manifest.json`과 같음을 확인했다.
- 상위 `analyze_boundary.py`는 재열림 묶음이 비어 있으면 집계에서 멈춘다. 그래서 빈 묶음이면 `None`을 돌려주는 2줄만 더한 사본을 썼다([`tools/analyze_boundary_firstopen.py`](tools/analyze_boundary_firstopen.py), diff는 [`tools/analyze_boundary_firstopen.diff`](tools/analyze_boundary_firstopen.diff)). 시행별 계산은 원본과 같다.
- 완전 표시는 상위 `analyze_complete.py`의 기존 기준(폭 비 0.60·대비 비 0.60)으로 읽었다.
  B 여섯 시행은 판독 프레임을 직접 보고 네 카드 값·CPU/Memory TOP5 5행·CPU·Disk 그래프가 보이며, 직전 프레임에는 팝오버가 없음을 확인했다.
  A는 여섯 시행의 판독 프레임과 직전 프레임을 나란히 보았고, 04번은 확대해서 CPU 9%·Memory 21.4GB·TOP5 행이 반투명 상태로 식별됨을 확인했다. A의 값은 기존 기준을 그대로 따른 것이며, 더 엄격하게 읽으면 A가 더 늦어질 뿐 B와의 순서는 바뀌지 않는다.

### 입력·부하 판정

- [`tools/monitor.py`](tools/monitor.py)가 측정 내내 HIDIdleTime(0.25초 간격)과 `top` 상위 8개 프로세스(2초 간격)를 기록했다([`monitor/hid-idle.jsonl.gz`](monitor/hid-idle.jsonl.gz), [`monitor/top.jsonl.gz`](monitor/top.jsonl.gz)).
- 무효 기준은 측정 전에 정해 스크립트에 고정했다.
  - 입력: 클릭 직전 HIDIdle이 18초 미만이거나, 앱 실행부터 클릭까지 HIDIdle이 0.5초 넘게 줄었거나, `event.jsonl`이 2행이 아니면 무효다.
  - 부하: 같은 구간의 `top` 표본에서 측정과 무관한 프로세스가 하나라도 50% 이상이거나 user+sys가 25% 이상이면 무효다.
- 측정 동안 HIDIdle이 줄어든 34번은 모두 각 시행의 합성 열기·닫기 클릭 시각(클릭 직전 기록 뒤 0.35–0.58초와 2.23–2.52초)과 맞는다. 그 밖의 사용자 입력은 없었다.
  합성 클릭이 HIDIdle을 0으로 되돌리므로, 클릭 직전 HIDIdle은 직전 시행 닫기 클릭 뒤 흐른 시간(약 37.5초)이 된다.
- 유효 시행에서 클릭 직전 `top` 표본의 user+sys는 6.4–11.8%였다. 실행부터 클릭까지 다른 프로세스의 최대는 39.2%(08번 WindowServer)였다.
- 시행별 판정과 클릭 직전 `top` 표본은 [`monitor/plan-log.json`](monitor/plan-log.json)에 있다.
- Amphetamine이 화면 잠자기를 막고 있었고, 측정 동안 `caffeinate -di`를 함께 띄웠다.

## 파일

- `raw/<시행>/`: `launch.json`·`exit.json`·`trial-status.json`·`runner.log`·`app-events-<pid>.jsonl`과 `trial-00-firstopen/`의 identity·event·click·ax·probe 출력. `frames/frames.jsonl`은 gzip(-n)했다.
  원시 ROI JPEG는 `/private/tmp/resourcerunner-task008-r3/runs/`에 있다.
- `results/<시행>-boundary.{json,txt}`, `results/<시행>-complete.{json,txt}`: 기존 도구 출력.
- `results/frame-change-scan.json`(차이 > 24, 툴팁 사각형 높이 22 첫 시험)과 `results/frame-change-scan-thr6.json`(채택 기준): 팝오버 첫 픽셀 보조 판독.
- `results/summary.json`: 시행 표와 집계.
- `manifest.json`: 실행 파일·도구·검사 이미지·이 폴더 파일의 SHA.

## 정리

- 진단 앱은 시행마다 `run_variant.py`가 종료했다. 남은 진단 앱·probe·monitor·`caffeinate`(이번 세션이 띄운 PID 63733) 프로세스는 없다.
- 설치 앱 `/Users/zipkero/Applications/ResourceRunner.app` PID 16136(시작 2026-10-09 16:28:46)은 건드리지 않았고 그대로 실행 중이다.
- production bundle ID로는 아무것도 실행하지 않았다.
