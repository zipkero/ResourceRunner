# task-015 실제 잠금·절전·디스플레이 복귀 검증

2026-10-09 SPEC/DESIGN `[x]`, task-015 `[ ]` 계약에 따라 같은 Sandbox 앱 한 세션에서 잠금/해제·명시 디스플레이 sleep/wake·명시 시스템 sleep/wake 실제 전이를 관찰했습니다. 다른 계정 전환 실제 시험만 SPEC §4의 사용자 선택으로 제외했습니다. 이 파일은 worker 근거이며 Task 승인·상태 변경은 main이 판정합니다.

## 진단 경계

원본 프로젝트 HEAD `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`와 당시 작업 트리 소스를 `/tmp/rr-task015-probe/ResourceRunner`에 복사하고 `DEBUG` 전용 `Task015Probe` 계측을 더했습니다. 실행 중인 `/Users/zipkero/Applications/ResourceRunner.app` PID 64258과 다른 bundle ID인 `com.zipkero.ResourceRunner.Task015Probe`로 빌드했습니다. `codesign --verify --deep --strict` 통과, app-sandbox entitlement `true`, ad hoc 서명입니다. 원본 프로젝트 소스·테스트는 이 진단 작업에서 수정하지 않았습니다.

진단 앱은 `--dashboard-preferences-ui-test --settings-ui-test`로 네 카드 표시 설정을 프로세스 내 fixture에 두고 로그인 상태는 메모리 mock을 사용합니다. 수집 source, lifecycle observer, admission, scheduler, store와 native counter reader는 복사한 현재 제품 경로를 그대로 통과합니다. 이 fixture 때문에 사용자 설정·로그인 등록의 실동작을 검증하지는 않습니다.

`source-hashes.txt`는 원본 복사 시 해시, `instrumentation.patch`는 관찰 코드 차이, `build.log`는 빌드, `probe-full.raw.log`는 한 앱 세션의 stdout, `ax-lock-full.raw.log`와 `ax-display-full.raw.log`는 접근성 카드 상태입니다. 진단 앱 PID 62528은 세 전이가 끝난 뒤 종료했습니다. task-011/013의 별도 실제 UI 검증 중에는 진단 팝오버를 닫고 AX 감시를 종료했으며, 각 실제 전이 전에만 다시 켰습니다. Network의 실제 물리 부분 합계는 en0 raw 카운터와 대조하며, 이 환경에서는 llw0 등 불확정 대상 때문에 전체 대표값과 Network 내부 대표 이력이 비어 있는 정상 partial 상태입니다. 이 항목은 근거 한계로 별도 기록합니다.

## 준비된 실제 전이 순서

1. main이 시작 시각을 정하고 잠금 전 상태를 기록합니다. 사용자 비밀번호 잠금 해제는 사용자 직접 수행입니다. 잠금은 macOS의 로컬 `Control-Command-Q` 키보드 단축키로 수행하고, 해제 뒤 최소 두 번의 빠른 샘플을 확보합니다. 이 OS에서 과거 `CGSession` 경로는 존재하지 않습니다.
2. 디스플레이 전이는 `pmset displaysleepnow` 후 실제 `NSWorkspace.screensDidSleepNotification`과 `screensDidWakeNotification`을 확인합니다. 깨어나지 않으면 먼저 실제 로컬 키/마우스를 사용하고, `/tmp/rr-task015-probe/wake-display`는 공개 IOKit API `IOPMAssertionDeclareUserActivity`로 한 번 깨운 뒤 자기 assertion만 해제하는 보조 수단입니다. 이 보조 wake 사용 여부를 증거에 명시합니다.
3. 시스템 전이는 사용자 승인 범위에서 `pmset relative wake 30`을 1회 예약하고 `pmset sleepnow`를 호출합니다. man page는 relative wake가 취소 불가·시간 부정확하다고 명시합니다. `pmset -g sched`에 표시되지 않을 수 있습니다. 기존 예약을 취소하거나 설정·assertion·데몬을 수정하지 않습니다. `sudo -n -v`는 비밀번호 필요 상태입니다. Amphetamine PID 64228의 `PreventUserIdleSystemSleep`은 유지하며 명시적 sleep과 구별해 결과를 판정합니다.
4. 각 전이 전후 로그의 `native-*`, `lifecycle-snapshot`, `boundary`, `applied-plan`, 여섯 `accepted axis` 누적 수, `network-raw`/`disk-raw`의 readAt, `network-store`/`disk-store` baseline·rate·segment·history, `system-store`와 AX 네 카드를 대조합니다. 실제 화면의 CPU·Memory·Disk 공백과 Disk 42pt 미니 판은 이미지와 접근성 문구를 함께 확인합니다.

