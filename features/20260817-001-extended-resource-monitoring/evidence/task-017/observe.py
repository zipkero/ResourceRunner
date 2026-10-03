#!/usr/bin/env python3
"""앱 밖 합성 파일 부하와 iostat 원문을 같은 시계로 기록합니다."""

import argparse
import fcntl
import json
import os
import pty
import random
import subprocess
import tempfile
import threading
import time
from datetime import datetime, timezone
from pathlib import Path


CHUNK_BYTES = 1024 * 1024
FILE_BYTES = 256 * CHUNK_BYTES
PACE_SECONDS = 1 / 32


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
    raw = (args.output / "iostat.raw.txt").open("w", buffering=1)

    def event(**fields):
        events.write(json.dumps({"utc": stamp(), "monotonic": time.monotonic(), **fields}) + "\n")

    with tempfile.TemporaryDirectory(prefix="rr-task017-synthetic-", dir="/tmp") as directory:
        path = Path(directory) / "read-write.bin"
        fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_TRUNC, 0o600)
        try:
            fcntl.fcntl(fd, fcntl.F_NOCACHE, 1)
            block = random.Random(17017).randbytes(CHUNK_BYTES)
            event(kind="prepare_start", path=str(path), bytes=FILE_BYTES,
                  fNocache=fcntl.F_NOCACHE, filesystem="/System/Volumes/Data")
            for offset in range(0, FILE_BYTES, CHUNK_BYTES):
                written = os.pwrite(fd, block, offset)
                if written != CHUNK_BYTES:
                    raise RuntimeError(f"incomplete prepare write {written}")
            os.fsync(fd)
            event(kind="prepare_stop", bytes=FILE_BYTES)
            time.sleep(5)
            event(kind="prepare_settled", seconds=5)

            master, slave = pty.openpty()
            proc = subprocess.Popen(["/usr/sbin/iostat", "-d", "-w", "1", "disk0"],
                                    stdin=subprocess.DEVNULL, stdout=slave, stderr=slave)
            os.close(slave)

            def read_iostat():
                pending = b""
                while True:
                    try:
                        data = os.read(master, 4096)
                    except OSError:
                        break
                    if not data:
                        break
                    pending += data
                    while b"\n" in pending:
                        line, pending = pending.split(b"\n", 1)
                        raw.write(f"utc={stamp()} monotonic={time.monotonic():.9f} "
                                  + line.decode(errors="replace").rstrip("\r") + "\n")
                if pending:
                    raw.write(f"utc={stamp()} monotonic={time.monotonic():.9f} "
                              + pending.decode(errors="replace") + "\n")

            reader = threading.Thread(target=read_iostat, daemon=True)
            reader.start()
            phases = [("read-idle", 15), ("read-load", 30), ("read-recovery", 15),
                      ("write-idle", 15), ("write-load", 30), ("write-recovery", 15)]
            for phase, duration in phases:
                (args.app_cache / "phase.txt").write_text(phase)
                event(kind="phase_start", phase=phase, durationSeconds=duration)
                deadline = time.monotonic() + duration
                if phase.endswith("-load"):
                    count = 0
                    total_bytes = 0
                    next_op = time.monotonic()
                    last_report = next_op
                    while time.monotonic() < deadline:
                        offset = (count * CHUNK_BYTES) % FILE_BYTES
                        if phase.startswith("read"):
                            transferred = len(os.pread(fd, CHUNK_BYTES, offset))
                        else:
                            transferred = os.pwrite(fd, block, offset)
                            if count % 8 == 7:
                                os.fsync(fd)
                        if transferred != CHUNK_BYTES:
                            raise RuntimeError(f"incomplete {phase} transfer {transferred}")
                        count += 1
                        total_bytes += transferred
                        now = time.monotonic()
                        if now - last_report >= 1:
                            event(kind="io_progress", phase=phase, operations=count,
                                  bytes=total_bytes, fNocache=True)
                            last_report = now
                        next_op += PACE_SECONDS
                        if next_op > now:
                            time.sleep(min(next_op - now, max(0, deadline - now)))
                    if phase.startswith("write"):
                        os.fsync(fd)
                    event(kind="io_total", phase=phase, operations=count, bytes=total_bytes)
                else:
                    remaining = deadline - time.monotonic()
                    if remaining > 0:
                        time.sleep(remaining)
                event(kind="phase_stop", phase=phase)
            (args.app_cache / "phase.txt").write_text("done")
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=3)
            reader.join(timeout=3)
            os.close(master)
        finally:
            os.close(fd)
    events.close()
    raw.close()


if __name__ == "__main__":
    main()
