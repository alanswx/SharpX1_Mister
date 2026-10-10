"""Audit same-fit context repair/data exclusions; not full-flow or FPGA acceptance."""
import argparse
import collections
import hashlib
import pathlib
import re

from audit_vsync_sys_reports import rows
from audit_hdmi_inactive_data_probe import CLOCKS, PREFETCH
from audit_hdmi_inactive_data_inventory import OUTPUTS
from audit_hdmi_csync_reports import INPUTS, PAIRS, VID, SYS, PREFIX
from audit_hdmi_held_mode_probe import KEYS

CORNERS = [(model, str(t)) for model in ("slow", "fast") for t in (-40, 0, 85, 100)]
PACKED = {"hdmi_dv_hs", "hdmi_dv_de", "hdmi_dv_data[0]", "hdmi_dv_data[6]", "hdmi_dv_data[17]"}


def audit_sources(log, root):
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
             "scripts/constraints/hdmi_held_mode_candidate.sdc",
             "../held-context-d02ee67-v3/hdmi_held_mode_candidate.sdc",
             "../held-context-d02ee67-v3/hdmi_inactive_data_candidate.sdc",
             "../held-context-d02ee67-v3/quartus_held_sdc_context_probe.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("fit.rpt", "fit.summary", "sta.rpt", "sta.summary", "rbf")]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert len(hashes) == 22 and [name for _, name in hashes] == names * 2, "missing/reordered provenance"
    assert hashes[:11] == hashes[11:], "source/original artifacts changed"
    assert hashes[2][0] == "71889e04b0f6dc073f8139988418662edf755b0f45a10bb5fa61235a5b5b1763", "original held baseline changed"
    assert hashes[10][0] == "38a779e9e6e72ea80d8d19087b32978e705b192b14573f180248496b027fb8ee", "wrong historical fit/RBF"
    for index, path in [(0, names[0]), (1, names[1]),
                        (3, "scripts/constraints/hdmi_held_mode_candidate.sdc"),
                        (4, "scripts/constraints/hdmi_inactive_data_candidate.sdc"),
                        (5, "scripts/quartus_held_sdc_context_probe.tcl")]:
        assert hashes[index][0] == hashlib.sha256((root / path).read_bytes()).hexdigest(), "current source mismatch"


def audit(directory, log):
    text = log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1, "native flow incomplete/warned"
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.M), "native diagnostic warning/error"
    assert text.count("HELD CONTEXT BASELINE INACTIVE OMITTED: paths remain timed") == 1, "baseline must time inactive paths"
    assert text.count("HELD MUX CANDIDATE: 29 exact D-route pairs; max 31.25 ns/min -31.25; raw inputs and clock pins untouched") == 2, "held guard missing/repeated"
    assert text.count("INACTIVE DATA PIN PROFILE fitted4cd") == 1, "wrong new fitted pin profile"
    assert text.count("HELD CONTEXT PROBE COMPLETE: same-fit context comparison only; no full-flow or hardware acceptance") == 1, "native footer missing"
    assert re.findall(r"^HELD CONTEXT CORNER (before|after) (slow|fast) (-?\d+) 1100$", text, re.M) == [(p, *c) for p in ("before", "after") for c in CORNERS]
    cuts = re.findall(r"^INACTIVE DATA CUT (output|prefetch) (\S+)$", text, re.M)
    expected = [("output", f"{name}|{pin}") for name in OUTPUTS for pin in (["d"] if name == "vs" else ["d", "asdata"])]
    expected += [("prefetch", f"{name}|{'asdata' if name in PACKED else 'd'}") for name in PREFETCH]
    assert len(cuts) == 77 and collections.Counter(cuts) == collections.Counter(expected), "new fit cut scope changed"
    assert len(list(directory.glob("*.rpt"))) == 384, "missing/extra report inventory"
    preserved = excluded = raw_excluded = mode_rows = 0
    minima = {"setup": float("inf"), "hold": float("inf")}
    reference = {}
    for model, temperature in CORNERS:
        for check in ("setup", "hold"):
            for kind in [*CLOCKS, *INPUTS, "mode", "global"]:
                before_path = directory / f"before_{model}_{temperature}_{kind}_{check}.rpt"
                after_path = directory / f"after_{model}_{temperature}_{kind}_{check}.rpt"
                old = rows(before_path, allow_excluded=kind in INPUTS)
                new = rows(after_path, allow_excluded=kind.startswith("inactive") or kind in INPUTS)
                if kind.startswith("inactive"):
                    assert not new, "inactive paths still timed"
                    targets = OUTPUTS if kind.endswith("hdmi") else PREFETCH
                    assert {r[2] for r in old} == targets and all(r[3:5] == list(CLOCKS[kind]) for r in old), "inactive baseline scope changed"
                    excluded += len(old)
                    continue
                if kind == "global":
                    # Excluding inactive paths intentionally changes the
                    # global worst-path ranking; it must not be called equal.
                    assert len(old) == len(new) == 50, "global report truncated/empty"
                    minima[check] = min(minima[check], *(float(r[0]) for r in new))
                    continue
                assert collections.Counter(map(tuple, old)) == collections.Counter(map(tuple, new)), f"context repair changed timed/excluded rows: {kind}"
                scope = collections.Counter(tuple(r[1:5]) for r in old)
                if kind != "global":
                    if kind not in reference:
                        reference[kind] = scope
                    assert scope == reference[kind], "corner endpoint/clock scope changed"
                if kind in CLOCKS:
                    assert old and all(r[3:5] == list(CLOCKS[kind]) for r in old), "active/pipe route clock changed"
                if kind in INPUTS:
                    if not old:
                        raw_excluded += 1
                    else:
                        clocks = [VID, SYS] if "echo" in kind else [SYS, VID]
                        assert len(old) == 1 and old[0][1:5] == [*PAIRS[kind], *clocks], "raw endpoint/clock changed"
                if kind == "mode":
                    selected = [r for r in old if tuple(r[1:5]) in KEYS]
                    assert len(selected) == 58 and {tuple(r[1:5]) for r in selected} == KEYS, "incomplete held budget scope"
                    assert all(float(r[5]) == (31.25 if check == "setup" else -31.25) for r in selected), "held relationship changed"
                    assert all(r[1].startswith(PREFIX + "active_mode[") and r[3] == SYS for r in old), "mode source/domain changed"
                    mode_rows += len(selected)
                preserved += len(old)
    print(f"PASS same-fit context/data diagnostic: 384 reports; {mode_rows} held budget rows and {preserved} active/raw/mode rows unchanged; {excluded} inactive rows EXCLUDED; {raw_excluded} pre-existing raw reports remain excluded")
    print(f"OPEN: global setup/hold {minima}; exclusions are not timing passes; fresh full flow, PCG-WE, CDC/MTBF/I/O and hardware acceptance remain required")
    return preserved, excluded, raw_excluded, mode_rows, minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", type=pathlib.Path, required=True)
    parser.add_argument("--source-root", type=pathlib.Path, required=True)
    args = parser.parse_args()
    audit_sources(args.native_log, args.source_root)
    audit(args.directory, args.native_log)
