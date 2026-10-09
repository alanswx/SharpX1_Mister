"""Strict one-corner isolated mux probe audit, never board/MTBF acceptance."""
import argparse
import pathlib
import re

from audit_vsync_sys_reports import rows

PREFIX = "x1_hdmi_clock_handoff:handoff|"
CLOCKS = {"probe_mux_hdmi", "probe_mux_video"}
PAIRS = {
    "enable": ("gate_request_meta", "gate_request_sample"),
    "witness": ("gate_request_sample", "gate_observed_enable"),
    "native_gate": ("gate_request_sample", "gate~FF_0"),
}


def audit(directory, native_log):
    text = native_log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1, "native probe incomplete/warned"
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.MULTILINE), "native diagnostics not clean"
    marker = "HANDOFF PROBE two generated mux choices only; PLL masters remain concurrent"
    assert text.count(marker) == 1, "wrong/absent mux scope"
    fanouts = re.findall(r"HANDOFF ENABLE FANOUT gate_request_meta (.+) \(reg\)", text)
    assert fanouts == [PREFIX + "gate_request_sample"], "first stage has unreviewed fanout"
    status = re.findall(r"HANDOFF STATUS FANIN (.+) \((.+)\)", text)
    assert set(status) == {("refclk", "port"), (PREFIX + "gate_observed_enable", "reg")} and len(status) == 2, "status bypassed falling-edge witness"
    minima = {}
    for kind, (source, target) in PAIRS.items():
        minima[kind] = {}
        for check in ("setup", "hold"):
            report = rows(directory / f"handoff_probe_mux_{kind}_{check}.rpt")
            assert len(report) == 2, "missing/duplicate active clock choice"
            assert {r[3] for r in report} == CLOCKS and all(r[3] == r[4] for r in report), "wrong/cross clock choices"
            assert all(r[1:3] == [PREFIX + source, PREFIX + target] for r in report), "wrong physical pair"
            assert all(float(r[0]) >= 0 for r in report), "negative bounded path"
            minima[kind][check] = min(float(r[0]) for r in report)
    raw = rows(directory / "handoff_probe_mux_raw_enable_setup.rpt")
    assert len(raw) == 2 and {r[4] for r in raw} == CLOCKS, "raw input report excluded/incomplete"
    assert all(r[1] in {PREFIX + "gate_request", PREFIX + "gate_request~DUPLICATE"}
               and r[2:4] == [PREFIX + "gate_request_meta", "probe_ref"] for r in raw), "wrong raw scope"
    assert min(float(r[0]) for r in raw) < 0, "raw input violation hidden"
    global_min = {}
    for check in ("setup", "hold"):
        report = rows(directory / f"handoff_probe_mux_global_{check}.rpt")
        assert len(report) == 50, "global diagnostic truncated/excluded"
        global_min[check] = min(float(r[0]) for r in report)
        assert global_min[check] < 0, "unexpected global waiver/qualification"
    print(f"PASS: twelve positive one-corner enable/witness/native-gate rows: {minima}")
    print(f"OPEN: raw enable setup {min(float(r[0]) for r in raw):+.3f} ns; global {global_min}; no board/I/O/all-corner/MTBF acceptance")
    return minima, global_min


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit(args.directory, args.native_log)
