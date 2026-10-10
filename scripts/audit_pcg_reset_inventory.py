"""Audit reset/WE discovery completeness, never infer timing closure."""
import argparse
import collections
import hashlib
import pathlib
import re

from audit_vsync_sys_reports import rows, SYS
from audit_hdmi_csync_reports import VID

DOWNLOAD = "emu:emu|hps_io:hps_io|ioctl_download"
PIPE = "emu:emu|sharpx1:sharpx1|x1_reset_release:video_reset_domain.release_reset|release_pipe"
PIPES = {f"{PIPE}[{bit}]" for bit in (0, 1)}
WE = re.compile(r"^emu:emu\|sharpx1:sharpx1\|x1_video_ram:pcg_([brg])\|.+~porta_we_reg$")
CORNERS = [(model, str(t)) for model in ("slow", "fast") for t in (-40, 0, 85, 100)]


def audit_sources(log, root):
    names = ["rtl/x1_pcg_access.v", "rtl/x1_reset_release.sv", "rtl/sharpx1.v",
             "sharpx1.sv", "pcg_reset_inventory_diagnostic.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("sta.rpt", "sta.summary", "rbf")]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert len(hashes) == 16 and [name for _, name in hashes] == names * 2, "missing/reordered provenance"
    assert hashes[:8] == hashes[8:], "original sources/artifacts changed"
    paths = names[:4] + ["scripts/quartus_pcg_reset_inventory.tcl"]
    assert [h for h, _ in hashes[:5]] == [hashlib.sha256((root / name).read_bytes()).hexdigest() for name in paths], "source/reporter mismatch"


def audit(directory, log):
    text = log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.M)
    assert text.count("PCG RESET INVENTORY COMPLETE: original SDC only; not timing acceptance") == 1
    assert re.findall(r"^PCG RESET CORNER (slow|fast) (-?\d+) 1100$", text, re.M) == CORNERS
    fanins = re.findall(r"^PCG RESET FANIN (\S+) (\S+) \((\S+)\)$", text, re.M)
    assert fanins and len(set(fanins)) == len(fanins), "missing/duplicate fanin inventory"
    targets = {target for target, _, _ in fanins}
    assert len(targets) == 12 and all(WE.fullmatch(name) for name in targets), "wrong WE inventory"
    assert collections.Counter(WE.fullmatch(name)[1] for name in targets) == {"b": 4, "r": 4, "g": 4}
    counts = collections.Counter()
    minima = {}
    reference = {}
    expected_files = set()
    for model, temperature in CORNERS:
        for kind, checks in (("download", ("setup", "hold")), ("all_we", ("setup", "hold")),
                             ("local", ("setup", "hold", "recovery", "removal"))):
            for check in checks:
                filename = f"{model}_{temperature}_{kind}_{check}.rpt"
                expected_files.add(filename)
                path = directory / filename
                parsed = rows(path, allow_excluded=kind != "all_we")
                if parsed:
                    found = re.search(rf"Report Timing: Found (\d+) {check} paths", path.read_text())
                    assert found and int(found[1]) == len(parsed) < 10000, "missing/saturated summary"
                elif "Nothing to report." not in path.read_text():
                    raise AssertionError("invalid empty discovery report")
                for row in parsed:
                    if kind in ("download", "all_we") or check in ("setup", "hold"):
                        assert row[2] in targets and row[4] == VID, "wrong WE target/domain"
                    if kind == "download":
                        assert row[1] == DOWNLOAD and row[3] == SYS, "wrong raw reset launch"
                    elif kind == "local":
                        assert row[1] in PIPES and row[3] == VID, "wrong local reset launch"
                if kind == "all_we":
                    assert {row[2] for row in parsed} == targets, "omitted fitted WE"
                key = (kind, check)
                inventory = collections.Counter(tuple(row[1:5]) for row in parsed)
                if key not in reference:
                    reference[key] = inventory
                assert inventory == reference[key], "corner endpoint/clock coverage changed"
                counts[key] += len(parsed)
                if parsed:
                    minima[key] = min(minima.get(key, float("inf")), *(float(row[0]) for row in parsed))
    assert {p.name for p in directory.glob("*.rpt")} == expected_files | {"clocks.rpt"}, "missing/extra reports"
    print(f"PASS discovery: 64 reports, twelve fitted WE keepers, rows {dict(counts)}")
    print(f"OPEN timing/physical: minima {minima}; raw-path absence is not placement/reset/MTBF acceptance")
    return counts, minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit_sources(args.native_log, args.source_root)
    audit(args.directory, args.native_log)
