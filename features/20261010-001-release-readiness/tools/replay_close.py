#!/usr/bin/env python3
"""원본의 본문 2회차 닫힘 이력을 후보 진단 앱에 재현한다."""
import argparse
import datetime as dt
import json
from pathlib import Path
import subprocess
import time


def observe(gui, pid, action):
    return json.loads(subprocess.run([str(gui), str(pid), action], check=True,
                                     capture_output=True, text=True, timeout=4).stdout)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--gui', type=Path, required=True)
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise RuntimeError('output exists')
    deadline = time.monotonic() + 1800
    while not args.raw.exists() or args.raw.stat().st_size == 0:
        if time.monotonic() > deadline:
            raise TimeoutError('second body run did not start')
        time.sleep(0.5)
    started = args.raw.stat().st_birthtime
    target = started + 116
    while time.time() < target:
        time.sleep(min(0.5, target - time.time()))
    before = observe(args.gui, args.pid, 'inspect')
    if before['state'] != 'body':
        raise RuntimeError(f'expected body before replay: {before["state"]}')
    after = observe(args.gui, args.pid, 'toggle')
    record = {'at': dt.datetime.now(dt.timezone.utc).isoformat(),
              'rawBirthEpoch': started, 'targetOffsetSeconds': 116,
              'actualOffsetSeconds': time.time() - started,
              'before': before, 'after': after}
    args.output.write_text(json.dumps(record, ensure_ascii=False, sort_keys=True) + '\n', encoding='utf-8')
    if after['state'] != 'closed':
        raise RuntimeError(f'replay did not close body: {after["state"]}')


if __name__ == '__main__':
    main()
