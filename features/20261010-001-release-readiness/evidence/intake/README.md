# 성능 개선 착수 입력

2026-10-10 사용자 Phased 착수 이전 읽기 전용 관찰을 다음 단계 입력으로 보존합니다.
이 자료는 정식 M5 성능 검증 통과 근거가 아닙니다.

## 환경

- Mac15,11 / Apple M3 Max / 물리 메모리38,654,705,664bytes(36GiB).
- macOS26.6.2(25G83), 설치한 arm64 Release 실행 파일.
- 앱 /Users/zipkero/Applications/ResourceRunner.app, PID16136, 시작2026-10-09 16:28:46KST.
- 실행 파일 SHA256 a4073395407599a16cec757957ded1f4ecbdc535a070e7c985647a3f6bd32c80.
- 2026-10-10 11:52 CGWindowList는 앱 소유 onscreen 창으로 「ResourceRunner 설정」만 반환했습니다.
  창을 닫거나 앱을 재실행하지 않았습니다. 일반 설정의 현재값을 재확인한 정식 baseline이 아닙니다.

## 1분 관찰 결과

12회5초 간격과 시작 표본, 실제 구간60.188665125초입니다.
CPU시간은 ps 누적time의 시작/종료 차분으로 계산했고 메모리는 SDK resource.h의
rusage_info_v0 / proc_pid_rusage와 ps RSS를 읽었습니다. 프로파일러는 이 구간 이후 실행했습니다.

| 지표 | 값 |
| --- | ---: |
| 평균CPU(한 논리코어100% 기준) | 5.1670858517% |
| RSS 시작/종료 | 178.328125 / 183.640625MiB |
| RSS 최소/최대 | 178.328125 / 183.718750MiB |
| Physical Footprint 시작/종료 | 369.4697113 / 369.7665863MiB |
| Physical Footprint 최소/최대 | 366.6103363 / 495.0478363MiB |

vmmap 시작 관찰 Footprint364.9MiB / 커널 보고 실행 최고524.6MiB,
그래픽 owned-unmapped resident234.5MiB와 malloc 총allocated35.4MiB를 구분했습니다.
같은 프로세스의 전날 관찰 최고값도524.6MiB이고 malloc allocated도35.4MiB였습니다.
이는 두 시점 비교이며13시간의 연속 활성 사용·누수 없음이나 지표 합산을 증명하지 않습니다.

## CPU sample

[5초·10ms 간격 raw sample](./20261010-process-sample.txt)을 보존합니다.
주 스레드의 대부분은 이벤트 대기이며 활동 구간에 SwiftUI layout·ViewGraph·CoreAnimation·RenderBox가 관찰됩니다.
특정 숨김 그래프가 비용의 전부라고 확정하지 않습니다. 후속 Task의 창 상태별 대조가 필요합니다.

원시13표본 JSON 전체는 앞선 도구 출력에만 있고 이 파일에는 실제 구간과 요약값을 옮겼습니다.
따라서 이 관찰을 전후 비교용 baseline으로 재사용하지 않고 Task에서 새 측정 절차를 고정합니다.
