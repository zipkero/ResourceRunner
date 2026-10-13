# task-008 retry-1: 본체 팝오버 애니메이션 끄기 적용과 전후 비교

2026-10-12 22:00–00:00 KST. HEAD `1eaf32104d50d78be098859bbaec9a42dfcadeb1`에 이번 제품 변경(`popover.animates = false`)과 회귀 테스트를 얹은 작업 트리다.
이 자료는 진단 근거이며 정식 100/200ms 판정이나 task-005 cohort가 아니다.
상위 폴더의 기존 파일은 바꾸지 않았다.

## 판정 요약

- 재열림 첫 픽셀·완전 표시와 첫 열림 완전 표시는 V0보다 앞당겨졌다.
  애니메이션이 없어 재열림 18회 모두 첫 픽셀 프레임이 곧 완전 표시 프레임이다.
- 닫힘 상태 Footprint 최대가 task-004 대비 약 9MB 늘었다(60.92–61.02MB → 69.81–69.98MB).
  같은 절차로 측정한 대조군(현재 HEAD, 애니메이션 켬)은 60.67–61.49MB이므로 증가는 이번 변경에서 온다.
  vmmap에서 차이는 IOSurface resident(4.66MB → 13.4MB)에 모여 있다.
- 닫힘 CPU는 이번 변경과 대조군이 같은 수준이다(2.81–2.83% 대 2.71–2.82%).
  task-004의 2.52–2.53%보다 높은 것은 대조군에서도 나타나므로 이번 변경 탓이 아니다.

## 제품 변경

- `ResourceRunner/StatusBarController.swift`: 팝오버 생성부에 `popover.animates = false`와 이유 주석 1줄.
- `ResourceRunnerTests/StatusBarControllerTests.swift`: `popoverIsConfiguredWithoutAnimation(automaticallyCloses:)`(인자 true/false). 두 behavior 구성과 `applyAutomaticallyClosesPopover` 전환 뒤에도 `animates == false`인지 본다.
- 정확한 diff는 [`variants/product-source.patch`](variants/product-source.patch).

## 검증

| 항목 | 결과 | 근거 |
|---|---|---|
| 전체 단위 `ResourceRunnerTests`(직렬) | 697/697, skip 0 | `/private/tmp/resourcerunner-task008-r1/unit.xcresult` |
| 격리 UI suite(app ID `com.zipkero.ResourceRunner.Task005UITest`) | 56/56, skip 0 | `/private/tmp/resourcerunner-task008-r1/ui-suite-r2.xcresult` |
| 격리 Release UI 읽기(`testReleaseBuildRightClickOpensSingleSettingsWindow`) | 1/1, skip 0 | `/private/tmp/resourcerunner-task008-r1/ui-release-read.xcresult` |
| 원본 project Debug/Release build | BUILD SUCCEEDED | `/private/tmp/resourcerunner-task008-r1/build-{Debug,Release}.log` |

- 단위 명령은 task-005와 같다(`-only-testing:ResourceRunnerTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO`).
- UI는 원본 `project.pbxproj`의 bundle ID 4줄만 바꾼 임시 `ResourceRunnerTask005UITests.xcodeproj`로 실행했고, 그 SHA는 task-005 `uiPBXSHA256`(`de1a8dd1…`)과 같다. 실행 뒤 지웠다.
- 제외는 task-005와 같은 6개다(실제 로그인 등록·해제·System Settings 제거 5개, Release 경로 전용 1개). 제외한 Release 사례는 격리 Release 앱을 `RR_RELEASE_APP_PATH`로 넘긴 `test-without-building`에서 따로 실행했다.
- 첫 UI suite(`ui-suite.xcresult`)는 runner가 "Timed out while enabling automation mode"로 시작하지 못해 0건 실행 후 실패했다. 단일 smoke 1/1 통과(`ui-smoke.xcresult`)를 확인한 뒤 전체를 다시 실행했다.
- production ID로 XCUIApplication을 실행하지 않았다.

## 열림 지연 전후 비교

