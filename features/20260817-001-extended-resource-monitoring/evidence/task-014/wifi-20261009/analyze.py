import json
import re
from pathlib import Path

root = Path(__file__).parent
activities = []
for line in (root / "probe.log").read_text().splitlines():
    if " activity " not in line:
        continue
    time = re.search(r"wall=([^ ]+)", line).group(1)
    revision = int(re.search(r" rev=(\d+)", line).group(1))
    segment = int(re.search(r" segment=(\d+)", line).group(1))
    status = re.search(r" status=(.*?) complete=", line).group(1)
    en0 = re.search(r"(?:\[|\|)en0:(.*?)(?:\||\])", line)
    known = re.search(r" known=Optional\(ResourceRunner.RatePair\(receivedBytesPerSecond: ([0-9.eE+-]+), sentBytesPerSecond: ([0-9.eE+-]+)\)\)", line)
    activities.append(dict(time=time, revision=revision, segment=segment, status=status,
                           en0=en0.group(1) if en0 else None,
                           known_rx=float(known.group(1)) if known else None,
                           known_tx=float(known.group(2)) if known else None))
window = [row for row in activities if "2026-10-09T01:51:04Z" <= row["time"] <= "2026-10-09T01:51:30Z"]
known = [row for row in window if row["known_rx"] is not None]
history = [int(m.group(1)) for line in (root / "probe.log").read_text().splitlines()
           if (m := re.search(r" history count=(\d+)", line))]
ax = [(line.split(" wall=")[1].split(" ")[0], line.split(" label=", 1)[1])
      for line in (root / "ax-retry.log").read_text().splitlines()
      if " id=NetworkCard label=" in line]
summary = {
    "window": "2026-10-09T01:51:04Z..01:51:30Z",
    "activity_samples": len(window),
    "baseline_only_samples": sum("baselineOnly" in row["status"] for row in window),
    "partial_samples": sum("partial" in row["status"] for row in window),
    "disconnected_samples": sum("disconnected" in row["status"] for row in window),
    "revision_first_last": [window[0]["revision"], window[-1]["revision"]],
    "segment_first_last": [window[0]["segment"], window[-1]["segment"]],
    "known_rate_count": len(known),
    "known_rate_max_rx_bytes_per_second": max(row["known_rx"] for row in known),
    "known_rate_max_tx_bytes_per_second": max(row["known_tx"] for row in known),
    "known_rate_negative_count": sum(row["known_rx"] < 0 or row["known_tx"] < 0 for row in known),
    "history_count_min_max": [min(history), max(history)],
    "ax_network_card_samples": len(ax),
    "ax_network_card_speed_absent_while_off": sum("측정된 속도 없음" in label for time, label in ax
                                                  if "2026-10-09T01:51:07Z" <= time <= "2026-10-09T01:51:17Z"),
}
print(json.dumps(summary, ensure_ascii=False, indent=2))
