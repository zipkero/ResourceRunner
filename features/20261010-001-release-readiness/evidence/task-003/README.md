# task-003: 요소별 원인 대조

## 판정

`StatusBarController`의 dashboard `NSHostingController`를 실제 열림에 만들고 실제 `popoverDidClose`에 해제하는 **단일 요소 후보를 닫힘 상태의 그래픽 보유 감소 후보로 채택**한다. 동결 원본과 후보를 각각 새 진단 PID에서 600초 이상 닫힘 워밍업, 본체 약 5초 열림·네 카드 AX 확인, 닫힘 60초 안정화, 300초/1초 표본 3회로 대조했다. 여섯 실행 모두 301개 표본이 유효했다. [`aggregate.json`](aggregate.json)은 원시 자료를 다시 읽어 설정·PID·시작 식별자·창 상태·표본 순서·AX·운영 이벤트를 확인한 결과다.

| 순번 | 원본 CPU 평균 | 후보 CPU 평균 | 원본 Footprint 표본 최대 | 후보 Footprint 표본 최대 | 최대 감소 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 3.2901% | 2.2008% | 424,084,464 B | 62,800,880 B | 361,283,584 B |
| 2 | 3.6010% | 2.1038% | 424,543,216 B | 62,817,264 B | 361,725,952 B |
| 3 | 5.8330% | 2.2755% | 422,560,752 B | 62,931,952 B | 359,628,800 B |

원본 실행 간 Footprint 최대의 범위는 1,982,464 B이고 후보의 세 짝 모두 최소 359,628,800 B 낮다. 원본 각 실행의 400,000,000 B 초과 표본은 168/190/69개였고 후보는 모두 0개다. 후보의 별도 lifetime 최고는 296,190,960 B로, 앞선 열림/전환 최고까지 100MB 아래로 내려갔다는 뜻은 아니다. 사후 `vmmap -summary` 단일 스냅샷에서 `owned unmapped (graphics)` resident는 원본 194.1 MiB, 후보 2.112 MiB였다. `IOSurface` resident는 두 쪽 모두 5.504 MiB였다. `vmmap` 분류와 Footprint는 서로 더하지 않으며, 단일 스냅샷을 300초 최대값으로 대신하지 않는다. 닫힘 `sample` 5초에는 원본의 `NSHostingView.layout`·SwiftUI `ViewGraph`·`HistoryGraphView`/`Canvas` 호출 흔적이 있고 후보에는 같은 문자열이 나타나지 않는다. 이 sample 하나만으로 개별 SwiftUI 뷰의 CPU 비용이나 할당 횟수를 정량화하지 않는다. 소스의 실제 host 해제와 세 쌍의 보유 감소를 연결한 판정이다.

CPU 차이는 같은 순번에서 1.0893/1.4972/3.5575%p로 모두 감소 방향이지만 원본 자체의 세 실행 간 범위가 2.5429%p다. 앞 두 쌍은 이 범위를 넘지 않는다. 따라서 CPU 감소의 크기와 숨김 publication/collector/그래프 각각의 기여는 **미확정**이다. 후보 닫힘 CPU도 2.10~2.28%로 향후 1% 목표를 충족하지 못한다. 후보에서 본체가 열린 비용, 일곱 상태 전체, 반응 시간과 반복 보유 시험은 정식 비교하지 않았다. task-003의 메모리 원인 판정을 전체 성능 통과로 읽지 않는다.

## 입력과 차이

