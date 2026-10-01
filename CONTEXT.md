# Context

저장: 2026-10-01 16:34 +09:00

## 현재 목표

`20260812-001-core-resource-monitoring`의 잔여 task-012 검증과 IMPLEMENT 완료 처리를 마쳤다. M3 착수의 CPU·Memory 선행 조건이 해소됐다. M2 전체에는 캐릭터 자산·메뉴바 애니메이션이 남아 있으며, 2026-09-14 사용자 결정에 따라 M3 이후 진행한다.

## 현재 상태

branch `main`, 이번 검증의 기준 HEAD `39be237`. 이전 M2·graph-plot-surface 구현은 이 커밋에 반영돼 있다. `CONTEXT.md`, `ROADMAP.md`, core-resource-monitoring `README.md`·`implement.md`의 근거·완료 상태 갱신을 완료 처리 커밋에 함께 저장한다. 제품 코드 변경은 없다.

core-resource-monitoring SPEC·DESIGN·IMPLEMENT는 모두 `[x]`, task-001~016 모두 `[x]`다. 2026-10-01 task-012 독립 verifier의 approved 후보를 main이 확정해 SPEC §5.11·§5.12·§5.14의 마지막 매핑을 닫았다. 기존 reject·시도 3/3 이력은 implement.md에 보존했다. graph-plot-surface도 기존 승인대로 완료다.

현 HEAD에서 새 격리 Debug 빌드(`/private/tmp/ResourceRunner-task012-20261001`, 로그 `...-build.log`)가 성공했다. macOS 26.6.2 arm64의 관찰 앱 PID50111에서 16:09:01.029~16:21:55.579의 실제 잠금 774.550초 동안 두 축 appendedTotal 164·75가 불변이고 중지 구간 추가 샘플은 0건이었다. epoch 1 재개 첫 CPU tick은 기준점만 갱신했고 다음 유효 이력점과 메뉴바 지속 판정 초기화도 새 epoch를 따랐다.

증거 디렉터리는 `/private/tmp/ResourceRunner-task012-20261001-evidence`다. `observation.log`·`watcher.log`·`before-lock.png`, 해제 직후 전 구간 빈 그래프의 `unlock-0.75s.png`·`unlock-1.5s.png`·`unlock-3s.png`, 16:22:42의 오른쪽 새 선(00:43/10:00)을 담은 `right-refill.png`를 독립 verifier가 직접 확인했다. +8·20초는 외부 클릭으로 팝오버가 닫힌 캡처여서 성공 근거에서 제외했다. watcher는 +60초까지 저장한 뒤 종료했고, 관찰 앱 PID50111과 로그 PID50068도 종료했다. 현재 관찰 프로세스를 유지할 필요는 없다.

기존 짧은 잠금 5회는 `/tmp/ResourceRunner-task012-final-observation.log`와 `/tmp/ResourceRunner-task012-lock-cycles-20260927.tsv`의 epoch 10·12·13·15·16(5.329·6.169·5.701·6.347·6.629초)이다. 실제 epoch·샘플 수·CPU 기준점·메뉴바 초기화 로그와 결정적 선분 테스트를 결합해 짧은 중지를 판정했다. 실제 디스플레이 슬립·잠금 결합 로그와 슬립 단독 신호 주입 생명주기 테스트를 결합한 판정도 승인됐다. 둘째 계정 부재로 빠른 사용자 전환은 승인 계약의 예외대로 미확인이다. 실기기 하한 OS 26.5 실행 근거는 없으며, 실행 OS는 26.6.2이고 배포 대상은 26.5다.

task-013·014의 기존 독립 승인은 유지한다. task-013의 현 DP13·DP20 정렬 9회 원자료는 `/Users/zipkero/Library/Containers/com.zipkero.ResourceRunnerUITests.xctrunner/Data/tmp/ResourceRunner-dp20-task013-evidence-aligned3-20260927`에 있다. 전체 CPU 최대 차이 3.41%p, Memory 구성 최대 차이 1.96%, 물리 36GB·Swap 0, Memory 상위 3개 앱 키 9/9 일치, 실제 yes 14개 PID의 값·경로·방향 및 동일 PID zsh→Xcode Python 경로 전환을 확인했다. 임의 배경 CPU 상위 3개 차이는 idle-1·memory-1에 기록했고 기존 실패 원자료는 보존한다. task-014 기존 단위·UI·Release 근거는 `/private/tmp/ResourceRunner-dp20-task014-*`에 있다. 이번 verifier가 기존 관련 테스트 통과 행과 xcresult 요약 503 passed·0 failed, Release arm64 단일 실행 파일·App Sandbox를 재확인했다.

## 현재 작업 문서

- [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md) — SPEC·DESIGN·IMPLEMENT `[x]`
- [features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md) — task-012 승인 근거 및 기존 reject 이력
- [features/20260812-001-core-resource-monitoring/design.md](./features/20260812-001-core-resource-monitoring/design.md) — 현행 DP1~20
- [ROADMAP.md](./ROADMAP.md) — core 기능 완료·M3 선행 조건 해소, M2 전체의 잔여 범위

## 확정된 결정

- 명시적 수집 중지는 collectionEpoch를 바꾸고 CPU·그래프·메뉴바 지속 판정을 단절한다. 일반 지연의 10초 허용 간격은 유지한다.
- task-013의 현 DP13은 시스템 CPU 5%p·Memory 10%·Memory 상위 3개 전회차 일치를 유지한다. 임의 배경 CPU 상위 3개 집합은 매회 대조·차이 기록 대상으로 두고 실제 부하 값·경로·방향 및 결정적 순위 검증을 유지한다.
- DP20은 성공 조사 대상 경로를 매회 읽고 같은 PID·시작 시각의 경로 전환에서 이력을 초기화한다.
- M2 캐릭터 자산·애니메이션과 관련 전환 기준은 M3 착수의 선행 조건에서 제외한다. core 기능 완료를 M2 전체 완료로 취급하지 않는다.

## 미확정 판단

- `docs/product.md`의 1·5·10분 선택 문구와 현재 10분 고정 구현 관계는 M4 소관이다.

## 다음 작업

- 작업: 다음 기능 진행 시 M3 `extended-resource-monitoring`의 기존 문서와 현 구현을 읽고 Network·Disk 범위를 복원한다.
- 완료 기준: 승인된 선행 문서로 M3 범위·배치·검증 계약을 확정하고 해당 단계 절차로 진행한다. 이번 core 기능 완료 처리에는 M3 구현 착수가 포함되지 않았다.

## 먼저 읽을 파일

- [ROADMAP.md](./ROADMAP.md)
- [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md)
- [features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md)
- [features/20260817-001-extended-resource-monitoring/README.md](./features/20260817-001-extended-resource-monitoring/README.md)
- [features/20260817-001-extended-resource-monitoring/spec.md](./features/20260817-001-extended-resource-monitoring/spec.md)

## 문서 반영 필요

없음.
