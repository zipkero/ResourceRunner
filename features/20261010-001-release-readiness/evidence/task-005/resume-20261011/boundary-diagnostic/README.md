# task-005 경계 진단: PID tap callback과 앱 실제 수신의 오차 상한

2026-10-11 20:55–21:00 KST. verifier Resolution 중 "PID tap callback과 실제 mouse-up 전달 사이의 오차 상한을 같은 픽셀 시계에 연결"하기 위한 **보조 근거**다(DESIGN §2.4: 임시 진단 계측은 실제 Release 외부 관찰을 대체하지 않는다). 승인 cohort(첫 열림 2회 정식·재열림 20회·반복 자원 20회)가 아니며 100/200ms 합격·실패 판정이 아니다.

## 결론

1. 38개 mouse-up(열기 19·닫기 19) 모두 외부 PID tap callback이 앱의 mouse-up dequeue보다 **먼저**였다. `tap − 앱 수신` = −8.45 ~ −0.48ms, 중앙값 −2.80ms. `tap − 이벤트 생성(CGEventTimestamp)` = +0.12 ~ +0.49ms, 중앙값 +0.19ms.
2. 실제 전달 시각은 어떤 정의든 [이벤트 생성, 앱 dequeue] 안에 있으므로 이번 관측에서 `tap − 실제 전달` ∈ [−8.45, +0.49]ms다. 정식 첫 열림(PID 29449)의 tap 기준 첫 픽셀 +144.98ms(직전 빈 프레임 +136.65ms)는 이 오차로 설명되지 않는다. 100ms 이하가 되려면 앱 수신이 tap보다 약 37~45ms 늦어야 하는데, 이번 최대치(8.45ms)의 4배를 넘는다. 따라서 **145ms는 측정 오차가 아니라 실제 앱·시스템 지연**으로 본다.
3. 지연이 가장 큰 구간은 앱 main thread의 동기 `NSPopover.show(relativeTo:of:preferredEdge:)` 호출이다(재열림 중앙 45.6ms, 34.5–59.6ms, 첫 열림 79.5ms). 그다음은 show 반환부터 첫 픽셀까지다(중앙 52.9ms, 44.9–60.8ms. 그중 첫 run loop 대기 진입까지 약 20–28ms). 첫 픽셀부터 애니메이션 97%까지는 모든 시행에서 175.0–183.3ms로 거의 일정하다.

## 방법

- 격리 사본 `/private/tmp/resourcerunner-task005-boundary-src`: 원본 127개 파일은 `resume-runtime-manifest-r2.json`과 127/127 같다. 사본은 다음 두 곳만 다르다.
  - `project.pbxproj`: bundle ID 4줄만 `com.zipkero.ResourceRunner.Task005PerfDiagnostic` 계열로 바꿨고, SHA는 기존 성능 진단 project와 같은 `bd4efb94…`다.
  - `StatusBarController.swift`: 계측을 넣었고 `Task005BoundaryDiagnostic.swift`를 추가했다. 차이 전체는 [`instrumentation.patch`](instrumentation.patch)에 있다.

  Release(`-O`)로 빌드했고 sandbox를 유지했다. PID 17729, exe SHA `d742c682…`이며 상세는 [`input-manifest.json`](input-manifest.json)에 있다.
- 앱 내부 계측은 main thread에서 `mach_absolute_time`만 잡고, 쓰기는 별도 queue에서 한다. 기록 위치는 다음과 같다.
  - `NSApplication.nextEvent(matching:until:inMode:dequeue:)` / `sendEvent(_:)` swizzle: left mouse down/up을 dequeue한 시각, `NSEvent.timestamp`, `cgEvent.timestamp`(외부 tap 행의 `eventTimestamp`와 1:1 대응), 직전 run loop afterWaiting/beforeWaiting.
  - `togglePopover` 진입 → `openBegin` → hosting 할당 → viewport → `NSApp.activate()` 반환 → `popoverWillShow` → `show` 반환 → `makeKey` 반환 → `openEnd`.
  - show 뒤 첫 run loop `beforeWaiting`(observer order 최대값이라 CA commit observer 뒤에 잡힌다), `_NSPopoverWindow` occlusion visible, `popoverDidShow`/`popoverDidClose`.
