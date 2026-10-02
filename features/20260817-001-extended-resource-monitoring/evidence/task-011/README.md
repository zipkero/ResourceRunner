# task-011 실행 근거

기준 작업 디렉터리: `/Users/zipkero/XcodeProjects/ResourceRunner`  
기준 HEAD: `331bdc5ea002c53f4d313c5551f46e6cd0666f76` (`main`).  
승인 문서와 `CONTEXT.md`는 수정하지 않았습니다. 관련 변경 전체는 `changes.patch`, 최종 파일·실행 이진 파일 해시는 `source-binary-sha256.txt`에 있습니다. `head.txt`의 `CONTEXT.md` 수정은 main 소유의 동시 변경이며 이 patch에서 제외했습니다.

## 실행 결과

- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -derivedDataPath /tmp/ResourceRunner-M3-task011-tests -only-testing:ResourceRunnerTests test` — **605/605 통과**, 0 실패. 원시 로그 `all-unit.log`, xcresult 요약 `all-unit-summary.json`; 최종 4개 Disk 직접 테스트를 포함합니다. 해당 최종 xcresult: `/tmp/ResourceRunner-M3-task011-tests/Logs/Test/Test-ResourceRunner-2026.10.02_17-39-16-+0900.xcresult`. 카드 상태·최장 UInt64·de_DE 로케일 248×294 렌더와 볼륨/외장/마운트/조건부 IOPS 상세 렌더 21장을 `renders/`에 내보냈습니다(`manifest.json`).
- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -derivedDataPath /tmp/ResourceRunner-M3-task011-release CODE_SIGNING_ALLOWED=NO build` — **BUILD SUCCEEDED**, `release-build.log`.
- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -derivedDataPath /tmp/ResourceRunner-M3-task011-probe build` — **BUILD SUCCEEDED**, `signed-debug-build.log`. Sign to Run Locally, `com.apple.security.app-sandbox=true`는 `environment.txt`·`entitlements.txt`에 기록했습니다. 최종 production 파일은 이 빌드 후 수정하지 않았습니다. 이후 직접 테스트 fixture의 과거 용량 표시만 보강하고 전체 unit을 다시 실행했습니다.
- `RR_DISK_UI_PROBE=1 RR_DISK_PROBE=1 /tmp/ResourceRunner-M3-task011-probe/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner` — 서명된 실제 앱 **PID 10787**, macOS 26.6.2/arm64. `actual/signed-sandbox-pid10787.log`에 native 반환코드와 원시 driver/volume 관계, 실제 카드·상세 AX·프레임·명시 닫기 기록이 있습니다. 앱 컨테이너 Caches에 저장한 실제 NSWindow 캡처를 셸에서 `actual/`로 복사했습니다. PNG 크기와 해시는 `png-inspection.log`, `actual-png-sha256.txt`에 있습니다.
- `git diff --check` — 통과. `changes.patch`는 위 HEAD에 대한 관련 수정 및 새 파일 전체를 포함합니다.

## 실제 UI 대조

Native `IOServiceGetMatchingServices=0`으로 물리 driver 1개와 IOBlockStorageDriver Statistics 누적 바이트·Operations를 읽었고, `getmntinfo=success`/`DASessionCreate=success`로 볼륨 8개와 관계 완전·외장 없음이 반환됐습니다. 실제 `/` APFS의 전체 994,662,584,320 B·사용 가능 833,332,527,104 B가 카드의 926.4 GB·776.1 GB와 대응합니다. 여러 APFS 볼륨에서 같은 전체/사용 가능 공간을 공유하므로 볼륨별 사용 중은 `전체 − 사용 가능`이라고 설명하고 합산 용량은 만들지 않습니다. `actual-disk-detail-top.png`와 `actual-disk-detail-devices.png`에는 이 설명, 외장 장치 없음, disk0의 현재 Read/Write·원시 누적 Read/Write·드라이버 IOPS 회/s가 보입니다. `actual-disk-dashboard.png`의 카드에는 용량 상태와 원본 경과 `5초 전`이 그래프 범위와 함께 잘리지 않고 표시됩니다.

실제 AX에서 DiskCard 248×294, DiskDetail 400×480, 본체 창 306×627, 상세 자식 창 426×506을 확인했습니다. 공통 `selectCard(.disk)` 뒤 AX `DiskDetailClose`의 `AXPress` 반환코드 0으로 `.none`에 복귀했고, 재선택과 같은 카드 재선택 해제 뒤에도 본체 프레임이 306×627이었습니다. `DiskSummary` AX에 활동과 용량 각각의 원본 경과, APFS 정의, 외장 없음이 들어 있으며 물리 장치 행 AX에 원시 누적과 IOPS가 있습니다.

`DiskCardUITests` 소스도 추가했습니다. XCUITest는 이전 task-010에서 앱 automation mode 초기화 시간 초과로 테스트 본문에 진입하지 못한 환경입니다. 이번에 1회 시도했으나 runner가 `Running tests...` 이후 본문에 진입하지 않아 중단했고, `ui-runner-attempt.log`를 남겼습니다. 이를 성공 근거로 쓰지 않았으며 위 서명 앱 자체 probe의 실제 NSWindow/AX/PNG 관찰을 사용했습니다. 실제 외장 연결·분리는 task-014 범위이고, 현재 하드웨어에서는 외장 없음만 관찰했습니다. 전체 키보드·AX 도달 및 네 카드 viewport는 task-012/013에 남습니다.

이전 거절 후보에서는 극단적인 `UInt64.max` 두 용량(각 16,777,216.0 TB)을 함께 넣은 카드 fixture의 248pt 첫 보조행 숫자가 말줄임됐습니다. 이때도 294pt 슬롯과 상태/원본 경과, 상세 행·AX의 전체 값은 유지됩니다. 실제 926.4/776.1 GB 및 로케일 fixture의 일반 범위는 카드에서 읽힙니다. 이 기록은 아래 재시도 전의 거절 근거이며 현재 승인 근거가 아닙니다.

## DESIGN §3.3 보완 후 재시도 — 현재 후보

main이 적용한 DESIGN §3.3에 따라 **같은 단위이면 단위를 끝에서 공유**하고 `전체 <숫자>·가용 <숫자> <단위>`, 다르면 각 값의 단위를 보존합니다. 숫자는 기존 `ResourceQuantityFormatter.bytes` 결과를 그대로 분리·재조립하므로 1024 기반 선택, 소수 한 자리, 반올림, 그룹 구분, 로케일이 바뀌지 않습니다. 첫 14pt 보조행만 간결한 라벨을 쓰며 상세·카드/상세 AX는 전체 `사용 가능` 라벨과 각 단위를 유지합니다. 카드 AX는 뷰의 `locale`을 모델 서식 함수에 전달합니다. 두 번째 14pt 보조행의 상태·과거 여부·원본 경과·그래프 범위, 32pt 보조 영역·294pt 카드·그래프/글꼴은 그대로입니다.

최종 재시도 기준 HEAD는 여전히 `331bdc5ea002c53f4d313c5551f46e6cd0666f76`, cwd는 `/Users/zipkero/XcodeProjects/ResourceRunner`입니다. 최종 관련 diff는 `retry/changes.patch`, source 및 서명 Debug 실행 dylib 해시는 `retry/source-binary-sha256.txt`입니다. main 소유 `design.md`·feature `README.md`·`implement.md`·`CONTEXT.md` 변경은 이 patch에 포함하지 않았습니다.

- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -derivedDataPath /tmp/ResourceRunner-M3-task011-retry-tests -only-testing:ResourceRunnerTests/DiskDashboardViewTests test` — 직접 테스트 **5/5 통과**(`retry/focused.log`). 같은 단위 최대 UInt64, 다른 단위 TB/GB, 단위 경계, 0, 작은 양수 × `en_US/de_DE/ko_KR/gez_ER/my_MM` 25개를 실제 SwiftUI 248×294로 렌더했습니다. 11pt label 역할의 원문 문자열 폭이 모두 232pt보다 작다고 단언했고, 최댓값 두 숫자가 실제 PNG에서도 말줄임 없이 보입니다. `retry-renders/manifest.json`이 렌더와 fixture의 대응을 담습니다. 예: en_US 최대값 `E33340A7-F705-4EE9-B21F-F73D6608FA85.png`, gez_ER `8BE9B937-02C5-4752-8801-9B246E1BE74B.png`, my_MM `71E2A942-197C-4119-9F26-CEA8B94CDFB6.png`.
- 같은 derived data에서 `-only-testing:ResourceRunnerTests test` — 전체 unit **606/606 통과**, 0 실패(`retry/all-unit.log`, `retry/all-unit-summary.json`). 최종 xcresult `/tmp/ResourceRunner-M3-task011-retry-tests/Logs/Test/Test-ResourceRunner-2026.10.02_23-54-01-+0900.xcresult`.
- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -derivedDataPath /tmp/ResourceRunner-M3-task011-retry-release CODE_SIGNING_ALLOWED=NO build` — **BUILD SUCCEEDED** (`retry/release-build.log`).
- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -derivedDataPath /tmp/ResourceRunner-M3-task011-retry-probe build` — **BUILD SUCCEEDED**, Sandbox entitlement 유지(`retry/signed-debug-build.log`, `retry/entitlements.txt`).
- `RR_DISK_UI_PROBE=1 RR_DISK_PROBE=1 /tmp/ResourceRunner-M3-task011-retry-probe/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner` — 실제 서명 Sandbox 앱 **PID 73723**. 최종 바이너리와 원본 해시는 `retry/source-binary-sha256.txt`, OS·아키텍처는 `retry/environment.txt`. 원시 native 반환/볼륨 관계·Disk AX·프레임·닫기 반환은 `retry/actual/signed-sandbox-pid73723.log`, 실제 NSWindow 캡처 세 장은 `retry/actual/`입니다. 카드 첫 행은 실제 `/`의 `전체 926.4·가용 775.7 GB`, 둘째 행은 `용량 확인 · 5초 전`과 범위를 온전히 보여줍니다. 상세 AX의 전체 라벨·APFS 사용 중 정의·외장 없음, 물리 disk0 현재/원시누적/IOPS, 카드248×294·상세400×480·본문306×627 및 AXPress닫기/재선택도 유지됩니다.
- `git diff --check` — 통과. XCUITest runner의 기존 automation 초기화 제한은 재시도에서 반복 실행하지 않았고, 실제 서명 앱 관찰을 UI 근거로 유지합니다. 실제 외장 전환은 task-014 범위입니다.
