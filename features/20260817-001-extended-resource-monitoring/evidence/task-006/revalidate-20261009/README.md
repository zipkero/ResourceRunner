# task-006 Disk 활동·용량 캐시 재검증 (2026-10-09)

기준 HEAD는 `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`입니다. 현재 `DiskNativeAdapter.swift`의 important-usage 용량 읽기, `StorageMetadata.swift`의 조회 시각·마지막 성공 캐시, `DiskActivity.swift`의 실제 읽기 시각 차분을 함께 확인했습니다. 제품 소스는 수정하지 않았고, `StorageMetadataTests.swift`에 현재 승인 계약의 경계 테스트 하나를 추가했습니다. 다른 Task의 미커밋 변경은 보존했습니다. [소스 SHA-256](./source-sha256.txt), [테스트 patch](./test-change.patch), [환경](./environment.txt), [diff 검사](./diff-check.txt)를 남겼습니다.

## 결정적 검증

아래 명령을 프로젝트 루트에서 실행했습니다. [집중 로그](./focused-test.log)와 [xcresult 요약](./focused-summary.json)은 **31/31 통과, 실패·skip 0**입니다. 원본 결과 번들은 `/tmp/ResourceRunner-M3-task006-revalidate-20261009/Logs/Test/Test-ResourceRunner-2026.10.09_12-24-55-+0900.xcresult`에 있습니다.

```sh
xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -destination 'platform=macOS,arch=arm64' -only-testing:ResourceRunnerTests/DiskActivityTests -only-testing:ResourceRunnerTests/StorageMetadataTests -only-testing:ResourceRunnerTests/DiskNativeAdapterTests -derivedDataPath /tmp/ResourceRunner-M3-task006-revalidate-20261009 CODE_SIGNING_ALLOWED=NO
```

새 테스트 `capacityRefreshFailureAndVolumeReplacementPreserveCacheLifetime`는 동일한 볼륨 정체성과 마운트에서 important-usage에 대응하는 `availableBytes`가 400→450으로 갱신돼도 topology revision은 유지되고 사용 중은 `1000−450=550`으로 다시 계산되는지 확인합니다. 다음 조회가 실패하면 현재 상태는 실패이고 마지막 성공 용량·`readAt`은 두 번째 성공값 그대로입니다. 같은 `/` 경로가 `volume-a`에서 `volume-b`로 교체되면 revision이 전진하고, 새 snapshot을 저장하기 전 관계 캐시는 빈 값이며 저장 후 새 볼륨의 300 값만 노출합니다. 기존 같은 suite는 다대다 APFS 관계·마운트 변화·느린 storage 중 빠른 Disk 진행·늦은 결과 폐기를, `DiskNativeAdapterTests`는 important-usage 누락·잘못된 값의 오류와 fallback 부재를 확인합니다. `DiskActivityTests`는 Bytes/Operations 실제 시간 차분·물리 장치 단일 집계·기준점/실패/장치 수명과 유효점만 담는 이력, 짧은 실패 segment를 확인합니다. 현재 이력 구현은 M4 승인 변경에 따른 **1203개 링·600초 선별**이며 집중 테스트에 0.5초 간격 끝점 검증이 포함됩니다. [M4 task-003](../../../../20261003-001-app-preferences/evidence/task-003/README.md)과 [M4 task-005](../../../../20261003-001-app-preferences/evidence/task-005/README.md)의 일정·표시 보존 근거도 현재 계약으로 인수했습니다.

## 실제 Sandbox 읽기

기존 task-002의 격리 사본을 `/tmp/rr-task006-probe`에 복사하고 [진단 `AppDelegate.swift`](./probe-AppDelegate.swift)의 `--task006-disk-probe` 분기만 추가했습니다. [진단 project](./probe-project.pbxproj)의 별도 bundle ID는 `com.zipkero.ResourceRunner.Task006Probe`입니다. `DiskNativeAdapter.swift`, `DiskActivity.swift`, `StorageMetadata.swift`, `DiskTopology.swift`, `ResourceQuantityFormatter.swift`, `PrivacyInfo.xcprivacy`는 현재 프로젝트와 byte-for-byte 일치합니다([SHA-256](./source-sha256.txt)). 다음 명령을 `/tmp/rr-task006-probe`에서 실행했습니다.

```sh
xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/rr-task006-probe/DerivedData build CODE_SIGNING_ALLOWED=YES
/tmp/rr-task006-probe/DerivedData/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner --task006-disk-probe
```

[빌드 로그](./sandbox-build.log)는 성공했고 `codesign --verify --deep --strict --verbose=2`도 통과했습니다([서명](./sandbox-signature.txt), [entitlements](./sandbox-entitlements.plist)). 앱 Sandbox는 true이며 임시 예외가 없습니다. [PrivacyInfo](./privacy-result.txt)에 DiskSpace `85F4.1`이 있습니다. 설치된 `/Users/zipkero/Applications/ResourceRunner.app`와 실행 중인 PID 64258은 수정·재시작하지 않았습니다.

[실측 로그](./native.log)의 UTC `03:25:46`, PID 45599에서 물리 driver ID `4294969732` 한 개와 로컬 볼륨 8개, 완료된 관계, 외장 없음이 관측됐습니다. `/`는 `uuid:F8964231-DC64-47CF-9322-32B3B00CDC3F|bsd:disk3s1s1`, 전체 `994662584320`, important-usage 사용 가능 `839646476969`, 사용 중 `155016107351` bytes였습니다. 캐시의 볼륨 정체성과 `readAt`은 해당 저장소 조회와 일치합니다. 별도의 raw Foundation 재조회는 약 1초 뒤 important-usage `839646427817`로 변해 용량의 시간 가변성도 드러났습니다. 서로 다른 시각의 두 값을 동일해야 한다고 비교하지 않았습니다. task-002 [같은 adapter의 Sandbox 원자료](../../task-002/revalidate-20261009/README.md)는 동일 시점의 raw 값과 저장값 일치를 이미 확인했습니다.

활동 tick 0은 `.baselineOnly(.first)`였고 tick 1은 `.rate`, 물리 합계 Read `50279.80`, Write `491194.99` B/s 및 Read `12.2753`, Write `8.4983` operations/s였습니다. 원시 드라이버 누적량 차이는 Read `53248`, Write `520192` bytes, Operations `13`/`9`회이고 실제 두 `readAt` 사이 약 `1.05903`초로 나눈 값과 일치합니다. 두 tick의 topology revision·rate segment는 각각 `1`로 유지됐습니다. 원본 누적량은 앱 시작 시 0으로 재설정하지 않았습니다.

전체 unit·Release build는 이 재검증에서 다시 실행하지 않았습니다. 현재 코드에 대응하는 Disk 집중31개와 서명 Debug 실제 수집을 확인했고, 이전 전체 빌드·통합 검증은 [기존 task-006](../README.md), [M4 Disk 승인](../../../../20261003-001-app-preferences/evidence/disk-capacity-20261004/README.md), [M4 task-010](../../../../20261003-001-app-preferences/evidence/task-010/README.md)에서 영향 범위를 구분해 인수합니다. 실제 외장 연결·제거는 현재 SPEC §4의 사용자 제외 범위입니다. Task 승인·상태 변경은 main과 독립 verifier가 담당합니다.
