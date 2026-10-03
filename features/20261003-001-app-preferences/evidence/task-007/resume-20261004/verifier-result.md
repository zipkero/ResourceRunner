<!-- prowl-workflow: v1 verify -->
1. Status: `approved` 후보
2. Target: task-007: 카드·TOP 5 숨김과 자연 높이·선택 정리
3. Validation:
   - Criterion: 네 카드와 두 TOP 5의 독립 표시, 고정 순서, 숨긴 영역의 높이·AX 제거. Source: [implement.md](/Users/zipkero/XcodeProjects/ResourceRunner/features/20261003-001-app-preferences/implement.md), [design.md](/Users/zipkero/XcodeProjects/ResourceRunner/features/20261003-001-app-preferences/design.md). Evidence: 조건부 렌더링 원본, 64개 렌더 조합, 실제 UI 숨김·재표시 및 전체 숨김 검사. Result: `충족`
   - Criterion: 대표값·그래프·Memory 구성·상세와 기본 글꼴·간격·무스크롤 배치 보존. Source: task-007 검증 조건. Evidence: 원본 대조와 카드 높이·접근성·통합 요약 단위 검증. Result: `충족`
   - Criterion: 선택 카드 숨김, 숨긴 카드 진입 차단, 늦은 닫힘 방어. Source: task-007 검증 조건. Evidence: [DashboardPresentationStore.swift](/Users/zipkero/XcodeProjects/ResourceRunner/ResourceRunner/DashboardPresentationStore.swift)와 세대값 단위 검증, 실제 UI 상세 숨김 검사. Result: `충족`
   - Criterion: 전체 숨김 설명과 접근 가능한 설정 callback. Source: task-007 및 DESIGN §3.2. Evidence: 실제 UI에서 버튼의 이름·클릭 가능 상태·프레임과 카드 AX 부재 확인, callback 단위 검증. Result: `충족`
   - Criterion: 현재 소스에 대응하는 실행 근거. Source: [acceptance.md](/Users/zipkero/.codex/skills/verify/references/acceptance.md). Evidence: HEAD `cac4ca981caa94d09dcf3c3ff8b2a3857d69751a`, 10파일 SHA 일치, 새 파일을 포함한 patch 역적용 검사 통과. 최종 [UI 로그](/tmp/rr-m4-task007-ui-repair-20261004.log)는 2/2, [단위 로그](/tmp/rr-m4-task007-unit-repair-20261004.log)는 40/40이며 모두 실패·skip 0. Result: `충족`
4. Completed requirements: 없음
5. Explanation: 이전 UI 환경 차단과 버튼 AX 식별자 실패는 최종 재실행 근거로 해소됐습니다. 실제 설정창 연결은 task-009, 조합별 포커스·viewport 완성은 task-008 범위입니다. 최종 승인과 문서·상태 변경은 main이 결정합니다.