- 원본 제품 소스는 task-001의 `/tmp/resourcerunner-task001-frozen`이다. `/tmp/resourcerunner-task003-hosting-source/ResourceRunner`와 파일별 대조에서 [`hosting-source.patch`](hosting-source.patch)의 `StatusBarController.swift` 한 파일만 다르다. 후보는 `makePopoverContentController` factory를 보관하고, `togglePopover()` 열림 때 host를 연결하며 `popoverDidClose`에서 연결을 끊는다. 원본은 init 때 host를 연결하고 닫힌 뒤에도 보유한다. `DashboardPresentationStore`, collector, ranking, history/epoch/admission, 메뉴바 및 설정 파일은 변경하지 않았다.
- 후보는 동결 소스를 Release/`CODE_SIGNING_ALLOWED=NO`로 새로 빌드한 `/tmp/resourcerunner-task003-hosting-diagnostic.app`이다. 원본 진단 앱은 task-002의 `/tmp/resourcerunner-task002-perf-diagnostic.app`이다. 두 앱의 `diff -qr`에는 실행 파일만 나타난다. 둘 다 `com.zipkero.ResourceRunner.PerfDiagnostic`, 같은 ad hoc 서명·원본 entitlements·별도 sandbox 설정 namespace를 사용한다. `codesign --verify --strict`는 후보에서 통과했다. 정확한 실행 경로는 두 쪽 모두 `/private/tmp/...`이며 `measure`의 path identity 검사에 이 문자열을 사용했다. 실행 SHA와 도구 SHA는 [`manifest.json`](manifest.json)에 있다.
- 설정은 task-002 GUI `Restore Defaults`가 진단 sandbox에 영속화한 11개 기본값을 그대로 사용했다. 각 원시 표본의 canonical settings SHA는 양쪽 모두 `5588eace0f7e5afd6fd7fa8f43880a1834ea1e1d8cba751407d4dbf032f759c8`이다. 네 카드·양쪽 TOP 5·최근 10분·표준·시스템 제외·상세 20개·자동 닫기 켜짐을 유지했다. 사용자 production 설정은 만지지 않았다.
- 동일 Mac15,11/M3 Max/36 GiB, macOS 26.6.2 (25G83), AC 전원·저전력 꺼짐·Dark/Retina 조건에서 원본 다음 후보를 순차 실행했다. 설치 앱 PID 16136과 Amphetamine은 두 arm의 공통 배경이며 사용자 무상호작용 구간에 측정했다. 임시 `caffeinate` PID 90478은 두 arm에 걸쳐 유지 후 종료했다. 상태별 백그라운드 CPU를 고정했다는 주장은 하지 않는다.

## 실행과 기능 근거

- 정식 원본 [`hosting-final-baseline/`](hosting-final-baseline/)은 PID 13523, 2026-10-10 16:55:46 KST 시작, 17:05:46 워밍업 종료, 본체 열림/닫힘 및 60초 안정화 뒤 17:07:00~17:22:13 세 실행이다. 후보 [`hosting-final-candidate/`](hosting-final-candidate/)는 PID 49148, 17:23:11 시작, 보수적으로 17:23:12를 warmup 기준으로 삼아 17:33:12 이후 같은 GUI 이력/안정화, 17:34:23~17:49:34 세 실행이다. 후보 런치 직후 기존 빈 출력 디렉터리 생성에서 실패했으나 앱은 이미 시작됐다. GUI 행동 전 처음 orchestrator를 중단·[`orchestrator-preflight-uncertain-launch.jsonl`](hosting-final-candidate/orchestrator-preflight-uncertain-launch.jsonl)로 보존하고 `ps lstart`의 초 단위 시작 시각에 1초를 더해 600초 이상을 보장했다. 무효 정식 표본은 없고 이 preflight는 정식 실행에 넣지 않았다.
- 동일 SHA의 `orchestrate_closed_after_open.py`, task-001 `measure`·`analyze.py`, task-002 GUI helper 및 별도 `window_observer`를 양 arm에 사용했다. 여섯 raw의 공식 창 hash/AX/설정/PID/세션/지연 조건은 모두 유효했고 최대 표본 일정 지연은 10.063ms였다. observer의 각 정식 구간 기록도 대상 PID 화면 창 0개였지만 관찰기는 1초 사이 창을 놓칠 수 있고 `CGWindowListCopyWindowInfo == nil`을 빈 목록처럼 기록한다. 따라서 observer는 창 상세 분류 보조일 뿐 공식 유효성 판단을 대체하지 않는다.
- 양 arm 모두 600초 숨김 이후 첫 열림 AX에 CPU·Memory·Network·Disk 네 카드, 실제 최신 수치, CPU User/System 두 계열·최근 10분, 양쪽 TOP 5·시스템 제외가 나타났다. 후보는 세 번의 5분 닫힘 실행 뒤 재열림에서도 네 카드와 변화한 최신 수치가 즉시 나타나고 다시 닫혔다([`behavior-after-final.jsonl`](hosting-final-candidate/behavior-after-final.jsonl)). 소스상 store의 갱신·캐시·실패/epoch 경로는 한 줄도 바뀌지 않았다. 이 근거는 수집을 멈춰 얻은 닫힘 감소가 아님을 뒷받침한다. 열기·닫기와 AX 외의 Escape·외부 닫힘·상세·설정·메뉴바·반응 시간·오랜 반복은 task-004/005에서 별도 검증해야 한다.
- 기존 [`hosting-baseline/`](hosting-baseline/)과 [`hosting-candidate/`](hosting-candidate/)의 본체 시도는 후보 두 번째 실행에서 예상하지 않은 자동 닫힘과 서로 다른 GUI 이력 때문에 **정식 paired body 비교가 아니다**. [`hosting-controlled-baseline/`](hosting-controlled-baseline/)의 두 번째 닫힘 시도는 공식 `windows_changed`로 전체 무효이며 2초 창 종류는 당시 hash만으로 복원할 수 없다. [`hosting-baseline-preflight/`](hosting-baseline-preflight/)의 Code 8은 `/tmp` 대신 정확한 `/private/tmp` 실행 경로를 넣어 해결한 측정 전 실패다. [`hosting-quick-candidate/`](hosting-quick-candidate/)의 30초/31표본·sample/vmmap은 순서 결정용 짧은 탐색이며 정식 세 쌍을 대체하지 않는다. 종료 로그의 과거 복사 문구 `all21`은 이 task의 실행 개수와 다르며 실제 run 파일/manifest를 따른다.

