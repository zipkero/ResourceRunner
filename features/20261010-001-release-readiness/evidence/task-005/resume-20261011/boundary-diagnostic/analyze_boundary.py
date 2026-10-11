"""task-005 경계 진단 계산: 외부 PID tap·프레임 displayTime·앱 내부 기록을 같은 mach 시계로 묶는다.
사용: python3 analyze_boundary.py RUNS_DIR APP_EVENTS_JSONL PIXEL_DIFF_BIN OUT_JSON
CGEventTimestamp(ns)는 mach tick * numer/denom 이며 timebase는 앱 install 행에서 읽는다."""
import json, pathlib, statistics, subprocess, sys

runs, app_log, pixel_bin, out_json = map(pathlib.Path, sys.argv[1:5])
app = [json.loads(l) for l in app_log.read_text().splitlines()]
install = next(r for r in app if r['name'] == 'install')
NUM, DEN = install['timebaseNumer'], install['timebaseDenom']
# 팝오버 고정 영역(ROI JPEG 1x 좌표, 위쪽 기준). 메뉴바 행과 상태 항목 강조를 제외한다.
REGION = ['80', '28', '240', '492']


def ms(a, b):
    return None if a is None or b is None else (a - b) * NUM / DEN / 1e6


def ns_to_mach(ns):
    return ns * DEN / NUM


def by_cg(ts, hook, etype):
    rows = [r for r in app if r['name'] == 'event' and r.get('cgTimestamp') == ts
            and r['hook'] == hook and r['type'] == etype]
    return rows[0] if rows else None


def first_after(name, mach, until=None, **match):
    for r in app:
        if r['name'] == name and r['mach'] >= mach and (until is None or r['mach'] < until) \
                and all(r.get(k) == v for k, v in match.items()):
            return r
    return None


def mouse_down_before(up_row):
    downs = [r for r in app if r['name'] == 'event' and r['hook'] == 'nextEventReturn'
             and r['type'] == 1 and r['mach'] <= up_row['mach']]
    return downs[-1] if downs else None


def pixels(trial, tap, close_tap):
    rows = [json.loads(l) for l in (trial / 'frames' / 'frames.jsonl').read_text().splitlines()]
    imgs = [r for r in rows if r.get('image')]
    base = [r for r in imgs if r['displayTimeMach'] < tap][-1]
    ref = [r for r in imgs if r['displayTimeMach'] < close_tap][-1]
    out = subprocess.check_output([str(pixel_bin), str(trial / 'frames'), base['image'], ref['image'],
                                   *REGION], text=True)
    stats = {json.loads(l)['image']: json.loads(l) for l in out.splitlines()}
    post = [r for r in imgs if tap <= r['displayTimeMach'] < close_tap]
    plateau = statistics.median(stats[r['image']]['baseMean'] for r in post
                                if ms(r['displayTimeMach'], tap) >= 400)
    first = next((r for r in post if stats[r['image']]['baseMean'] > 0.01), None)
    visible = next((r for r in post if stats[r['image']]['baseFrac'] >= 0.01), None)
    full = next((r for r in post if stats[r['image']]['baseMean'] >= 0.97 * plateau), None)
    prev = None
    if first:
        before = [r for r in imgs if r['displayTimeMach'] < first['displayTimeMach']]
        prev = before[-1] if before else None
    # 프레임 사이 간격: 직전 저장 프레임과의 displayTime 차이가 그 경계의 관측 불확실성이다.
    gaps = [ms(b['displayTimeMach'], a['displayTimeMach']) for a, b in zip(post, post[1:])
            if ms(b['displayTimeMach'], tap) <= 400]
    return {'baseline': base['image'], 'reference': ref['image'], 'plateauMean': plateau,
            'firstPixel': first and {'image': first['image'], 'mach': first['displayTimeMach']},
            'firstPixelPrevMach': prev and prev['displayTimeMach'],
            'visible1pct': visible and {'image': visible['image'], 'mach': visible['displayTimeMach']},
            'animationFull97': full and {'image': full['image'], 'mach': full['displayTimeMach']},
            'maxFrameGapMsTo400': max(gaps) if gaps else None,
            'curve': [{'image': r['image'], 'tMs': ms(r['displayTimeMach'], tap),
                       'baseMean': stats[r['image']]['baseMean'], 'baseFrac': stats[r['image']]['baseFrac']}
                      for r in post if ms(r['displayTimeMach'], tap) <= 400]}


def boundary(ev):
    up = by_cg(ev['eventTimestamp'], 'nextEventReturn', 2)
    created = ns_to_mach(ev['eventTimestamp'])
    down = mouse_down_before(up) if up else None
    return up, {
        'tapObservedMach': ev['observedMach'], 'createdMach': created,
        'appUpDequeueMach': up and up['mach'],
        'appWakeMach': up and up['lastAfterWaitingMach'],
        'appDownDequeueMach': down and down['mach'],
        'tapMinusAppUpDequeueMs': up and ms(ev['observedMach'], up['mach']),
        'tapMinusCreatedMs': ms(ev['observedMach'], created),
        'appUpDequeueMinusCreatedMs': up and ms(up['mach'], created),
        'appWakeMinusTapMs': up and ms(up['lastAfterWaitingMach'], ev['observedMach']),
        'appMainBusyAtArrival': bool(up and down and down['lastBeforeWaitingMach'] > ev['observedMach']),
    }


