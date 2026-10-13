#!/bin/zsh
# 사용: assemble.sh SRC_DIR NAME — 원본 project Release 빌드 후 task-002 진단 bundle 사본에 실행 파일만 바꿔 ad hoc 서명
set -e; T=/private/tmp/resourcerunner-task008-r2; SRC=$1; N=$2
(cd $SRC && xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS' -derivedDataPath $T/build-$N CODE_SIGNING_ALLOWED=NO > $T/build-$N.log 2>&1)
grep -q "BUILD SUCCEEDED" $T/build-$N.log
A=$T/diag-$N.app; rm -rf $A; cp -R /private/tmp/resourcerunner-task002-perf-diagnostic.app $A
cp $T/build-$N/Build/Products/Release/ResourceRunner.app/Contents/MacOS/ResourceRunner $A/Contents/MacOS/
codesign --force --sign - --entitlements /private/tmp/resourcerunner-task001-entitlements.plist $A 2>/dev/null
codesign --verify --strict $A
echo "$N $(shasum -a 256 $A/Contents/MacOS/ResourceRunner | cut -c1-64)"
