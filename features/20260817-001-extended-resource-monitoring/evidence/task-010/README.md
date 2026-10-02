# task-010 실행 근거

기준 cwd는 /Users/zipkero/XcodeProjects/ResourceRunner, 기준 HEAD는 29264987d1fd37a1b7e94380c7cce84994099afa입니다. change.patch는 worker 소유 소스와 직접 테스트만 포함합니다. main 소유 CONTEXT.md 변경은 포함하지 않습니다. 최종 소스 7개와 화면 PNG 42개는 source-sha256.txt, image-sha256.txt에 고정했습니다. git diff --check는 빈 출력으로 통과했습니다.

## 실행 명령과 결과

아래 명령은 모두 위 cwd에서 실행했습니다. 전체 출력과 xcresult 요약을 옆 파일에 보존했습니다.

    xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task010-final-focused -parallel-testing-enabled NO -only-testing:ResourceRunnerTests/NetworkDashboardViewTests -only-testing:ResourceRunnerTests/DashboardCardLayoutTests -only-testing:ResourceRunnerTests/DashboardPresentationTests -only-testing:ResourceRunnerTests/ResourceRateGraphRenderingTests -only-testing:ResourceRunnerTests/ResourceActivityPresentationTests test
    xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task010-full -parallel-testing-enabled NO -only-testing:ResourceRunnerTests test
    xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task010-release CODE_SIGNING_ALLOWED=NO build
    xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task010-probe build
    git diff --check

집중 16/16, 전체 unit 601/601, Release와 서명 Debug 빌드가 통과했습니다. 서명 Debug 앱 실행 파일은 arm64이고 App Sandbox가 켜져 있습니다(architecture.raw.txt, entitlements.raw.plist, signature.raw.txt). OS·Xcode·Swift·cwd는 environment.raw.txt, 원시 빌드·테스트 결과는 각 raw.log에 있습니다. Release의 기존 Text 연결 deprecation과 AppIntents metadata 생략 경고는 남아 있습니다.

## 실제 서명 앱 관찰

RR_NETWORK_UI_PROBE=1 RR_NETWORK_UI_PROBE_OUTPUT=1로 위 서명 Debug 앱 실행 파일을 직접 실행했습니다. 현재 소스와 같은 빌드의 PID 77408 원시 기록은 signed-ui-probe.raw.log입니다. Debug probe는 실제 StatusBarController의 NSPopover를 열고 본체 NSScrollView를 310pt 이동한 후, 카드 Button과 동일한 DashboardPresentationStore.selectCard(.network) 경계로 상세를 열었습니다. 실제 AX의 NetworkDetailClose 버튼에 AXPress를 보내 명시적으로 닫고, 같은 공통 선택 경계를 다시 두 번 호출해 재선택과 같은 카드 닫힘을 확인했습니다. selection은 network → none → network → none으로 전이했습니다.

실제 앱 AX에서 Network 카드 248×294pt, 상세 콘텐츠 400×480pt, 본체 창 306×627pt, 자식 팝오버 창 426×506pt를 확인했습니다. 카드의 AX 위치·크기는 열기 전, 스크롤 뒤, 상세 개폐 뒤에도 유지됐습니다. 본체 창 frame도 전후 동일했습니다. 실제 en0 물리 Wi-Fi의 현재 RX/TX, 원시 누적 RX/TX, IPv4/IPv6, 연결 활성과 확인된 provider 근거 및 링크 속도 미지원 이유를 확인했습니다. utun 대상은 VPN 서비스 미확인 터널로, bridge 대상은 논리 대상으로 표시됐습니다. 이 세션에서 실제 VPN 서비스를 연결·해제하지 않았습니다. 확인된 VPN 표기의 제어 fixture는 아래 렌더 시험이며 실제 전환은 task-014 소유입니다.

실제 NSHostingView를 앱 자신의 Sandbox Caches에 캡처한 다음 shell로 복사한 파일은 actual-dashboard.png, actual-network-detail.png, actual-network-detail-physical.png, actual-network-detail-tunnel.png입니다. 처음 두 화면은 요약과 상세 첫 화면, 뒤의 두 화면은 상세 내부 스크롤로 실제 en0와 utun 행을 화면 안에 놓은 결과입니다. 앱이 프로젝트 evidence 폴더로 직접 쓰려고 했을 때는 Sandbox EPERM이 발생했고, Caches 경로 저장 후 복사로 해결했습니다. 그 실패 원본은 sandbox-path-failure.raw.log에 보존했습니다.

## 상태·렌더 검증

NetworkDashboardViewTests는 설계의 12+68+32+118+48+16 = 294pt 슬롯을 직접 단언하고, 최초·정상·물리 부분 실패·활동 실패·중지·보조 실패·연결 없음·긴 수치의 카드 프레임을 라이트·다크 PNG로 재었습니다. 독일어 로케일 표본과 긴 이름을 포함한 물리 Wi-Fi·VPN·터널 세 행의 실제 텍스트 렌더는 renders/에 있습니다. 이 제어 fixture에서 물리 Wi-Fi의 대표 속도와 VPN·터널의 별도 속도를 구분하고, 큰 UInt64 원시 누적량·IPv4/IPv6·조건부 링크 속도 사유·긴 대상 이름 줄바꿈을 확인했습니다. ResourceRateGraphRenderingTests의 그래프 판 PNG도 함께 export됐습니다.

Network 카드의 수치 옆 점선/실선 범례는 그래프와 같은 ResourceRateLegendMarkerView를 씁니다. 보조 영역은 활성 확인 수와 종류, 상태 미확인 수를 구분하고, 실패·중지에서 과거 수치와 원본으로부터 경과한 시간을 제목 슬롯에 표시합니다. 그래프의 범위는 측정된 이력이 없으면 대기 상태로 남아 가짜 peak를 만들지 않습니다. 상세에는 프로세스 목록이 없습니다. 단위 모델·CPU/Memory 카드·선택·그래프 회귀는 집중/전체 suite에 포함됩니다.

## 환경 제한과 남은 관문

ResourceRunnerUITests/NetworkCardUITests.swift는 빌드됐으나 XCUITest 실행은 테스트 본문 진입 전에 Runner의 Timed out while enabling automation mode로 실패했습니다(ui-runner-failure.raw.log). OS 접근성 권한·보안 설정이나 entitlement를 바꾸지 않았습니다. 실제 앱의 팝오버·AX·프레임·닫기 버튼은 위 Debug probe로 별도 관찰했습니다. 전체 키보드/오프스크린 선택과 화면별 viewport는 task-012/013, 실제 VPN 연결 전환은 task-014 범위입니다.
