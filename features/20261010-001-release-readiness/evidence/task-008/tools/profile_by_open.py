"""xctrace time-profile XML에서 NSPopover show 아래 main thread 표본을 열림별(시간 간격 300ms 이상으로 분리)로 나누고
첫 열림과 이후 열림의 상위 inclusive 기호를 비교한다. 사용: python3 profile_by_open.py TP_XML"""
import collections, sys
import xml.etree.ElementTree as ET
ids = {}
def reg(el):
    if el.get('id') is not None: ids[el.get('id')] = el
    for c in el: reg(c)
def deref(el): return ids[el.get('ref')] if el.get('ref') else el
root = ET.parse(sys.argv[1]).getroot()
samples = []
for row in root.iter('row'):
    reg(row)
    cols = [deref(c) for c in row]
    t = int(next(c for c in cols if c.tag == 'sample-time').text)
    bt = next((c for c in cols if c.tag in ('tagged-backtrace', 'backtrace')), None)
    if bt is None: continue
    frames = [deref(f).get('name', '?') for f in bt.iter('frame')][::-1]
    i = next((k for k, f in enumerate(frames) if 'showRelativeToRect' in f), None)
    if i is not None: samples.append((t, frames[i:]))
samples.sort()
groups, last = [], None
for t, st in samples:
    if last is None or t - last > 300e6: groups.append([])
    groups[-1].append(st); last = t
print('samples per open:', [len(g) for g in groups])
def flat(gs):
    c = collections.Counter()
    for st in gs:
        for f in set(st): c[f] += 1
    return c
first, rest = flat(groups[0]), flat([s for g in groups[1:] for s in g])
n_rest = len(groups) - 1
print(f'{"first":>6} {"rest/open":>9}  symbol')
keys = sorted(set(first) | set(rest), key=lambda k: -(first[k] - rest[k] / n_rest))
for k in keys[:45]:
    print(f'{first[k]:6d} {rest[k]/n_rest:9.1f}  {k[:140]}')
