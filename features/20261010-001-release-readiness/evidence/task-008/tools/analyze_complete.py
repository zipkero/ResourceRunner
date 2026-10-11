"""task-008 판독 집계: analyze_boundary.py 결과(첫 픽셀 등)에 완전 표시 판독을 더해 시행별·묶음별로 낸다.
사용: python3 analyze_complete.py RUNS_DIR BOUNDARY_RESULTS_JSON CONTENT_MATCH_BIN OUT_JSON [SCALE] [CONTRAST]
완전 표시 = 열기 tap 뒤 첫 프레임 중 팝오버 경계 상자 폭이 최종(닫기 직전 프레임)의 SCALE(기본 0.60) 이상이고
대비(표준편차 비)가 CONTRAST(기본 0.60) 이상인 첫 프레임. 기준은 시행 사이에 고정한다.
최종 프레임은 analyze_boundary.py의 reference(닫기 tap 직전 마지막 프레임), 기준 프레임은 baseline(열기 tap 직전)이다."""
import json, pathlib, statistics, subprocess, sys

runs, bres, binp, out = map(pathlib.Path, sys.argv[1:5])
SCALE = float(sys.argv[5]) if len(sys.argv) > 5 else 0.60
CONTRAST = float(sys.argv[6]) if len(sys.argv) > 6 else 0.60
REGION = ['0', '48', '400', '712']  # 메뉴바·상태 항목 강조·화살표(y<48) 제외
res = json.loads(bres.read_text())
NUM, DEN = res['timebase']


def ms(a, b):
    return (a - b) * NUM / DEN / 1e6


rows = []
for t in res['trials']:
    trial = runs / t['trial']
    ev = [json.loads(l) for l in (trial / 'event.jsonl').read_text().splitlines()]
    tap, close_tap = ev[0]['observedMach'], ev[1]['observedMach']
    frames = [json.loads(l) for l in (trial / 'frames' / 'frames.jsonl').read_text().splitlines()]
    imgs = [r for r in frames if r.get('image')]
    t_of = {r['image']: r['displayTimeMach'] for r in imgs}
    out_lines = subprocess.check_output([str(binp), str(trial / 'frames'), t['pixels']['baseline'],
                                         t['pixels']['reference'], *REGION], text=True).splitlines()
    cm = {json.loads(l)['image']: json.loads(l) for l in out_lines}
    post = [r for r in imgs if tap <= r['displayTimeMach'] < close_tap]
    done = next((r for r in post if cm.get(r['image'], {}).get('scale', 0) >= SCALE
                 and cm[r['image']].get('contrast', 0) >= CONTRAST), None)
    prev = None
    if done:
        before = [r for r in imgs if r['displayTimeMach'] < done['displayTimeMach']]
        prev = before[-1] if before else None
    s = t['openSegmentsMsFromTap']
    rows.append({'trial': t['trial'], 'label': t['label'], 'axProbe': t['axProbe'],
                 'showDurationMs': t['showDurationMs'], 'showReturnMs': s['showReturn'],
                 'firstPixelMs': s['firstPixel'], 'firstPixelPrevMs': s['firstPixelPrev'],
                 'completeMs': done and ms(done['displayTimeMach'], tap),
                 'completePrevMs': prev and ms(prev['displayTimeMach'], tap),
                 'completeImage': done and done['image'],
                 'completeScale': done and cm[done['image']]['scale'],
                 'completeContrast': done and cm[done['image']]['contrast'],
                 'finalBBox': cm.get(t['pixels']['reference'], {}).get('bbox'),
                 'curve': [{'image': r['image'], 'tMs': ms(r['displayTimeMach'], tap),
                            **{k: cm.get(r['image'], {}).get(k) for k in ('scale', 'hscale', 'contrast', 'bbox')}}
                           for r in post if ms(r['displayTimeMach'], tap) <= 450]})


def summ(v):
    v = [x for x in v if x is not None]
    return v and {'n': len(v), 'median': statistics.median(v), 'min': min(v), 'max': max(v)}


groups = {'firstopen': [r for r in rows if r['label'] == 'firstopen'],
          'reopen': [r for r in rows if r['label'] != 'firstopen']}
agg = {g: {k: summ([r[k] for r in rs]) for k in ('showDurationMs', 'showReturnMs', 'firstPixelMs', 'completeMs')}
       for g, rs in groups.items()}
out.write_text(json.dumps({'criterion': {'scale': SCALE, 'contrast': CONTRAST, 'region': REGION},
                           'trials': rows, 'aggregate': agg}, indent=1, sort_keys=True) + '\n')
for r in rows:
    print(f"{r['trial']:20s} show {r['showDurationMs']:6.2f} firstPx {r['firstPixelMs'] or float('nan'):7.2f} "
          f"complete {r['completeMs'] or float('nan'):7.2f} (prev {r['completePrevMs'] or float('nan'):7.2f}) {r['completeImage']} "
          f"s={r['completeScale'] and round(r['completeScale'],3)} c={r['completeContrast'] and round(r['completeContrast'],3)}")
print(json.dumps(agg, indent=1))
