import json
import re
from pathlib import Path

root = Path(__file__).parent
command_start = "2026-10-09T02:59:44Z"
command_end = "2026-10-09T02:59:57Z"
start = "2026-10-09T02:59:48Z"
end = "2026-10-09T02:59:56Z"
recovery_end = "2026-10-09T03:00:12Z"
ax = (root / "ax-offdetail.log").read_text().splitlines()
probe = (root / "probe-offdetail.log").read_text().splitlines()

def time(line):
    found = re.search(r"wall=([^ ]+)", line)
    return found.group(1) if found else ""

def en0_rate(line):
    found = re.search(r"(?:\[|\|)en0:[^|]*?rate=Optional\(ResourceRunner.RatePair\(receivedBytesPerSecond: ([0-9.eE+-]+), sentBytesPerSecond: ([0-9.eE+-]+)\)\)", line)
    return (float(found.group(1)), float(found.group(2))) if found else None

card_off = [line for line in ax if start <= time(line) <= end and " id=NetworkCard label=" in line]
en0_off = [line for line in ax if start <= time(line) <= end and " id=NetworkInterface-en0 label=" in line]
activity = [line for line in probe if command_start <= time(line) <= recovery_end and " activity " in line]
history = [int(m.group(1)) for line in probe if (m := re.search(r" history count=(\d+)", line))]
rates = [rate for line in activity if (rate := en0_rate(line)) is not None]
raw_off = [line for line in probe if start <= time(line) <= end and " raw " in line]
summary = {
    "command_off_on_utc": [command_start, command_end],
    "stable_off_observation_utc": [start, end],
    "ax_network_card_off_samples": len(card_off),
    "ax_card_no_current_speed": sum("측정된 속도 없음" in line for line in card_off),
    "ax_en0_off_rows": len(en0_off),
    "ax_en0_link_inactive": sum("연결 비활성" in line for line in en0_off),
    "ax_en0_ipv4_absent": sum("IPv4 없음 또는 미확인" in line for line in en0_off),
    "ax_en0_zero_rx_tx": sum("현재 RX 0.0 B/s · 현재 TX 0.0 B/s" in line for line in en0_off),
    "raw_en0_off_reads": len(raw_off),
    "activity_samples_through_recovery": len(activity),
    "activity_baseline": sum("status=baselineOnly" in line for line in activity),
    "activity_partial": sum("status=partial" in line for line in activity),
    "activity_disconnected": sum("status=disconnected" in line for line in activity),
    "en0_rate_max_rx_bytes_per_second": max((x for x, _ in rates), default=None),
    "en0_rate_max_tx_bytes_per_second": max((y for _, y in rates), default=None),
    "en0_rate_negative_count": sum(x < 0 or y < 0 for x, y in rates),
    "history_count_min_max": [min(history), max(history)],
    "post_disk_card_present": "id=DiskCard" in (root / "ax-post-cards.log").read_text(),
}
print(json.dumps(summary, ensure_ascii=False, indent=2))
