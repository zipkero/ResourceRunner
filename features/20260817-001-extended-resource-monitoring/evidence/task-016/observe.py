#!/usr/bin/env python3
"""앱 밖에서 합성 트래픽과 netstat 원본을 같은 시계로 기록합니다."""

import argparse
import json
import subprocess
import threading
import time
from datetime import datetime, timezone
from pathlib import Path


def stamp():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    args.app_cache.mkdir(parents=True, exist_ok=True)
    events = (args.output / "events.jsonl").open("w", buffering=1)
    raw = (args.output / "netstat.raw.txt").open("w", buffering=1)
    stop = threading.Event()
    payload = args.output / "synthetic-2MiB.bin"
    payload.write_bytes(bytes(2 * 1024 * 1024))

    def event(**fields):
        events.write(json.dumps({"utc": stamp(), "monotonic": time.monotonic(), **fields}) + "\n")

    def observe():
        next_tick = time.monotonic()
        while not stop.is_set():
            started = time.monotonic()
            result = subprocess.run(["/usr/sbin/netstat", "-ibn"], capture_output=True, text=True)
            raw.write(f"BEGIN utc={stamp()} monotonic={started:.9f} exit={result.returncode}\n")
            raw.write(result.stdout)
            raw.write(result.stderr)
            raw.write("END\n")
            next_tick += 1
            stop.wait(max(0, next_tick - time.monotonic()))

    thread = threading.Thread(target=observe, daemon=True)
    thread.start()
    phases = [("download-idle", 15), ("download-load", 30),
              ("download-recovery", 15), ("upload-idle", 15),
              ("upload-load", 30), ("upload-recovery", 15)]
    for phase, duration in phases:
        (args.app_cache / "phase.txt").write_text(phase)
        event(kind="phase_start", phase=phase, durationSeconds=duration)
        deadline = time.monotonic() + duration
        if phase.endswith("-load"):
            while time.monotonic() < deadline:
                request_start = time.monotonic()
                if phase.startswith("download"):
                    command = ["/usr/bin/curl", "-sS", "--max-time", "5", "-o", "/dev/null",
                               "-w", "%{http_code} %{size_download} %{size_upload} %{time_total}",
                               "https://speed.cloudflare.com/__down?bytes=2097152"]
                else:
                    command = ["/usr/bin/curl", "-sS", "--max-time", "5", "-o", "/dev/null",
                               "-w", "%{http_code} %{size_download} %{size_upload} %{time_total}",
                               "-X", "POST", "--data-binary", f"@{payload}",
                               "https://speed.cloudflare.com/__up"]
                result = subprocess.run(command, capture_output=True, text=True)
                event(kind="request", phase=phase, exit=result.returncode,
                      result=result.stdout.strip(), error=result.stderr.strip())
                remaining = min(1.0 - (time.monotonic() - request_start), deadline - time.monotonic())
                if remaining > 0:
                    time.sleep(remaining)
        else:
            remaining = deadline - time.monotonic()
            if remaining > 0:
                time.sleep(remaining)
        event(kind="phase_stop", phase=phase)
    (args.app_cache / "phase.txt").write_text("done")
    stop.set()
    thread.join(timeout=2)
    events.close()
    raw.close()
    payload.unlink()


if __name__ == "__main__":
    main()
