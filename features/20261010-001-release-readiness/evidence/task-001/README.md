# task-001: 원본 동결·외부 측정

## 원본 출처

2026-10-10, `main` HEAD `69842e14e920e95da179f525055b22dd75c56b74`와 당시 미커밋 변경을
`/tmp/resourcerunner-task001-tracked.tar.gz`(HEAD의 tracked 파일),
`/tmp/resourcerunner-task001-working.patch`(binary diff),
`/tmp/resourcerunner-task001-current-source.tar.gz`(현재 제품 소스·테스트·Xcode 프로젝트·문서)로 보존했습니다.
마지막 tar를 `/tmp/resourcerunner-task001-frozen/`에 풀고 그 경로에서 Xcode 26.6(17F113),
macOS SDK 26.5, Release, `CODE_SIGNING_ALLOWED=NO`로 빌드했습니다.
명령은 아래와 같고 전체 로그는 `/tmp/resourcerunner-task001-release-build.log`입니다.

```sh
xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner \
  -configuration Release -derivedDataPath /tmp/resourcerunner-task001-derived \
  CODE_SIGNING_ALLOWED=NO build
```

결과는 `BUILD SUCCEEDED`입니다. 생성 실행 파일 SHA256은
`dbd1f192c2496982d961989c9b487c7d22ea045034527a326f367dba988a4b6e`입니다.
빌드 산출물은 `/tmp/resourcerunner-task001-frozen-release.app`에 보존했습니다.
기존 설치 앱에서 읽은 entitlements를 `/tmp/resourcerunner-task001-entitlements.plist`에 보존하고,
별도 복사본 `/tmp/resourcerunner-task001-frozen-release-signed.app`에 ad hoc 서명했습니다.
`codesign --verify --strict` 통과, 서명된 Identifier는 `com.zipkero.ResourceRunner`입니다.
진단용 고유 bundle ID로 실행하기 전에는 Task 002에서 동일 entitlements를 적용해 다시 서명해야 합니다.
서명/ID 차이를 성능 개선 효과로 해석할 수 없습니다.

현재 설치 경로 `/Users/zipkero/Applications/ResourceRunner.app`의 실행 파일 SHA256은
`a4073395407599a16cec757957ded1f4ecbdc535a070e7c985647a3f6bd32c80`이고,
동결 Release와 다릅니다. 설치 바이너리의 정확한 소스 출처는 입증되지 않았으므로
공식 전후 비교의 원본은 위 동결 소스에서 빌드한 Release입니다. 설치 앱 복사본은
`/tmp/resourcerunner-task001-installed.app`, sandbox 설정 원본은
`/tmp/resourcerunner-task001-settings.plist`에 보존했습니다. 실제 설치 앱 PID 16136은
종료·재시작·설정 변경하지 않았습니다. 동결 원본과 설치 앱 복사본은 우발 변경을 막기 위해
쓰기 권한을 제거했습니다. 각 파일과 번들 구성 파일의 SHA256 및 절대 경로는 [manifest.json](./manifest.json),
재대조 결과는 [manifest-verification.txt](./manifest-verification.txt)에 있습니다.

## 외부 도구 검증

`tools/measure.swift`는 앱 밖에서 1초 원시 표본, 예정/실제 monotonic 시각, Mach tick/timebase,
CPU 차분, RSS·Footprint·실행 최고값, 창/설정/세션 식별자와 이벤트를 기록합니다.
`tools/analyze.py`는 원시값으로 전체 요약과 무효 사유를 재계산합니다.
`python3 -m unittest -v test_analyze.py`에서 Mach 125/3 변환, 단일 코어 100%, byte 보존,
카운터 역전, PID/시작 식별자, 누락/API 오류, 250ms 지연, 상태·잠금·설정·창·절전 전환,
상한 종료의 합성 경계를 확인했습니다. 2048-byte 상한 실행은
`final-limit.jsonl`에 `reason=output_limit invalid=true`를 남기고 2048 byte 이내에 멈췄습니다.
최대 허용 길이는 1800초/32MiB이며 그 밖의 입력은 시작 전에 거절합니다.
`operator-transition.jsonl`은 운영 이벤트 파일의 내용을 `settings`에서 `changed`로 바꾸자
이벤트·`event_changed`와 실행 전체 무효를 남긴 실측입니다. 대상 앱 상태는 바꾸지 않았습니다.

실제 설치 앱의 10초 `ps` 교차 확인은 [ps-crosscheck.txt](./ps-crosscheck.txt)와
`live-crosscheck.jsonl`에 있습니다. `ps` 누적 CPU 시간은 17:07.76→17:08.26으로 0.50초 증가했고,
같은 10초 원시 차분을 재계산한 CPU 평균은 5.0024%입니다. `ps`의 0.01초 표시 정밀도를 고려하면
일치합니다. `live-20s.jsonl`, `final-current-tool.jsonl`, `final-compiled-smoke.jsonl`은 읽기 전용 smoke 자료입니다.
이 실행들은 설정의 상세 목록 제한이 `ten`인 장기 실행 설치 앱을 읽었으므로 Task 002의
기본 설정·600초 워밍업·300초×3회 공식 baseline으로 사용하지 않습니다.

도구는 창 번호·geometry의 안정성과 운영자 이벤트를 검사하지만 일곱 창 상태를 자동 분류하지 않습니다.
창·설정·세션의 1초 표본 사이 전환은 놓칠 수 있어 운영 이벤트와 상태별 화면 확인을 함께 기록해야 합니다.
`proc_pid_rusage`의 실행 최고 Footprint와 1초 표본 최대는 다른 값이며, 표본 사이 peak 전체를
포착했다는 뜻이 아닙니다.
