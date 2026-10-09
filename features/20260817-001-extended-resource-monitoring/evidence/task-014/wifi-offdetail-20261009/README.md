# 실제 Wi-Fi Off 상세/복귀 관찰 (2026-10-09)

이 패킷은 앞선 [`wifi-20261009`](../wifi-20261009/README.md) 시험의 미확인 항목이던 **Off 중 설치 Release 앱 상세 화면**을 추가로 관찰한 결과다. 제품 코드·설정·등록 설치 앱을 변경하지 않았다.

## 관측 경계

- 설치 Release `/Users/zipkero/Applications/ResourceRunner.app` PID 64258의 Network 상세를 AX로 열었다. `ax-detail-preflight.log`에서 네트워크 조작 전 8회 연속 `NetworkDetail`과 en0 상세 행이 확인됐다. `ax-monitor-detail.swift`는 상태바 AX 버튼을 누른 뒤 해당 PID에 ⌘3을 보내 상세를 선택하고 카드·en0·llw0·awdl0 행을 매초 읽는다. 새 상세 코드를 제품에 넣지 않았다.
- 동시에 앞선 패킷에서 출처·서명·계측 diff를 보존한 **별도** 전체 앱 소스 Debug Sandbox 진단 앱 PID 15598을 재실행했다. `probe-offdetail.log`는 이 앱의 실제 native reader→source→store/lifecycle/admission 출력이다. Release 앱 내부 메모리를 직접 측정한 것으로 확대하지 않는다. `environment-final.txt`에 설치 Release/진단 앱 바이너리 SHA-256, Sandbox entitlement, HEAD, 종료 후 상태가 있다. 계측 소스/전체 앱 대응은 앞선 패킷의 `probe-instrumentation.diff`, `source-tree-diff.txt`, `source-hashes.txt`에 있다.
- 네트워크 조작 프로세스와 독립된 watchdog PID 15900을 먼저 시작했다. `recovery.log`에 armed/heartbeat와 마지막 Power On 확인이 있다. 25초 뒤 On 재시도, 최대 100초까지 반복하는 `wifi-recovery.sh`와 종료 trap을 가진 `run-transition.sh` 원문을 함께 남겼다. 앞선 시험의 watchdog 94560/94980/96088 종료를 확인한 뒤 새 프로세스 하나만 사용했다.

## 전이와 제품 표시

- `transition-offdetail.log`: 02:59:44Z preflight에서 watchdog 15900, 설치 Release 64258, 진단 15598 생존, Wi-Fi On·en0 active, `setairportpower on` rc=0. 같은 시각 off rc=0. 02:59:48Z·:53Z·:57Z 모두 Wi-Fi Off, IPv4 없음/Not Reachable, en0 OS 카운터 고정. 02:59:57Z on rc=0과 종료 trap rc=0. 03:00:06Z en0 IPv4/DNS Reachable 복귀. 시작/종료 명령 시각 간격은 13초이며 실제 Off 지속 시간의 정확한 초 단위 상한을 단정하지 않는다. watchdog은 03:00:09Z On을 확인하고 종료했다.
- `ax-offdetail.log`의 안정 Off 구간 02:59:48~56Z: Network 카드 8회 모두 “측정된 속도 없음”. en0 상세 행 9회 모두 “물리 Wi-Fi · 연결 비활성”, 현재 RX/TX `0.0 B/s`, IPv4 없음 또는 미확인, 원시 누적 RX/TX 고정. llw0는 “종류 미확인 · 연결 상태 미확인”, awdl0는 가상 활성으로 남았다. 카드/상세의 부분 미확인 상태는 실제 다른 논리·가상·미확인 대상이 남은 native 결과와 일치한다. 이것을 시스템 전체 `disconnected`로 부르지 않는다.
- 진단 앱 `probe-offdetail.log`: Off 첫 activity 02:59:45Z는 revision 85/segment 7의 `baselineOnly(topologyChanged)`이고, 안정 Off에서는 en0 raw RX/TX 3,631,978,496/3,882,053,632 B가 고정됐다. source 분류에서 en0 link=false이며 대표·확인된 물리 부분 속도는 nil이다. 복귀 후 02:59:59Z revision 404/segment 14, 03:00:01Z revision 427/segment 15, 03:00:03Z revision 450/segment 16은 모두 새 기준점이다. 03:00:05Z부터 새 카운터 간격의 부분 속도가 재개됐다. 이전 Wi-Fi 대상의 registry ID 4294971925는 같지만 topology lifetime 14→102→322로 갱신됐고 끊김 전 값과 복귀 값을 하나의 속도로 차분하지 않았다.
- `analysis.json`/`analyze.py`: 명령 전후 14개 activity 중 baseline 6개, partial 8개, 음수 en0 속도 0. 이 구간 최대 en0 RX 42,425.68 B/s·TX 15,334.58 B/s이며 비정상 급증은 보이지 않았다. 기존 llw0 분류가 `unknown`이라 실제 native 대표 합계는 전후 모두 partial/nil이고 유효 대표 history count는 0이다. source는 부분 상태마다 segment를 증가시키고, 결정적 테스트 [`NetworkActivityTests.swift`](../../../../../ResourceRunnerTests/NetworkActivityTests.swift)의 유효점 재개/segment 분리와 `disconnected` 전이를 현재 계약대로 검증한다. 실제 이력에 유효점을 임의로 주입하지 않았다.
- 복귀 후 `ax-offdetail.log`에는 NetworkCard 부분 속도·Wi-Fi 활성과 en0 상세 주소/현재·누적 RX/TX가 다시 기록됐다. `ax-post-cards.log`의 설치 Release DiskCard는 정상 측정·현재 Read/Write·용량 보조 정보와 그래프 상태를 표시한다. Off 중 DiskCard와 DiskDetail은 이번 AX 루프에서 직접 수집하지 않았다. Disk native/표시의 기존 실기기 AX 근거는 [`task-013`](../../task-013/README.md)과 현재 코드·결정적 검증을 참조한다.

## 종료 상태와 한계

진단 앱 PID 15598과 watchdog 15900은 종료했다. 설치 Release PID 64258은 계속 실행 중이며 Wi-Fi Power On, en0 IPv4/DNS Reachable을 확인했다. UI 상세를 닫고 본체 팝오버도 닫았다. en0은 Off에서도 native 목록에 link inactive로 남았으므로 제거된 target이라고 주장하지 않는다. 다른 활성·미확인 인터페이스가 있어 실제 `disconnected`와 대표 유효 history 점 전후 비교는 이 장치에서 나오지 않았고, 그 동작은 앞선 결정적 테스트 범위로 대조한다. VPN·외장·유선 전환은 사용자 제외 범위다.
