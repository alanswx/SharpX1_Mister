"""Audit first-stage csync exclusions without hiding downstream timing."""
import argparse
import collections
import hashlib
import pathlib
import re

from audit_hdmi_csync_reports import PAIRS, INPUTS, FIRST, CONSUMERS, SYS, VID
from audit_vsync_sys_reports import rows

CORNERS = [(model, str(t)) for model in ("slow", "fast") for t in (-40, 0, 85, 100)]


def audit_sources(log, root):
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
             "scripts/constraints/hdmi_csync_input_candidate.sdc", "csync_input_probe_diagnostic.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("sta.rpt", "sta.summary", "rbf")]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert len(hashes) == 14 and [name for _, name in hashes] == names * 2, "missing/reordered provenance"
    assert hashes[:7] == hashes[7:], "original sources/artifacts changed"
    paths = names[:3] + ["scripts/quartus_hdmi_csync_input_probe.tcl"]
    assert [h for h, _ in hashes[:4]] == [hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths], "source/proposal/reporter mismatch"


def audit(directory, log):
    text = log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.M)
    assert text.count("CSYNC INPUT PROBE COMPLETE: before/after original fit; candidate not board-selected") == 1
    assert text.count("CSYNC INPUT CANDIDATE: four exact first-stage inputs only") == 1
    triples = [(PAIRS[kind][0], PAIRS[kind][1], second) for kind, (_, second) in zip(INPUTS, FIRST)]
    assert re.findall(r"^CSYNC INPUT VERIFIED (\S+) (\S+) (\S+)$", text, re.M) == triples
    assert re.findall(r"^CSYNC INPUT PROBE CORNER (before|after) (slow|fast) (-?\d+) 1100$", text, re.M) == [
        (phase, model, t) for phase in ("before", "after") for model, t in CORNERS]
    fanouts = re.findall(r"^CSYNC INPUT PROBE CONSUMER (\S+) (\S+) \((\S+)\)$", text, re.M)
    assert fanouts and len(set(fanouts)) == len(fanouts)
    assert {source for source, _, _ in fanouts} == set(CONSUMERS.values())
    assert all(kind == "reg" for _, _, kind in fanouts)
    preserved = raw = 0
    minima = {check: float("inf") for check in ("setup", "hold")}
    global_minima = {phase: minima.copy() for phase in ("before", "after")}
    files = set()
    for model, t in CORNERS:
        for check in minima:
            for kind, (source, target) in PAIRS.items():
                paths = {phase: directory / f"{phase}_{model}_{t}_{kind}_{check}.rpt" for phase in ("before", "after")}
                files.update(p.name for p in paths.values())
                before = rows(paths["before"])
                after = rows(paths["after"], allow_excluded=kind in INPUTS)
                assert len(before) == 1 and before[0][1:3] == [source, target], "wrong pair coverage"
                row = before[0]
                if kind in INPUTS:
                    assert row[3:5] == ([VID, SYS] if "echo" in kind else [SYS, VID]), "wrong raw clocks"
                    assert after == [], "proposal did not exclude intended first-stage input"
                    raw += 1
                else:
                    clock = SYS if kind.endswith("return") else VID
                    assert row[3:5] == [clock, clock] and float(row[0]) >= 0, "wrong/negative bounded pair"
                    assert before == after, "proposal changed bounded pair timing"
                    minima[check] = min(minima[check], float(row[0]))
                    preserved += 1
            for kind, source in CONSUMERS.items():
                reports = {}
                for phase in ("before", "after"):
                    path = directory / f"{phase}_{model}_{t}_{kind}_consumer_{check}.rpt"
                    files.add(path.name)
                    reports[phase] = rows(path)
                    found = re.search(rf"Report Timing: Found (\d+) {check} paths", path.read_text())
                    assert found and int(found[1]) == len(reports[phase]) < 1000, "truncated consumers"
                assert collections.Counter(map(tuple, reports["before"])) == collections.Counter(map(tuple, reports["after"])), "consumer timing changed"
                before = reports["before"]
                assert {r[2] for r in before} == {target for src, target, _ in fanouts if src == source}, "consumer omitted/substituted"
                assert all(r[1] == source and r[3:5] == [SYS, SYS] and float(r[0]) >= 0 for r in before), "wrong/negative consumers"
                minima[check] = min(minima[check], *(float(r[0]) for r in before))
                preserved += len(before)
            globals_ = {}
            for phase in ("before", "after"):
                path = directory / f"{phase}_{model}_{t}_global_{check}.rpt"
                files.add(path.name)
                globals_[phase] = rows(path)
                assert len(globals_[phase]) == 50, "missing global diagnostics"
                global_minima[phase][check] = min(global_minima[phase][check], *(float(r[0]) for r in globals_[phase]))
            unaffected = [r for r in globals_["before"] if tuple(r[1:3]) not in {PAIRS[k] for k in INPUTS}]
            assert not (collections.Counter(map(tuple, unaffected)) - collections.Counter(map(tuple, globals_["after"]))), "unrelated global paths hidden/changed"
    assert {p.name for p in directory.glob("*.rpt")} == files | {"clocks.rpt"}, "missing/extra report files"
    print(f"PASS probe audit: 640 reports; {preserved} unchanged bounded rows; {raw} raw rows excluded, not passed; minima {minima}")
    print(f"OPEN: global before/after {global_minima}; native inventory, placement/MTBF, fresh fit and hardware separate")
    return preserved, raw, minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit_sources(args.native_log, args.source_root)
    audit(args.directory, args.native_log)
