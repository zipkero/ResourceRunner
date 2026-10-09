# 실제 Wi-Fi 끊김·복귀 관찰 (2026-10-09)

## 대상과 방법

- 기존 설치 Release 앱 PID 64258(`/Users/zipkero/Applications/ResourceRunner.app`)은 재빌드·재서명·재시작하지 않았다. `ax-retry.log`, `ax-detail-current.log`는 이 PID의 실제 접근성 화면이다. 원격 AX 관찰 프로그램은 `/tmp/rr-task014-probe`에서만 실행했고 `ax-monitor.swift`와 `ax-open-detail.swift`를 보존했다.
- 내부 기준점·대상 수명은 전체 현재 앱 소스를 `/tmp/rr-task014-probe`로 복사해 만든 고유 번들 ID `com.zipkero.ResourceRunner.Task014Probe`의 arm64 Debug 앱 PID 92795로 확인했다. 이 앱은 App Sandbox 서명이며, 실제 `ApplicationCoordinator`→`CollectionPipelines.make`→native reader/source/store/lifecycle/admission을 그대로 실행했다. `probe-instrumentation.diff`의 네 기존 파일에는 출력만 추가했고 새 `Task014Probe.swift`가 stdout에 썼다. 원본 SHA-256은 `source-hashes.txt`, 전체 앱 소스 차이는 `source-tree-diff.txt`, 고유 bundle ID 변경은 `project-id.diff`, 빌드 성공 원문은 `build.log`, 임시 앱 서명/바이너리 및 기준 HEAD는 `environment.txt`에 있다. 임시 Debug 인자는 메모리 내 preferences와 login service를 쓰므로 기존 로그인 등록을 변경하지 않았다. `probe.log`는 이 별도 앱의 내부 상태이며 Release PID의 내부 메모리를 직접 읽은 값이 아니다.
- `wifi-recovery.sh`는 네트워크 작업 호출 프로세스와 분리한 session의 PID 96088로 **전원 끄기 전에** 시작해 1초 heartbeat를 기록했다. 시작 후 25초에 `networksetup -setairportpower en0 on`을 시도하고, 필요하면 시작 후 100초까지 2초 간격으로 재시도하도록 했다. 설치된 LaunchAgent/Daemon/helper나 영구 설정 변경은 없다. `run-transition.sh`는 preflight 실패 시 off를 하지 않으며 종료 trap에서 on을 재시도한다. 전원 조작은 사용자 승인된 Wi-Fi en0에만 했다.

## 원시 결과

