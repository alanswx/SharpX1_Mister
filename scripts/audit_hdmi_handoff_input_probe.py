"""Strict completed-fit first-stage-only before/after audit, not new RBF closure."""
import argparse
import hashlib
import pathlib
import re

from audit_hdmi_handoff_board_reports import PAIRS, PREFIX, MUX_CLOCKS, SYS
from audit_vsync_sys_reports import rows

INPUTS = {
    "enable": ("gate_request", "gate_request_meta", "gate_request_sample"),
    "blank": ("blank_request", "blank_meta", "blank_sample"),
    "generation": ("generation", "generation_meta", "generation_sample"),
    "ack": ("blank_ack", "ack_meta", "ack_sample"),
    "completed": ("completed_generation", "completed_meta", "completed_sample"),
    "gate_status": ("gate_observed_enable", "gate_meta", "gate_sample"),
}
CORNERS = [(model, str(t)) for model in ("slow", "fast") for t in (-40, 0, 85, 100)]


def audit(directory, native_log):
    text = native_log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1, "native execution incomplete/warned"
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.MULTILINE), "unreviewed native diagnostic"
    assert text.count("HANDOFF INPUT PROBE COMPLETE: before/after original fit; candidate not board-selected") == 1, "wrong/missing probe completion"
    assert text.count("HANDOFF INPUT CANDIDATE: six exact first-stage inputs only") == 1, "wrong/missing candidate scope"
    verified = re.findall(r"^HANDOFF INPUT VERIFIED (\S+) (\S+) (\S+)$", text, re.MULTILINE)
    assert verified == list(INPUTS.values()), "wrong/missing/duplicate verified input inventories"
    markers = re.findall(r"^HANDOFF INPUT PROBE CORNER (before|after) (slow|fast) (-?\d+) 1100$", text, re.MULTILINE)
    assert markers == [(phase, model, t) for phase in ("before", "after") for model, t in CORNERS], "wrong native phase/corner enumeration"
    minima = {"setup": float("inf"), "hold": float("inf")}
    global_minima = {phase: minima.copy() for phase in ("before", "after")}
    stage_count = raw_count = held_count = 0
    for model, temperature in CORNERS:
        for check in ("setup", "hold"):
            for kind, (source, target) in PAIRS.items():
                before = rows(directory / f"before_{model}_{temperature}_{kind}_chain_{check}.rpt")
                after = rows(directory / f"after_{model}_{temperature}_{kind}_chain_{check}.rpt")
                clocks = {SYS} if kind in {"ack", "completed", "gate_status"} else MUX_CLOCKS
                assert len(before) == len(clocks) and {r[3] for r in before} == clocks, "missing/duplicate stage clock choice"
                assert all(r[1:3] == [PREFIX+source, PREFIX+target] and r[3] == r[4] for r in before), "wrong stage physical/domain scope"
                assert sorted(before) == sorted(after), "candidate changed interstage/witness/native-gate timing"
                assert all(float(r[0]) >= 0 for r in before), "negative bounded stage"
                minima[check] = min(minima[check], *(float(r[0]) for r in before))
                stage_count += len(before) + len(after)
            for kind, (source, first, _) in INPUTS.items():
                before = rows(directory / f"before_{model}_{temperature}_{kind}_input_{check}.rpt")
                after = rows(directory / f"after_{model}_{temperature}_{kind}_input_{check}.rpt", allow_excluded=True)
                outgoing = kind in {"enable", "blank", "generation"}
                assert len(before) == 2, "raw input coverage missing/repeated"
                assert all(r[1:3] == [PREFIX+source, PREFIX+first] for r in before), "wrong raw input physical endpoints"
                assert ({r[4] for r in before} if outgoing else {r[3] for r in before}) == MUX_CLOCKS, "raw input mux-choice coverage changed"
                assert all(r[3 if outgoing else 4] == SYS for r in before), "raw input SYS endpoint changed"
                assert after == [], "candidate did not cut only the intended raw input"
                raw_count += len(before)
            globals_ = {}
            for phase in ("before", "after"):
                report = rows(directory / f"{phase}_{model}_{temperature}_global_{check}.rpt")
                assert len(report) == 50, "global diagnostic missing/truncated"
                globals_[phase] = report
                global_minima[phase][check] = min(global_minima[phase][check], *(float(r[0]) for r in report))
            # Previously reported held-mode paths must not disappear or change.
            held = [r for r in globals_["before"] if re.fullmatch(re.escape(PREFIX) + r"active_mode\[[012]\]", r[1])]
            if check == "setup":
                assert held, "held-mode diagnostic absent before candidate"
            assert all(r in globals_["after"] for r in held), "candidate hid/changed unrelated held-mode paths"
            held_count += len(held)
    assert global_minima["after"]["setup"] < 0, "unrelated setup failures were unexpectedly waived"
    print(f"PASS: {stage_count} unchanged positive stage rows, {raw_count} original raw rows and 96 excluded input reports; {held_count} unchanged held-mode diagnostic rows")
    print(f"BOUNDED: {minima}; OPEN global before/after {global_minima}; completed-fit probe only, new fit/MTBF/data/I/O/hardware remain required")
    return stage_count, raw_count, minima, global_minima


def audit_sources(native_log, source_root):
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", native_log.read_text(), re.MULTILINE)
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "handoff_input_probe_v1.tcl", "handoff_input_candidate_v3.sdc",
             "output_files/sharpx1_turbo_z_handoff.sta.rpt", "output_files/sharpx1_turbo_z_handoff.sta.summary", "output_files/sharpx1_turbo_z_handoff.rbf"]
    assert len(hashes) == 14 and [name for _, name in hashes] == names*2, "source/artifact hash evidence missing/reordered"
    assert hashes[:7] == hashes[7:], "probe changed source/candidate/original flow artifacts"
    source_names = names[:2] + ["scripts/quartus_hdmi_handoff_input_probe.tcl", "scripts/constraints/hdmi_handoff_input_candidate.sdc"]
    expected = [hashlib.sha256((source_root / name).read_bytes()).hexdigest() for name in source_names]
    assert [value for value, _ in hashes[:4]] == expected, "current source/probe/candidate differs from frozen inputs"
    print("PASS: current controller/framework/probe/candidate hashes and unchanged original flow artifacts")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit_sources(args.native_log, args.source_root)
    audit(args.directory, args.native_log)
