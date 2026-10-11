#!/usr/bin/env python3
"""정식 비교 전 후보 hosting 해제의 방향만 짧게 살핀다."""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import subprocess
import time


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gui(tool, pid, action):
    return json.loads(subprocess.run([str(tool), str(pid), action], check=True,
                                     capture_output=True, text=True, timeout=4).stdout)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--gui', type=Path, required=True)
    parser.add_argument('--measure', type=Path, required=True)
    parser.add_argument('--analyze', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise RuntimeError('output exists')
    args.output.mkdir(parents=True)
    exe = args.app / 'Contents/MacOS/ResourceRunner'
    proc = subprocess.Popen([str(exe)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            start_new_session=True)
    log = args.output / 'chronology.jsonl'

    def record(phase, detail):
        with log.open('a', encoding='utf-8') as output:
            output.write(json.dumps({'at': dt.datetime.now(dt.timezone.utc).isoformat(),
                'phase': phase, 'detail': detail}, ensure_ascii=False, sort_keys=True) + '\n')

    try:
        record('launch', {'pid': proc.pid, 'exe': str(exe), 'exeSHA256': sha(exe)})
        time.sleep(3)
        record('initial', gui(args.gui, proc.pid, 'inspect'))
        time.sleep(60)
        record('before-open', gui(args.gui, proc.pid, 'inspect'))
        record('body-open', gui(args.gui, proc.pid, 'toggle'))
        time.sleep(5)
        record('body-held', gui(args.gui, proc.pid, 'inspect'))
        record('body-close', gui(args.gui, proc.pid, 'toggle'))
        time.sleep(60)
        record('closed-settled', gui(args.gui, proc.pid, 'inspect'))
        events = args.output / 'closed-30s.events'
        events.write_text('closed\n')
        raw = args.output / 'closed-30s.jsonl'
        command = [str(args.measure), '--pid', str(proc.pid), '--state', 'closed',
                   '--domain', 'com.zipkero.ResourceRunner.PerfDiagnostic',
                   '--output', str(raw), '--duration', '30', '--interval', '1',
                   '--events', str(events), '--exe', str(exe), '--sha', sha(exe),
                   '--max-bytes', '33554432']
        record('measure-start', command)
        measured = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        while measured.poll() is None:
            time.sleep(5)
            observed = gui(args.gui, proc.pid, 'inspect')
            record('measure-ax', observed)
            if observed['state'] != 'closed':
                events.write_text('AX state changed\n')
        stdout, stderr = measured.communicate()
        record('measure-end', {'returncode': measured.returncode, 'stdout': stdout, 'stderr': stderr})
        if measured.returncode != 0:
            return
        summary = args.output / 'closed-30s.summary.json'
        subprocess.run(['python3', str(args.analyze), str(raw), '--output', str(summary)], check=True)
        record('summary', json.loads(summary.read_text()))
        sample = args.output / 'sample-closed.txt'
        subprocess.run(['sample', str(proc.pid), '5', '-file', str(sample)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        record('sample', {'path': str(sample), 'SHA256': sha(sample)})
        vmmap = args.output / 'vmmap-closed.txt'
        with vmmap.open('w') as output:
            subprocess.run(['vmmap', '-summary', str(proc.pid)], check=True,
                           stdout=output, stderr=subprocess.STDOUT)
        record('vmmap', {'path': str(vmmap), 'SHA256': sha(vmmap)})
        record('reopen', gui(args.gui, proc.pid, 'toggle'))
        record('final-close', gui(args.gui, proc.pid, 'toggle'))
    finally:
        proc.terminate()
        proc.wait(timeout=10)
        record('terminated', {'pid': proc.pid, 'returncode': proc.returncode})


if __name__ == '__main__':
    main()
