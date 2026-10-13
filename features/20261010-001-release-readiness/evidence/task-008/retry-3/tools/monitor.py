"""task-008 retry-3 배경 기록: HIDIdleTime(0.25초 간격)과 top 상위 CPU 프로세스(2초 간격)를 epoch와 함께 JSONL로 남긴다.
사용: python3 monitor.py OUT_DIR  (SIGTERM으로 끝낸다)"""
import json, pathlib, re, signal, subprocess, sys, threading, time

out = pathlib.Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
stop = threading.Event()
signal.signal(signal.SIGTERM, lambda *_: stop.set())


def hid():
    with open(out / 'hid-idle.jsonl', 'a') as f:
        while not stop.is_set():
            text = subprocess.check_output(['ioreg', '-c', 'IOHIDSystem'], text=True)
            v = next((int(l.split('=')[-1].strip()) / 1e9 for l in text.splitlines() if 'HIDIdleTime' in l), None)
            f.write(json.dumps({'epoch': time.time(), 'hidIdleSeconds': v}) + '\n')
            f.flush()
            stop.wait(0.25)


def top():
    p = subprocess.Popen(['top', '-l', '0', '-s', '2', '-o', 'cpu', '-n', '8', '-stats', 'pid,command,cpu'],
                         stdout=subprocess.PIPE, text=True)
    block = None
    with open(out / 'top.jsonl', 'a') as f:
        for line in p.stdout:
            if stop.is_set():
                break
            if line.startswith('Processes:'):
                if block and block.get('procs') is not None:
                    f.write(json.dumps(block) + '\n')
                    f.flush()
                block = {'epoch': time.time(), 'procs': None}
            elif block is None:
                continue
            elif line.startswith('CPU usage:'):
                m = re.findall(r'([\d.]+)% (user|sys|idle)', line)
                block['cpu'] = {k: float(v) for v, k in m}
            elif line.startswith('PID'):
                block['procs'] = []
            elif block.get('procs') is not None and line.strip():
                parts = line.split()
                try:
                    block['procs'].append({'pid': int(parts[0]), 'command': ' '.join(parts[1:-1]),
                                           'cpu': float(parts[-1])})
                except ValueError:
                    pass
    p.terminate()


threads = [threading.Thread(target=hid, daemon=True), threading.Thread(target=top, daemon=True)]
for t in threads:
    t.start()
while not stop.is_set():
    stop.wait(0.5)
