# 실제 설치 앱 반영 — 2026-10-09

task016 독립 승인 뒤 main이 최종 원본 Release를 `/Users/zipkero/Applications/ResourceRunner.app`에 반영했습니다. 이전 앱은 `/tmp/rr-m4-016-installed-backup/ResourceRunner.app`에 백업하고 PID64258을 SIGTERM으로 종료했습니다. `ditto`로 기존 앱 디렉터리에 덮어써 등록 경로와 디렉터리 inode43094210을 유지했습니다. Sandbox/global 일반 설정의 `preferences.v1`은 설치 전후 모두 없으며 보존됐습니다. 그 외 설정이나 로그인 등록 함수는 변경하지 않았습니다.

- 설치 실행파일 SHA `be4f5ce7ac7550cd8f205d5e1e598f68784992b99e7ab010a46ef8e0b6066e3f`, CDHash `37ccc4acddeeac1655e03fe9b526de61ac280498`, arm64/ad hoc/App Sandbox/LSUIElement, strict codesign 통과. 원본100제품·단위파일의 검증 시점 SHA는 반영 후에도 일치합니다.
- 같은 고유 DEBUG UI runner의 `ResourceRunner_installed_readonly_task016.xctestrun`에서 `RR_RELEASE_APP_PATH`를 실제 설치 경로로 지정하고 `RR_EXPECT_DEFAULT_PREFERENCES=1`, `RR_EXPECT_NATIVE_LOGIN_ENABLED=1`을 사용했습니다. `RR_NATIVE_RELEASE_APP_PATH`와 고유 저장값 기대 env는 제거했습니다. cwd `/tmp/rr-m4-016-isolated`, `xcodebuild test-without-building -xctestrun /tmp/rr-m4-016-unique-dd/Build/Products/ResourceRunner_installed_readonly_task016.xctestrun -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:ResourceRunnerUITests/SettingsWindowUITests/testReleaseBuildRightClickOpensSingleSettingsWindow -resultBundlePath /tmp/rr-m4-016-installed-readonly.xcresult`: **1/1, 실패·skip0**.
- 실제 AX는 시스템 포함0·상세20개·자동닫기1입니다. 최초 설정창 비자동 열림, 메뉴바 우클릭의 단일 설정창, 로그인 토글1 및 native 상태의 “허용” 문구, 닫기까지 단언했습니다. `readonly-ui.log`와 원시 xcresult/summary가 근거이며 실제 register/unregister·로그아웃·재부팅은 수행하지 않았습니다.
- 최종 PID59351은 실제 설치 경로의 새 Release로 실행 중입니다. 검사 뒤 설정창은 닫혔고 Amphetamine PID64228은 유지됩니다. 이 반영은 수동 재실행 검증이며, 새 바이너리의 다음 로그인을 다시 시험한 것으로 확대하지 않습니다. 실제 다음 로그인 근거는 기존 task011 이력입니다.

`before.json`/`after.json`은 경로·inode·실행파일·일반 설정 보존의 읽기 전용 점검입니다. 초기 task016 근거에서 “설치 PID64258 보존”은 설치 전 검증 시점 이력이며, 현재 실행은 위 PID59351입니다.