## 남은 원인과 제품 범위

task-004에는 확인된 `StatusBarController` hosting 연결/해제 수명과 실제 delegate 기반 display session, 이전 `scheduleFrameCorrection` 지연 작업의 generation/cancel 경계를 우선 반영한다. 기존 `StatusBarControllerTests`의 직접 `popover.show` 호출은 eager host 전제라 실제 열기 진입점으로 옮겨야 하며 behavior/content/delegate assertion은 유지한다. `DashboardPresentationStore`의 “콘텐츠 뷰가 앱 시작 때 한 번 만들어진다”는 주석도 제품의 lazy 수명에 맞게 고쳐야 한다. 후보는 진단 소스일 뿐 아직 제품 파일에 적용하지 않았다.

본체 CPU/Footprint에는 별도 원인이 남는다. task-002 원본 본체 CPU 9.66~9.75%, Footprint 최대 약 424MB였고, task-003의 단일 후보 본체 탐색 한 회도 CPU 8.76%, Footprint 최대 425MB였다. 이 탐색은 paired 3회가 아니므로 감소나 동등성 판정에 쓰지 않는다. 원본 소스에는 CPU와 Network/Disk 그래프의 독립 1초 `TimelineView`/`Canvas`, 시스템 CPU·Memory와 Network·Disk의 별도 `@Published` 전달이 있다. 기존 body sample에 SwiftUI render/Canvas 흔적이 있으나 같은 tick이 실제 몇 번 렌더됐는지 확인되지 않았다. 다음 단일 후보는 **수집·최신 캐시는 유지하면서 표시 중 같은 1초 tick의 자료 전달/그리기 중복을 계측하고 하나만 줄이는 것**이다. peak/gap·시간 축·네 카드·TOP 5·20개 목록은 그대로 유지해야 한다. 이 후보는 아직 구현·3쌍 비교·채택하지 않았다. 닫힘 CPU 1% 목표를 위해 hidden publication 비용도 별도 측정이 필요하다.

`SettingsWindowController`의 host 보유는 설정창 경로에서, `DashboardViewport`의 show 후 짧은 correction은 전환 경로에서 조사할 후보로 남는다. `ApplicationIconCache`는 이미 32px bitmap과 512개 LRU/실패 캐시를 사용하므로 원본 고해상도 아이콘을 무제한 보유한다는 가설과 맞지 않는다. 이들에 대한 성능 기각·채택 판정은 아직 없다. 제품 전체 목표는 task-005/006/007의 독립 판정 대상이다.
