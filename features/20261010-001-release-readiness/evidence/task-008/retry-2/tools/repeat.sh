#!/bin/zsh
# 사용: repeat.sh APP LABEL N OUTFILE — 새 프로세스마다 15초 뒤 vmmap/heap, 본체 3초 열기·닫기, +15s/+60s 큰 IOSurface 목록
T=/private/tmp/resourcerunner-task008-r1; G=/private/tmp/resourcerunner-task002-gui-state
APP=$1; L=$2; N=$3; OUT=$4; EXE=$APP/Contents/MacOS/ResourceRunner
surf() { vmmap $1 2>/dev/null | grep -E "^IOSurface .*\[ *[0-9]{3,}K" | awk '{print $4}' | tr '\n' ' '; }
for i in $(seq 1 $N); do
  open -n $APP; sleep 15; P=$(ps -axo pid=,comm= | awk -v e="$EXE" '$2==e{print $1}')
  vmmap -summary $P >/dev/null 2>&1; heap $P >/dev/null 2>&1
  $G $P toggle >/dev/null; sleep 3; $G $P toggle >/dev/null; sleep 15; a=$(surf $P); sleep 45; b=$(surf $P)
  fp=$(vmmap -summary $P 2>/dev/null | awk '/Physical footprint:/{print $3}')
  echo "$L run$i pid=$P +15s: $a| +60s: $b| fp=$fp idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {printf "%.1f", $NF/1e9; exit}')" | tee -a $OUT
  kill $P; sleep 2
done
