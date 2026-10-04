<!-- prowl-workflow: v1 verify -->
1. Status: `approved` — 읽기 전용 독립 판정 후보
2. Target: `task-008: 표시 조합의 포커스·단축키·현재 앵커`
3. Validation:
   - Criterion: 포커스 복귀의 원래 카드 → 남은 첫 카드 → 전체 숨김 설정 버튼 순서와 stale generation·revision·대상 거부.
     - Source: [implement.md](/Users/zipkero/XcodeProjects/ResourceRunner/features/20261003-001-app-preferences/implement.md:87), [DashboardPresentationStore.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/DashboardPresentationStore.swift:54), [DashboardView.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/DashboardView.swift:185)
     - Evidence: 단위 `focusReturnTargetUsesCurrentVisibilityAndRejectsReorderedIntent` 통과. UI에서 선택한 Memory 제거 후 CPU로 복귀해 Return·Space로 활성화됨을 확인. 전체 숨김 설정 버튼은 UI 존재와 단위 대상 선택, 소스의 포커스 연결로 확인.
     - Result: `충족`
   - Criterion: 고정 ⌘1~⌘4, 숨긴 카드 무동작, Return·Space의 단일 활성화, key 설정창 포커스 보호.
     - Source: [design.md](/Users/zipkero/XcodeProjects/ResourceRunner/features/20261003-001-app-preferences/design.md:315), [DashboardView.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/DashboardView.swift:39), [StatusBarController.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/StatusBarController.swift:58)
     - Evidence: signed UI에서 숨긴 Disk·Memory·CPU 단축키 무동작과 Return·Space 활성화를 확인. `focusReturnAllowsOwnedWindowsButRejectsKeySettingsWindow` 단위 통과. 실제 설정창을 key로 둔 UI 검증은 계약대로 task-009 범위.
     - Result: `충족`
   - Criterion: 현재 마지막 카드 앵커와 revision·capture order·weak view identity에 따른 stale 등록·제거 거부.
     - Source: [DashboardViewport.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/DashboardViewport.swift:74)
     - Evidence: `currentLastCardRejectsOldRevisionOlderViewAndStaleRemoval` 단위 통과. UI에서 Memory·Network·Disk가 각각 마지막 카드인 조합의 상세 위치를 확인.
     - Result: `충족`
   - Criterion: Memory TOP 5 표시·숨김, 마지막·위쪽·숨김 위치에 맞는 높이 보정과 기본 Disk 결과 보존.
     - Source: [DashboardViewport.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/DashboardViewport.swift:17), [DashboardViewportTests.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunnerTests/DashboardViewportTests.swift:73)
     - Evidence: 높이 보정·실제 NSView 좌표 단위 통과. UI의 Memory 마지막 본체 높이는 TOP 5 off 96pt, on 185pt였고 Network 마지막 303pt, 기본 Disk 마지막 668pt였다.
     - Result: `충족`
   - Criterion: 무효 앵커 상세 닫기, chrome·8pt 여유·최대 400×480pt·frame 보정, 본체 크기·상세 스크롤·기본 글꼴과 무스크롤 배치 보존.
     - Source: [DashboardViewport.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/DashboardViewport.swift:25), [StatusBarController.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/StatusBarController.swift:193), [design.md](/Users/zipkero/XcodeProjects/ResourceRunner/features/20261003-001-app-preferences/design.md:324)
     - Evidence: 무효 앵커 닫기·729pt 가상 visible frame·chrome 단위 통과. 실제 1728×1084pt 화면의 네 조합 모두 상세 400×480pt와 8pt 경계 안에 있고, 상세 개방 전후 본체 frame이 같았다. 기존 상세·확장·선택 UI 13건과 카드 높이·기본 요약 단위 회귀도 통과.
     - Result: `충족`
   - Criterion: 변경과 실행 근거의 현재 코드 대응.
     - Source: [changes.patch](/Users/zipkero/XcodeProjects/ResourceRunner/features/20261003-001-app-preferences/evidence/task-008/changes.patch), [source-sha256.txt](/Users/zipkero/XcodeProjects/ResourceRunner/features/20261003-001-app-preferences/evidence/task-008/source-sha256.txt)
     - Evidence: HEAD `b8a83973efd29905d3d9e2406b2fb63ad6f7bedd`, 7파일 해시 일치, 패치 역적용 검사와 `git diff --check` 통과. 원본 xcresult를 직접 조회해 signed 단위 46/46·6 suite, UI 17/17, 실패·skip 0을 확인.
     - Result: `충족`
4. Completed requirements: 없음
6. Explanation: task-008의 현재 계약은 충족합니다. 729pt 작은 화면은 단위 계산 근거이며 실제 화면 검증은 1084pt 높이에서 수행됐습니다. 실제 key 설정창과 전체 설정 동작은 task-009, 통합·로그인 관문은 task-010~011에 남아 있어 이번 승인으로 완료되는 SPEC 조건은 없습니다.