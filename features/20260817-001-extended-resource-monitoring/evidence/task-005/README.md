# Task 005 실행 근거

- cwd: `/Users/zipkero/XcodeProjects/ResourceRunner`
- 구현 시작·실행 HEAD: `90204a1e4f6d6b958fd3792130af39f0fc917f97` (`main`)
- 변경 원본 해시: `source-sha256.txt`; 추적·신규 파일 diff: `change.patch`; `git diff --check`: exit 0, 출력 없음 (`diff-check.txt`)
- 환경 원자료: `environment.raw.txt`; 실행 결과 원자료는 아래 log/json 및 Sandbox probe 파일.

## 명령·결과

1. `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -destination 'platform=macOS' -only-testing:ResourceRunnerTests/NetworkActivityTests -only-testing:ResourceRunnerTests/NetworkMetadataTests -only-testing:ResourceRunnerTests/NetworkNativeAdapterTests -derivedDataPath /tmp/ResourceRunner-M3-task005-tests CODE_SIGNING_ALLOWED=NO` → exit 0, 24 passed / 0 failed (`focused-test.log`, `focused-summary.json`).
2. `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -destination 'platform=macOS' -only-testing:ResourceRunnerTests -derivedDataPath /tmp/ResourceRunner-M3-task005-tests CODE_SIGNING_ALLOWED=NO` → exit 0, 552 unique tests passed / 0 failed (`unit-test.log`, `unit-summary.json`). 결과 요약에는 병렬 장치 실행별 count도 포함되므로 최상위 `totalTestCount`를 사용.
3. `xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task005-release CODE_SIGNING_ALLOWED=NO` → exit 0 (`release-build.log`).
4. `xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task005-sandbox` → exit 0 (`sandbox-build.log`). `codesign -dv --verbose=4`, `codesign -d --entitlements :-`로 실제 app 서명과 `com.apple.security.app-sandbox=true` 확인 (`sandbox-signature.txt`, `sandbox-entitlements.plist`, `sandbox-binary-sha256.txt`).
5. `RR_NETWORK_PROBE=1 /tmp/ResourceRunner-M3-task005-sandbox/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner` → PID 36178, 실행 6초 뒤 종료 143, 후속 `ps`에 없음 (`sandbox-probe-process.txt`). `/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "com.zipkero.ResourceRunner" AND category == "NetworkNativeProbe"'` 원시 로그 `sandbox-network-probe.log`의 PID 36178 줄 참조. `sandbox-probe-stdout.log`는 출력 없음.
6. `git diff --check` → exit 0, 출력 없음.

## 실제 Sandbox 관측

같은 서명 앱 안에서 task-001 full native와 task-005 fast route·metadata/activity source를 호출했다. `NET_RT_IFLIST2 sysctl=0 interfaces=29`, `getifaddrs=0`, SC/IOKit 반환 성공, fast route 28개. en0은 registry ID·물리 Wi-Fi·링크 true·주소 확인. llw0은 registry/provider 미확보로 unknown이며 full adapter의 `complete=false`. Activity tick 0은 `baselineOnly(first)`, tick 1은 약 1.05초 뒤 `partial`과 `knownPhysicalRates=18485.11/17512.21 B/s`, `representative=nil`. 즉 확인된 물리 속도는 보존하되 불완전 총합은 완전값으로 표시하지 않는다.

## 범위

프로덕션 `ApplicationCoordinator`의 여섯 축 배선과 UI는 승인된 task-007 이후 범위. 실제 외장/인터페이스 연결·해제 전환은 이 환경에서 강제로 만들지 않았고 직접 테스트의 제어 snapshot으로 검증했다. 전체 scheme의 UI test runner가 초기 기동 이후 약 3분 이상 진행하지 않아 중단(exit 75); 이어 모든 `ResourceRunnerTests`를 별도 실행해 552/552 통과했다. UI suite의 최종 실행 성공 근거는 이 task에 없다.
