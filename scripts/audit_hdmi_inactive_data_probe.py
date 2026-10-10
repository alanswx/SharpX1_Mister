"""Audit exact inactive exclusions and active preservation, not FPGA acceptance."""
import argparse
import collections
import hashlib
import pathlib
import re

from audit_vsync_sys_reports import rows
from audit_hdmi_csync_reports import PAIRS, INPUTS, VID, SYS, PREFIX
from audit_hdmi_inactive_data_inventory import HDMI, OUTPUTS

PREFETCH = {"hdmi_dv_hs", "hdmi_dv_vs", "hdmi_dv_de"} | {
    f"hdmi_dv_data[{i}]" for i in range(24) if i not in (4, 8, 20)}
CLOCKS = {
    "inactive_hdmi": (HDMI, "x1_video_handoff_mux"),
    "inactive_video": (VID, "x1_hdmi_handoff_mux"),
    "active_hdmi": (HDMI, "x1_hdmi_handoff_mux"),
    "active_video": (VID, "x1_video_handoff_mux"),
    "pipe_hdmi": ("x1_hdmi_handoff_mux", "x1_hdmi_handoff_mux"),
    "pipe_video": ("x1_video_handoff_mux", "x1_video_handoff_mux"),
}
PACKED_PREFETCH = {f"hdmi_dv_data[{i}]" for i in (0, 1, 10, 12, 15, 16, 21)}


def audit_sources(log, root):
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "hdmi_inactive_data_candidate.sdc", "quartus_hdmi_inactive_data_probe.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("sta.rpt", "sta.summary", "rbf")]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert len(hashes) == 14 and [n for _, n in hashes] == names * 2, "missing/reordered provenance"
    assert hashes[:7] == hashes[7:], "source/original artifacts changed"
    paths = names[:2] + ["scripts/constraints/hdmi_inactive_data_candidate.sdc", "scripts/quartus_hdmi_inactive_data_probe.tcl"]
    assert [h for h, _ in hashes[:4]] == [hashlib.sha256((root / n).read_bytes()).hexdigest() for n in paths], "current source mismatch"


def checked_rows(path, check, limit):
    report = rows(path)
    found = re.search(rf"Report Timing: Found (\d+) {check} paths", path.read_text())
    assert found and len(report) == int(found[1]) < limit, "missing/truncated report"
    return report


def audit(directory, log):
    text = log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.M)
    assert text.count("INACTIVE DATA CANDIDATE: opposite-parent exact DATA pins only; active routes and raw inputs untouched") == 1
    assert text.count("INACTIVE PROBE COMPLETE: diagnostic only; no board selection or timing acceptance") == 1
    cuts = re.findall(r"^INACTIVE DATA CUT (output|prefetch) \{?([^{}\s]+)\}?$", text, re.M)
    expected = {(g, f"{n}|{pin}") for g, names in (("output", OUTPUTS), ("prefetch", PREFETCH))
                for n in names for pin in (("d", "asdata") if g == "output" and n != "vs"
                                          else ("asdata",) if n in PACKED_PREFETCH else ("d",))}
    assert len(cuts) == 77 and set(cuts) == expected, "missing/duplicate/unreviewed pin cut"
    corners = [(m, str(t)) for m in ("slow", "fast") for t in (-40, 0, 85, 100)]
    assert re.findall(r"^INACTIVE PROBE CORNER (before|after) (slow|fast) (-?\d+) 1100$", text, re.M) == [(p, *c) for p in ("before", "after") for c in corners]
    excluded = preserved = 0
    reference = {}
    minima = {c: float("inf") for c in ("setup", "hold")}
    active_minima = {}
    for model, temperature in corners:
        for check in minima:
            originals = {}
            for phase in ("before", "after"):
                stem = f"{phase}_{model}_{temperature}"
                for kind, clocks in CLOCKS.items():
                    path = directory / f"{stem}_{kind}_{check}.rpt"
                    inactive = kind.startswith("inactive")
                    if inactive and phase == "after":
                        assert rows(path, allow_excluded=True) == [], "inactive route still timed"
                        continue
                    report = checked_rows(path, check, 5000)
                    assert all(r[3:5] == list(clocks) for r in report), "wrong data-route clocks"
                    if not kind.startswith("pipe"):
                        targets = OUTPUTS if kind.endswith("hdmi") else PREFETCH
                        assert {r[2] for r in report} == targets, "missing/substituted bank target"
                        pattern = r"(?:osd:hdmi_osd|csync:csync_hdmi)\|.+" if kind.endswith("hdmi") else r"dv_(?:data\[[0-9]+\]|hs|vs|de)(?:~.*|_Duplicate_.*)?"
                        assert all(re.fullmatch(pattern, r[1]) for r in report), "wrong data bank source"
                    scope = collections.Counter(tuple(r[1:5]) for r in report)
                    if kind not in reference:
                        reference[kind] = scope
                    assert scope == reference[kind], "corner route inventory changed"
                    if phase == "before":
                        originals[kind] = report
                        if inactive:
                            excluded += len(report)
                    else:
                        assert collections.Counter(map(tuple, report)) == collections.Counter(map(tuple, originals[kind])), "active timing/physical route changed"
                        preserved += len(report)
                        active_minima[kind, check] = min(active_minima.get((kind, check), float("inf")), *(float(r[0]) for r in report))
                for kind in [*INPUTS, "mode"]:
                    report = checked_rows(directory / f"{stem}_{kind}_{check}.rpt", check, 100 if kind != "mode" else 1000)
                    if kind != "mode":
                        clocks = [VID, SYS] if "echo" in kind else [SYS, VID]
                        assert len(report) == 1 and report[0][1:5] == [*PAIRS[kind], *clocks], "wrong raw input"
                    else:
                        assert all(r[1] in {PREFIX + f"active_mode[{i}]" for i in range(3)} and r[3] == SYS for r in report), "wrong held-mode scope"
                    if phase == "before":
                        originals[kind] = report
                    else:
                        assert collections.Counter(map(tuple, report)) == collections.Counter(map(tuple, originals[kind])), "raw input/held-mode timing changed"
                        preserved += len(report)
                global_rows = rows(directory / f"{stem}_global_{check}.rpt")
                assert len(global_rows) == 50, "missing global diagnostic"
                if phase == "after":
                    minima[check] = min(minima[check], *(float(r[0]) for r in global_rows))
    print(f"PASS preservation: 384 reports; 77 exact pin cuts, {excluded} original inactive rows EXCLUDED, {preserved} active/raw/mode rows unchanged")
    print(f"OPEN: global after {minima}; active-bank/pipe minima {active_minima}; exclusions are not timing passes or hardware acceptance")
    return excluded, preserved, minima, active_minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit_sources(args.native_log, args.source_root)
    audit(args.directory, args.native_log)