- 외부 도구는 기존 binary를 그대로 썼다(SHA가 기존 manifest와 같다): PID tap `target_event_probe`(tail/listenOnly), `external_frame_probe --fixed-roi`(SCStream displayTime), 클릭 `gui_state toggle`. [`boundary_driver.py`](boundary_driver.py)는 `firstopen_driver.py`의 준비 조건(tap ready ACK·첫 ROI JPEG 저장·probe 생존·128장 미만)을 따르고 600초 guard는 쓰지 않는다. 한 시행은 열기 클릭, 1.5초 대기, 닫기 클릭이다.
- 시행:
  - trial-00은 새 프로세스의 첫 열림이다. 실행 약 20초 뒤에 열었고, 정식 측정처럼 AX probe를 켰다.
  - trial-01~18은 재열림이다. 홀수(A)는 AX probe를 껐고 짝수(B)는 켰다.
  - 매 시행 직전 HIDIdleTime은 trial-00 172s, trial-01 41.9s, 나머지 약 10.3s다. 10.3s는 직전 시행의 합성 클릭부터 흐른 시간이므로 시행 사이 사람 입력은 관측되지 않았다.
- 픽셀 판독은 [`pixel_diff.swift`](pixel_diff.swift)로 했다. ROI JPEG의 팝오버 고정 영역(x80 y28 240×492, 메뉴바·상태 항목 강조 제외)을 클릭 직전 프레임과 회색조로 비교한다. 배경이 정지해 있어 변화가 없는 프레임의 평균 차이는 정확히 0.00이었다. 판독 기준은 다음 셋이다.
  - 첫 픽셀: 평균 차이 > 0.01
  - 1% 변화: 24단계 넘게 바뀐 픽셀 ≥ 1%
  - 애니메이션 97%: 평균 차이가 +400ms 이후 정지값 중앙의 97% 이상

  첫 열림의 frame 0030(+126.33 없음), 0031(+134.66 옅은 윤곽), 0035(+167.99 작고 반투명한 내용), 0051(+317.99 완전 크기)을 직접 보고 기준과 맞음을 확인했다. 첫 픽셀의 실제 시각은 직전 저장 프레임과 첫 픽셀 프레임 사이(모든 시행에서 간격 8.33ms)에 있다.
- 계산은 [`analyze_boundary.py`](analyze_boundary.py)가 한다. 앱 기록 사본 `raw/app-events-17729.jsonl`로 다시 실행해 `results.json`이 바이트 단위로 같게 재현됨을 확인했다.

## 시행별 표

[`trial-table.md`](trial-table.md)에 있다. 값은 열기 tap callback을 0으로 한 ms이며, 첫 픽셀 괄호 안은 직전 빈 프레임 시각이다. 시행별 전체 값·곡선·선택 프레임은 [`results.json`](results.json)에, 원시 행은 `raw/`에 있다.

## 구간 분해

| 구간 (열기 tap 기준 ms) | 첫 열림 trial-00 | 재열림 18회 중앙 (최소–최대) |
|---|---|---|
| tap → 앱 mouse-up dequeue | 2.83 | 2.81 (0.48–8.38) |
| `NSApp.activate()` 반환 | 3.74 | 5.18 (0.94–14.88) |
| `popover.show` 동기 호출 길이 | 79.46 | 45.56 (34.52–59.63) |
| show 반환 | 83.20 | 49.56 (39.72–73.59) |
| 첫 run loop beforeWaiting (commit 포함) | 103.29 | 73.91 (62.09–101.58) |
| `_NSPopoverWindow` occlusion visible | 123.64 | 86.00 (67.24–112.91) |
| 첫 픽셀 | 134.66 (직전 126.33) | 102.01 (85.14–127.87) |
| 1% 변화 | 167.99 | 139.40 (118.47–158.22) |
| 애니메이션 97% | 317.99 | 281.21 (268.15–308.22) |
| 첫 픽셀 → 97% | 183.33 | 175.00 (175.00–183.34) |
| `popoverDidShow` | 600.97 | 561.64 (551.25–591.61) |

