# task-009 실행 근거

기준 작업 디렉터리는 `/Users/zipkero/XcodeProjects/ResourceRunner`, 기준 HEAD는 `2068184ff2bce845e31d960b4c522eb44ffb0f1e`입니다. 실행 OS·도구 버전은 `environment.raw.txt`, 최종 변경 원본은 `change.patch`와 `source-sha256.txt`에 보존했습니다. `git diff --check`는 빈 출력으로 성공했습니다.

## 실행

아래 명령은 모두 위 작업 디렉터리에서 실행했습니다. 전체 원시 출력과 xcresult 요약은 같은 이름의 `.raw.log` 및 `*-summary.json`에 있습니다.

```sh
xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task009-tests -parallel-testing-enabled NO -only-testing:ResourceRunnerTests/ResourceRateGraphTests -only-testing:ResourceRunnerTests/ResourceRateGraphRenderingTests -only-testing:ResourceRunnerTests/DashboardCardLayoutTests -only-testing:ResourceRunnerTests/DashboardPresentationTests -only-testing:ResourceRunnerTests/DashboardColorPaletteTests -only-testing:ResourceRunnerTests/NetworkActivityTests -only-testing:ResourceRunnerTests/DiskActivityTests test
xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task009-full -parallel-testing-enabled NO -only-testing:ResourceRunnerTests test
xcodebuild -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/ResourceRunner-M3-task009-release CODE_SIGNING_ALLOWED=NO build
git diff --check
```

집중 실행은 Swift Testing 기준 51개·5개 suite 통과, 전체 실행은 597개·116개 suite 통과, Release 빌드는 성공했습니다. xcresult 요약의 전체 `passedTests`는 597, `failedTests`는 0입니다. 전체 실행에는 기존 CPU 그래프/코어, Dashboard presentation/layout/palette, Network/Disk 원본 source/store 회귀가 포함됩니다. Release 로그에는 기존 `Text` 결합의 macOS 26 deprecation과 AppIntents metadata 생략 경고가 남습니다. 변경한 `BandRole`의 Swift 6 격리 경고는 최종 Release 로그에 없습니다.

## 조건별 근거

- `ResourceRateGraphTests`는 두 계열의 다른 시각 원본 peak와 1–2–5 축, 0·빈 값·경계, epoch/rateSegment/10초 초과 분리 뒤 양쪽 극값 index 합집합 downsampling, 짧은 실패·중지·장기 경과를 검사합니다. 최초 유효 시각을 history point 축출과 별도로 보존하여 600초 이후 진행 문구가 다시 나타나지 않는 store·card 전달도 검사합니다.
- `ResourceRateGraphRenderingTests`는 Network/Disk 정상·자리표시의 100pt 판과 118pt slot, 라이트·다크의 plot 면·중간 1pt 기준선·edge outline 부재·공백·팔레트·점선/실선·별도 범례와 범위 단위를 검사합니다. 실제 `ImageRenderer` PNG 20개와 SHA-256은 `renders/`, `render-sha256.txt`에 보존했습니다. `*-extended-*`는 10초 이하 간격의 넓은 연속 구간, 실제 0, 두 peak, 큰 공백을 시각 검토하기 위한 fixture입니다.
- 기존 `DashboardCardLayoutTests`와 전체 suite로 CPU의 0–100% 축, 누적 밴드, 코어 단계와 그래프 판 회귀를 확인했습니다. CPU plot 계산 및 색 의미는 변경하지 않았습니다.

## 범위

Task-009는 속도 그래프 모델과 독립 렌더 판까지 구현했습니다. Network/Disk 카드의 실제 배치는 task-010/011 소유이므로 이 단계의 서명 Sandbox 앱에서 카드 통합 화면은 실행하지 않았습니다. 새 native 읽기·entitlement·외장 연결 검증도 이 단계의 변경 범위가 아닙니다.
