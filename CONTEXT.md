# Context

저장: 2026-09-28 06:50 +09:00

## 현재 목표

M2 `20260812-001-core-resource-monitoring`의 task-012·013 실기기 검증을 마쳐 IMPLEMENT를 승인하고 M3 선행 조건을 닫는다. 사용자는 DP20 경로 재조회·이력 초기화와 남은 작업의 자율 진행을 승인했고, 이에 따라 DP13 권장 기준 개정을 적용했다. 반복 조작 요청은 최소화한다.

## 현재 상태

branch `main`, HEAD `bf0d186`. M2와 완료된 graph-plot-surface 변경은 공유 작업 트리에서 미커밋이며 보존해야 한다. M2 SPEC·DESIGN은 `[x]`, IMPLEMENT는 `[ ]`; `design.md`는 DP1~20을 담은 미추적 원본이다. DP20 task-004·005·006과 task-014는 독립 verify approved로 `[x]`다. task-014의 격리 Release 빌드·전체 단위·UI suite, arm64/Sandbox/26.5 배포 대상, 실제 PID 경로 전환과 두 카드·일정 근거는 `implement.md`와 `/private/tmp/ResourceRunner-dp20-task014-*`에 있다. 현재 기기는 macOS 26.6.2 arm64다.

task-012는 시도·worker 호출 3/3으로 추가 구현 없이 실기기 근거를 보완한다. 관찰용 Debug 앱 PID 4797과 `log stream` PID 56195는 사용자 요청에 따라 2026-09-28 06:50 KST에 종료했다. `/tmp/ResourceRunner-task012-final-observation.log`는 보존 중이다. epoch 10·12·13·15·16의 5.329·6.169·5.701·6.347·6.629초 잠금에서 두 축 정지·재개 카운트 불변, epoch 전진, 첫 CPU 기준점 전용, 다음 유효점 새 epoch, 메뉴바 판정 초기화를 확인했다. 표 `/tmp/ResourceRunner-task012-lock-cycles-20260927.tsv`. 16:57:57~17:12:42의 약 14분 45초 잠금에서도 epoch18의 두 축 정지·재개와 샘플 수 불변이 기록됐지만 해제 직후 팝오버 화면은 놓쳤다. 18:21:32~18:27:32의 약 6분 잠금 epoch19에서 두 축 샘플 수 불변과 재개를 확인했고, 18:27:59 CUA 화면에 그래프의 긴 빈 구간과 오른쪽 새 점이 보였다. 10분 이상 잠금 직후 전 구간 빈 그래프는 아직 미확보다. 이후 19:09:47~19:35:32의 약 25분 45초 디스플레이 슬립·잠금에서 시스템·프로세스 appendedTotal 12571·5255 불변과 epoch20 재개를 확인했다. 19:46:03~19:50:27의 약 4분 24초 중지도 기록됐다. 20:46:24~22:29:07 약 1시간 43분, 22:40:39~23:44:48 약 1시간 4분, 23:55:36~다음 날 06:47:37 약 6시간 52분의 추가 잠금에서도 두 축 샘플 수 불변과 재개를 확인했다. 10분 이상 중지 직후 그래프 화면은 여전히 미확보다. CUA Mac 연결은 20:27경 native pipe startup failed로 사용할 수 없었다. 짧은 선 틈은 실제 epoch 로그와 결정적 선분 테스트, 독립 절전은 결합된 실제 로그와 단독 신호 주입 테스트를 함께 판정한다. 둘째 계정이 없어 빠른 사용자 전환은 미확인으로 기록한다. 관찰 앱은 종료됐으므로 재검증 시 하나만 다시 실행한다.