## 잠금/해제 실제 결과

03:52:50Z `native-screen-lock locked` 뒤 `CollectionBoundary(revision:1, sequence:1, epoch:1, stopped:true)`와 여섯 `.paused`가 기록됐습니다. 직전 누적 accepted는 systemMetrics 505, processSurvey 211, networkActivity 504, diskActivity 504, networkMetadata 23, storageMetadata 19이며 잠금 중 이 수가 증가하지 않았습니다. 03:53:20Z 디스플레이 sleep 알림이 잠금 상태에 병합됐고, 04:05:46Z 디스플레이 wake 뒤에도 잠금이 남아 중지는 유지됐습니다. 이는 잠금 중 우연히 발생한 화면 sleep/wake이며 별도 `pmset displaysleepnow` 실제 관문의 대체로 세지 않습니다.

04:05:49Z 사용자가 직접 해제한 뒤 `sequence:2, epoch:2, stopped:false`가 됐습니다. 보조 두 축은 즉시 24/20회로 증가했습니다. 04:05:51Z 첫 빠른 tick에서 CPU는 `success(nil)`, Memory는 실제 순간값, Network·Disk는 `baselineOnly(newEpoch)`와 rate nil입니다. Disk 이력 누적은 잠금 전 503, 첫 tick 503, 둘째 504이며 segment 1→2로 바뀌었습니다. 04:05:53Z 두 번째 Disk 원시값은 첫 snapshot의 read 1,296,014,163,968→1,296,014,495,744 bytes, write 6,348,104,523,776→6,348,104,740,864 bytes이고 실제 readAt 차분 약 1.999833초에 대해 165,901.84/108,553.05 B/s가 계산됐습니다. Network en0은 첫 rx 3,987,148,800/tx 3,981,969,408→둘째 rx 3,987,241,984/tx 3,981,990,912 bytes이고 약 1.999921초에 대해 알려진 물리 부분 합계 46,593.84/10,752.42 B/s입니다. Network 전체 대표값·대표 이력은 llw0 등 다른 물리 후보의 부분 정보 때문에 이 환경에서 계속 nil입니다. 첫 tick의 원시 카운터를 잠금 전 원시값과 나눠 수면 중 속도를 만들지 않았습니다.

자동 unlock 캡처는 macOS가 진단 팝오버를 닫아 `missing-app-window`로 남았습니다. 복귀 두 번째 빠른 tick 후 04:06:00Z 앱창만 다시 열어 [lock-after-reopened.png](./lock-after-reopened.png)을 찍었고, CPU·Disk 새 점 앞의 빈 10분 판을 확인했습니다. 약 13분 잠금으로 중지 전 점은 10분 표시 범위에서 빠졌으므로 전후 점이 연결되지 않는 짧은 공백은 후속 디스플레이 시험 화면에서 확인해야 합니다. [lock-before.png](./lock-before.png)는 중지 전 네 카드와 Disk 42pt 미니 판입니다. [lock-recovery.raw.log](./lock-recovery.raw.log)와 [lock-ax.raw.log](./lock-ax.raw.log)에 관찰 시각·원시 수치·화면 접근성 근거를 남겼습니다.

## 명시 디스플레이 sleep/wake 실제 결과

