#!/usr/bin/env python3
"""실제 물리 드라이버와 iostat의 변화 방향을 같은 구간에서 요약합니다."""

import csv
import json
import re
import statistics
from datetime import datetime, timedelta
from pathlib import Path


ROOT = Path(__file__).parent


def utc(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


events = [json.loads(line) for line in (ROOT / "events.jsonl").read_text().splitlines()]
phases = {}
for item in events:
    if item["kind"] == "phase_start":
        phases[item["phase"]] = [utc(item["utc"]), None]
    elif item["kind"] == "phase_stop":
        phases[item["phase"]][1] = utc(item["utc"])


def interior(phase, time):
    start, stop = phases[phase]
    return start + timedelta(seconds=3) <= time <= stop - timedelta(seconds=3)


rows = list(csv.DictReader((ROOT / "app-samples.tsv").open(), delimiter="\t"))
app = {name: [] for name in phases}
cards = {name: [] for name in phases}
devices = {name: {} for name in phases}
seen = set()
for row in rows:
    phase = row["phase"]
    if phase not in phases or not interior(phase, utc(row["wallUTC"])):
        continue
    key = (phase, row["readAt"])
    if row["record"] == "sample":
        if key in seen or not row["statusOrKind"].startswith(("rate", "partial")):
            continue
        seen.add(key)
        read, write = float(row["readBps"]), float(row["writeBps"])
        if read >= 0 and write >= 0:
            app[phase].append({"readAt": row["readAt"], "readBps": read,
                               "writeBps": write, "sumBps": read + write,
                               "epoch": row["epoch"], "revision": row["topologyRevision"],
                               "status": row["statusOrKind"], "complete": row["completeOrPartial"]})
    elif row["record"] == "device" and row["statusOrKind"] == "physical":
        devices[phase].setdefault(row["readAt"], []).append(row)
    elif row["record"] == "card":
        read, write = float(row["readBps"]), float(row["writeBps"])
        if read >= 0 and write >= 0:
            cards[phase].append({"readBps": read, "writeBps": write,
                                 "sumBps": read + write,
                                 "partial": row["completeOrPartial"] == "true"})

all_names = [frozenset((item["identity"], item["bsdNames"]) for item in devices[phase].get(sample["readAt"], []))
             for phase in phases for sample in app[phase]]
physical = sorted(set.intersection(*(set(names) for names in all_names))) if all_names else []
same_names = all(set(names) == set(physical) for names in all_names)

iostat = []
first_data = True
for line in (ROOT / "iostat.raw.txt").read_text().splitlines():
    match = re.match(r"utc=([^ ]+) monotonic=([^ ]+)\s+(.+)$", line)
    if not match:
        continue
    fields = match.group(3).split()
    if len(fields) != 3:
        continue
    try:
        kb_per_transfer, tps, mbps = map(float, fields)
    except ValueError:
        continue
    if first_data:
        first_data = False  # iostat 첫 수치 행은 부팅 이후 평균입니다.
        continue
    iostat.append({"utc": utc(match.group(1)), "KB/t": kb_per_transfer,
                   "tps": tps, "MB/s": mbps})

tool = {name: [] for name in phases}
for old, new in zip(iostat, iostat[1:]):
    for phase in phases:
        if interior(phase, old["utc"]) and interior(phase, new["utc"]):
            tool[phase].append(new)
            break


def describe(values):
    if not values:
        return {"count": 0}
    names = ("readBps", "writeBps", "sumBps") if "sumBps" in values[0] else ("MB/s",)
    result = {"count": len(values)}
    for name in names:
        result[name + "Median"] = statistics.median(item[name] for item in values)
        result[name + "Min"] = min(item[name] for item in values)
        result[name + "Max"] = max(item[name] for item in values)
    return result


result = {
    "scope": {"appPhysicalDriverAndBSD": physical,
              "sameIdentityEveryValidAppSample": same_names,
              "iostatTarget": "disk0", "iostatUnit": "MB/s, Read+Write combined",
              "firstIostatSinceBootRowExcluded": True,
              "edgeExclusionSeconds": 3,
              "appStatus": "rate or partial with valid knownPhysicalRates; baseline/failure excluded"},
    "phases": {},
}
for phase, (start, stop) in phases.items():
    values = [row for group in devices[phase].values() for row in group
              if row["statusOrKind"] == "physical"]
    # 원시 바이트는 앱 sample 시각에 연결되므로 첫/끝 동일 물리 driver를 직접 대조합니다.
    raw = {}
    for driver, bsd in physical:
        matching = [row for row in values if row["identity"] == driver and row["bsdNames"] == bsd
                    and row["readBytes"] != "nil" and row["writeBytes"] != "nil"]
        if matching:
            first, last = matching[0], matching[-1]
            raw[driver + "/" + bsd] = {
                "firstReadAt": first["readAt"], "lastReadAt": last["readAt"],
                "readBytesFirst": int(first["readBytes"]), "readBytesLast": int(last["readBytes"]),
                "writeBytesFirst": int(first["writeBytes"]), "writeBytesLast": int(last["writeBytes"]),
                "readBytesDelta": int(last["readBytes"]) - int(first["readBytes"]),
                "writeBytesDelta": int(last["writeBytes"]) - int(first["writeBytes"]),
            }
    total = next((item for item in events if item["kind"] == "io_total" and item["phase"] == phase), None)
    result["phases"][phase] = {
        "startUTC": start.isoformat(), "stopUTC": stop.isoformat(),
        "app": describe(app[phase]), "card": describe(cards[phase]),
        "cardPartialCount": sum(item["partial"] for item in cards[phase]),
        "iostat": describe(tool[phase]), "rawDrivers": raw,
        "syntheticLoadBytes": total["bytes"] if total else 0,
    }

(ROOT / "comparison.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(result, ensure_ascii=False, indent=2))
