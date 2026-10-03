#!/bin/zsh
set -eu

evidence_dir=/Users/zipkero/XcodeProjects/ResourceRunner/features/20260817-001-extended-resource-monitoring/evidence/task-016
app_cache=/Users/zipkero/Library/Containers/com.zipkero.ResourceRunner/Data/Library/Caches/Task016NetworkComparison
app=/tmp/rr-task016-signed/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner
mkdir -p "$app_cache"
python3 -c 'from pathlib import Path; root=Path("/Users/zipkero/Library/Containers/com.zipkero.ResourceRunner/Data/Library/Caches/Task016NetworkComparison"); [(root/name).unlink(missing_ok=True) for name in ("ready.txt", "app-samples.tsv")]'
printf 'unmarked\n' > "$app_cache/phase.txt"

/usr/bin/caffeinate -i -d -t 165 &
caffeinate_pid=$!
RR_NETWORK_COMPARISON_PROBE=1 "$app" > "$evidence_dir/app.stdout" 2>&1 &
app_pid=$!
printf 'pid=%s\npath=%s\n' "$app_pid" "$app" > "$evidence_dir/app-identity.txt"
cleanup() {
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
    kill "$caffeinate_pid" 2>/dev/null || true
    wait "$caffeinate_pid" 2>/dev/null || true
}
trap cleanup EXIT

ready=0
for _ in {1..20}; do
    if [[ -s "$app_cache/ready.txt" ]]; then ready=1; break; fi
    sleep 1
done
if [[ "$ready" != 1 ]]; then print -u2 'Sandbox app probe did not become ready'; exit 1; fi

python3 "$evidence_dir/observe.py" --app-cache "$app_cache" --output "$evidence_dir"
sleep 2
/usr/bin/log show --style compact --last 5m --predicate "processID == $app_pid AND subsystem == 'com.zipkero.ResourceRunner' AND category == 'NetworkComparison'" > "$evidence_dir/app-probe.log"
cp "$app_cache/app-samples.tsv" "$evidence_dir/app-samples.tsv"
for picture in "$app_cache"/{download,upload}-{idle,load,recovery}-{card,detail}.png; do
    [[ -f "$picture" ]] && cp "$picture" "$evidence_dir/"
done
print "completed pid=$app_pid"
