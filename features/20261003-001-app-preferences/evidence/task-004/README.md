# task-004 검증 근거

기준 HEAD `ccb1bf812c2b3c3d3ed00fdaf1df84dba70f6003`, cwd `/Users/zipkero/XcodeProjects/ResourceRunner`.

LoginItemService는 공개 SMAppService.mainApp adapter이며 LoginItemController는 실제 상태·요청 결과·일반 복원 결과를 분리합니다. 진행 중 mutation 하나와 최신 pending 의도·operation ID를 유지하고 완료/실패 뒤 실제 상태를 읽습니다. 생성·조회는 OS mutation을 수행하지 않습니다.

`worker-result.md`의 명령으로 signed arm64 단위7/7·실패/skip0을 확인했습니다. `unit.log`·`unit-summary.json`은 동일 실행이며 보존 xcresult는 `/tmp/rr-m4-task004-unit.xcresult`입니다. 로그의 원래 resultBundlePath는 unit4이며 보존 경로를 변경했습니다. `change.patch`의 새3파일 blob 및 `source-sha256.txt`가 현재 파일과 일치합니다. 독립 verifier approved를 main이 확정했습니다. 구현 재시도0·근거 재검증0입니다.

실제 register/unregister·시스템 설정 열기는 실행하지 않았습니다. 초기 앱 배선·제품 UI·실제 다음 로그인은 task-005/009/011이며 이번에 완료되는 SPEC 전체 조건은 없습니다.
