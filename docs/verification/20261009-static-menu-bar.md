# 정적 CPU 색상과 얇은 포커스 표시 검증

2026-10-09 Per-Request. 사용자가 고양이 애니메이션을 제외하고 색상으로 표시하는 방향을 승인했으며,
팝오버의 두꺼운 파란 포커스 테두리를 줄이도록 요청했습니다.

## 변경 기준

- 기존 18pt 정적 고양이, 고정 메뉴바 폭과 기존 CPU 상태 판정을 유지합니다.
- 낮음·보통은 native template, 높음은 노랑, 매우 높음은 주황, 장시간 고부하는 빨강입니다.
- 같은 색상의 이미지는 재사용합니다. 상태 툴팁과 기존 다섯 접근성 이름을 제공합니다.
- 네 카드의 기본 focus halo를 1pt accent 선(불투명도 0.7)으로 대체합니다.
- 캐릭터 선택·FPS·애니메이션 활성화·보조 효과 설정은 사용자 결정으로 제외합니다.
- 이전 M1의 동일 이미지 참조 조건은 이번 요청에서 동일 실루엣·크기와 색상별 캐시 재사용으로 대체했습니다.
  과거 feature 승인·근거는 당시 기준의 이력이며, 이번 변경의 현재 기준은 제품 정의와 이 문서입니다.

## 검증 결과

- 원본 Debug build-for-testing·Release build 성공, git diff --check 통과.
- 고유 bundle ID의 검증용 앱에서 StatusBarControllerTests·CharacterStateSourceTests·ApplicationCoordinatorTests
  27/27 통과. 실제 AppKit 렌더 픽셀의 세 색상·알파 마스크, 크기·참조 재사용·툴팁·접근성 이름과
  열린 팝오버·delegate 보존을 확인했습니다.
- 기존 UI 4/4 통과: 다섯 상태 이름, 카드 빈 영역 클릭, 상세 선택·닫힘·크기 보존,
  카드 제거 후 Return·Space 활성화와 포커스 복귀.
- 임시 검증용 앱에서 Light/Dark를 강제한 캡처 fixture 1/1 통과.
  같은 실루엣의 색상과 두 appearance의 얇은 CPU 포커스 선을 화면에서 확인하고 Return 재활성화를 단언했습니다.
  appearance 강제와 캡처용 test는 /tmp 검증 복사본에만 있으며 원본 앱에 추가하지 않았습니다.
  시스템 메뉴바 appearance는 변경하지 않았고 실제 VoiceOver 낭독·M5 성능/장기 안정성을 검증한 것으로 확대하지 않습니다.
- 최초 픽셀 진단은 TIFF 변환의 Generic RGB 재해석 차이로 실패했습니다. RGB bitmap에 실제 그리는 경로로
  검증을 수정하여 최종 27/27을 확인했습니다. 실패 진단은 최종 통과 수에 포함하지 않습니다.

실행 결과: /tmp/rr-static-color-unit-final.xcresult,
/tmp/rr-static-color-check.xcresult(기존 UI 4개 통과·초기 픽셀 진단 실패),
/tmp/rr-static-color-visual-schemes.xcresult, /tmp/rr-static-color-installed.xcresult.
캡처: /tmp/rr-static-color-screens-schemes. 임시 파일은 장기 보관을 보장하지 않습니다.

## 실제 앱 반영

- /Users/zipkero/Applications/ResourceRunner.app에 원본 Release를 반영했습니다.
- 이전 앱 백업: /tmp/rr-static-color-installed-backup/ResourceRunner.app.
- 앱 디렉터리 inode 43094210 유지, strict 서명 검증 성공(ad hoc).
- 실행 파일 SHA256: a4073395407599a16cec757957ded1f4ecbdc535a070e7c985647a3f6bd32c80.
- 설치 URL의 읽기 전용 Release UI 1/1 통과: 시스템 포함0·상세20·자동닫기1,
  로그인 토글1·허용, 시작 시 설정창 없음·단일 설정창·명시적 닫기.
- Sandbox/global preferences.v1 부재를 전후 비교하여 보존했습니다. 로그인 등록·해제·로그아웃은 실행하지 않았습니다.
- 확인 후 실제 설치 앱을 다시 실행했습니다. 새 바이너리의 다음 로그인 재시험을 주장하지 않습니다.

M2와 M4의 애니메이션 관련 잔여 범위는 위 사용자 결정과 대체 검증으로 해소했습니다.
M5 성능·접근성·장기 안정성 관문은 별도 작업입니다. 이후 2026-10-09 사용자가 개인 사용을 확정하여
외부 배포용 서명·공증·배포 준비는 ROADMAP 범위에서 제외했습니다.
