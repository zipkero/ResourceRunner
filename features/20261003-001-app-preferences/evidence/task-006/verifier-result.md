<!-- prowl-workflow: v1 verify -->
1. Status: `approved` 후보
2. Target: task-006: CPU·Disk의 공통1/5/10분 표시 범위
3. Validation:
   - Criterion: 선택 범위의 축·진행·접근성 안내와 재확대가 실제 이력에 일치함. Source: `implement.md` task-006, `design.md` §2.5·§3.4. Evidence: 현재 코드가 공통 `GraphTimeRange`를 CPU·Disk 렌더링에 전달하고 최대 이력에서 표시 구간만 선별함. 범위 전환·실패·중지 테스트 통과. Result: `충족`
   - Criterion: 당시 허용 간격과 epoch·segment에 따른 단절, 가시 극값·다운샘플링을 보존함. Source: `design.md` DP5·DP6. Evidence: 양쪽 그래프의 연결·축 계산 원본과 관련 모델·렌더 테스트 통과. Result: `충족`
   - Criterion: CPU 밴드와 Disk 42pt 미니 그래프·Read 점선/Write 실선 및 기존 Memory 계산을 보존함. Source: `implement.md` task-006 검증 조건. Evidence: 현재 뷰·계산 원본과 CPU·Disk·Memory 회귀 테스트 통과. Result: `충족`
   - Criterion: 실행 근거가 현재 변경에 대응함. Source: `acceptance.md` §절차. Evidence: HEAD `8345f58`, 9개 파일 해시와 현재 diff가 보관 패치에 일치함. 최종 로그와 xcresult의 테스트명·시각·결과가 일치하며 86개 논리 테스트(동적 실행 90개), 실패·건너뜀 0개. Result: `충족`
4. Completed requirements: 없음
6. Explanation: Task 006 범위의 승인 후보입니다. 로그에 기록된 `unit-serial.xcresult` 경로는 현재 없지만, 보관된 `unit.xcresult`의 실행 정보와 결과는 로그에 일치합니다. 실제 설정 조작과 앱 UI 통합 관찰은 후속 task-009·010의 검증 범위입니다.