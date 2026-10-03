#!/usr/bin/env python3
"""정상 앱 바깥에서 제한된 CPU 부하와 메뉴바 AX 상태를 기록합니다."""

import datetime
import subprocess
import sys
import time


pid = sys.argv[1]
helper = "/tmp/rr-task018-normal-ax"
workers = []


def sample(phase):
    result = subprocess.run([helper, pid, "dump"], capture_output=True, text=True, check=True)
    lines = result.stdout.splitlines()
    status = next((line for line in lines if line.startswith("status ")), "missing")
    cpu = next((line for line in lines if "id=CPUCard " in line), "missing")
    print(f"{datetime.datetime.now(datetime.timezone.utc).isoformat()} phase={phase} {status}", flush=True)
    print(f"{datetime.datetime.now(datetime.timezone.utc).isoformat()} phase={phase} {cpu}", flush=True)


try:
    for _ in range(4):
        sample("idle")
        time.sleep(2)
    print(f"{datetime.datetime.now(datetime.timezone.utc).isoformat()} load_start workers=12 command=/usr/bin/yes stdout=/dev/null", flush=True)
    for _ in range(12):
        workers.append(subprocess.Popen(["/usr/bin/yes"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    for _ in range(9):
        sample("load")
        time.sleep(2)
finally:
    for worker in workers:
        worker.terminate()
    for worker in workers:
        try:
            worker.wait(timeout=5)
        except subprocess.TimeoutExpired:
            worker.kill()
            worker.wait(timeout=5)
    print(f"{datetime.datetime.now(datetime.timezone.utc).isoformat()} load_stop workers_terminated={len(workers)}", flush=True)

for _ in range(16):
    sample("recovery")
    time.sleep(2)
