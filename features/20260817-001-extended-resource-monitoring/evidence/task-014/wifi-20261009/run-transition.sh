#!/bin/zsh
set -u
log=/tmp/rr-task014-probe/transition.log
watchdog=96088
exec > >(tee -a "$log") 2>&1
print -- "preflight wall=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
/bin/ps -p "$watchdog" -o pid=,stat=,etime= || exit 10
/usr/bin/grep -q "watchdog-heartbeat.*pid=$watchdog" /tmp/rr-task014-probe/recovery.log || exit 11
/bin/ps -p 64258 -o pid=,comm= || exit 12
/bin/ps -p 92795 -o pid=,comm= || exit 13
power=$(/usr/sbin/networksetup -getairportpower en0)
print -- "$power"
[[ "$power" == *": On" ]] || exit 14
/usr/sbin/scutil --nwi | /usr/bin/grep -q 'en0' || exit 15
/usr/sbin/networksetup -setairportpower en0 on
rc=$?
print -- "preflight-set-on-rc=$rc"
(( rc == 0 )) || exit 16
print -- "preflight-ok wall=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ') watchdog=$watchdog"
restore() {
  print -- "trap-restore wall=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
  /usr/sbin/networksetup -setairportpower en0 on
  print -- "trap-restore-rc=$?"
}
trap restore EXIT INT TERM
print -- "OFF-BEGIN wall=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
/usr/sbin/networksetup -setairportpower en0 off
print -- "off-rc=$? wall=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
for n in 1 2 3; do
  /bin/sleep 4
  print -- "OFF-SAMPLE n=$n wall=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
  /usr/sbin/networksetup -getairportpower en0
  /usr/sbin/scutil --nwi | /usr/bin/tail -10
  /usr/sbin/netstat -ib -I en0 | /usr/bin/head -4
done
print -- "ON-BEGIN wall=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
/usr/sbin/networksetup -setairportpower en0 on
print -- "on-rc=$? wall=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
/usr/sbin/networksetup -getairportpower en0
/usr/sbin/scutil --nwi | /usr/bin/tail -14
