# task-008 승인 근거

2026-10-04 main 최종 판정: approved. 기준 HEAD `b8a83973efd29905d3d9e2406b2fb63ad6f7bedd`, cwd `/Users/zipkero/XcodeProjects/ResourceRunner`.

현재 표시 조합별 포커스 복귀·고정 단축키·마지막 앵커와 Memory 보정을 구현했습니다. 일반 본체 글꼴·무스크롤·상세 내부 스크롤을 유지했습니다. 기본 본체280×668pt, 실제 마지막 Memory TOP5 off/on·Network·Disk의 상세400×480pt와8pt 화면 여유를 확인했습니다.

- [worker 결과/명령](./worker-result.md), [전체7파일 패치](./changes.patch), [소스 SHA256](./source-sha256.txt)
- [단위46/46](./unit-summary.json), [로그](./unit.log)
- [UI17/17](./ui-summary.json), [실제 좌표 로그](./ui.log)
- [독립 verifier 후보](./verifier-result.md)

signed arm64 macOS26.6.2, 실패/skip0. 원본 번들은 `/tmp/rr-m4-task008-unit.xcresult`, `/tmp/rr-m4-task008-ui.xcresult`입니다. main과 verifier가 소스 해시·패치 역검사·실행 대응을 확인했습니다. 내장 verifier agent thread 제한으로 동일 gpt-6-sol/high 읽기 전용 역할을 로컬Codex CLI로 수행했습니다.

loop 구현 재시도0·근거 재검증0. 초기 구현 중 발견한 Return/Space 기본 활성화 실패는 focused onKeyPress의 단일 처리로 수정했고 최종회귀가 통과했습니다. 실제 key 설정창은 task-009에서 확인하며 이번에는 독립 창 key 소유권 단위를 확인했습니다. 작은729pt 화면은 단위 계산, 실제UI는1084pt 화면입니다. native 로그인/TCC/시스템 인증 설정 변경 없음. 이번 승인으로 마지막 매핑이 끝나는 SPEC 조건은 없습니다.
