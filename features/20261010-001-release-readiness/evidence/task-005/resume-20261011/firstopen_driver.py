import argparse, ctypes, hashlib, json, pathlib, subprocess, sys, time
p = argparse.ArgumentParser()
p.add_argument('pid', type=int)
p.add_argument('exe')
p.add_argument('exe_sha')
p.add_argument('output')
p.add_argument('--guard-mach', type=int)
a = p.parse_args()
out = pathlib.Path(a.output)
out.mkdir(parents=True, exist_ok=False)
mach = ctypes.CDLL('/usr/lib/libSystem.B.dylib').mach_absolute_time
mach.restype = ctypes.c_uint64
def now(): return mach()
def write(name, value): (out/name).write_text(json.dumps(value, sort_keys=True, indent=2)+'\n')
actual = hashlib.sha256(pathlib.Path(a.exe).read_bytes()).hexdigest()
comm = subprocess.check_output(['ps','-p',str(a.pid),'-o','comm='],text=True).strip()
start = {'epoch': time.time(), 'mach': now(), 'pid': a.pid, 'exe': a.exe,
         'exeSHA256': actual, 'psComm': comm, 'guardMach': a.guard_mach}
write('identity.json', start)
if actual != a.exe_sha or comm != a.exe:
 sys.exit('target identity mismatch')
commands = {
 'frame': ['/private/tmp/resourcerunner-task005-external-frame-probe-resume-r3',str(a.pid),str(out/'frames'),'10','--fixed-roi'],
 'event': ['/private/tmp/resourcerunner-task005-target-event-probe-resume-r3',str(a.pid),str(out/'event.jsonl'),'10'],
 'ax': ['/private/tmp/resourcerunner-task005-target-ax-probe-resume',str(a.pid),str(out/'ax.jsonl'),'10'],
}
processes = {}
files = {}
try:
 for name, command in commands.items():
  stdout = open(out/(name+'.stdout'),'w')
  stderr = open(out/(name+'.stderr'),'w')
  files[name]=(stdout,stderr)
  processes[name]=subprocess.Popen(command,stdout=stdout,stderr=stderr)
 deadline=time.monotonic()+3
 ready=False
 while time.monotonic()<deadline:
  event_ready=(out/'event.stdout').exists() and 'ready' in (out/'event.stdout').read_text()
  frames=out/'frames'/'frames.jsonl'
  frame_lines=frames.read_text().splitlines() if frames.exists() else []
  frame_ready=any(
   (entry.get('status') == 0 and entry.get('image') and
    (out/'frames'/entry['image']).is_file())
   for entry in (json.loads(line) for line in frame_lines)
  )
  image_budget_ok=sum(1 for line in frame_lines if '"image":' in line)<128
  ax=out/'ax.jsonl'
  ax_ready=ax.exists() and ax.stat().st_size>0
  running=all(proc.poll() is None for proc in processes.values())
  if event_ready and frame_ready and ax_ready and running and image_budget_ok:
   ready=True
   break
  time.sleep(0.02)
 before={'epoch':time.time(),'mach':now(),'ready':ready,'eventReady':event_ready,
         'frameReady':frame_ready,'axReady':ax_ready,'running':running,'imageBudgetOK':image_budget_ok,'baselineImages':sum(1 for line in frame_lines if '"image":' in line)}
 if a.guard_mach is not None:
  before['guardElapsedSeconds']=(before['mach']-a.guard_mach)*125/3/1e9
  ready=ready and before['guardElapsedSeconds']>=600
 write('before-input.json',before)
 if not ready: sys.exit('probes not ready or guard incomplete; no click')
 click_start=now()
 gui=subprocess.run(['/private/tmp/resourcerunner-task005-gui-state-resume',str(a.pid),'toggle'],
                    capture_output=True,text=True)
 (out/'gui-after-click.stdout').write_text(gui.stdout)
 (out/'gui-after-click.stderr').write_text(gui.stderr)
 write('click-call.json',{'startMach':click_start,'endMach':now(),'exitCode':gui.returncode})
 for proc in processes.values(): proc.wait(timeout=20)
 write('probe-exits.json',{name:proc.returncode for name,proc in processes.items()})
 if gui.returncode or any(proc.returncode for proc in processes.values()): sys.exit('click or probe failure')
finally:
 for proc in processes.values():
  if proc.poll() is None:
   proc.terminate()
   try: proc.wait(timeout=2)
   except subprocess.TimeoutExpired: proc.kill()
 for stdout,stderr in files.values():
  stdout.close(); stderr.close()