방법은 상위 README와 같다. V0 소스 사본(`/private/tmp/resourcerunner-task005-boundary-src`)에 이번 제품 변경 2줄만 얹었다.
계측 줄은 V0 patch와 같고([`variants/v4-diag-instrumentation.patch`](variants/v4-diag-instrumentation.patch)), 원본 `ResourceRunner/`와의 차이는 계측한 `StatusBarController.swift`와 `Task005BoundaryDiagnostic.swift`뿐이다.
진단 exe SHA `6e60ac74d40d246ffea76def8dbcb32bf4666eaf4f8ad37de6b9dbb3abef3133`, bundle ID `com.zipkero.ResourceRunner.Task005PerfDiagnostic`, 설정 plist 없음(기본값).
도구는 상위 `tools/`를 그대로 썼고 해시가 상위 `manifest.json`과 같다.

열기 tap 기준 ms, 중앙값(최소–최대).

| 구간 | V0 | V4(이번 제품, p1) |
|---|---|---|
| 첫 열림 첫 픽셀 | 124.3 | 131.05 (수동 판독, 아래 참고) |
| 첫 열림 완전 표시 | 199.3 | 131.05 |
| 재열림 첫 픽셀 (n=18) | 103.5 (85.5–130.9) | 94.5 (76.6–118.3) |
| 재열림 완전 표시 (n=18) | 174.9 (156.6–197.6) | 94.5 (76.6–118.3) |
| 재열림 A(AX 끔) 첫 픽셀=완전 표시 (n=9) | 113.4 (106.4–130.9) / 180.9 (179.3–197.6) | 105.6 (102.1–118.3) |
| 재열림 B(AX 켬) 첫 픽셀=완전 표시 (n=9) | 94.9 (85.5–100.6) / 162.7 (156.6–170.5) | 81.6 (76.6–87.0) |
| 재열림 `show` 동기 길이 | 48.0 (35.1–73.9) | 46.4 (35.6–70.3) |

- 첫 열림(p1)은 자동 판독이 첫 픽셀 39.38ms를 냈지만, 그 프레임 변화는 다른 앱(JetBrains Toolbox) 팝업의 hover 변화였다. 시행 직전 HIDIdleTime은 0.11초로 사용자가 Mac을 쓰고 있었다.
  114.38ms 프레임에는 Toolbox 팝업이 사라졌을 뿐 이 앱 팝오버가 없고, 131.05ms 프레임에서 네 카드 값·CPU/Memory TOP5·CPU/Disk 그래프가 모두 보인다. 그래서 첫 픽셀과 완전 표시를 모두 131.05ms로 읽었다(프레임 간격 8.3–16.7ms).
- 보조로 새 프로세스 p2를 한 번 더 돌렸다. 첫 열림은 149.12ms(직전 115.79ms 프레임에는 팝오버 없음)였지만 그때 GoLand가 CPU 647%를 쓰고 있어 부하 조건이 다르다.
  p2 trial-01-A는 사용자 클릭이 섞여 event가 4행이라 분석에서 빼고(symlink view), trial-17-A의 94.16ms는 팝오버 없는 배경 변화 오판이다. p2 재열림은 비교에 쓰지 않고 원시 자료만 남긴다.
- 재열림의 A/B 차이는 V0에도 있던 같은 방향의 차이다. 같은 묶음끼리 비교해도 첫 픽셀은 −8~−13ms, 완전 표시는 −75~−81ms다.

### 100ms/200ms 기준과의 공백(진단 기준, 정식 판정 아님)

- 재열림 첫 픽셀: 중앙 94.5ms는 100ms 안이지만 18회 중 A 묶음 9회 전부가 102.1–118.3ms로 100ms를 넘는다(최대 +18.3ms).
- 재열림 완전 표시: 최대 118.3ms로 200ms 안이다.
- 첫 열림 첫 픽셀: 131.05ms로 +31ms(부하 높은 p2는 149.12ms, +49ms).
- 첫 열림 완전 표시: 131.05ms로 200ms 안이다.
- 남은 첫 픽셀 구간은 `show` 동기 비용(재열림 중앙 46ms, 첫 열림 82ms)과 show 반환 뒤 첫 commit·합성이다. 상위 README가 확인한 가장 큰 앱 쪽 비용은 열 때마다 새로 만드는 hosting의 SwiftUI graph 생성(V1에서 `show` 48.0→12.3ms)이며, 이는 task-004 hosting 회수 결정에 걸린다.

## 닫힘 상태 Footprint/CPU

