import unittest

from analyze import analyze, convert_ticks


def fixture():
    event = lambda name, value: {"kind": "event", "sequence": -1, "wallTime": "synthetic", "name": name, "value": value}
    rows = []
    for sequence in range(3):
        rows.append({
            "kind": "sample", "sequence": sequence,
            "scheduledNS": sequence * 1_000_000_000,
            "actualNS": sequence * 1_000_000_000,
            "delayNS": 0, "wallTime": "synthetic", "pid": 7,
            "executablePath": "/synthetic/app", "startTicks": 123,
            "userTicks": sequence * 24_000_000, "systemTicks": 0,
            "timebaseNumer": 125, "timebaseDenom": 3,
            "cpuPercent": None if sequence == 0 else 100.0,
            "rssBytes": 12_345_678, "footprintBytes": 23_456_789,
            "lifetimeMaxFootprintBytes": 34_567_890,
            "state": "closed", "session": "active",
            "settingsSHA256": "settings", "settingsSource": "/synthetic/plist",
            "windowSHA256": "windows", "valid": True, "reasons": [],
        })
    return [event("start", "synthetic"), *rows, event("end", "reason=duration_complete invalid=false")]


class AnalyzeTests(unittest.TestCase):
    def test_mach_and_one_core_and_bytes(self):
        result = analyze(fixture())
        self.assertTrue(result["valid"], result)
        self.assertEqual(result["cpuAveragePercent"], 100.0)
        self.assertEqual(result["rssMaximumBytes"], 12_345_678)
        self.assertEqual(result["footprintMaximumBytes"], 23_456_789)
        self.assertEqual(convert_ticks(24_000_000, 125, 3), 1_000_000_000)

    def test_invalid_boundaries(self):
        cases = {
            "counter_reversed": lambda rows: rows[2].update(userTicks=0),
            "pid_change": lambda rows: rows[2].update(pid=8),
            "late": lambda rows: rows[2].update(delayNS=250_000_001),
            "api_error": lambda rows: rows[2].update(footprintBytes=None, valid=False, reasons=["api_error"]),
            "session": lambda rows: rows[2].update(session="locked"),
            "settings": lambda rows: rows[2].update(settingsSHA256="changed"),
            "window": lambda rows: rows[2].update(windowSHA256="changed"),
            "state": lambda rows: rows[2].update(state="body"),
            "start": lambda rows: rows[2].update(startTicks=124),
            "conversion": lambda rows: rows[2].update(timebaseDenom=0),
        }
        for name, change in cases.items():
            with self.subTest(name=name):
                rows = fixture()
                change(rows)
                self.assertFalse(analyze(rows)["valid"])

    def test_missing_and_operator_event_and_limit(self):
        rows = fixture()
        del rows[2]
        self.assertIn("missing_sequence", analyze(rows)["reasons"])
        rows = fixture()
        rows.insert(-1, {"kind": "event", "sequence": 1, "name": "operator_event", "value": "changed"})
        self.assertFalse(analyze(rows)["valid"])
        rows = fixture()
        rows[-1]["value"] = "reason=output_limit invalid=true"
        self.assertIn("incomplete_run", analyze(rows)["reasons"])
        for cause in ("sleep_transition", "api_error", "event_changed"):
            rows = fixture()
            rows[2]["valid"] = False
            rows[2]["reasons"] = [cause]
            self.assertIn(cause, analyze(rows)["reasons"])


if __name__ == "__main__":
    unittest.main()
