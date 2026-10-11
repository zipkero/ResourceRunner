"""task-005 경계 진단 1시행: 외부 PID tap·프레임 probe(선택 AX probe)를 띄우고
준비 확인 뒤 같은 프로세스 흐름에서 열기 클릭, 1.5초 뒤 닫기 클릭을 보낸다.
firstopen_driver.py의 준비 조건을 따르며 600초 guard는 쓰지 않는다(오차 측정용)."""
import argparse, ctypes, hashlib, json, pathlib, subprocess, sys, time

p = argparse.ArgumentParser()
p.add_argument('pid', type=int)
p.add_argument('exe')
p.add_argument('exe_sha')
p.add_argument('output')
p.add_argument('--ax', action='store_true')
p.add_argument('--label', default='')
a = p.parse_args()
out = pathlib.Path(a.output)
out.mkdir(parents=True, exist_ok=False)
mach = ctypes.CDLL('/usr/lib/libSystem.B.dylib').mach_absolute_time
mach.restype = ctypes.c_uint64
GUI = '/private/tmp/resourcerunner-task005-gui-state-resume'


def write(name, value):
    (out / name).write_text(json.dumps(value, sort_keys=True, indent=2) + '\n')


def hid_idle_seconds():
    text = subprocess.check_output(['ioreg', '-c', 'IOHIDSystem'], text=True)
    for line in text.splitlines():
        if 'HIDIdleTime' in line:
            return int(line.split('=')[-1].strip()) / 1e9
    return None


actual = hashlib.sha256(pathlib.Path(a.exe).read_bytes()).hexdigest()
comm = subprocess.check_output(['ps', '-p', str(a.pid), '-o', 'comm='], text=True).strip()
write('identity.json', {'epoch': time.time(), 'mach': mach(), 'pid': a.pid, 'exe': a.exe,
                        'exeSHA256': actual, 'psComm': comm, 'label': a.label, 'ax': a.ax,
                        'hidIdleSecondsBefore': hid_idle_seconds()})
if actual != a.exe_sha or comm != a.exe:
    sys.exit('target identity mismatch')
commands = {
    'frame': ['/private/tmp/resourcerunner-task005-external-frame-probe-resume-r3', str(a.pid),
              str(out / 'frames'), '10', '--fixed-roi'],
    'event': ['/private/tmp/resourcerunner-task005-target-event-probe-resume-r3', str(a.pid),
              str(out / 'event.jsonl'), '10'],
}
if a.ax:
    commands['ax'] = ['/private/tmp/resourcerunner-task005-target-ax-probe-resume', str(a.pid),
                      str(out / 'ax.jsonl'), '10']
processes, files = {}, {}
try:
    for name, command in commands.items():
        stdout = open(out / (name + '.stdout'), 'w')
        stderr = open(out / (name + '.stderr'), 'w')
        files[name] = (stdout, stderr)
        processes[name] = subprocess.Popen(command, stdout=stdout, stderr=stderr)
    deadline = time.monotonic() + 3
    ready = False
    while time.monotonic() < deadline:
        event_ready = (out / 'event.stdout').exists() and 'ready' in (out / 'event.stdout').read_text()
        frames = out / 'frames' / 'frames.jsonl'
        frame_lines = frames.read_text().splitlines() if frames.exists() else []
        rows = []
        for line in frame_lines:
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        frame_ready = any(r.get('status') == 0 and r.get('image') and
                          (out / 'frames' / r['image']).is_file() for r in rows)
        images = sum(1 for r in rows if r.get('image'))
        ax_ready = (not a.ax) or ((out / 'ax.jsonl').exists() and (out / 'ax.jsonl').stat().st_size > 0)
        running = all(proc.poll() is None for proc in processes.values())
        if event_ready and frame_ready and ax_ready and running and images < 128:
            ready = True
            break
        time.sleep(0.02)
    write('before-input.json', {'mach': mach(), 'ready': ready, 'baselineImages': images})
    if not ready:
        sys.exit('probes not ready; no click')
    clicks = []
    for step in ('open', 'close'):
        start = mach()
        gui = subprocess.run([GUI, str(a.pid), 'toggle'], capture_output=True, text=True)
        clicks.append({'step': step, 'startMach': start, 'endMach': mach(),
                       'exitCode': gui.returncode, 'stdout': gui.stdout, 'stderr': gui.stderr})
        if gui.returncode:
            break
        if step == 'open':
            time.sleep(1.5)
    write('click-calls.json', clicks)
    for proc in processes.values():
        proc.wait(timeout=20)
    write('probe-exits.json', {name: proc.returncode for name, proc in processes.items()})
    if any(c['exitCode'] for c in clicks) or any(proc.returncode for proc in processes.values()):
        sys.exit('click or probe failure')
finally:
    for proc in processes.values():
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
    for stdout, stderr in files.values():
        stdout.close()
        stderr.close()
