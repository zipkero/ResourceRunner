# task-002 Disk native adapter 재검증 (2026-10-09)

기준 HEAD는 `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`입니다. 현재 `DiskNativeAdapter.swift`, `ResourceQuantityFormatter.swift`, `PrivacyInfo.xcprivacy`, `DiskNativeAdapterTests.swift`는 2026-10-04 승인된 [Disk 용량 수정 근거](../../../../20261003-001-app-preferences/evidence/disk-capacity-20261004/README.md)의 SHA-256과 각각 일치합니다. 제품 소스 수정은 없습니다. 다른 Task의 미커밋 변경은 유지했습니다.

## 같은 native adapter의 Sandbox 재실행

`/tmp/rr-task014-probe`의 기존 전체 소스 사본을 `/tmp/rr-task002-probe`에 복사했습니다. `DiskNativeAdapter.swift`, `ResourceQuantityFormatter.swift`, `PrivacyInfo.xcprivacy`는 현재 프로젝트와 byte-for-byte 동일합니다([SHA-256](./source-sha256.txt)). 진단 전용 `AppDelegate.swift`는 [보존본](./probe-AppDelegate.swift)에 보이는 `--task002-disk-probe` 분기에서 **제품의 `DiskNativeAdapter().read()`**를 직접 실행한 뒤 raw Foundation 키와 결과를 출력하고 종료합니다. [진단 project](./probe-project.pbxproj)의 별도 bundle ID는 `com.zipkero.ResourceRunner.Task002Probe`입니다. 기존 설치 앱 `/Users/zipkero/Applications/ResourceRunner.app`와 PID 64258은 수정하거나 종료하지 않았습니다.

실행 명령과 cwd는 [build-result.txt](./build-result.txt) 및 아래와 같습니다. 서명 검증은 `codesign --verify --deep --strict --verbose=2 /tmp/rr-task002-probe/DerivedData/Build/Products/Debug/ResourceRunner.app` 성공입니다. [환경](./environment.txt)에 macOS 26.6.2, arm64, Xcode 26.6, 서명·번들 파일을 기록했습니다. [entitlements](./entitlements.plist)는 app-sandbox=true, user-selected.read-only=true, get-task-allow=true이며 추가 temporary exception이 없습니다. 앱 번들 PrivacyInfo에는 DiskSpace `85F4.1`이 있고 Helper/XPC/appex는 없습니다.

```sh
cd /tmp/rr-task002-probe
xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/rr-task002-probe/DerivedData build CODE_SIGNING_ALLOWED=YES
/tmp/rr-task002-probe/DerivedData/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner --task002-disk-probe
```

[native.log](./native.log)의 `2026-10-09T03:19:50Z` / PID 37363 결과: `IOServiceGetMatchingServices=0`, DASession/getmntinfo 성공, 물리 driver 1개·Disk 볼륨 8개, `physicalComplete=true`, `relationshipsComplete=true`. 물리 `disk0` / registry ID `4294969732`의 Read `1291048194048`, Write `6337687785472` bytes와 두 Operations가 확보됐습니다. 내부 판정은 `DA DeviceInternal=true`, removable/ejectable은 각각 false입니다. `/`와 Data는 BSD 정체성을 따로 유지하면서 같은 공유 APFS 용량을 합산하지 않습니다. 네트워크 파일 시스템은 `mountedDiskURLs()`의 `/dev/disk` 범위에서 제외됩니다.

같은 시각 `/` raw Foundation 값은 total `994662584320`, 일반 rawAvailable `828039884800`, **importantAvailable `840213850793`**입니다. adapter의 system total/available은 정확히 `994662584320`/`840213850793`, used는 차이 `154448733527`입니다. 전용 1000 formatter는 각각 `994.7 GB`/`840.2 GB`/`154.4 GB`로 표시했습니다. 시각에 따라 가용량은 변하므로 이전 UI 관찰값과 절대값 일치는 요구하지 않습니다. 실제 공유 APFS 볼륨 중 일부는 OS가 important-usage available `0`을 반환하며 adapter가 그 raw 값을 그대로 보존했습니다.

## 결정적 경계 및 인수 근거

- [DiskNativeAdapterTests.swift](../../../../../ResourceRunnerTests/DiskNativeAdapterTests.swift)는 필수 키 누락·타입 오류·음수·전체 초과·0 total을 오류로 처리하고, 중복 드라이버·마운트, 다대다/미확인 관계, 외장 판정과 선택적 Operations를 검증합니다. 현재 테스트 소스 SHA가 승인 당시와 같고 [기존 unit.log](../../../../20261003-001-app-preferences/evidence/disk-capacity-20261004/unit.log)의 관련 48/48·DiskNativeAdapter suite 성공을 인수했습니다. 이 Task에서 suite를 재실행하지 않았습니다.
- 같은 승인 근거의 [Sandbox UI 로그](../../../../20261003-001-app-preferences/evidence/disk-capacity-20261004/ui.log)는 signed app에서 raw total `994662584320`·importantAvailable `818551316339`, 카드 `994.7 GB`/`818.6 GB`, 상세의 회수 가능 설명을 확인했고 1/1 성공했습니다. [M4 task-010](../../../../20261003-001-app-preferences/evidence/task-010/README.md)은 현재 Disk 소스 SHA와 UI/수집 통합 대응을 기록합니다.
- 이전 [task-002 native 로그](../sandbox-disk-probe.log)의 물리 장치·관계·서명 범위는 재사용하지만, 당시 용량은 이전 정의이므로 현재 important-usage 근거로 사용하지 않습니다.

실제 외장 장치 연결·제거는 SPEC §4의 제외 범위입니다. 이 재검증은 현재 물리 관계와 외장 판정 정책을 확인했으며 실제 외장 전환 성공은 주장하지 않습니다. Task 상태·승인 판정은 main과 독립 verifier가 담당합니다.
