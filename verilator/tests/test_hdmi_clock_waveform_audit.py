"""Synthetic controls for the waveform auditor, not native clock qualification."""
import copy
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_hdmi_clock_waveforms import audit_events


def fixture():
    events = []
    for edge in range(101):
        level = str(edge % 2)
        events.append((100000 + edge * 10, {
            "clk_vid": level, "clk_hdmi": level, "outclk": level,
            "transition": "1" if edge in (25, 26, 50, 51) else "0",
            "select_video": "1" if 25 <= edge < 50 else "0",
            "run_vid": "1", "run_hdmi": "1", "checked": 48,
            "video_half": 10, "hdmi_half": 10, "stop_profile": 0,
        }))
    return events


class AuditControls(unittest.TestCase):
    def test_positive(self):
        self.assertEqual(audit_events(fixture(), 10, 10, 0), (100, 96, 10))

    def test_negatives(self):
        def change(field, value, index):
            events = fixture()
            events[index][1][field] = value
            return events

        short = fixture()
        short[30] = (short[30][0] - 1, short[30][1])
        unknown = change("outclk", "x", 30)
        missing = fixture()
        del missing[30][1]["clk_vid"]
        incomplete = change("checked", 47, -1)
        wrong_profile = change("stop_profile", 1, 30)
        wrong_rate = change("video_half", 11, 30)
        wrong_source = change("clk_vid", "0", 31)
        no_source = copy.deepcopy(wrong_source)
        no_source[31][1]["clk_hdmi"] = "0"
        no_request = fixture()
        for _, value in no_request:
            value["select_video"] = "0"
        no_steady = fixture()
        for _, value in no_steady:
            value["transition"] = "1"
        stopped_running = change("run_vid", "0", 30)
        unfinished = change("transition", "1", -1)
        for name, events in (("short", short), ("unknown", unknown), ("missing", missing),
                             ("incomplete", incomplete), ("profile", wrong_profile),
                             ("rate", wrong_rate), ("wrong source", wrong_source),
                             ("no source", no_source), ("requests", no_request),
                             ("steady coverage", no_steady),
                             ("running source stopped", stopped_running),
                             ("unfinished", unfinished)):
            with self.subTest(name=name), self.assertRaises(AssertionError):
                audit_events(events, 10, 10, 0)


if __name__ == "__main__":
    unittest.main()