task-013은 시도·worker 호출 3/3, 과거 독립 재검증 `rejected` 이력을 보존하고 현 DP13·DP20 기준에서 독립 verify approved로 `[x]`다. DP20 새 앱의 서명 UI 테스트로 유휴·`yes` 14개·4GB Python 시나리오 각 3회, 총 9회 화면·전체 PID `top`·`ps`·경로·시작 시각 원자료를 수집했다. 자료는 `/Users/zipkero/Library/Containers/com.zipkero.ResourceRunnerUITests.xctrunner/Data/tmp/ResourceRunner-dp20-task013-evidence-baseline-20260927`, 전체 시스템 비교 요약·Activity Monitor GUI 원시값은 `/private/tmp/ResourceRunner-dp20-task013-system-report.md`, 연속 `top`은 `/private/tmp/ResourceRunner-dp20-task013-continuous-top-final.txt`, 앱 조사 tick은 `/private/tmp/ResourceRunner-dp20-task014-live-scheduler.log`의 PID73623이다. 9회 전체 CPU 오차 최대 4.93%p, Memory 구성 오차 최대 4.6%, 물리 36GB 일치, Swap 0; Memory 상위3 집합은 9/9 일치. 동일 PID75429의 `/bin/zsh`→Xcode Python 전환 뒤 앱 화면은 Xcode 4.5GB로 귀속했다. 그러나 CPU `memory-2` 상위3은 화면 `{Xcode, Activity Monitor, Orca}` 대 현 재집계 `{Xcode, Activity Monitor, Codex Computer Use}`이고, `top` 초 단위 표본을 앱 ms 단위 tick에 정확히 연결하지 못했다. 비교 스크립트 `/private/tmp/ResourceRunner-dp20-task013-continuous-rank.py`는 tick의 ms를 잘라 버리고 최신 경로를 CPU 세 표본에 적용하므로 승인 근거로 부족하다. 실패 회차를 골라 제외하지 않는다. 이전 실패 표본도 보존한다. 측정용 임시 UI 소스는 저장소에서 제거해 `/private/tmp/ResourceRunner-dp20-task013-harness-source.swift`에 보관했다. 측정 helper·부하 프로세스는 종료했고 관찰 앱 PID4797만 남았다.

18:33경 동기화 개선 재측정을 시작했지만 유휴 1회차에서 앱 CPU 14% 대 Activity Monitor 20.46%로 다른 갱신 시점이 잡혔다. 성공 회차 선별을 피하려고 유휴 3회차 뒤 중단했고 전체 측정 성공으로 취급하지 않는다. 중단 원자료는 `/Users/zipkero/Library/Containers/com.zipkero.ResourceRunnerUITests.xctrunner/Data/tmp/ResourceRunner-dp20-task013-evidence-aborted-sync-20260927`, `top` 도착 시각 원자료는 `/private/tmp/ResourceRunner-dp20-task013-top-stamped-rerun.txt`. 측정 helper·부하 프로세스는 정리했고 PID4797만 남았다. 새 시각 대응 도구 `/private/tmp/ResourceRunner-dp20-task013-aligned-rank.py`와 `...-top-stamped.py`는 다음 전체 재측정에 쓸 수 있다.