`pmset displaysleepnow`는 main이 실행했고 종료 코드 0입니다. 04:09:23Z 실제 `NSWorkspaceScreensDidSleepNotification`을 수신해 boundary sequence 3/epoch 3/stopped true와 여섯 `.paused`가 적용됐습니다. 같은 시각 화면 잠금도 관찰됐습니다. 04:09:27Z 실제 `NSWorkspaceScreensDidWakeNotification` 뒤에도 잠금이 남아 수집이 중지된 상태였고, 같은 초 잠금 해제 신호 후 sequence 4/epoch 4/stopped false가 됐습니다. 독립 보조 wake helper는 04:09:38Z에야 실행되어 공개 `IOPMAssertionDeclareUserActivity` rc=0, 자기 assertion release rc=0을 기록했습니다. 실제 display wake는 helper보다 먼저 발생했으므로 그 원인으로 helper를 주장하지 않습니다.

첫 빠른 tick 04:09:29Z는 CPU 기준점 nil·Memory 현재값과 Network/Disk `baselineOnly(newEpoch)`·rate nil, 두 번째 04:09:31Z는 Disk 339,760.01/26,290.95 B/s와 Network 알려진 물리 부분 합계 35,894.18/6,572.17 B/s였습니다. Network 전체 대표값과 이력은 환경의 partial 상태 그대로 nil입니다. Disk 내부 이력은 626→첫 baseline 626→둘째 627, segment 2→3입니다. [display-before.png](./display-before.png)와 [display-after-reopened.png](./display-after-reopened.png)에서 CPU·Disk의 오른쪽 짧은 공백과 실제 현재값을 확인했습니다. 4초의 짧은 수면으로 10분 축에서는 공백이 수 픽셀인 한계가 있습니다. 자동 capture watcher는 별도 CLI에서 화면 wake notification을 받지 못해 종료했고, 화면 복귀와 두 빠른 tick을 앱 로그에서 확인한 뒤 팝오버를 다시 열어 앱 창만 촬영했습니다. [display-recovery.raw.log](./display-recovery.raw.log), [display-ax.raw.log](./display-ax.raw.log), [display-auto-wake.log](./display-auto-wake.log)에 원자료가 있습니다.

## 명시 시스템 sleep/wake 실제 결과

main이 명시적 `pmset sleepnow`를 실행했습니다. 04:11:47Z 앱이 실제 `NSWorkspaceWillSleepNotification`을 받아 boundary sequence 5/epoch 5/stopped true와 여섯 `.paused`를 적용했습니다. 이어 디스플레이 sleep·잠금 알림이 같은 중지에 병합됐습니다. 04:11:55Z 화면 wake·잠금 해제가 와도 `systemAsleep:true`가 남은 동안 실행은 중지 상태였고, 실제 `NSWorkspaceDidWakeNotification` 뒤 sequence 6/epoch 6/stopped false가 됐습니다. `pmset -g stats`는 Sleep Count 3877→3878, User Wake Count 238→239를 기록했습니다. [system-pmset.raw.log](./system-pmset.raw.log)는 local 13:11:52 Software Sleep pid=10400 진입과 13:11:55 Deep Idle wake를 보여 줍니다. 상대 wake 예약이 원인이었는지는 로그만으로 확정하지 않습니다.

중지 직전 누적 accepted는 systemMetrics 760, processSurvey 328, networkActivity 759, diskActivity 759, networkMetadata 41, storageMetadata 31입니다. stop 경계부터 resume 경계까지 accepted·Network/Disk raw read·store 반영은 각각 0건입니다. 복귀 첫 빠른 tick 04:11:57Z에 CPU 기준점 nil·Memory 현재값, Network/Disk `baselineOnly(newEpoch)`·rate nil이 기록됐습니다. 둘째 04:11:59Z에 Disk 449,772.72/6,864,733.84 B/s와 Network 알려진 물리 부분 합계 10,363.93/10,882.13 B/s가 실제 읽기 시각 차분으로 계산됐습니다. Disk 내부 이력은 756→첫 baseline 756→둘째 757, segment 3→4이며, Network 전체 대표값과 대표 이력은 기존 partial 환경 한계로 nil입니다.

