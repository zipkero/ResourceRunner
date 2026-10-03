# task-010 compact retry — blocked candidate

- cwd: `/Users/zipkero/XcodeProjects/ResourceRunner`; HEAD: `e63e5151579c183267613c22e3b49bea7cc6c506`; 2026-10-03 KST.
- 범위: Network 요약 248×160pt, 그래프 전용 표시 제거, Disk의 기존 294pt 그래프 슬롯 분리. `change.patch`는 worker 소유 파일만 포함한다. `CONTEXT.md`와 feature 문서의 동시 변경은 main 소유이며 보존했다.
- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -derivedDataPath /tmp/ResourceRunner-M3-task010compact-tests -only-testing:ResourceRunnerTests/NetworkDashboardViewTests -only-testing:ResourceRunnerTests/DiskDashboardViewTests test`: 통과. 원시 로그 `logs/task010compact-focused-final.log`.
- 같은 프로젝트/경로에서 `-only-testing:ResourceRunnerTests test`: 606/606 통과 (`logs/task010compact-full-unit.log`); 이후 production 변경 없이 max-rate fixture만 UInt64.max로 되돌려 Network 직접 4/4 통과 (`logs/task010compact-max-focused.log`).
- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -derivedDataPath /tmp/ResourceRunner-M3-task010compact-release build`: 통과 (`logs/task010compact-release.log`). 서명 Debug 빌드: `/tmp/ResourceRunner-M3-task010compact-probe`, 통과 (`logs/task010compact-signed-build.log`, `logs/codesign.stderr.log`).
- 실제 서명 Sandbox 앱 `RR_NETWORK_UI_PROBE=1 RR_NETWORK_UI_PROBE_OUTPUT=1 /tmp/ResourceRunner-M3-task010compact-probe/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner`: PID 80721 원시 로그 `logs/task010compact-actual-probe.log`. 본체 306×627, Network AX 248×160, 상세 426×506, 물리 일부합계 RX/TX, en0/utun의 현재속도·누적량·IP·조건부 링크 사유, AXPress 닫기 및 재선택/같은 카드 닫기, 본체 frame 불변 확인. `actual/`은 앱 컨테이너 Caches 원본을 복사했다. `actual-dashboard.png`에는 그래프 없는 Network160과 기존 Disk294 그래프가 함께 보인다. 실제 VPN 전환은 task-014 범위다.
- `renders/manifest.json`은 XCTest 첨부물 이름 매핑이다. 정상·일부실패 및 en_US/gez_ER/my_MM 최대값 PNG를 보존했다. `source-binary-hashes.txt`는 소스·서명Debug/Release 바이너리 해시이며 `logs/diff-check.log`는 빈 출력(통과)이다. XCUITest 자동화는 이전 task-010에서 앱 본문 전에 timeout이 발생한 원시 근거가 있어 재시도하지 않았다.

## 미충족 조건

최장 유효 속도 표기가 232pt 내용 폭에서 잘린다. `ResourceQuantityFormatter.byteRate`는 GB/s보다 큰 단위를 사용하지 않고 1자리 소수를 유지한다. `RatePair`는 유한·비음수 Double을 허용하며, UInt64 누적 카운터가 1초에 `UInt64.max`만큼 증가한 경우의 Double 표현도 유효 범위다. 이 값을 넣은 248×160 실제 SwiftUI 렌더에서 다운로드·업로드 숫자가 `…`로 끝난다. `renders/39BE7DB1-877D-416A-9EF5-879DE51098E0.png`(en_US), `renders/8F60EE58-35F9-4BCC-802B-501A3A851CB8.png`(gez_ER), `renders/BA231873-BBDA-4815-8794-F315D2D3DBEA.png`(my_MM). 이전 294pt Network 카드도 같은 232pt 수치행·GB/s 상한을 사용하므로 이번 세로 축소가 만든 회귀는 아니지만, 새 task-010의 '최장 수치 읽힘' 완료 조건을 충족하지 못한다. 단위/정밀도/글꼴을 임의 변경하지 않았다. DESIGN §3.3 소유의 지원 범위 또는 표현 결정을 기다린다.
