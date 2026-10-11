"""task-008 진단 변형 1회 실행: 새 프로세스를 띄워 task-005 경계 진단과 같은 방식으로
첫 열림 1회(AX probe 켬) 뒤 재열림 N회(홀수 AX 끔/짝수 AX 켬)를 boundary_driver.py로 연속 시행한다.
사용: python3 run_variant.py APP_PATH OUT_DIR [--reopens N] [--settle 20]
앱 내부 진단 기록(container tmp/task005-boundary-<pid>.jsonl)을 OUT_DIR/app-events-<pid>.jsonl로 복사하고 앱을 종료한다."""
import argparse, hashlib, json, pathlib, shutil, subprocess, sys, time

p = argparse.ArgumentParser()
p.add_argument('app')
p.add_argument('out')
p.add_argument('--reopens', type=int, default=18)
p.add_argument('--settle', type=float, default=20)
a = p.parse_args()
here = pathlib.Path(__file__).resolve().parent
out = pathlib.Path(a.out)
out.mkdir(parents=True, exist_ok=False)
exe = str(pathlib.Path(a.app) / 'Contents/MacOS/ResourceRunner')
sha = hashlib.sha256(pathlib.Path(exe).read_bytes()).hexdigest()
CONTAINER = pathlib.Path.home() / 'Library/Containers/com.zipkero.ResourceRunner.Task005PerfDiagnostic/Data/tmp'


def pids():
    rows = subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True).splitlines()
    return [int(r.split(None, 1)[0]) for r in rows if r.split(None, 1)[1:] == [exe]]


if pids():
    sys.exit('diagnostic already running')
if any('Task005PerfDiagnostic' in l for l in subprocess.check_output(['ps', '-axo', 'comm='], text=True).splitlines()):
    sys.exit('another diagnostic running')
before = time.time()
subprocess.run(['open', '-n', a.app], check=True)
pid = None
for _ in range(100):
    found = pids()
    if found:
        pid = found[0]
        break
    time.sleep(0.05)
if pid is None:
    sys.exit('launch failed')
lstart = subprocess.check_output(['ps', '-p', str(pid), '-o', 'lstart='], text=True).strip()
launch = {'app': a.app, 'exe': exe, 'exeSHA256': sha, 'pid': pid, 'lstart': lstart, 'openEpoch': before,
          'settleSeconds': a.settle, 'reopens': a.reopens}
(out / 'launch.json').write_text(json.dumps(launch, indent=2, sort_keys=True) + '\n')
time.sleep(a.settle)
plan = [('trial-00-firstopen', True, 'firstopen')]
for i in range(1, a.reopens + 1):
    plan.append((f'trial-{i:02d}-{"A" if i % 2 else "B"}', i % 2 == 0, 'reopen-' + ('A' if i % 2 else 'B')))
status = []
try:
    for name, ax, label in plan:
        cmd = [sys.executable, str(here / 'boundary_driver.py'), str(pid), exe, sha, str(out / name), '--label', label]
        if ax:
            cmd.append('--ax')
        r = subprocess.run(cmd, capture_output=True, text=True)
        (out / name / 'driver.log').write_text(r.stdout + r.stderr) if (out / name).exists() else None
        status.append({'trial': name, 'exit': r.returncode})
        if r.returncode:
            break
finally:
    (out / 'trial-status.json').write_text(json.dumps(status, indent=2) + '\n')
    log = CONTAINER / f'task005-boundary-{pid}.jsonl'
    time.sleep(1)
    if log.exists():
        shutil.copy2(log, out / f'app-events-{pid}.jsonl')
        log.unlink()
    subprocess.run(['kill', str(pid)])
    for _ in range(100):
        if not pids():
            break
        time.sleep(0.05)
    (out / 'exit.json').write_text(json.dumps({'pid': pid, 'stillRunning': bool(pids()), 'epoch': time.time()}) + '\n')
print(json.dumps(status))