task-004와 같은 절차다: task-002 진단 bundle 사본에서 실행 파일만 원본 project Release exe로 바꾸고 같은 entitlements로 ad hoc 서명(`codesign --verify --strict` 통과), bundle ID `com.zipkero.ResourceRunner.PerfDiagnostic`, 설정 plist SHA `a5088394…`(task-004와 같음).
`tools/orchestrate_closed_after_open.py`로 600초 닫힘 warm, 본체 열림 5초, 닫힘 정착 60초, 300초×3회·1초 간격. 공통 `caffeinate -di -t 9000`, window observer를 같이 띄웠다.

| 반복 | task-004 Footprint 최대 | 이번 변경 Footprint 최대 | 대조군(HEAD) Footprint 최대 | task-004 CPU | 이번 변경 CPU | 대조군 CPU |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 60.92 MB | 69.81 MB | 61.49 MB | 2.52% | 2.83% | 2.71% |
| 2 | 61.02 MB | 69.96 MB | 60.69 MB | 2.53% | 2.81% | 2.82% |
| 3 | 60.97 MB | 69.98 MB | 60.67 MB | 2.52% | 2.83% | 2.82% |

- 여섯 실행 모두 `valid=true`, 301표본, 무효 사유 없음.
- 이번 변경: [`closed-product/`](closed-product/), PID 50210, exe SHA `f01d2b66…`(서명 전 Release exe `332ea60a…`).
- 대조군: [`closed-control-head/`](closed-control-head/), PID 81700, 현재 HEAD 소스(이번 2줄 제외)를 같은 명령으로 빌드, exe SHA `93fa1ce0…`(서명 전 `c357b86a…`).
  첫 orchestrator 호출은 앱 메뉴바 항목이 준비되기 전에 `inspect`를 불러 측정 전에 끝났다(`attempt0-*`). 같은 PID와 launch epoch로 다시 시작했고 warm 600초를 처음부터 채웠다.
- RSS 최대는 이번 변경 137.7–137.8MB, 대조군 139.1–139.2MB다.
- 모든 값이 100,000,000 bytes 미만이지만, task-008 검증 조건의 "task-004 대비 회귀 없음"은 Footprint에서 성립하지 않는다.
- CPU는 1% 목표에 세 실행 모두 미달이며 이번 변경과 무관하다.

### 증가 위치(보조, 정식 구간 밖)

정식 측정 뒤 이번 변경 진단 앱을 새로 띄워(PID 5714) 30초 뒤, 본체 5초 열기·닫기 60초 뒤 `vmmap -summary`를 떴다([`vmmap/`](vmmap/)).
대조군은 정식 측정을 마친 PID 81700의 닫힘 상태에서 떴다.

| | Physical footprint | IOSurface resident | MALLOC_SMALL resident |
|---|---:|---:|---:|
| 이번 변경, 열기 전 | 39.6M | 1.58M | 23.5M |
| 이번 변경, 열고 닫은 뒤 | 64.1M | 13.4M | 33.3M |
| 대조군, 닫힘 | 57.8M | 4.66M | 35.2M |

- 닫힌 뒤 남은 IOSurface가 대조군보다 약 8.8MB 많고 heap은 비슷하다.
  애니메이션 없이 닫으면 팝오버 창의 그래픽 surface가 닫힌 뒤에도 회수되지 않는 것으로 보인다. 원인 경로(NSPopover 창 보유, AppKit 내부 캐시 등)는 확인하지 않았다.
- 표본 1회이고 warm 시간이 달라(30초 대 600초 이상) 정량 비교는 정식 측정 표를 쓴다.

## 정리

- 진단 앱 PID 36586(p1), 42814(p2), 50210, 81700, 5714와 window observer, caffeinate 50207을 종료했다. probe 잔존 프로세스는 없다.
- Release UI 테스트가 남긴 격리 앱 PID 35365(`/private/tmp/resourcerunner-task008-r1/ui-release/...`)도 종료했다.
- 설치 앱 `/Users/zipkero/Applications/ResourceRunner.app` PID 16136(시작 2026-10-09 16:28:46, exe SHA `a4073395…`)은 유지했다.
- 원시 ROI JPEG와 빌드·xcresult는 `/private/tmp/resourcerunner-task008-r1/`에 남겼다. `raw/**/frames/frames.jsonl`은 gzip(-n)했다.
