"""Audit exact held-mux budgets and preservation; not board acceptance."""
import argparse
import collections
import hashlib
import pathlib
import re

from audit_vsync_sys_reports import rows, SYS
from audit_hdmi_csync_reports import PAIRS, INPUTS, VID, PREFIX

CORNERS = [(m, str(t)) for m in ("slow", "fast") for t in (-40, 0, 85, 100)]
MUXES = {"x1_hdmi_handoff_mux", "x1_video_handoff_mux"}
TARGETS = ["hs", "vs", "de"] + [f"d[{i}]" for i in range(24)]
KEYS = {(f"{PREFIX}active_mode[{bit}]", target, SYS, clock)
        for target in TARGETS for bit in (range(3) if target == "hs" else [0]) for clock in MUXES}


def audit_sources(log, root):
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
             "hdmi_held_mode_candidate.sdc", "quartus_hdmi_held_mode_probe.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("sta.rpt", "sta.summary", "rbf")]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert len(hashes) == 14 and [n for _, n in hashes] == names * 2, "missing/reordered provenance"
    assert hashes[:7] == hashes[7:], "original inputs/artifacts changed"
    paths = names[:2] + ["scripts/constraints/hdmi_held_mode_candidate.sdc", "scripts/quartus_hdmi_held_mode_probe.tcl"]
    assert [v for v, _ in hashes[:4]] == [hashlib.sha256((root / n).read_bytes()).hexdigest() for n in paths], "current source mismatch"


def audit(directory, log):
    text = log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.M)
    assert text.count("HELD MUX CANDIDATE: 29 exact D-route pairs; max 31.25 ns/min -31.25; raw inputs and clock pins untouched") == 1
    assert text.count("HELD MUX PROBE COMPLETE: diagnostic only; original SDC/artifacts unchanged") == 1
    assert re.findall(r"^HELD MUX PROBE CORNER (before|after) (slow|fast) (-?\d+) 1100$", text, re.M) == [(p, *c) for p in ("before", "after") for c in CORNERS]
    minima = {c: float("inf") for c in ("setup", "hold")}
    globals_after = minima.copy()
    count = unchanged = raw_count = 0
    reference = None
    for model, temperature in CORNERS:
        for check in minima:
            reports = {}
            for phase in ("before", "after"):
                stem = f"{phase}_{model}_{temperature}"
                path = directory / f"{stem}_mode_{check}.rpt"
                parsed = rows(path)
                found = re.search(rf"Report Timing: Found (\d+) {check} paths", path.read_text())
                assert found and len(parsed) == int(found[1]) < 1000, "empty/truncated mode report"
                scope = collections.Counter(tuple(r[1:5]) for r in parsed)
                if reference is None:
                    reference = scope
                assert scope == reference, "mode endpoint/clock inventory changed"
                selected = [r for r in parsed if tuple(r[1:5]) in KEYS]
                assert len(selected) == 58 and {tuple(r[1:5]) for r in selected} == KEYS, "missing/repeated budgeted routes"
                other = [r for r in parsed if tuple(r[1:5]) not in KEYS]
                assert all(r[1].startswith(PREFIX + "active_mode[") and r[3] == SYS and
                           (r[2].startswith(PREFIX) and r[4] == SYS or
                            r[1:5] == [PREFIX + "active_mode[2]", "dv_csync_meta", SYS, VID]) for r in other), "unreviewed noncandidate mode path"
                reports[phase] = (selected, other)
                for kind in INPUTS:
                    raw = rows(directory / f"{stem}_{kind}_{check}.rpt")
                    source, target = PAIRS[kind]
                    clocks = [VID, SYS] if "echo" in kind else [SYS, VID]
                    assert len(raw) == 1 and raw[0][1:5] == [source, target, *clocks], "wrong raw-input scope"
                    if phase == "before":
                        reports[kind] = raw
                    else:
                        assert raw == reports[kind], "raw timing changed or excluded"
                        raw_count += 1
                global_rows = rows(directory / f"{stem}_global_{check}.rpt")
                assert len(global_rows) == 50, "missing global diagnostic"
                if phase == "after":
                    globals_after[check] = min(globals_after[check], *(float(r[0]) for r in global_rows))
            before, before_other = reports["before"]
            after, after_other = reports["after"]
            assert collections.Counter(map(tuple, before_other)) == collections.Counter(map(tuple, after_other)), "unbudgeted mode/control timing changed"
            assert collections.Counter(tuple(r[1:5] + [r[7]]) for r in before) == collections.Counter(tuple(r[1:5] + [r[7]]) for r in after), "physical route/data delay changed"
            assert all(float(r[0]) >= 0 and 0 <= float(r[7]) < 31.25 for r in after), "budgeted delay/slack failure"
            relationship = 31.25 if check == "setup" else -31.25
            assert all(float(r[5]) == relationship for r in after), "candidate delay relationship not bound"
            minima[check] = min(minima[check], *(float(r[0]) for r in after))
            count += len(after)
            unchanged += len(after_other)
    print(f"PASS diagnostic: 192 reports; {count} budgeted rows {minima}; {unchanged} other mode rows and {raw_count} raw rows unchanged")
    print(f"OPEN: global after {globals_after}; clock-selection pins, pixel data, MTBF/I/O, new fitting and physical switching")
    return count, unchanged, raw_count, minima, globals_after


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit_sources(args.native_log, args.source_root)
    audit(args.directory, args.native_log)
