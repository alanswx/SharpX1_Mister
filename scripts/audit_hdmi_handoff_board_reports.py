"""Bounded full-board handoff stage audit, not raw CDC/whole-board acceptance."""
import argparse
import pathlib
import re

from audit_vsync_sys_reports import rows, SYS

PREFIX = "x1_hdmi_clock_handoff:hdmi_handoff|"
MUX_CLOCKS = {"x1_hdmi_handoff_mux", "x1_video_handoff_mux"}
PAIRS = {
    "enable": ("gate_request_meta", "gate_request_sample"),
    "ack": ("ack_meta", "ack_sample"),
    "completed": ("completed_meta", "completed_sample"),
    "gate_status": ("gate_meta", "gate_sample"),
    "blank": ("blank_meta", "blank_sample"),
    "generation": ("generation_meta", "generation_sample"),
    "witness": ("gate_request_sample", "gate_observed_enable"),
    "native_gate": ("gate_request_sample", "gate~FF_0"),
}


def audit(directory, native_log):
    text = native_log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1, "native execution incomplete/warned"
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.MULTILINE), "unreviewed native diagnostic"
    assert text.count("HANDOFF BOARD INVENTORY COMPLETE: original SDC only; not whole-board acceptance") == 1, "wrong/missing completion scope"
    observed_pairs = re.findall(r"^HANDOFF BOARD PAIR (\S+) (\S+) (\S+)$", text, re.MULTILINE)
    assert observed_pairs == [(kind, *pair) for kind, pair in PAIRS.items()], "missing/repeated/substituted physical pair inventory"
    corners = [(model, str(temperature)) for model in ("slow", "fast") for temperature in (-40, 0, 85, 100)]
    assert re.findall(r"^HANDOFF BOARD CORNER (slow|fast) (-?\d+) 1100$", text, re.MULTILINE) == corners, "wrong native corner enumeration"
    count = 0
    minima = {check: float("inf") for check in ("setup", "hold")}
    global_minima = minima.copy()
    for model, temperature in corners:
        for check in ("setup", "hold"):
            for kind, (source, target) in PAIRS.items():
                report = rows(directory / f"{model}_{temperature}_{kind}_{check}.rpt")
                clocks = {SYS} if kind in {"ack", "completed", "gate_status"} else MUX_CLOCKS
                assert len(report) == len(clocks), f"missing/duplicate active clock choice: {kind}"
                assert {r[3] for r in report} == clocks and all(r[3] == r[4] for r in report), f"wrong stage domains: {kind}"
                assert all(r[1:3] == [PREFIX + source, PREFIX + target] for r in report), f"wrong physical endpoints: {kind}"
                assert all(float(r[0]) >= 0 for r in report), f"negative bounded stage: {kind}/{model}/{temperature}/{check}"
                minima[check] = min(minima[check], *(float(r[0]) for r in report))
                count += len(report)
            report = rows(directory / f"{model}_{temperature}_global_{check}.rpt")
            assert len(report) == 50, "global diagnostic truncated or omitted"
            global_minima[check] = min(global_minima[check], *(float(r[0]) for r in report))
    print(f"PASS: 128 bounded full-board reports, {count} stage/witness/native-gate rows; minima {minima}")
    print(f"OPEN: original-constraint global diagnostics {global_minima}; raw inputs, fanout/MTBF, held data, I/O and physical acceptance remain separate")
    return count, minima, global_minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit(args.directory, args.native_log)
