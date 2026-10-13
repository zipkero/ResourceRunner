# task-008 retry-2: 애니메이션 없이 닫을 때 남는 IOSurface 원인 조사 (정지 반환)

2026-10-13 KST. 기준은 retry-1 작업 트리다(HEAD `1eaf32104d50d78be098859bbaec9a42dfcadeb1` + `popover.animates = false` + 회귀 테스트).
진단 사본에서 후보 3개를 한 번에 하나씩 시험했고, 효과가 확인된 경로가 없어 제품 코드는 retry-1 상태 그대로 두었다.
상위 폴더와 retry-1의 파일은 바꾸지 않았다.

## 판정

- 재현성: 같은 순서(새 프로세스 → 15초 → vmmap/heap → 본체 3초 열기·닫기 → +15s/+60s)에서 애니메이션 끔 제품은 3/3회 8240K IOSurface를 닫힌 뒤 유지했고(Footprint 63.6–64.5M), 애니메이션 켬 대조군은 3/3회 회수했다(56.2–56.3M).
- 이 8240K surface는 열린 동안 두 쪽 모두에 있다. 애니메이션 켬 쪽은 닫힌 뒤 5–15초 사이에 사라지고, 끔 쪽은 60초 뒤에도(정식 측정에서는 15분 넘게) 남는다.
- 원인은 좁히지 못했다. 확인한 것은 아래와 같다.
  - 닫힌 뒤 `_NSPopoverWindow`는 두 쪽 모두 화면 밖에 306×694로 남는다. heap의 창·popover·RenderBox·Metal pool 객체 개수도 두 쪽이 같다.
  - 닫힌 팝오버 창의 layer tree(19개)에서 `contents`를 가진 layer는 작은 `CASDFElementLayer` 하나뿐이다. 앱 쪽 layer 내용이 붙잡는 것이 아니다.
  - 닫힌 창을 lldb로 1×1로 줄여도 surface는 그대로였다. 창 backing 크기에 묶인 것도 아니다.
  - 닫힘 순서가 다르다. 애니메이션 켬은 `willClose` 뒤 약 533ms에 `didClose`가 오고, 끔은 1–2ms 안에 동기로 온다. 끔에서는 hosting 해제가 창의 hidden occlusion(약 9–17ms)보다 먼저 일어난다.
- 후보 3개 모두 회수 경로로 확인되지 않았다.

| 후보 | 변경(`popoverDidClose`) | 8240K 유지 | Footprint(+60s) |
|---|---|---|---|
| 대조군(애니메이션 켬, HEAD) | 없음 | 0/3 | 56.2–56.3M |
| 제품(애니메이션 끔) | 없음 | 3/3 | 63.6–64.5M |
| V-a | `contentViewController = nil`을 main queue 한 턴 뒤로(generation 확인) | 3/3 | 63.7–63.9M |
| V-b | 해제 뒤 닫힌 창 frame layer `setNeedsDisplay()` + `CATransaction.flush()` | 3/3 | 64.0–64.3M |
| V-c | hosting 해제를 0.6초 뒤로(창이 hidden이 된 뒤, generation 확인) | 2/3 | 63.6–64.4M |

- V-c에서 surface를 회수한 1회(run2)도 Footprint는 63.6M로 대조군(56.2M)보다 높았다. 그래서 Footprint 차이 전체를 이 surface 하나로 설명할 수 있는지도 확정하지 못했다.
- 시행 원시 행은 [`probe/repeat-frequency.txt`](probe/repeat-frequency.txt), 120초 warm·3회 반복 비교는 [`probe/product-noanim/`](probe/product-noanim/)·[`probe/control-anim/`](probe/control-anim/)에 있다.
  `idle` 열의 HIDIdleTime 값은 62.7–62.8로 거의 고정돼 있어 판독을 신뢰하지 않는다. 시행 중 사용자 입력 여부는 확인하지 못했다.

## 방법

- 진단 앱은 retry-1과 같은 방식으로 만들었다([`tools/assemble.sh`](tools/assemble.sh)): 원본 project Release 빌드(`CODE_SIGNING_ALLOWED=NO`) → task-002 진단 bundle 사본의 실행 파일만 교체 → 같은 entitlements로 ad hoc 서명(`codesign --verify --strict`).
  bundle ID `com.zipkero.ResourceRunner.PerfDiagnostic`, 설정 plist SHA `a5088394…`.
- 제품·대조군 실행 파일은 retry-1의 `/private/tmp/resourcerunner-task008-r1/perf-diagnostic.app`(`f01d2b66…`)와 `perf-diagnostic-control.app`(`93fa1ce0…`)을 그대로 썼다.
- 후보 소스는 현재 작업 트리 사본 `/private/tmp/resourcerunner-task008-r2/src-base`에서 `StatusBarController.swift` 한 파일만 바꿨다([`variants/`](variants/)). 실행 파일 SHA: V-a `51a22e01…`, V-b `c4b55937…`, V-c `7ce28508…`.
- 관측 도구는 [`tools/probe_closed.sh`](tools/probe_closed.sh)(vmmap·heap·화면 밖 포함 창 목록), [`tools/repeat.sh`](tools/repeat.sh)(재현 빈도), [`tools/windows_all.swift`](tools/windows_all.swift), lldb 스크립트 [`tools/walk_layers.py`](tools/walk_layers.py)·[`tools/lldb-windows.txt`](tools/lldb-windows.txt)다.
  lldb attach와 창 크기 변경 실험은 정식 측정이 아닌 별도 프로세스에서만 했다.
- 닫힘 순서 비교는 상위 `raw/v0-baseline/app-events-83766.jsonl`과 `retry-1/raw/v4-product-p1/app-events-36586.jsonl`의 기존 기록을 다시 읽었다.

## 남은 조사 후보(시험하지 않음)

- 회수가 일어나는 5–15초 지연은 CoreAnimation/WindowServer 쪽 surface 정리 시점으로 보인다. 앱 코드에서 이를 일으키는 공개 API는 이번 범위에서 찾지 못했다.
- 닫을 때마다 `NSPopover`를 새로 만드는 방식은 팝오버·delegate 동일성(`savedOffAndRapidChangesKeepPopoverAndDelegateIdentity`)과 hosting 수명 설계에 걸려 시험하지 않았다.
- 닫기 때만 애니메이션을 켜는 방식은 SPEC §3(열기·닫기 애니메이션 끔)에 어긋나 시험하지 않았다.

## 정리

- 모든 진단 프로세스를 종료했다. lldb·debugserver 잔존 프로세스는 없다.
- 설치 앱 `/Users/zipkero/Applications/ResourceRunner.app` PID 16136(시작 2026-10-09 16:28:46)은 유지했다.
- 빌드 산출물과 후보 소스는 `/private/tmp/resourcerunner-task008-r2/`에 남겼다.
