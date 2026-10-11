#!/usr/bin/env python3
"""요소별 닫힘 원본·후보의 유효 원시 실행 세 쌍을 대조한다."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_run(directory, repeat):
    summaries = sorted(directory.glob(f'closed-r{repeat}-a*.summary.json'))
    valid = [path for path in summaries if json.loads(path.read_text()).get('valid')]
    if len(valid) != 1:
        raise ValueError(f'{directory}/closed-r{repeat}: expected one valid attempt')
    name = valid[0].name.removesuffix('.summary.json')
    files = {suffix: directory / (name + extension) for suffix, extension in {
        'raw': '.jsonl', 'ax': '.ax.jsonl', 'events': '.events',
        'summary': '.summary.json',
    }.items()}
    summary = json.loads(files['summary'].read_text())
    records = [json.loads(line) for line in files['raw'].read_text().splitlines()]
    samples = [record for record in records if record['kind'] == 'sample']
    ax = [json.loads(line) for line in files['ax'].read_text().splitlines()]
    if not summary['valid'] or summary['reasons'] or summary['sampleCount'] != 301:
        raise ValueError(f'{directory}/{name}: invalid summary')
    if len(samples) != 301 or [row['sequence'] for row in samples] != list(range(301)):
        raise ValueError(f'{directory}/{name}: missing or reordered sample')
    if any(not row['valid'] or row['state'] != 'closed' or row['reasons'] for row in samples):
        raise ValueError(f'{directory}/{name}: invalid sample')
    if any(row['state'] != 'closed' for row in ax):
        raise ValueError(f'{directory}/{name}: AX state changed')
    if files['events'].read_text().strip() != 'closed':
        raise ValueError(f'{directory}/{name}: operator event changed')
    footprints = [row['footprintBytes'] for row in samples]
    return {
        'name': name, 'hashes': {key: digest(path) for key, path in files.items()},
        'pid': samples[0]['pid'], 'startTicks': samples[0]['startTicks'],
        'exePath': samples[0]['executablePath'],
        'settingsSource': samples[0]['settingsSource'],
        'settingsSHA256': samples[0]['settingsSHA256'],
        'cpuAveragePercent': summary['cpuAveragePercent'],
        'rssMaximumBytes': summary['rssMaximumBytes'],
        'footprintMinimumBytes': min(footprints),
        'footprintMedianBytes': statistics.median(footprints),
        'footprintMaximumBytes': summary['footprintMaximumBytes'],
        'footprintOver400MBCount': sum(value > 400_000_000 for value in footprints),
        'lifetimeMaximumFootprintBytes': summary['lifetimeMaximumFootprintBytes'],
        'maximumScheduleDelayMS': max(row['delayNS'] for row in samples) / 1_000_000,
        'axObservations': len(ax), 'sampleCount': len(samples), 'valid': True,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise RuntimeError('output exists')
    baseline = [read_run(args.baseline, repeat) for repeat in range(1, 4)]
    candidate = [read_run(args.candidate, repeat) for repeat in range(1, 4)]
    for label, runs in [('baseline', baseline), ('candidate', candidate)]:
        if len({run['pid'] for run in runs}) != 1 or len({run['startTicks'] for run in runs}) != 1:
            raise ValueError(f'{label}: process changed')
        if len({run['settingsSHA256'] for run in runs}) != 1:
            raise ValueError(f'{label}: settings changed')
    if baseline[0]['settingsSHA256'] != candidate[0]['settingsSHA256']:
        raise ValueError('settings differ between arms')
    if baseline[0]['settingsSHA256'] != '5588eace0f7e5afd6fd7fa8f43880a1834ea1e1d8cba751407d4dbf032f759c8':
        raise ValueError('settings do not match canonical defaults')
    pairs = [{
        'repeat': index + 1,
        'cpuReductionPercentagePoints': before['cpuAveragePercent'] - after['cpuAveragePercent'],
        'footprintMaximumReductionBytes': before['footprintMaximumBytes'] - after['footprintMaximumBytes'],
        'footprintMedianReductionBytes': before['footprintMedianBytes'] - after['footprintMedianBytes'],
        'rssMaximumReductionBytes': before['rssMaximumBytes'] - after['rssMaximumBytes'],
    } for index, (before, after) in enumerate(zip(baseline, candidate))]
    result = {
        'baseline': baseline, 'candidate': candidate, 'pairs': pairs,
        'baselineCpuRunRangePercentagePoints': max(run['cpuAveragePercent'] for run in baseline)
            - min(run['cpuAveragePercent'] for run in baseline),
        'baselineFootprintMaximumRunRangeBytes': max(run['footprintMaximumBytes'] for run in baseline)
            - min(run['footprintMaximumBytes'] for run in baseline),
        'allValid': True,
    }
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
