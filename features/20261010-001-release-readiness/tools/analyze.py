#!/usr/bin/env python3
"""원시 JSONL 실행 전체를 재계산하고 무효 사유를 보존합니다."""

import argparse
import json
import math
from pathlib import Path


def convert_ticks(ticks, numer, denom):
    if ticks < 0 or numer <= 0 or denom <= 0:
        raise ValueError("invalid Mach input")
    whole, remainder = divmod(ticks, denom)
    result = whole * numer + remainder * numer // denom
    if result > 2**64 - 1:
        raise ValueError("Mach overflow")
    return result


def analyze(records):
    samples = [record for record in records if record.get("kind") == "sample"]
    events = [record for record in records if record.get("kind") == "event"]
    reasons = set()
    if not samples or not events or events[0].get("name") != "start" or events[-1].get("name") != "end":
        reasons.add("missing_boundary")
    if samples and [row["sequence"] for row in samples] != list(range(len(samples))):
        reasons.add("missing_sequence")
    if len(samples) < 2:
        reasons.add("insufficient_samples")
    cpu_seconds = 0.0
    elapsed_seconds = 0.0
    previous = None
    rss = []
    footprint = []
    lifetime = []
    identities = set()
    settings = set()
    windows = set()
    states = set()
    for row in samples:
        reasons.update(row.get("reasons", []))
        if not row.get("valid", False):
            reasons.add("invalid_sample")
        if row["delayNS"] > 250_000_000:
            reasons.add("late_over_250ms")
        identities.add((row.get("pid"), row.get("startTicks"), row.get("executablePath")))
        settings.add((row.get("settingsSHA256"), row.get("settingsSource")))
        windows.add(row.get("windowSHA256"))
        states.add(row.get("state"))
        if row.get("session") != "active":
            reasons.add("session_changed")
        for key, target in (("rssBytes", rss), ("footprintBytes", footprint),
                            ("lifetimeMaxFootprintBytes", lifetime)):
            value = row.get(key)
            if value is None or value < 0:
                reasons.add("missing_" + key)
            else:
                target.append(value)
        if previous is not None:
            old_ticks = previous.get("userTicks"), previous.get("systemTicks")
            new_ticks = row.get("userTicks"), row.get("systemTicks")
            delta_time = row["actualNS"] - previous["actualNS"]
            if None in old_ticks + new_ticks or delta_time <= 0:
                reasons.add("missing_cpu_interval")
            else:
                delta_ticks = sum(new_ticks) - sum(old_ticks)
                if delta_ticks < 0:
                    reasons.add("counter_reversed")
                else:
                    try:
                        ns = convert_ticks(delta_ticks, row["timebaseNumer"], row["timebaseDenom"])
                        percent = ns / delta_time * 100
                        if row.get("cpuPercent") is None or not math.isclose(percent, row["cpuPercent"], abs_tol=1e-6):
                            reasons.add("cpu_mismatch")
                        cpu_seconds += ns / 1e9
                        elapsed_seconds += delta_time / 1e9
                    except ValueError:
                        reasons.add("cpu_conversion_failed")
        previous = row
    if len(identities) != 1:
        reasons.add("identity_changed")
    if len(settings) != 1:
        reasons.add("settings_changed")
    if len(windows) != 1:
        reasons.add("windows_changed")
    if len(states) != 1:
        reasons.add("state_changed")
    if any(event.get("name") == "operator_event" and event.get("sequence", 0) > 0 for event in events):
        reasons.add("operator_event_changed")
    end_value = events[-1].get("value", "") if events else ""
    if "reason=duration_complete" not in end_value:
        reasons.add("incomplete_run")
    return {
        "valid": not reasons,
        "reasons": sorted(reasons),
        "sampleCount": len(samples),
        "cpuAveragePercent": cpu_seconds / elapsed_seconds * 100 if elapsed_seconds else None,
        "rssMaximumBytes": max(rss, default=None),
        "footprintMaximumBytes": max(footprint, default=None),
        "lifetimeMaximumFootprintBytes": max(lifetime, default=None),
        "startEvent": events[0] if events else None,
        "endEvent": events[-1] if events else None,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    records = [json.loads(line) for line in args.input.read_text().splitlines() if line]
    result = json.dumps(analyze(records), indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(result + "\n")
    else:
        print(result)


if __name__ == "__main__":
    main()
