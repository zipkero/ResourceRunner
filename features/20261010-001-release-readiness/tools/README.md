# 외부 측정 도구

`measure.swift`는 대상 PID를 읽기만 하는 macOS 도구입니다. 앱을 실행·종료하거나 설정을 쓰지 않습니다.
`proc_pidinfo(PROC_PIDTASKINFO)`의 누적 user/system Mach tick을 검증된 `mach_timebase_info`로 환산하고,
`proc_pid_rusage(RUSAGE_INFO_V4)`의 RSS·Physical Footprint·실행 최고 Footprint를 byte로 남깁니다.
`analyze.py`는 원시 JSONL을 다시 계산하며 구간 하나라도 무효이면 실행 전체를 무효로 표시합니다.

```sh
swiftc -O tools/measure.swift -o /tmp/resourcerunner-task001-measure
/tmp/resourcerunner-task001-measure \
  --pid PID --state closed --domain com.zipkero.ResourceRunner \
  --output /tmp/closed-run-1.jsonl --duration 300 --interval 1 \
  --events /tmp/closed-run-1.events \
  --exe /absolute/path/ResourceRunner.app/Contents/MacOS/ResourceRunner \
  --sha EXPECTED_EXECUTABLE_SHA256 --max-bytes 33554432
python3 tools/analyze.py /tmp/closed-run-1.jsonl --output /tmp/closed-run-1-summary.json
```

한 번의 실행은 1800초·32MiB 이하입니다. 출력 경로가 이미 있으면 덮어쓰지 않습니다.
`--events`는 운영자가 상태·잠금·설정 전환을 기록하는 UTF-8 파일입니다. 시작 전에 예상 상태를 한 줄로
적고, 전환 때 해당 내용을 바꾸면 이벤트와 무효 사유가 남습니다. 도구도 설치 실행 파일 경로·PID 시작 tick,
설정 `preferences.v1`의 canonical SHA, 화면 위 해당 PID 창 번호·layer·geometry, 세션 상태와
sleep/awake 시간 차이를 매 표본 확인합니다. 설정 출처는 sandbox plist가 있으면 해당 경로,
없으면 사용자 전역 plist입니다. `preferences.v1`가 없는 기존 설정은 `absent`로 구분합니다.

예정 시각에서 250ms 초과 지연, API 실패·누적 카운터 역전·PID/시작 식별자 변경·창/설정/세션 변화,
절전 전환, 운영자 이벤트, 누락·출력 상한은 실행 전체를 무효로 처리합니다. 세션·창·설정의 표본 사이
전환을 모두 관찰할 수는 없으므로 운영 이벤트와 상태별 화면 확인이 필요합니다. 창 해시는 지정 상태의
동일성 검사이며 일곱 창 상태를 자동 분류하지 않습니다. 첫 표본은 차분 전 기준점이라 CPU 값이 없습니다.
원시 출력의 `valid`는 해당 행의 즉시 판정이며 최종 유효성은 `analyze.py`의 `valid`를 사용합니다.

## task-002 GUI 상태 확인과 원본 실행

`gui_state.swift`는 지정 PID의 AX 앱 트리 안에 있는 `AXMenuExtra`만 사용해 메뉴바,
네 카드, 상세 제목, 설정창을 확인하고 CGEvent로 전환합니다. 기존 설치 앱의 PID를 전달하지 않습니다.
`inspect`의 `state`는 `closed`, `body`, `cpu`, `memory`, `network`, `disk`, `settings` 중 하나이며,
본문에서는 네 카드, 상세에서는 해당 머리글, 설정에서는 11개 기본값을 함께 기록합니다.

```sh
swiftc -O tools/gui_state.swift -o /tmp/resourcerunner-task002-gui-state
/tmp/resourcerunner-task002-gui-state DIAGNOSTIC_PID inspect
python3 tools/orchestrate_baseline.py \
  --pid DIAGNOSTIC_PID --launch-epoch PROCESS_LAUNCH_EPOCH \
  --output evidence/task-002/runs \
  --exe /private/tmp/resourcerunner-task002-perf-diagnostic.app/Contents/MacOS/ResourceRunner \
  --gui /tmp/resourcerunner-task002-gui-state \
  --measure /tmp/resourcerunner-task001-measure --analyze tools/analyze.py
```

오케스트레이터는 새 진단 프로세스의 닫힘 상태에서 600초가 될 때까지 기다리고,
상태별 60초 안정화 후 300초씩 세 번 실행합니다. 매 5초 AX 상태를 별도 파일에 기록하며
불일치를 발견하면 해당 실행의 `--events`를 바꿔 전체를 무효로 남깁니다. 도구 자체의 1초
창/설정/세션 검사도 계속 적용됩니다. 무효 원본은 삭제하지 않고 최대 세 번 재측정한 뒤
계속 실패하면 원인 조사를 위해 중단합니다. 상태 관찰의 5초 사이 순간 변화는 직접 포착할 수
없으므로 도구의 창/설정/세션 이벤트와 함께 판정합니다.

CPU·Memory 상세는 `DashboardDetail`, Network는 `NetworkDetail`, Disk는 `DiskDetail`로
구분합니다. 실제 제목은 각각 `CPU 상세`, `Memory 상세`, `Network 인터페이스`,
`Disk 장치와 볼륨`입니다. GUI 도구는 대상 PID의 메뉴바 요소 소유 PID를 확인하며,
설정창 AX 값과 포커스 창도 관찰 파일에 기록합니다. AX 호출은 4초, 측정 자식 프로세스는
340초 제한을 두어 관찰 중단을 운영 이벤트와 무효 판정으로 남깁니다.

이미 완료된 상태의 유효 raw를 보존하고 다음 상태부터 재개할 때는 동일 프로세스와 설정,
이전 상태의 3회 유효 결과를 먼저 확인한 뒤 `--resume-from network`처럼 지정합니다.
재개 상태 전환 뒤 60초 안정화부터 다시 수행하며 새 `resume-orchestrator.jsonl`을 남깁니다.
원본 Task002 실행에서 이 경로를 사용한 이유와 v1 관찰기 보존 내역은
`../evidence/task-002/README.md`에 기록했습니다.
