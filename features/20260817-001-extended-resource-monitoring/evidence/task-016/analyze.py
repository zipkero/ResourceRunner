#!/usr/bin/env python3
"""전환 가장자리를 제외한 원시 관찰값의 변화 방향만 요약합니다."""

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
physical = {}
unknown = set()
seen = set()
for row in rows:
    phase = row["phase"]
    if phase not in phases or not interior(phase, utc(row["wallUTC"])):
        continue
    if row["record"] == "interface":
        if row["statusOrKind"].startswith("physical"):
            physical.setdefault((phase, row["readAt"]), set()).add(row["identity"].split("#")[0])
        elif row["statusOrKind"] == "unknown":
            unknown.add(row["identity"].split("#")[0])
    elif row["record"] == "sample":
        key = (phase, row["readAt"])
        if key in seen or not row["statusOrKind"].startswith(("rate", "partial")):
            continue
        seen.add(key)
        rx, tx = float(row["rxBps"]), float(row["txBps"])
        if rx >= 0 and tx >= 0:
            app[phase].append({"readAt": row["readAt"], "wallUTC": row["wallUTC"],
                               "rxBps": rx, "txBps": tx, "epoch": row["epoch"],
                               "revision": row["topologyRevision"], "segment": row["rateSegment"],
                               "status": row["statusOrKind"], "complete": row["completeOrPartial"]})
    elif row["record"] == "card":
        rx, tx = float(row["rxBps"]), float(row["txBps"])
        if rx >= 0 and tx >= 0:
            cards[phase].append({"rxBps": rx, "txBps": tx,
                                 "partial": row["completeOrPartial"] == "true"})

names_by_sample = [physical.get((phase, item["readAt"]), set())
                   for phase, values in app.items() for item in values]
known_names = set.intersection(*names_by_sample) if names_by_sample else set()
same_names = all(names == known_names for names in names_by_sample)

snapshots = []
current = None
for line in (ROOT / "netstat.raw.txt").read_text().splitlines():
    if line.startswith("BEGIN "):
        match = re.search(r"utc=([^ ]+) monotonic=([^ ]+) exit=([^ ]+)", line)
        current = {"utc": utc(match.group(1)), "exit": int(match.group(3)), "links": {}}
    elif line == "END":
        if current is not None:
            snapshots.append(current)
        current = None
    elif current is not None:
        fields = line.split()
        if len(fields) >= 10 and fields[2].startswith("<Link#"):
            name = fields[0].removesuffix("*")
            if name not in current["links"]:
                try:
                    current["links"][name] = (int(fields[-5]), int(fields[-2]))
                except ValueError:
                    pass

tool = {name: [] for name in phases}
for old, new in zip(snapshots, snapshots[1:]):
    elapsed = (new["utc"] - old["utc"]).total_seconds()
    if elapsed <= 0 or old["exit"] or new["exit"]:
        continue
    if not known_names.issubset(old["links"]) or not known_names.issubset(new["links"]):
        continue
    rx = sum(new["links"][name][0] - old["links"][name][0] for name in known_names)
    tx = sum(new["links"][name][1] - old["links"][name][1] for name in known_names)
    if rx < 0 or tx < 0:
        continue
    for phase in phases:
        if interior(phase, old["utc"]) and interior(phase, new["utc"]):
            tool[phase].append({"fromUTC": old["utc"].isoformat(), "toUTC": new["utc"].isoformat(),
                                "elapsed": elapsed, "rxBps": rx / elapsed, "txBps": tx / elapsed,
                                "rawRxDelta": rx, "rawTxDelta": tx})
            break


def describe(values):
    if not values:
        return {"count": 0}
    return {"count": len(values),
            "rxMedianBps": statistics.median(item["rxBps"] for item in values),
            "txMedianBps": statistics.median(item["txBps"] for item in values),
            "rxMinBps": min(item["rxBps"] for item in values),
            "rxMaxBps": max(item["rxBps"] for item in values),
            "txMinBps": min(item["txBps"] for item in values),
            "txMaxBps": max(item["txBps"] for item in values)}


result = {
    "scope": {"confirmedPhysicalNames": sorted(known_names),
              "sameNamesEveryValidAppSample": same_names,
              "unknownNamesExcluded": sorted(unknown),
              "netstatSelection": "one <Link#...> row per confirmed physical interface; address rows excluded",
              "edgeExclusionSeconds": 3,
              "appStatus": "rate or partial with nonnegative knownPhysicalRates; baseline/failure excluded"},
    "phases": {},
}
for phase, (start, stop) in phases.items():
    requests = [item for item in events if item["kind"] == "request" and item["phase"] == phase]
    result["phases"][phase] = {
        "startUTC": start.isoformat(), "stopUTC": stop.isoformat(),
        "app": describe(app[phase]), "card": describe(cards[phase]),
        "cardPartialCount": sum(item["partial"] for item in cards[phase]),
        "netstat": describe(tool[phase]),
        "requests": len(requests),
        "http200": sum(item["exit"] == 0 and item["result"].startswith("200 ") for item in requests),
        "responseBytes": sum(float(item["result"].split()[1]) for item in requests
                             if item["exit"] == 0 and len(item["result"].split()) >= 3),
        "uploadBytes": sum(float(item["result"].split()[2]) for item in requests
                           if item["exit"] == 0 and len(item["result"].split()) >= 3),
    }

(ROOT / "comparison.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")

# 터널의 누적량은 물리 집계에 합치지 않고 별도 원본 표로 남깁니다.
tunnels = {}
for row in rows:
    phase = row["phase"]
    if row["record"] != "interface" or row["statusOrKind"] not in ("tunnel", "vpn") \
            or phase not in phases or not interior(phase, utc(row["wallUTC"])):
        continue
    key = (phase, row["statusOrKind"], row["identity"])
    tunnels.setdefault(key, []).append(row)
with (ROOT / "tunnel-summary.csv").open("w", newline="") as output:
    writer = csv.writer(output)
    writer.writerow(["phase", "kind", "identity", "firstReadAt", "lastReadAt",
                     "appFirstRxBytes", "appLastRxBytes", "appFirstTxBytes", "appLastTxBytes",
                     "toolFirstRxBytes", "toolLastRxBytes", "toolFirstTxBytes", "toolLastTxBytes"])
    for (phase, kind, identity), values in sorted(tunnels.items()):
        name = identity.split("#")[0]
        matches = [item["links"][name] for item in snapshots
                   if name in item["links"] and interior(phase, item["utc"])]
        first, last = values[0], values[-1]
        writer.writerow([phase, kind, identity, first["readAt"], last["readAt"],
                         first["rxBytes"], last["rxBytes"], first["txBytes"], last["txBytes"],
                         matches[0][0] if matches else "", matches[-1][0] if matches else "",
                         matches[0][1] if matches else "", matches[-1][1] if matches else ""])
print(json.dumps(result, ensure_ascii=False, indent=2))