results = []
for trial in sorted(p for p in runs.glob('trial-*') if p.is_dir()):
    events = [json.loads(l) for l in (trial / 'event.jsonl').read_text().splitlines()]
    identity = json.loads((trial / 'identity.json').read_text())
    open_ev, close_ev = events
    up, ob = boundary(open_ev)
    _, cb = boundary(close_ev)
    tap = open_ev['observedMach']
    toggle = first_after('event', up['mach'], hook='togglePopoverEnter')
    seg = {}
    for name in ['openBegin', 'contentControllerAssigned', 'viewportUpdated', 'activateReturn',
                 'popoverWillShow', 'showReturn', 'openEnd', 'popoverDidShow']:
        r = first_after(name, up['mach'], close_ev['observedMach'])
        seg[name] = r and r['mach']
    commit = first_after('beforeWaitingAfter', up['mach'], close_ev['observedMach'], label='open')
    occl = first_after('popoverWindowOcclusion', up['mach'], close_ev['observedMach'], visible=True)
    seg['firstBeforeWaitingAfterOpen'] = commit and commit['mach']
    seg['occlusionVisible'] = occl and occl['mach']
    px = pixels(trial, tap, close_ev['observedMach'])
    rel = {k: ms(v, tap) for k, v in seg.items()}
    rel['togglePopoverEnter'] = ms(toggle['mach'], tap)
    rel['firstPixel'] = px['firstPixel'] and ms(px['firstPixel']['mach'], tap)
    rel['firstPixelPrev'] = ms(px['firstPixelPrevMach'], tap)
    rel['visible1pct'] = px['visible1pct'] and ms(px['visible1pct']['mach'], tap)
    rel['animationFull97'] = px['animationFull97'] and ms(px['animationFull97']['mach'], tap)
    results.append({'trial': trial.name, 'label': identity['label'], 'axProbe': identity['ax'],
                    'hidIdleSecondsBefore': identity['hidIdleSecondsBefore'],
                    'openBoundary': ob, 'closeBoundary': cb, 'openSegmentsMsFromTap': rel,
                    'appUpToShowCallMs': ms(seg['openBegin'], up['mach']),
                    'showDurationMs': ms(seg['showReturn'], seg['activateReturn']),
                    'showReturnToFirstPixelMs': px['firstPixel'] and ms(px['firstPixel']['mach'], seg['showReturn']),
                    'firstPixelToFull97Ms': px['firstPixel'] and px['animationFull97'] and
                    ms(px['animationFull97']['mach'], px['firstPixel']['mach']),
                    'pixels': px})


def summary(values):
    values = [v for v in values if v is not None]
    return {'n': len(values), 'min': min(values), 'median': statistics.median(values), 'max': max(values)}


reopen = [r for r in results if r['label'] != 'firstopen']
groups = {'all': results, 'reopen': reopen,
          'reopenA_noAX': [r for r in reopen if not r['axProbe']],
          'reopenB_AX': [r for r in reopen if r['axProbe']]}
agg = {}
for gname, rows in groups.items():
    bounds = [r['openBoundary'] for r in rows] + [r['closeBoundary'] for r in rows]
    agg[gname] = {
        'tapMinusAppUpDequeueMs_openClose': summary([b['tapMinusAppUpDequeueMs'] for b in bounds]),
        'appUpDequeueMinusCreatedMs_openClose': summary([b['appUpDequeueMinusCreatedMs'] for b in bounds]),
        'tapMinusCreatedMs_openClose': summary([b['tapMinusCreatedMs'] for b in bounds]),
        **{k: summary([r['openSegmentsMsFromTap'][k] for r in rows]) for k in
           ['togglePopoverEnter', 'activateReturn', 'showReturn', 'firstBeforeWaitingAfterOpen',
            'occlusionVisible', 'firstPixel', 'visible1pct', 'animationFull97', 'popoverDidShow']},
        'showDurationMs': summary([r['showDurationMs'] for r in rows]),
        'showReturnToFirstPixelMs': summary([r['showReturnToFirstPixelMs'] for r in rows]),
        'firstPixelToFull97Ms': summary([r['firstPixelToFull97Ms'] for r in rows]),
        'maxFrameGapMsTo400': summary([r['pixels']['maxFrameGapMsTo400'] for r in rows]),
    }
out_json.write_text(json.dumps({'timebase': [NUM, DEN], 'region': REGION, 'trials': results,
                                'aggregate': agg}, indent=1, sort_keys=True) + '\n')


def f(v):
    return '-' if v is None else f'{v:+.2f}' if isinstance(v, float) and v < 0 else f'{v:.2f}'


print('| trial | AX probe | tap−app up 열기 | tap−app up 닫기 | app up−생성 열기/닫기 | toggle | activate 반환 | show 반환 | 첫 commit | occlusion visible | 첫 픽셀(직전 프레임) | 1% 변화 | 애니메이션 97% | didShow |')
print('|' + '---|' * 14)
for r in results:
    o, c, s = r['openBoundary'], r['closeBoundary'], r['openSegmentsMsFromTap']
    print(f"| {r['trial']} | {'Y' if r['axProbe'] else 'N'} | {f(o['tapMinusAppUpDequeueMs'])} | {f(c['tapMinusAppUpDequeueMs'])} | "
          f"{f(o['appUpDequeueMinusCreatedMs'])} / {f(c['appUpDequeueMinusCreatedMs'])} | {f(s['togglePopoverEnter'])} | "
          f"{f(s['activateReturn'])} | {f(s['showReturn'])} | {f(s['firstBeforeWaitingAfterOpen'])} | {f(s['occlusionVisible'])} | "
          f"{f(s['firstPixel'])} ({f(s['firstPixelPrev'])}) | {f(s['visible1pct'])} | {f(s['animationFull97'])} | {f(s['popoverDidShow'])} |")
print()
print(json.dumps(agg, indent=1, ensure_ascii=False))
