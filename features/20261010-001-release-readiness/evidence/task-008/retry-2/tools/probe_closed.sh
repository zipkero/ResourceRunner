#!/bin/zsh
# 사용: probe_closed.sh APP OUT_DIR WARM_SECONDS [CYCLES]
# 새 프로세스를 띄워 WARM초 뒤 기준 스냅샷, 본체 5초 열기→닫기→60초 뒤 스냅샷을 CYCLES회 반복한다.
# 스냅샷: vmmap -summary, vmmap IOSurface 영역, heap 클래스 개수(창·popover·layer), 화면 밖 포함 창 목록.
set -e
APP=$1; OUT=$2; WARM=$3; CYCLES=${4:-1}
EXE=$APP/Contents/MacOS/ResourceRunner
G=/private/tmp/resourcerunner-task002-gui-state
W=/private/tmp/resourcerunner-task008-r2/windows-all
mkdir -p $OUT; [ -z "$(ls $OUT)" ] || { echo "output not empty"; exit 3; }
if ps -axo comm= | grep -qx "$EXE"; then echo "already running"; exit 4; fi
open -n $APP
for i in $(seq 1 100); do P=$(ps -axo pid=,comm= | awk -v e="$EXE" '$2==e{print $1}'); [ -n "$P" ] && break; sleep 0.05; done
echo "{\"pid\":$P,\"exe\":\"$EXE\",\"sha\":\"$(shasum -a 256 $EXE | cut -c1-64)\",\"warm\":$WARM,\"start\":\"$(date -u +%FT%TZ)\"}" > $OUT/launch.json
snap() {
  vmmap -summary $P > $OUT/$1.vmmap-summary.txt 2>&1
  vmmap $P 2>/dev/null | grep -E "^IOSurface|^CoreAnimation|^IOAccelerator" > $OUT/$1.vmmap-surfaces.txt || true
  heap $P 2>/dev/null | grep -E "Popover|NSWindow|_NSThemeFrame|NSHostingView|CALayer |CAContext|NSViewBackingLayer|NSBitmapImageRep|CABackingStore" > $OUT/$1.heap-classes.txt || true
  $W $P > $OUT/$1.windows.json
  echo "$1 $(grep 'Physical footprint:' $OUT/$1.vmmap-summary.txt | awk '{print $3}') ios=$(awk '/^IOSurface /{print $3; exit}' $OUT/$1.vmmap-summary.txt)" | tee -a $OUT/snapshots.txt
}
sleep $WARM
snap c0-before
for c in $(seq 1 $CYCLES); do
  $G $P toggle > $OUT/c$c-open.json; sleep 5; $G $P inspect > $OUT/c$c-held.json
  $G $P toggle > $OUT/c$c-close.json; sleep 60; $G $P inspect > $OUT/c$c-closed.json
  snap c$c-closed
done
kill $P; sleep 1
echo "{\"pid\":$P,\"stillRunning\":$(ps -p $P >/dev/null && echo true || echo false)}" > $OUT/exit.json
