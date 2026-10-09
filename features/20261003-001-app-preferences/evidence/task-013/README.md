# task-013 읽기 가능한 시스템 항목과 두 순위 자료

## 기준과 적용

- 기준 HEAD는 `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`입니다. 작업 전 소유 제품6·테스트4파일의 SHA-256이 격리 후보를 만들 때 기록한 값과 모두 일치했습니다. 다른 미커밋 변경은 보존했습니다.
- 격리 후보 patch `changes.patch`의 SHA-256은 `71a82fe29ac10435777de95ed5d34a0b4c4658dd7aeb4ab0f8acaf370fb07599`입니다. 제품6·테스트4파일만 원본에 적용했고, 적용 뒤 열 파일의 SHA-256이 격리 후보와 모두 일치합니다. 격리 빌드에서만 사용한 고유 bundle identifier 변경은 원본에 적용하지 않았습니다. 파일별·로그·Release 실행 파일 해시는 `sha256.txt`에 있습니다.

## 결과

- Collector는 UID 사전 제외 없이 모든 열거 항목에 같은 task-info와 현재 실행 경로 조회를 시도합니다. 읽기 성공의 원래 UID와 조사 당시 현재 UID 관계를 이력·snapshot·하위 프로세스까지 보존합니다. 같은 PID·시작시각·경로라도 UID/소속이 바뀌면 CPU 평활화와 Memory 기준점을 새로 시작합니다.
- 현재 사용자 전용 자료와 읽기 성공 전체 자료를 각각 **소속 선별 후** 앱 단위로 집계·정렬합니다. 순위 계산은 20개로 선절단하지 않아 50그룹과 20위 밖 사용자 앱을 보존합니다. 기본 화면에는 현재 사용자 자료를 선택하고 기존 TOP5·상세20개 표시 경계를 유지합니다. 후속 task-014가 설정의 현재 선택·10/20/50 정원·안내/AX를 화면에 배선합니다.
- 알려진 다른 UID의 조회 실패는 기본 목록의 실패 수에 섞지 않습니다. UID 미확인 실패는 보수적으로 기본 실패 수에 포함합니다. 전체 실패 수와 기본 범위 실패 수, 읽기 성공 후 의도적으로 제외한 수를 구분합니다. 혼합 UID 앱의 기본 합계와 자식 행에는 현재 사용자 항목만 들어갑니다.
- 캐시는 두 자료의 최신 조사 하나, 시각, 실패 상태, epoch와 전달 순서를 보관합니다. 동일 epoch의 오래된 시각·순서와 이전 epoch를 거르고 기존 admission을 통과한 결과만 반영합니다. 시스템 지표·메뉴바 소비는 독립 순위 계산을 기다리지 않습니다. 기존 3개 CPU/Memory 평활화, 조사시각 600초 Memory 창, 30초/21개 링, resolver512 및 종료 제거는 그대로입니다.

## 검증

- 원본 프로젝트의 실제 suite 이름 24개를 선택한 signed Debug 단위 **92 tests / 24 suites 통과, 실패·skip 0**: `focused-unit.log`, `focused-unit.xcresult`. Collector UID별 성공/실패, UID 미확인, PID·exec·소속 변경, 혼합 앱, 50그룹, 정렬, 실패 복구, pipeline/admission/메뉴바 독립을 포함합니다. 선택자는 파일 이름이 아닌 실제 `struct ...Tests` suite 이름입니다.
- 같은 최종 제품·테스트 SHA의 격리 복사본에서 `ResourceRunnerTests` 전체 **679 tests / 127 suites 통과**: `/tmp/rr-m4-task013-scope-final-unit.log`. 격리 복사본의 bundle identifier만 별도로 바꿨고 제품·테스트 열 파일 SHA는 원본 적용 후 값과 같습니다. 0개 실행을 통과로 세지 않았습니다.
- 원본 프로젝트 Release arm64 서명 빌드 **성공**: `release-build.log`. 번들 `codesign --verify --strict`가 통과했고 identifier는 `com.zipkero.ResourceRunner`입니다.
- `git diff --check` 통과. 기존 설치 앱·로그인 항목·OS 연결·잠금·절전·UI 동작은 변경하거나 실행하지 않았습니다.

현재 조사 자료를 설정 변경 즉시 화면에 재선택하는 동작과 새 컨트롤 UI는 task-014의 검증 대상입니다. 이 Task는 수집·이력·두 자료와 기본 표시 의미까지 확인합니다.
