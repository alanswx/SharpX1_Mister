"""Source-bound native helper reset matrix audit, not machine/PHY acceptance."""
import argparse
import hashlib
import itertools
import pathlib
import re

SOURCES = {
    "x1_hdmi_clock_handoff.sv": "rtl/x1_hdmi_clock_handoff.sv",
    "hdmi_handoff_reset_tb.sv": "verilator/tests/hdmi_handoff_reset_tb.sv",
    "hdmi_handoff_reset.do": "verilator/tests/hdmi_handoff_reset.do",
}


def audit(log, source_root):
    text = log.read_text()
    found = re.findall(r"^# PASS: native handoff reset phase=(\d+) stopped_ready=(\d+) video_half=(\d+) hdmi_half=(\d+)$", text, re.MULTILINE)
    observed = [(int(v), int(h), int(p), int(r)) for p, r, v, h in found]
    expected = list(itertools.product((11640, 17500), (3366, 6250, 10000), range(8), range(2)))
    assert observed == expected, "missing/repeated/out-of-order reset profiles"
    assert text.count("RESET_COMPLETION=1") == 96 and "RESET_COMPLETION=0" not in text, "incomplete native finish gate"
    assert len(re.findall(r"^# Errors: 0, Warnings: 7$", text, re.MULTILINE)) == 96, "wrong native error/warning summaries"
    assert not re.search(r"\*\* (?:Fatal|Error):|Errors: [1-9]|^Error\b", text, re.MULTILINE), "native execution error"
    warnings = re.findall(r"^# \*\* Warning: (.+)$", text, re.MULTILINE)
    assert len(warnings) == 96 * 7 and all(w.startswith("(vsim-3116) Problem reading symbols") for w in warnings), "unreviewed native warning"
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", text, re.MULTILINE)
    expected_hashes = [(hashlib.sha256((source_root / path).read_bytes()).hexdigest(), name)
                       for name, path in SOURCES.items()]
    assert hashes == expected_hashes * 2, "frozen source mismatch or missing final hash checks"
    print("PASS: 96 ordered native reset-phase/rate/readiness profiles, explicit completion gates and unchanged current source hashes")
    print("SCOPE: native helper only; connected DV epoch, board fitting, machine reset and physical output remain separate")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit(args.log, args.source_root)