- 첫 실행은 preflight 스크립트의 `/bin/grep` 경로 오류를 수정한 뒤 off rc=0으로 시작했다. 그러나 이전 preflight 시도에서 준비했던 watchdog PID 94560이 01:50:23Z에 Off를 감지해 전원을 On으로 복구했다. `transition.log`의 01:50:24Z에는 이미 On이므로 이 실행을 12초 연속 Off 시험으로 쓰지 않는다. 이 개입과 복구는 `recovery.log`에 보존했다. 해당 watchdog이 종료되고 기존 en0 On·active를 확인한 뒤 다음 실행을 했다.
- 유효 실행은 01:51:05Z preflight에서 watchdog PID 96088 alive/heartbeat, Release 64258와 진단 92795 alive, Wi-Fi On, en0 active, `setairportpower on` rc=0을 확인했다. 같은 시각 off rc=0. 01:51:09Z, :13Z, :17Z에는 모두 Power Off, `scutil --nwi` IPv4 없음·Not Reachable, en0 `netstat` 카운터 고정이었다. 01:51:17Z on rc=0 및 종료 trap rc=0. 01:51:25Z에는 Power On, en0 IPv4/DNS Reachable 복귀. watchdog 96088은 01:51:30Z Power On을 확인하고 정상 종료했다.
- 진단 앱의 en0 raw RX/TX는 01:51:06~18Z에 3,606,273,024/3,869,886,464 B로 고정됐다. native metadata는 en0 link=false, IPv4/IPv6 0을 확인했다. activity는 :06Z `baselineOnly(topologyChanged)`, :08~16Z `partial`/knownPhysicalRates=nil, :18Z `baselineOnly(topologyChanged)`를 냈다. 복귀 뒤 :20Z en0 link=true·주소 확보 상태의 첫 activity는 `baselineOnly(topologyChanged)`이고, :22Z부터 en0 known rate가 다시 나왔다. en0의 registry ID 4294971925는 유지됐지만 topology revision/lifetime은 전이 알림에 따라 새 값이 되었고, 전이 전 카운터를 복귀 속도에 이어 붙이지 않았다.
- `analysis.json`/`analyze.py`: 01:51:04~30Z의 activity 14개 중 baseline 5, partial 9, disconnected 0. 확인된 물리 부분 속도 최대 RX 49,589.84 B/s, TX 128,038.17 B/s, 음수 0. 대표 합계는 llw0 등 종류 미확인 활성 가능 대상 때문에 전체 기간 `nil`/partial이며 history count는 0이었다. `NetworkTopologyTracker` revision이 544→975로 빠르게 증가한 것은 `ResourceTopologyObserver`의 광범위 SCDynamicStore 변경 구독과 `noteChange()`/identity 초기화가 전이 중 연속 발생한 것과 일치한다. callback 키/횟수를 직접 기록하지 않아 정확한 증가 원인은 추론이다. 안정 후 부분 속도가 정상 범위로 재개됐다.
- 설치 Release 앱의 NetworkCard AX는 Off에서 “측정된 속도 없음”, 활성 논리·가상 2개와 상태 미확인 8개를 표시했고, On 후 Wi-Fi 포함 활성 4개와 부분 속도로 복귀했다. Off에서 `연결 없음`을 표시하지 않았다. 실제 raw에는 awdl0·bridge100 같은 가상/논리 활성 경로와 llw0 미확인 경로가 남았고, en0도 link inactive인 채 native 목록에 유지되므로 시스템 전체 단절이나 대상 제거를 추정하지 않는다. Off 구간의 상세는 AX로 열지 못했다. 복귀 후 `⌘3` 경로로 Release `NetworkDetail`을 열고 `ax-detail-current.log`에서 en0 물리 Wi-Fi·연결 활성·현재 RX/TX·누적값·IPv4/IPv6·링크 속도 미지원 사유와 awdl0 가상 상세를 확인했다. 상세를 닫고 원래 팝오버를 닫았다.
- 종료 후 임시 진단 PID 92795와 세 watchdog PID는 모두 종료, 설치 Release PID 64258은 생존하며 en0 Power On/IPv4 Reachable이다.

## 판정 경계

이 근거는 실제 Wi-Fi 전원 끊김·복귀에서 baseline과 부분 속도·카드 표시의 방향, 앱 생존을 확인한다. 시스템에 다른 활성/미확인 인터페이스가 있어 `disconnected` 상태는 검증하지 못했다. 대표 합계가 기존에도 partial이어서 rate history의 분리도 유효 점 추가 전후로 직접 비교하지 못했다. Off 구간 상세 목록 화면은 기록하지 못했으므로 native metadata/source와 복귀 상세 화면 근거를 구분한다. VPN·외장 디스크·유선 Ethernet 실제 전환은 사용자 제외 범위이며 이 자료는 해당 실기기 전환 근거가 아니다.

## main 인수와 최종 판정

2026-10-09 worker 결과를 main이 인수하고 독립 verifier의 `rejected / evidence`를 확정했습니다. 실제 Wi-Fi 조작·독립복구·복귀 연결·전이 baseline/다음 부분속도·앱 생존은 충족입니다. 전체 연결 없음 표시, Off 상세 AX, 대표 속도 이력의 전후 유효점 분리는 근거 부족이며 기능 오류로 확정하지 않았습니다. task014/IMPLEMENT [ ] 유지, 새 SPEC 완료 없음, 구현 재시도0·근거 재검증0입니다. 요청한 Wi-Fi 시험과 복구는 완료했고 추가 네트워크 변경은 수행하지 않습니다.
