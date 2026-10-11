#!/usr/bin/env python3
"""고정 Release 진단 앱의 상태별 원본 성능 구간을 기록한다."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

STATES = ('closed', 'body', 'cpu', 'memory', 'network', 'disk', 'settings')
CARDS = {'cpu': 'CPUCard', 'memory': 'MemoryCard', 'network': 'NetworkCard', 'disk': 'DiskCard'}
EXPECTED_SETTINGS = {
    'SettingsCPUCard': '1', 'SettingsMemoryCard': '1', 'SettingsNetworkCard': '1',
    'SettingsDiskCard': '1', 'SettingsCPUTop5': '1', 'SettingsMemoryTop5': '1',
    'SettingsIncludeSystemProcesses': '0', 'SettingsDetailListLimit': '20개',
    'SettingsGraphRange': '최근 10분', 'SettingsRefreshProfile': '기본',
    'SettingsAutomaticallyClosesPopover': '1',
}

def timestamp():
    return dt.datetime.now(dt.timezone.utc).isoformat()

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def command(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True, timeout=4).stdout.strip()

def inspect(gui, pid):
    return json.loads(command(str(gui), str(pid), 'inspect'))

def action(gui, pid, name, extra=None):
    args = [str(gui), str(pid), name]
    if extra:
        args.append(extra)
    return json.loads(command(*args))

def state_is(observation, state):
    if observation['state'] != state:
        return False
    if state in ('body', *CARDS):
        return observation['cards'] == list(CARDS.values())
    return True

def transition(gui, pid, state):
    current = inspect(gui, pid)['state']
    if current == state:
        return
    if current == 'settings':
        action(gui, pid, 'settings-close')
        current = 'closed'
    if current in CARDS:
        action(gui, pid, 'detail-close')
        current = 'body'
    if state == 'closed':
        if current == 'body':
            action(gui, pid, 'toggle')
    elif state == 'settings':
        if current == 'body':
            action(gui, pid, 'toggle')
        action(gui, pid, 'settings-open')
    else:
        if current == 'closed':
            action(gui, pid, 'toggle')
        if state in CARDS:
            action(gui, pid, 'card', CARDS[state])
    time.sleep(1)
    observed = inspect(gui, pid)
    if not state_is(observed, state):
        raise RuntimeError(f'transition {state} failed: {observed}')
    return observed

def record(path, value):
    with path.open('a', encoding='utf-8') as file:
        file.write(json.dumps(value, ensure_ascii=False, sort_keys=True) + '\n')

def run_once(args, state, repeat, attempt, log):
    name = f'{state}-r{repeat}-a{attempt}'
    raw = args.output / f'{name}.jsonl'
    events = args.output / f'{name}.events'
    summary = args.output / f'{name}.summary.json'
    ax = args.output / f'{name}.ax.jsonl'
    if any(path.exists() for path in (raw, events, summary, ax)):
        raise RuntimeError(f'output exists: {name}')
    events.write_text(state + '\n', encoding='utf-8')
    observed = inspect(args.gui, args.pid)
    if not state_is(observed, state):
        raise RuntimeError(f'pre-run state mismatch: {state} {observed}')
    record(ax, {'at': timestamp(), 'phase': 'before', **observed})
    cmd = [str(args.measure), '--pid', str(args.pid), '--state', state,
           '--domain', args.domain, '--output', str(raw), '--duration', '300',
           '--interval', '1', '--events', str(events), '--exe', str(args.exe),
           '--sha', args.exe_sha, '--max-bytes', '33554432']
    record(log, {'at': timestamp(), 'phase': 'start', 'state': state, 'repeat': repeat,
                 'attempt': attempt, 'pid': args.pid, 'raw': str(raw), 'command': cmd})
    process = subprocess.Popen(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    mismatch = None
    deadline = time.monotonic() + 340
    while process.poll() is None:
        if time.monotonic() > deadline:
            mismatch = 'measure exceeded 340s guard'
            events.write_text(mismatch + '\n', encoding='utf-8')
            process.terminate()
            break
        time.sleep(5)
        try:
            observed = inspect(args.gui, args.pid)
            record(ax, {'at': timestamp(), 'phase': 'during', **observed})
            if not state_is(observed, state):
                mismatch = f'AX state changed: {observed}'
        except Exception as error:
            mismatch = f'AX observation error: {error}'
            record(ax, {'at': timestamp(), 'phase': 'error', 'error': str(error)})
        if mismatch:
            events.write_text(mismatch + '\n', encoding='utf-8')
    stdout, stderr = process.communicate()
    record(ax, {'at': timestamp(), 'phase': 'after', **inspect(args.gui, args.pid)})
    if process.returncode:
        record(log, {'at': timestamp(), 'phase': 'measure_error', 'name': name,
                     'returncode': process.returncode, 'stdout': stdout, 'stderr': stderr})
        return False
    command(sys.executable, str(args.analyze), str(raw), '--output', str(summary))
    result = json.loads(summary.read_text())
    valid = bool(result.get('valid')) and mismatch is None
    record(log, {'at': timestamp(), 'phase': 'finish', 'name': name, 'valid': valid,
                 'mismatch': mismatch, 'summary': str(summary), 'result': result})
    print(f'{timestamp()} {name} valid={valid} raw={raw}', flush=True)
    return valid

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--launch-epoch', type=float, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--exe', type=Path, required=True)
    parser.add_argument('--domain', default='com.zipkero.ResourceRunner.PerfDiagnostic')
    parser.add_argument('--gui', type=Path, required=True)
    parser.add_argument('--measure', type=Path, required=True)
    parser.add_argument('--analyze', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    log = args.output / 'orchestrator.jsonl'
    if log.exists():
        raise RuntimeError('orchestrator log exists')
    args.exe_sha = sha(args.exe)
    initial = inspect(args.gui, args.pid)
    if not state_is(initial, 'closed'):
        raise RuntimeError(f'fresh process is not closed: {initial}')
    record(log, {'at': timestamp(), 'phase': 'initial', 'pid': args.pid,
                 'launchEpoch': args.launch_epoch, 'exe': str(args.exe),
                 'exeSHA256': args.exe_sha, 'state': initial})
    target = args.launch_epoch + 600
    print(f'{timestamp()} PID={args.pid} warmup until {dt.datetime.fromtimestamp(target).isoformat()}', flush=True)
    while time.time() < target:
        time.sleep(min(10, max(0.1, target - time.time())))
        observed = inspect(args.gui, args.pid)
        record(log, {'at': timestamp(), 'phase': 'warmup', 'state': observed})
        if not state_is(observed, 'closed'):
            raise RuntimeError(f'warmup state changed: {observed}')
    for state in STATES:
        observed = transition(args.gui, args.pid, state) or inspect(args.gui, args.pid)
        record(log, {'at': timestamp(), 'phase': 'transition', 'expected': state,
                     'observed': observed})
        print(f'{timestamp()} state={state} settling 60s', flush=True)
        for _ in range(12):
            time.sleep(5)
            observed = inspect(args.gui, args.pid)
            if not state_is(observed, state):
                raise RuntimeError(f'settle state changed: {observed}')
        if state == 'settings' and observed['settings'] != EXPECTED_SETTINGS:
            raise RuntimeError(f'settings differ: {observed["settings"]}')
        for repeat in range(1, 4):
            for attempt in range(1, 4):
                if run_once(args, state, repeat, attempt, log):
                    break
                print(f'{timestamp()} invalid {state} r{repeat} a{attempt}', flush=True)
                if attempt == 3:
                    raise RuntimeError(f'3 consecutive invalid attempts: {state} r{repeat}')
                observed = transition(args.gui, args.pid, state) or inspect(args.gui, args.pid)
                time.sleep(60)
            else:
                raise RuntimeError('unreachable')
    print(f'{timestamp()} all 21 valid runs complete', flush=True)

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'{timestamp()} ERROR {error}', file=sys.stderr, flush=True)
        raise
