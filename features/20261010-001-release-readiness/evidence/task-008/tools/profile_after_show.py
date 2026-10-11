"""show 표본 묶음(열림)마다 마지막 show 표본 뒤 WINDOW ms 안의 main thread 표본을 모아 상위 frame을 집계한다.
사용: python3 profile_after_show.py TP_XML [WINDOW_MS]"""
import collections, sys
import xml.etree.ElementTree as ET
ids = {}
def reg(el):
    if el.get('id') is not None: ids[el.get('id')] = el
    for c in el: reg(c)
def deref(el): return ids[el.get('ref')] if el.get('ref') else el
win = float(sys.argv[2]) if len(sys.argv) > 2 else 60
root = ET.parse(sys.argv[1]).getroot()
main = []
for row in root.iter('row'):
    reg(row)
    cols = [deref(c) for c in row]
    t = int(next(c for c in cols if c.tag == 'sample-time').text)
    th = next(c for c in cols if c.tag == 'thread').get('fmt', '')
    bt = next((c for c in cols if c.tag in ('tagged-backtrace', 'backtrace')), None)
    if bt is None: continue
    frames = [deref(f).get('name', '?') for f in bt.iter('frame')][::-1]
    if not any('NSApplication run' in f or 'NSApplicationMain' in f for f in frames): continue
    main.append((t, frames))
main.sort()
shows = [t for t, f in main if any('showRelativeToRect' in x for x in f)]
ends, last = [], None
for t in shows:
    if last is not None and t - last > 300e6: ends.append(last)
    last = t
ends.append(last)
c, n = collections.Counter(), 0
per = []
for e in ends:
    sel = [f for t, f in main if e < t <= e + win * 1e6 and not any('showRelativeToRect' in x for x in f)]
    per.append(len(sel)); n += len(sel)
    for f in sel:
        key = next((x for x in f if x.startswith('CA::Transaction::commit')), None) or \
              next((x for x in f if 'Task' in x or 'togglePopover' in x), None) or f[min(len(f) - 1, 12)]
        c[key] += 1
print('opens', len(ends), 'main samples within', win, 'ms after last show sample per open:', per)
for k, v in c.most_common(15): print(f'{v:5d} {k[:140]}')