- `contentControllerAssigned`는 openBegin 뒤 약 0.4ms다. NSHostingController의 view load와 SwiftUI 첫 layout은 그 뒤 `show` 안에서 일어나는 것으로 보이며, 이 진단은 그 내부를 더 나누지 않았다.
- AX probe를 켠 B 묶음이 오히려 빨랐다. show 중앙은 40.6ms(A는 52.4ms), 첫 픽셀 중앙은 95.4ms(A는 115.6ms), `tap − 앱 수신` 중앙은 −1.68ms(A는 −3.77ms)다. AX 질의가 앱 main thread를 깨어 있게 하는 효과로 추정하며, 원인은 확인하지 않았다.

## 원인 후보 (확정 아님)

- **`show` 내부 비용 (확인된 사실은 구간 길이뿐)**: task-004가 닫힐 때 `contentViewController = nil`로 hosting을 회수하고 열 때마다 새로 만든다. 이번 진단으로 확인한 것은 `show` 동기 호출이 35–80ms라는 사실뿐이다. 그 시간이 hosting 재생성·SwiftUI 첫 layout 비용인지는 hosting을 유지한 비교나 time profile이 없어 후보로 남긴다. 첫 열림이 재열림 중앙보다 약 34ms 긴 점이 첫 생성 비용과 맞아떨어지지만 증명은 아니다.
- **NSPopover 애니메이션 (첫 픽셀 → 완전 크기 구간)**: `popover.animates == true`로 기록됐다. 첫 픽셀부터 97%까지가 show 길이와 상관없이 175–183ms(21–22 프레임)로 일정하므로 이 구간은 시스템 애니메이션으로 본다. 첫 프레임들이 거의 투명해서 "첫 픽셀" 판독 자체도 늦춘다고 추정하지만, `animates = false` 비교를 하지 않아 그 크기는 후보로 둔다.
- show 반환부터 첫 픽셀까지(약 45–61ms)는 CA commit, WindowServer 합성, 애니메이션 시작이 섞여 있고 이번 계측으로는 더 나누지 못했다.

## 한계와 남는 공백

- 오차 상한의 앱 쪽(최대 8.45ms)은 계측 사본·한 프로세스·합성 클릭 38건에서 얻은 경험값이다. 정식 PID 29449에서 직접 잰 값이 아니고, 부하가 크면 더 길어질 수 있으므로 보장이 아니다.
- 반대쪽 상한 `tap − 실제 전달 ≤ tap − 이벤트 생성`은 구조적이다(전달은 생성보다 앞설 수 없다). 또 계측 없는 Release에서도 외부 tap 행(`eventTimestamp`, `observedMach`)만으로 시행마다 잴 수 있다. 정식 첫 열림은 0.29ms였다.
- "실제 mouse-up 전달"을 [생성, 앱 dequeue] 구간 어디로 볼지는 DESIGN 해석이다. 이 진단은 구간 전체를 덮는 상한만 준다.
- 애니메이션 97%는 픽셀 기반 대리 지표이며 SPEC의 "최신 내용 완전 표시" 판독과 같지 않다.
- 나머지 승인 cohort는 실행하지 않았다.

## 정리

- 진단 앱 PID 17729를 종료했고 probe 잔존 프로세스는 없다. 설치 앱 PID 16136(시작 2026-10-09 16:28:46, exe SHA `a4073395…`)은 유지했다. container의 임시 기록은 `raw/`에 복사한 뒤(cmp 동일) 지웠다.
- 원시 ROI JPEG에는 관련 없는 화면 내용이 섞여 있어 저장소에 넣지 않았다. 경로는 `/private/tmp/resourcerunner-task005-boundary-runs`이고, 선택 프레임 SHA는 `input-manifest.json`의 `selectedFrames`에 있다.
- 다음 임시 경로는 이 manifest의 재현 입력이라 남겨 두었다: `/private/tmp/resourcerunner-task005-boundary-src`, `/private/tmp/resourcerunner-task005-boundary-build`.
