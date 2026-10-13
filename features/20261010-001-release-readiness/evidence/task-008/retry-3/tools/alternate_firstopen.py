"""task-008 retry-3 첫 열림 교대 측정: 대조군(A)과 개선 후(B)를 A,B,A,B… 순서로 새 프로세스에서 첫 열림 1회씩 시행한다.
각 시행은 상위 tools/run_variant.py를 --reopens 0 --settle 20 으로 부른다(재열림 없음).
시행 뒤 monitor.py 기록으로 입력·부하 조건을 판정하고, 무효면 같은 쪽을 바로 다시 시행한다.
사용: python3 alternate_firstopen.py RUN_VARIANT CONTROL_APP PRODUCT_APP RUNS_DIR MONITOR_DIR PLAN_JSON [--per-side 6] [--warmup]
판정 기준(시행 전에 고정):
  - 입력: click 직전 driver HIDIdle >= 18초, launch~click+2초 구간 HIDIdle 표본이 단조 증가(감소 0.5초 초과 없음), event.jsonl 2행.
  - 부하: launch~click 구간 top 표본(첫 표본 제외)에서 측정 무관 프로세스 하나라도 >= 50% CPU 이거나 user+sys >= 25%면 무효."""
import argparse, json, pathlib, subprocess, sys, time

ap = argparse.ArgumentParser()
for k in ('run_variant', 'control', 'product', 'runs', 'monitor', 'plan_out'):
    ap.add_argument(k)
ap.add_argument('--per-side', type=int, default=6)
ap.add_argument('--warmup', action='store_true')
ap.add_argument('--gap', type=float, default=8)
ap.add_argument('--max-attempts', type=int, default=30)
a = ap.parse_args()
runs, mon = pathlib.Path(a.runs), pathlib.Path(a.monitor)
runs.mkdir(parents=True, exist_ok=True)
APPS = {'A': a.control, 'B': a.product}
IGNORE = ('top', 'ResourceRunner', 'python3', 'Python', 'resourcerunner-task005', 'ioreg')


def rows(name):
    p = mon / name
    return [json.loads(l) for l in p.read_text().splitlines() if l.strip()] if p.exists() else []


def judge(out):
    launch = json.loads((out / 'launch.json').read_text())
    trial = out / 'trial-00-firstopen'
    ident = json.loads((trial / 'identity.json').read_text())
    events = (trial / 'event.jsonl').read_text().splitlines() if (trial / 'event.jsonl').exists() else []
    t0, t1 = launch['openEpoch'], ident['epoch']
    hid = [r for r in rows('hid-idle.jsonl') if t0 <= r['epoch'] <= t1 + 0.0]
    drops = [(p['epoch'], p['hidIdleSeconds'], q['hidIdleSeconds']) for p, q in zip(hid, hid[1:])
             if q['hidIdleSeconds'] + 0.5 < p['hidIdleSeconds']]
    tops = [r for r in rows('top.jsonl')[1:] if t0 <= r['epoch'] <= t1 + 1.0]
    hot = [(r['epoch'], p['command'], p['cpu']) for r in tops for p in r['procs']
           if p['cpu'] >= 50 and not any(x in p['command'] for x in IGNORE)]
    busy = [(r['epoch'], r['cpu']['user'] + r['cpu']['sys']) for r in tops
            if r.get('cpu') and r['cpu']['user'] + r['cpu']['sys'] >= 25]
    last_top = max((r for r in tops), key=lambda r: r['epoch'], default=None)
    reasons = []
    if ident['hidIdleSecondsBefore'] is None or ident['hidIdleSecondsBefore'] < 18:
        reasons.append(f"driver HIDIdle {ident['hidIdleSecondsBefore']} < 18")
    if drops:
        reasons.append(f'HIDIdle drop during settle {drops[:3]}')
    if len(events) != 2:
        reasons.append(f'event rows {len(events)} != 2')
    if not tops:
        reasons.append('no top sample')
    if hot:
        reasons.append(f'hot process {hot[:3]}')
    if busy:
        reasons.append(f'total cpu busy {busy[:3]}')
    status = json.loads((out / 'trial-status.json').read_text())
    if not status or status[0]['exit'] != 0:
        reasons.append(f'driver status {status}')
    return {'pid': launch['pid'], 'exeSHA256': launch['exeSHA256'], 'launchEpoch': t0, 'clickIdentityEpoch': t1,
            'driverHidIdleBefore': ident['hidIdleSecondsBefore'],
            'hidSamples': len(hid), 'hidMinInWindow': min((r['hidIdleSeconds'] for r in hid), default=None),
            'topSamples': len(tops), 'lastTopBeforeClick': last_top,
            'valid': not reasons, 'invalidReasons': reasons}


plan = []
if a.warmup:
    plan += [('W', 'A'), ('W', 'B')]
for i in range(a.per_side):
    plan += [('M', 'A'), ('M', 'B')]
log, attempts, seq = [], 0, 0
try:
    for kind, side in plan:
        while True:
            attempts += 1
            if attempts > a.max_attempts:
                sys.exit('too many attempts')
            seq += 1
            name = f'{seq:02d}-{"warmup" if kind == "W" else "measure"}-{side}'
            out = runs / name
            r = subprocess.run([sys.executable, a.run_variant, APPS[side], str(out), '--reopens', '0', '--settle', '20'],
                               capture_output=True, text=True)
            (runs / f'{name}.runner.log').write_text(r.stdout + r.stderr)
            try:
                j = judge(out)
            except Exception as e:
                j = {'valid': False, 'invalidReasons': [f'judge error {e!r}']}
            entry = {'seq': seq, 'name': name, 'kind': kind, 'side': side, 'runnerExit': r.returncode, **j}
            log.append(entry)
            pathlib.Path(a.plan_out).write_text(json.dumps(log, indent=1) + '\n')
            print(name, 'valid' if j['valid'] else f"INVALID {j['invalidReasons']}", flush=True)
            time.sleep(a.gap)
            if j['valid'] or kind == 'W':
                break
finally:
    pathlib.Path(a.plan_out).write_text(json.dumps(log, indent=1) + '\n')
