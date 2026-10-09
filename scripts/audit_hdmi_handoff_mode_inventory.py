"""Validate held-mode discovery completeness, NOT timing acceptance."""
import argparse
import collections
import hashlib
import pathlib
import re

from audit_vsync_sys_reports import rows, SYS

PREFIX = "x1_hdmi_clock_handoff:hdmi_handoff|"
SOURCES = {f"{PREFIX}active_mode[{bit}]" for bit in range(3)}


def audit(directory, native_log, source_root):
    text = native_log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.M)
    assert text.count("HANDOFF MODE INVENTORY COMPLETE: discovery only; no new exceptions or acceptance") == 1
    assert set(re.findall(r"^HANDOFF MODE SOURCE (.+)$", text, re.M)) == SOURCES
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
             "/tmp/x1-handoff-mode-inventory-v2.tcl",
             "output_files/sharpx1_turbo_z_handoff.sta.rpt",
             "output_files/sharpx1_turbo_z_handoff.sta.summary",
             "output_files/sharpx1_turbo_z_handoff.rbf"]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", text, re.M)
    assert len(hashes) == 12 and [name for _, name in hashes] == names * 2
    assert hashes[:6] == hashes[6:], "source/original artifacts changed during inventory"
    local_names = names[:2] + ["scripts/quartus_hdmi_handoff_mode_inventory.tcl"]
    assert [value for value, _ in hashes[:3]] == [
        hashlib.sha256((source_root / name).read_bytes()).hexdigest() for name in local_names
    ], "current source/reporter mismatch"
    corners = [(model, str(t)) for model in ("slow", "fast") for t in (-40, 0, 85, 100)]
    assert re.findall(r"^HANDOFF MODE CORNER (slow|fast) (-?\d+) 1100$", text, re.M) == corners
    reference = None
    minima = {check: float("inf") for check in ("setup", "hold")}
    count = 0
    for model, temperature in corners:
        for check in minima:
            path = directory / f"{model}_{temperature}_{check}.rpt"
            report = path.read_text()
            parsed = rows(path)
            found = re.search(rf"Report Timing: Found (\d+) {check} paths", report)
            assert found and 0 < int(found[1]) < 1000, "empty/saturated inventory"
            assert len(parsed) == int(found[1]), "missing summary rows"
            assert all(r[1] in SOURCES and r[3] == SYS for r in parsed), "unexpected source/domain"
            endpoints = collections.Counter(tuple(r[1:5]) for r in parsed)
            if reference is None:
                reference = endpoints
            assert endpoints == reference, "missing/substituted endpoint/clock at a corner"
            minima[check] = min(minima[check], *(float(r[0]) for r in parsed))
            count += len(parsed)
    print(f"PASS discovery: {len(reference)} source/endpoint/clock combinations, {count} rows, 8 corners")
    print(f"OPEN timing: {minima}; clock-control fanout and DV epoch need separate contracts")
    return count, minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit(args.directory, args.native_log, args.source_root)
