"""xctrace time-profile export(XML)에서 main thread 표본 중 지정 frame(기본 NSPopover show)을 포함한 것만 모아
그 frame 아래 호출을 inclusive 표본 수로 집계한다. 사용: python3 profile_show.py TP_XML [ANCHOR_SUBSTR] [DEPTH]"""
import collections, sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
anchor = sys.argv[2] if len(sys.argv) > 2 else 'showRelativeToRect'
depth = int(sys.argv[3]) if len(sys.argv) > 3 else 6
ids = {}


def resolve(el):
    ref = el.get('ref')
    if ref is not None:
        return ids[ref]
    if el.get('id') is not None:
        ids[el.get('id')] = el
    for child in el:
        resolve(child)
    return el


root = ET.parse(path).getroot()
rows = root.iter('row')
total_main = 0
hits = []
for row in rows:
    resolve(row)
    cols = list(row)
    thread = next(c for c in cols if c.tag == 'thread' or (c.get('ref') and ids[c.get('ref')].tag == 'thread'))
    thread = ids[thread.get('ref')] if thread.get('ref') else thread
    tname = thread.get('fmt', '')
    bt = next((c for c in cols if c.tag in ('tagged-backtrace', 'backtrace')), None)
    if bt is None:
        continue
    bt = ids[bt.get('ref')] if bt.get('ref') else bt
    frames = []
    for fr in bt.iter('frame'):
        fr = ids[fr.get('ref')] if fr.get('ref') else fr
        frames.append(fr.get('name', '?'))
    frames.reverse()  # root first
    if 'Main Thread' not in tname and '0x' in tname and not any('NSApplication run' in f or 'NSApplicationMain' in f for f in frames):
        continue
    total_main += 1
    idx = next((i for i, f in enumerate(frames) if anchor in f), None)
    if idx is not None:
        hits.append(frames[idx:])
print(f'main-thread samples {total_main}, samples under "{anchor}": {len(hits)}')
tree = collections.Counter()
for stack in hits:
    seen = set()
    for d in range(1, min(depth, len(stack)) + 1):
        key = tuple(stack[:d])
        if key not in seen:
            tree[key] += 1
            seen.add(key)
# print top-down with pruning <2%
def show(prefix, level):
    kids = [(k, v) for k, v in tree.items() if len(k) == len(prefix) + 1 and k[:len(prefix)] == prefix]
    for k, v in sorted(kids, key=lambda kv: -kv[1]):
        if v < max(2, 0.02 * len(hits)):
            continue
        print('  ' * level + f'{v:5d} {100*v/len(hits):5.1f}% {k[-1][:150]}')
        show(k, level + 1)
show((), 0)
# flat: leaf-ish self-ownership by module-like symbols containing keywords
flat = collections.Counter()
for stack in hits:
    for f in set(stack):
        flat[f] += 1
print('\nTOP inclusive symbols under anchor:')
for f, v in flat.most_common(int(sys.argv[4]) if len(sys.argv) > 4 else 70):
    print(f'{v:5d} {100*v/len(hits):5.1f}% {f[:160]}')
