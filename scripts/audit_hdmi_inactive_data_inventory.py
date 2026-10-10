"""Check fitted inactive-bank discovery completeness; never accept timing."""
import argparse
import collections
import hashlib
import pathlib
import re

from audit_vsync_sys_reports import rows
from audit_hdmi_csync_reports import VID

HDMI = "pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk"
CLOCKS = {"hdmi_to_video": (HDMI, "x1_video_handoff_mux"),
          "video_to_hdmi": (VID, "x1_hdmi_handoff_mux")}
OUTPUTS = {"hs", "vs", "de"} | {f"d[{i}]" for i in range(24)}


def audit_sources(log, root):
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "inactive_data_inventory_diagnostic.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("sta.rpt", "sta.summary", "rbf")]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert len(hashes) == 12 and [n for _, n in hashes] == names * 2, "missing/reordered provenance"
    assert hashes[:6] == hashes[6:], "original artifacts changed"
    paths = names[:2] + ["scripts/quartus_hdmi_inactive_data_inventory.tcl"]
    assert [h for h, _ in hashes[:3]] == [hashlib.sha256((root / n).read_bytes()).hexdigest() for n in paths], "current source mismatch"


def audit(directory, log):
    text = log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.M)
    assert text.count("INACTIVE DATA INVENTORY COMPLETE: discovery only; no exclusions or timing acceptance") == 1
    assert re.findall(r"^INACTIVE DATA CLOCK PAIR (\S+) (\S+) (\S+)$", text, re.M) == [(k, *v) for k, v in CLOCKS.items()]
    targets = re.findall(r"^INACTIVE DATA TARGET (\S+)$", text, re.M)
    assert len(set(targets)) == len(targets) and OUTPUTS <= set(targets), "missing/duplicate output targets"
    prefetch = set(targets) - OUTPUTS
    assert {"hdmi_dv_hs", "hdmi_dv_vs", "hdmi_dv_de"} <= prefetch
    assert all(re.fullmatch(r"hdmi_dv_(?:hs|vs|de|data\[(?:[0-9]|1[0-9]|2[0-3])\])(?:~.*|_Duplicate_.*)?", n) for n in prefetch), "unreviewed physical prefetch keeper"
    drivers = re.findall(r"^INACTIVE DATA DRIVER (\S+) (\S+) \((\S+)\)$", text, re.M)
    assert drivers and len(set(drivers)) == len(drivers) and {t for t, _, _ in drivers} == set(targets)
    assert all(t in targets and kind == "reg" for t, _, kind in drivers), "unreviewed driver type"
    driver_pairs = {(s, t) for t, s, _ in drivers}
    pins = re.findall(r"^INACTIVE DATA PIN (\S+) (\S+)$", text, re.M)
    assert len(set(pins)) == len(pins) and {t for t, _ in pins} == set(targets), "missing/duplicate physical pins"
    assert all(t in targets and p.startswith(t + "|") for t, p in pins), "wrong target pin"
    assert all(any(t == n and p in {n + "|d", n + "|asdata"} for t, p in pins) for n in targets), "missing D input"
    corners = [(m, str(t)) for m in ("slow", "fast") for t in (-40, 0, 85, 100)]
    assert re.findall(r"^INACTIVE DATA CORNER (slow|fast) (-?\d+) 1100$", text, re.M) == corners
    reference, minima, count = {}, {}, 0
    for model, temperature in corners:
        for check in ("setup", "hold"):
            for kind, clocks in CLOCKS.items():
                path = directory / f"{model}_{temperature}_{kind}_{check}.rpt"
                report = rows(path)
                found = re.search(rf"Report Timing: Found (\d+) {check} paths", path.read_text())
                assert found and len(report) == int(found[1]) < 1000, "missing/truncated branch report"
                expected = OUTPUTS if kind == "hdmi_to_video" else prefetch
                assert {r[2] for r in report} == expected, "omitted/substituted target"
                assert all(r[3:5] == list(clocks) and (r[1], r[2]) in driver_pairs for r in report), "wrong clock/driver route"
                pattern = r"(?:osd:hdmi_osd|csync:csync_hdmi)\|.+" if kind == "hdmi_to_video" else r"dv_(?:data\[[0-9]+\]|hs|vs|de)(?:~.*|_Duplicate_.*)?"
                assert all(re.fullmatch(pattern, r[1]) and float(r[7]) >= 0 for r in report), "unreviewed bank/physical delay"
                scope = collections.Counter(tuple(r[1:5]) for r in report)
                if kind not in reference:
                    reference[kind] = scope
                assert scope == reference[kind], "corner/check route inventory changed"
                minima[kind, check] = min(minima.get((kind, check), float("inf")), *(float(r[0]) for r in report))
                count += len(report)
    print(f"PASS discovery: 32 reports, {len(targets)} physical targets, {count} rows; exact drivers/pins and eight corners")
    print(f"OPEN timing: {minima}; no exclusions, MTBF/physical or whole-output qualification")
    return count, minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit_sources(args.native_log, args.source_root)
    audit(args.directory, args.native_log)
