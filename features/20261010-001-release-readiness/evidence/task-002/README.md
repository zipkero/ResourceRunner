# task-002: 동결 Release 원본 baseline

## 대상과 격리

[task-001 manifest](../task-001/manifest.json)의 동결 Release를
`/tmp/resourcerunner-task002-perf-diagnostic.app`으로 복사했습니다. 진단 bundle ID만
`com.zipkero.ResourceRunner.PerfDiagnostic`으로 바꾸고 원래 sandbox entitlements로
ad hoc 재서명했으며 `codesign --verify --strict`를 통과했습니다.
원본 실행 파일 SHA256은 `dbd1f192c2496982d961989c9b487c7d22ea045034527a326f367dba988a4b6e`,
진단 실행 파일 SHA256은 `d549f7fd7ac53cb819419f2b39ed2205aaea3254db67ae19a16530030d4528c0`입니다.
서명 및 ID 차이는 성능 개선 효과로 해석하지 않습니다. 복사 전 진단 ID 설정 plist가 없음을 확인했습니다. `measure.swift`는 첫 설정 fingerprint를 요구하므로
준비용 진단 GUI의 `기본값 복원`으로 별도 namespace에 기본값을 기록했고, 2초 smoke 측정이 통과했습니다.
원본 namespace는 변경하지 않았습니다.
원본 `AppPreferences.defaults`는 네 카드·양쪽 TOP5·최근 10분·표준 수집·시스템 제외·상세 20개·
자동 닫기 켜짐입니다. 준비용 PID39156의 실제 설정창 AX 값도 모두 일치했습니다.
기존 설치 앱 PID16136은 종료·설정 변경하지 않았습니다.

## 공식 절차

준비용 앱을 종료하고 새 진단 PID43937을 2026-10-10 12:54:26 +0900에 시작했습니다.
사전 GUI 접근 없이 AX `closed`를 확인했고 그 시각부터 닫힘 상태 600초 워밍업을 시작했습니다.
상태 순서는 `closed`, `body`, `cpu`, `memory`, `network`, `disk`, `settings`이며,
각 전환 후 60초 안정화, 각 상태에서 300초·1초 간격 유효 실행 3개를 목표로 합니다.
`gui_state.swift`가 대상 PID의 AX 메뉴바와 네 카드/상세 제목/설정창을 확인하고,
`orchestrate_baseline.py`가 5초 간격 관찰 및 `measure.swift --events`와 연결합니다.
실행별 원시 JSONL, AX 관찰, 운영 이벤트, `analyze.py` 재계산 요약을 `runs/`에 남깁니다.
무효 실행은 전체를 보존하고 새 attempt로 재측정합니다.

환경·출처·도구 해시는 [manifest.json](./manifest.json)을 참조합니다. AC 전원·저전력 꺼짐,
내장 Retina 화면·Dark 외관, 기존 설치 앱과 공통 백그라운드 프로세스가 있습니다.
기존 Amphetamine assertion과 이번 `caffeinate -di -t 30000` 기간 assertion이 잠금/절전 없는
측정 환경을 유지합니다. 샘플 사이 순간 상태 변화는 외부 AX 관찰만으로 완전히 배제할 수 없습니다.

## 완료와 집계

2026-10-10 15:00:52 +0900에 7개 상태의 유효 실행 3개씩, 총 21개를 마쳤습니다.
각 실행은 300초에 1초 간격 표본 301개이며 같은 PID 43937·startTicks 28154177062305·
기본설정 canonical SHA를 사용했습니다. 원시 자료·AX 관찰·운영 이벤트를 실행별로 대조했고
모든 실행의 `analyze.py` 결과가 `valid=true`, `reasons=[]`입니다.
[aggregate.json](./aggregate.json)에 각 원시 파일 해시와 실행별 CPU/RSS/Footprint를 남겼습니다.
아래 CPU는 실행별 평균의 중앙값이며, 나머지는 세 실행을 통틀어 가장 큰 값입니다.

| 상태 | CPU 중앙값 | RSS 최대 bytes | 표본 Footprint 최대 bytes | 실행 최고 Footprint bytes |
| --- | ---: | ---: | ---: | ---: |
| 닫힘 | 2.595% | 122,748,928 | 47,023,088 | 254,624,752 |
| 본문 | 9.664% | 143,261,696 | 424,150,024 | 441,648,136 |
| CPU 상세 | 12.132% | 162,234,368 | 451,478,584 | 455,984,184 |
| Memory 상세 | 12.716% | 172,310,528 | 467,141,736 | 475,972,712 |
| Network 상세 | 12.643% | 186,122,240 | 477,660,264 | 491,422,824 |
| Disk 상세 | 10.337% | 184,778,752 | 477,086,824 | 491,422,824 |
| 설정 | 5.534% | 187,432,960 | 477,430,888 | 491,422,824 |

닫힘 CPU 1% 미만과 열린 상태 CPU 3% 미만·Footprint 100 MB 미만 목표는 원본에서
달성되지 않았습니다. 이는 원본 baseline 결과이며 task-002의 증거 유효성 실패는 아닙니다.
실행 최고 Footprint는 프로세스 시작부터의 누적 최고이므로 해당 상태에서 새로 생긴 peak로
해석하지 않습니다. 상태 전환 초기 peak와 표본 사이 peak도 300초 안정 표본만으로 단정할 수 없습니다.

`Network`로 전환할 때 v1 GUI 관찰기가 실제 제품 AX 제목을 잘못 예상해 오케스트레이터가
측정 시작 전에 멈췄습니다. 실패 기록과 v1 도구는 `preflight/`에 보존했습니다.
승인된 `measure.swift`·`analyze.py`와 기존 12개 유효 측정은 그대로 두고, 제품 원본의
`NetworkDetail`/`Network 인터페이스` 및 `DiskDetail`/`Disk 장치와 볼륨`을 반영한 v2로
같은 PID와 설정에서 `Network` 전환 후 60초 안정화부터 재개했습니다.

[behavior.jsonl](./behavior.jsonl)은 공식 측정 뒤 설정 닫힘, 본문 재열림, CPU 상세 선택과
닫힘, 팝오버 닫힘과 재열림을 실제 AX 결과로 기록합니다. 재열림은 본문으로 시작했고
네 카드 설명이 표시됐습니다. 설정창의 11개 AX 값과 포커스 창 식별자는 설정 실행의
`*.ax.jsonl`에 있습니다. [sample-body.txt](./sample-body.txt)와
[vmmap-body.txt](./vmmap-body.txt)는 공식 안정 측정 종료 후 별도로 수집했습니다.
원본 설치 앱의 PID·시작 시각·실행 파일 SHA가 [사전](./preflight/installed-original-before.json)과
[사후](./installed-original-after.json)에 같습니다. 5초 AX 관찰과 1초 도구 표본 사이의
순간 변화 및 profiler 자체의 관찰 부하는 배제할 수 없습니다.
