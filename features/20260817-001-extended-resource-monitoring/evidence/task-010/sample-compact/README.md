# task-010 승인 축소 샘플 구현 근거

- 기준 cwd: `/Users/zipkero/XcodeProjects/ResourceRunner`; HEAD: `e63e5151579c183267613c22e3b49bea7cc6c506`; 날짜: 2026-10-03 KST. `change.patch`는 worker 소유 코드·테스트 변경만 포함한다. 같은 작업 트리의 `CONTEXT.md`와 feature 원본문서 변경은 main 소유이며 보존했다. 기존 `evidence/task-010/compact/`는 철회된 160pt 후보의 이력이다.
- 구현: Network 요약 101pt, padding 6pt, 제목 8pt 슬롯, 두 속도 22pt 행·2pt 간격, 활성/보조 상태 27pt 슬롯. 요약 그래프와 전용 범례·범위·수집 진행 및 하단 조회 경과 안내를 제거했다. 현재 부모 폭 248pt와 최종 예정 카드 폭 264pt에 모두 유연하게 맞는다. 숫자·단위 formatter는 변경하지 않고, 거대 속도에서 숫자만 슬롯 안에서 축소한다. 상세·AX·선택/닫힘과 기존 Disk 294pt 슬롯은 유지했다.

## 실행

- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -derivedDataPath /tmp/ResourceRunner-M3-task010sample-tests -only-testing:ResourceRunnerTests/NetworkDashboardViewTests -only-testing:ResourceRunnerTests/DiskDashboardViewTests test`: 9/9 통과. `logs/task010sample-focused-final.log`, `logs/focused-summary.json`.
- 같은 cwd·project·scheme·DerivedData에서 `-only-testing:ResourceRunnerTests test`: 606/606 통과. `logs/task010sample-full-unit.log`, `logs/full-summary.json`.
- 이후 production 수정 없이 활성 종류 8개와 보조 실패가 겹치는 직접 렌더 fixture만 추가했다. 같은 경로의 `-only-testing:ResourceRunnerTests/NetworkDashboardViewTests test`: 4/4 통과 (`logs/task010sample-overlap-check.log`). 248pt·264pt 라이트/다크 네 PNG에서 활성 종류·수와 보조 실패가 보조 슬롯 안에 읽히고 속도 행이나 카드 바깥과 겹치지 않는다.
- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -derivedDataPath /tmp/ResourceRunner-M3-task010sample-release build`: 성공. `logs/task010sample-release.log`.
- `xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -derivedDataPath /tmp/ResourceRunner-M3-task010sample-probe build`: 성공·서명 확인. `logs/task010sample-signed-build.log`, `logs/codesign.stderr.log`.
- `RR_NETWORK_UI_PROBE=1 RR_NETWORK_UI_PROBE_OUTPUT=1 /tmp/ResourceRunner-M3-task010sample-probe/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner`: 실제 서명 Sandbox 앱 PID 16205. `logs/task010sample-actual-probe.log`. 본체 306×627, Network AX 카드 248×101, 상세 426×506. 물리 일부합계 RX/TX, en0의 원시 누적·IPv4/IPv6·조건부 링크 사유, utun 터널 상세, AXPress 닫기 성공·같은 카드 재선택 닫기, 개폐 전후 본체/카드 frame 불변을 확인했다. 실제 캡처 4장은 앱 컨테이너 Caches에서 `actual/`로 복사했다. `actual-dashboard.png`에서 Network 그래프/하단 조회 경과가 없고, 기존 Disk 294pt 그래프는 남아 있다. 실제 VPN 전환은 task-014 범위다.
- `git diff --check`: 통과(빈 `logs/diff-check.log`). 소스·Debug/Release 실행 파일 해시는 `source-binary-hashes.txt`, PNG 해시는 `png-hashes.txt`, OS·장치 정보는 `logs/os-version.log`와 XCTest summary에 있다. 변경 뒤 production 소스 재수정 없이 빌드·probe를 실행했다.

## 표시 확인과 한계

- `renders/`에는 XCTest가 렌더한 248×101·264×101 라이트/다크 상태별 카드, UInt64.max 대응 속도의 en_US·gez_ER·my_MM·ko_KR·fr_FR, 작은 양수·단위 경계와 상세/기존 Disk 회귀 첨부물 62장을 이름대로 보존했다. 예: `network-card-248-long-en_US-light.png`, `network-card-248-long-gez_ER-light.png`, `network-card-264-long-my_MM-light.png`, `network-card-248-many-kinds-aux-failure-light.png`. 두 방향 이름·전체 그룹 숫자·소수 한 자리·GB/s가 함께 보이고 말줄임은 없다. `manifest-map.tsv`는 처음 58장과 xcresult 첨부물 원본의 대응이며 마지막 네 장의 원본 UUID는 `logs/task010sample-overlap-check.log`의 xcresult 안에 있다.
- 활동·보조 정보의 별도 원본 시각, 세부 실패 이유, 물리/VPN/터널 구분은 기존 상세·AX에 남겼다. 264pt 실제 부모 배선·네 카드 동시 표시·화면/chrome는 승인된 task-012 관문이다. XCUITest runner는 이전 task-010에서 automation mode 진입 전에 timeout이 있었으므로 재시도하지 않았고, 이번 실제 앱의 NSWindow/AX/선택 경로를 DEBUG probe로 관찰했다.
