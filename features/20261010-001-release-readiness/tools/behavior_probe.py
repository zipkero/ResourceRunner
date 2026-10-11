#!/usr/bin/env python3
"""정식 측정 뒤 진단 앱의 닫힘·재열림 AX 값을 기록한다."""
import argparse
import datetime as dt
import json
from pathlib import Path
import subprocess
import time


def invoke(gui, pid, action, extra=None):
    args = [str(gui), str(pid), action]
    if extra:
        args.append(extra)
    return json.loads(subprocess.run(args, check=True, capture_output=True, text=True, timeout=4).stdout)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pid', required=True, type=int)
    parser.add_argument('--gui', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise RuntimeError('output exists')
    records = []

    def step(name, action=None, extra=None):
        observed = invoke(args.gui, args.pid, action or 'inspect', extra)
        records.append({'at': dt.datetime.now(dt.timezone.utc).isoformat(),
                        'step': name, 'observed': observed})
        return observed

    step('closed-before')
    step('first-reopen', 'toggle')
    time.sleep(2)
    step('first-reopen-settled')
    step('cpu-detail', 'card', 'CPUCard')
    step('detail-close', 'detail-close')
    step('body-close', 'toggle')
    time.sleep(15)
    step('closed-after-fifteen-seconds')
    step('second-reopen', 'toggle')
    step('second-reopen-settled')
    step('final-close', 'toggle')
    args.output.write_text(''.join(json.dumps(record, ensure_ascii=False, sort_keys=True) + '\n'
                                   for record in records), encoding='utf-8')


if __name__ == '__main__':
    main()