자동 unlock 앱창 촬영은 OS가 팝오버를 닫아 `missing-app-window`였고, 두 번째 빠른 tick 후 앱 팝오버를 열어 [system-after-reopened.png](./system-after-reopened.png)을 찍었습니다. [system-before.png](./system-before.png)와 비교해 CPU 그래프의 중간 공백과 Disk 미니 판의 단절을 확인했습니다. [system-recovery.raw.log](./system-recovery.raw.log), [system-ax.raw.log](./system-ax.raw.log), [system-before-system.txt](./system-before-system.txt), [system-after-system.txt](./system-after-system.txt)가 원자료입니다.

## 소스 대응과 남는 한계

진단 복사본에서 관찰을 넣지 않은 핵심 15개 파일(`ApplicationCoordinator`, scheduler 둘, admission, pipelines/delivery, dashboard presentation, Network/Disk native/topology, rate graph model/view와 카드 view)은 최종 현재 원본과 SHA-256이 모두 같습니다. [core-hashes-current.txt](./core-hashes-current.txt)에 각 쌍을 기록했습니다. 관찰을 넣은 파일의 원본 복사 시 SHA와 최종 계측 patch는 [source-hashes.txt](./source-hashes.txt), [instrumentation.patch](./instrumentation.patch)에 있습니다. 병행 M4 task-012가 진단 복사 후 `AppPreferences.swift`/`PreferencesStore.swift`에 기본값 보존 선호 필드 3개를 더했으며, 이 차이는 [m4-preferences-delta.patch](./m4-preferences-delta.patch)에 별도로 기록했습니다. 진단 앱은 이 새 설정을 사용하지 않아 task-015 lifecycle·counter·graph 경로의 의미는 같습니다. 전체 소스가 현재 원본과 같다고 주장하지 않습니다.

세 실제 전이 모두 stop과 resume boundary 사이 accepted·Network/Disk raw read·store 반영은 0건입니다. OS 잠금과 디스플레이·시스템 sleep은 팝오버를 자동으로 닫아 복귀 첫 두 tick이 closed 일정(빠른 네 축 2초, 보조 두 축 60초)에서 실행됐습니다. 화면 캡처는 두 tick 뒤 팝오버를 다시 열어 찍었습니다. Network는 이 Mac의 부분 물리 정보 상태로 대표 이력이 생성되지 않아 Network 대표 이력의 실제 전후 segment 시각 연속성은 시각화할 유효 양쪽 점이 없습니다. raw en0 차분·source의 새 segment·first baseline과 결정적 source/store 회귀로 해당 경계를 확인합니다. 지연 결과·짧은 병합·세션 비활성은 기존 결정적 테스트의 현재 내용과 해시를 따로 대조해 최종 검증에 인계합니다. [rate-crosscheck.txt](./rate-crosscheck.txt)는 세 전이 뒤 첫 두 실제 readAt·원시 카운터로 속도를 독립 계산한 결과입니다.

진단 앱 PID 62528과 소유 AX/watcher 프로세스는 증거 복사 후 종료했습니다. 설치 Release PID 64258과 Amphetamine PID 64228은 그대로 실행 중이며, 기존 예약·시스템 설정·권한·로그인 등록은 수정하지 않았습니다. 빌드 앱 executable과 Debug dylib, 로그 SHA는 [environment.txt](./environment.txt)와 [artifact-hashes.txt](./artifact-hashes.txt)에 있습니다. 복사 시점과 최종 원본 12개 소스 SHA는 [source-hashes.txt](./source-hashes.txt), [source-hashes-final.txt](./source-hashes-final.txt)가 일치합니다. [deterministic-evidence.md](./deterministic-evidence.md)는 현재 source SHA와 같은 task-018 unit 674/674의 필요한 test ID를 연결합니다. 추가 suite 반복은 하지 않았습니다.
