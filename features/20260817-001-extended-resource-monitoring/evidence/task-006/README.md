# Task 006 실행 근거

- cwd: `/Users/zipkero/XcodeProjects/ResourceRunner`
- 기준 HEAD: `854c97d77db6b0af376560eb710c7d8928a11075` (`main`)
- 변경 원본 해시: `source-sha256.txt`; 변경 diff: `change.patch`; 환경: `environment.raw.txt`.
- `git diff --check`: exit 0, 출력 없음 (`diff-check.txt`).

## 실행 명령·결과

1. `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -destination 'platform=macOS' -only-testing:ResourceRunnerTests/DiskActivityTests -only-testing:ResourceRunnerTests/StorageMetadataTests -only-testing:ResourceRunnerTests/DiskNativeAdapterTests -derivedDataPath /tmp/ResourceRunner-M3-task006-tests CODE_SIGNING_ALLOWED=NO` → exit 0, 27/27, 실패 0 (`focused-test.log`, `focused-summary.json`).
2. `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -destination 'platform=macOS' -only-testing:ResourceRunnerTests -derivedDataPath /tmp/ResourceRunner-M3-task006-tests CODE_SIGNING_ALLOWED=NO` → exit 0, 572 unique tests 통과, 실패 0 (`unit-test.log`, `unit-summary.json`). 결과 요약의 최상위 `totalTestCount`를 사용.
3. `xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task006-release CODE_SIGNING_ALLOWED=NO` → exit 0 (`release-build.log`).
4. `xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task006-sandbox` → exit 0 (`sandbox-build.log`). 실제 app 서명·`com.apple.security.app-sandbox=true`는 `sandbox-signature.txt`, `sandbox-entitlements.plist`, `sandbox-binary-sha256.txt`에 보존.
5. `RR_DISK_PROBE=1 /tmp/ResourceRunner-M3-task006-sandbox/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner` → PID 43148, 6초 실행 뒤 종료 143, 후속 `ps`에 없음 (`sandbox-probe-process.txt`). `/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "com.zipkero.ResourceRunner" AND category == "DiskNativeProbe"'` 결과 `sandbox-disk-probe.log`, stdout `sandbox-probe-stdout.log`.
6. `git diff --check` → exit 0, 출력 없음. `shasum -a 256 -c .../source-sha256.txt` → 변경 소스 7개 모두 OK.

## 실제 Sandbox 관측

같은 서명 앱 내부에서 기존 task-002 full native와 task-006 fast Statistics·slow metadata·activity source를 읽었다. `IOServiceGetMatchingServices=0`에서 물리 `disk0` 드라이버 한 개(registry ID 4294969732)의 원시 Bytes/Operations를 확보했고, `getmntinfo`/DA를 통해 로컬 볼륨 8개와 `/` 용량·물리 관계를 확인했다. `physicalComplete=true`, `relationshipsComplete=true`, 외장 없음으로 관측됐다. fast 경로도 같은 물리 ID 하나를 읽었다. Activity tick 0은 `baselineOnly(first)`, 약 1초 뒤 tick 1은 Read/Write 189012.39/13691584.82 B/s와 드라이버 Operations 11.54/28.84 회/s였다. 실제 장치의 연결·분리나 APFS 구성 변화는 강제하지 않았고 제어 snapshot 테스트로 검증했다.

## 구현 해석·범위

같은 드라이버 ID라도 볼륨 마운트·관계 집합이 바뀌면 topology revision을 전진시켜 이전 용량 캐시를 무효화한다. 조건부 Operations가 감소하면 해당 드라이버의 IOPS만 이번 구간에서 비우고 새 Operations 기준점을 잡는다. 유효한 필수 Bytes 차분은 유지한다. DESIGN §3.2의 동일 기준점·연속성 규칙을 각 원시 카운터 계열에 적용하고, 조건부 미지원/이상이 필수 Bytes 속도를 막지 않는 조건을 유지했다. 필수 Bytes가 누락되면 `partial`과 대상별 `bytesReason`, 다른 물리 대상에서 확인된 부분 속도를 보존한다.

빠른 경로는 IOKit 드라이버 Statistics와 물리 분류만 읽고 DA·Foundation 볼륨 용량·관계 탐색은 독립 보조 경로에서 수행한다. `ApplicationCoordinator`의 production 여섯 축 배선과 UI는 task-007·008 범위다. 전체 scheme UI 테스트는 이번에 반복하지 않았고 모든 `ResourceRunnerTests`를 실행했다. 실제 외장 연결 전환은 task-014 관문이다.
