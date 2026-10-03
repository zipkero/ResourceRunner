# task-005 검증 근거

기준 HEAD `d119c73a9755f91141ca71e06122636c2581dd62`, cwd `/Users/zipkero/XcodeProjects/ResourceRunner`.

설정 검증 로드→로그인 실제 조회→동일 snapshot의 Dashboard/최초 pipeline profile→소비 연결→최초 lifecycle 순서를 반영했습니다. 저장/게시 후 동기 callback으로 현재 snapshot을 전달하고 프로필 변경만 revision을 포함해 lifecycle에 전달합니다.

카드 모델은 전체600초 이력·상세를 이미 보유하므로 설정 변경마다 모델을 재조립하지 않습니다. guarded 현재 snapshot을 표시 경계에 게시하고 후속 view006/007이 이를 선별합니다. sample은 과거 설정을 운반하지 않으며 늦은 sample·실패·중지·역순 snapshot에서도 현재 설정과 이력을 유지합니다. 이는 task-005 목적/조건·DESIGN §2.1/2.5를 유지하는 내부 접근 차이로 main이 확정했습니다.

`worker-result.md`의 final signed 명령에서 고유42case·실패/skip0입니다. 로그의 반복 이름을 합산하지 않았으며 `unit-summary.json`이 실제 결과입니다. 원본 결과는 `/tmp/rr-m4-task005-unit.xcresult`입니다. `change.patch`와 전체8파일 `source-sha256.txt`가 현재 변경에 대응합니다. 독립 verifier approved를 main이 확정했습니다. 구현 재시도0·근거 재검증0; SPEC 전체 완료 조건은 없습니다.

실제 native 로그인 mutation은 수행하지 않았습니다. 그래프/카드/TOP5 표시006/007·창009·실제 로그인011은 후속 범위입니다.
