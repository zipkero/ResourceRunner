#!/bin/zsh
set -u
iface=en0
logfile=/tmp/rr-task014-probe/recovery.log
start=$(/bin/date +%s)
deadline=$((start + 25))
end=$((start + 100))
print -- "watchdog-ready pid=$$ start=$start deadline=$deadline end=$end" >> "$logfile"
while (( $(/bin/date +%s) < deadline )); do
  print -- "watchdog-heartbeat now=$(/bin/date +%s) pid=$$" >> "$logfile"
  /bin/sleep 1
done
while (( $(/bin/date +%s) < end )); do
  now=$(/bin/date +%s)
  before=$(/usr/sbin/networksetup -getairportpower "$iface" 2>&1)
  print -- "watchdog-check now=$now before=$before" >> "$logfile"
  if [[ "$before" == *": On" ]]; then
    print -- "watchdog-finished now=$now restored=On" >> "$logfile"
    exit 0
  fi
  result=$(/usr/sbin/networksetup -setairportpower "$iface" on 2>&1)
  rc=$?
  print -- "watchdog-retry now=$now rc=$rc result=$result" >> "$logfile"
  /bin/sleep 2
done
print -- "watchdog-deadline-exhausted now=$(/bin/date +%s)" >> "$logfile"
exit 1