18:45~18:48의 정렬 9회 재측정에서 각 화면과 가까운 Activity Monitor GUI 시스템 CPU 오차는 최대 2.71%p, 사용 중 메모리 오차는 0.23% 이하였다. 그러나 idle-1 CPU 상위3 화면은 Activity Monitor·mdworker_shared·Orca, 외부 전체 PID `top` 재집계는 Activity Monitor·duetexpertd·Orca였다. 원자료 `/Users/zipkero/Library/Containers/com.zipkero.ResourceRunnerUITests.xctrunner/Data/tmp/ResourceRunner-dp20-task013-evidence-aligned3-20260927`, AM GUI 원시값 `/private/tmp/ResourceRunner-dp20-task013-am-aligned3.tsv`, 전체 PID 도착 시각 `/private/tmp/ResourceRunner-dp20-task013-top-stamped-aligned.txt`. 30초 유휴 안정 대기·즉시 `ps` 경로 표본을 적용한 추가 실행에서도 idle-1 CPU 상위3 집합이 불일치했고 AM GUI 첫 회차가 누락돼 idle-3 이후 중단했다. 원자료는 같은 위치의 `ResourceRunner-dp20-task013-evidence-warmup-aborted-20260927`. 불일치 회차를 제외하거나 성공으로 처리하지 않았다. 측정 helper와 부하 프로세스는 정리됐고 PID4797만 실행 중이다. 코드 변경은 없고 임시 UI 테스트 소스도 저장소에서 제거했다. 사용자의 자율 진행 지시에 따라 `/private/tmp/ResourceRunner-task013-DP13-revision-proposal.md` 권장안을 design-init과 implement-init으로 반영했다. 임의 배경 CPU 상위3 전회차 일치만 필수에서 제외했고 나머지 기준은 유지했다. 새 기준 독립 verifier가 정렬된 9회 원자료를 다시 계산해 task-013을 approved로 판정했다. 전체 CPU 최대 3.41%p, Memory 구성 최대 1.96%, 물리 36GB·Swap 0, Memory 상위3 9/9 일치, 실제 yes 14개 PID의 화면 합산 1232/1155/1144% 대 top 1220.8/1152.3/1151.1%, 동일 PID zsh→Xcode Python 경로 전환, 결정적 테스트 통과를 확인했다. CPU 임의 배경 top3는 idle-1·memory-1에서 불일치를 기록했다. 기존 reject는 이력으로 유지했다.

## 현재 작업 문서

- [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md) — SPEC·DESIGN `[x]`, IMPLEMENT `[ ]`
- [features/20260812-001-core-resource-monitoring/design.md](./features/20260812-001-core-resource-monitoring/design.md) — 현행 DP1~20
- [features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md) — task-012 `[ ]`, task-013·014 `[x]`

## 확정된 결정

- 명시적 수집 중지는 collectionEpoch를 바꾸고 CPU·그래프·메뉴바 지속 판정을 단절한다. 일반 지연의 10초 허용 간격은 유지한다.
- task-012의 약 5초 실기기 잠금 5회, 10분 이상 중지 직후 화면, 실기기·결정적 테스트 결합 판정은 승인된 기준이다.
- task-013의 동일 모집단·표본 창·최근 세 유효값·앱 키 집계, CPU 5%p·Memory 10%·Memory 상위3 전 회차 일치 기준을 유지한다. 임의 배경 CPU 상위3 전회차 일치는 필수에서 제외하고 매 회차 차이를 기록하며, 실제 yes PID 값·경로·방향과 결정적 CPU 순위 검증을 유지한다. DP20은 성공 조사 대상 경로를 매회 읽고 같은 PID·시작 시각의 경로 전환에서 이력을 초기화한다.

## 미확정 판단

- task-012의 장시간 중지 직후 실제 그래프가 비고 오른쪽부터 다시 채워지는 화면을 확인해야 한다.
- `docs/product.md`의 1·5·10분 선택 문구와 현재 10분 고정 구현 관계는 M4 소관이다.

## 다음 작업

- 작업: 작업 재개 시 task-012 관찰 앱·로그를 하나만 다시 실행하고, 화면 연결 복구와 10분 이상 중지 직후 빈 그래프 화면 확보 방법을 조사한다. 사용자에게 반복 조작을 요청하지 않는다.
- 완료 기준: task-012 독립 verify 승인 뒤 IMPLEMENT `[x]`; 화면 근거를 확보할 수 없으면 근거 부족 상태를 정직하게 유지한다.

## 먼저 읽을 파일

- [features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md)
- [features/20260812-001-core-resource-monitoring/design.md](./features/20260812-001-core-resource-monitoring/design.md)
- [ResourceRunner/ProcessSurveyCollector.swift](./ResourceRunner/ProcessSurveyCollector.swift)
- [ResourceRunner/ProcessHistoryStore.swift](./ResourceRunner/ProcessHistoryStore.swift)
- [ResourceRunnerUITests/OneSessionMonitoringIntegrationUITests.swift](./ResourceRunnerUITests/OneSessionMonitoringIntegrationUITests.swift)

## 문서 반영 필요

없음.
