"""Synthetic before/after preservation controls, not native timing."""
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile

repo = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(repo / "scripts"))
import audit_hdmi_csync_input_probe as checker
from audit_hdmi_csync_reports import PAIRS, INPUTS, FIRST, CONSUMERS, PREFIX, SYS, VID


def row(source, target, launch, latch, slack=1):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; 10 ; 0.1 ; 1 ;\n"


with tempfile.TemporaryDirectory(prefix="x1-csync-input-probe-") as temp:
    root = pathlib.Path(temp)
    log = root / "native.log"
    originals = {root / "clocks.rpt": "synthetic clocks\n"}
    text = ""
    for kind, (_, second) in zip(INPUTS, FIRST):
        text += f"CSYNC INPUT VERIFIED {PAIRS[kind][0]} {PAIRS[kind][1]} {second}\n"
    text += "CSYNC INPUT CANDIDATE: four exact first-stage inputs only\n"
    for source in CONSUMERS.values():
        for target in ("state.OPEN", "state.SWITCH"):
            text += f"CSYNC INPUT PROBE CONSUMER {source} {PREFIX}{target} (reg)\n"
    for phase in ("before", "after"):
        for model, t in checker.CORNERS:
            text += f"CSYNC INPUT PROBE CORNER {phase} {model} {t} 1100\n"
            for check in ("setup", "hold"):
                for kind, (source, target) in PAIRS.items():
                    clock = SYS if kind.endswith("return") else VID
                    clocks = ((VID, SYS) if "echo" in kind else (SYS, VID)) if kind in INPUTS else (clock, clock)
                    content = "Nothing to report.\n" if phase == "after" and kind in INPUTS else row(source, target, *clocks, -2 if kind in INPUTS else 1)
                    originals[root / f"{phase}_{model}_{t}_{kind}_{check}.rpt"] = content
                for kind, source in CONSUMERS.items():
                    originals[root / f"{phase}_{model}_{t}_{kind}_consumer_{check}.rpt"] = f"Report Timing: Found 2 {check} paths\n" + "".join(row(source, PREFIX + target, SYS, SYS) for target in ("state.OPEN", "state.SWITCH"))
                originals[root / f"{phase}_{model}_{t}_global_{check}.rpt"] = "".join(row(f"s{i}", f"t{i}", SYS, SYS, -3) for i in range(50))
    text += "CSYNC INPUT PROBE COMPLETE: before/after original fit; candidate not board-selected\nTimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n"
    originals[log] = text
    for path, content in originals.items():
        path.write_text(content)
    def execute():
        with contextlib.redirect_stdout(io.StringIO()):
            return checker.audit(root, log)
    assert execute()[:2] == (272, 64)
    stage = root / "after_slow_-40_native_capture_setup.rpt"
    raw = root / "after_fast_100_csync_input_hold.rpt"
    consumer = root / "after_slow_100_csync_consumer_setup.rpt"
    global_report = root / "after_fast_0_global_hold.rpt"
    mutations = [
        (log, text.replace("0 warnings", "1 warning")),
        (log, text + "Warning: ignored scalar\n"),
        (log, text.replace("four exact", "whole-domain")),
        (log, text.replace("VERIFIED dv_policy_completed", "VERIFIED WRONG")),
        (log, text.replace("CORNER after fast 100 1100\n", "")),
        (log, text.replace("CONSUMER dv_policy_sample", "CONSUMER WRONG", 1)),
        (stage, originals[stage].replace("; 1 ;", "; -1 ;", 1)),
        (stage, originals[stage].replace("; 1 ;", "; 2 ;", 1)),
        (stage, originals[stage] * 2),
        (stage, originals[stage].replace("dv_hs1", "WRONG")),
        (stage, originals[stage].replace(VID, SYS)),
        (raw, originals[root / "before_fast_100_csync_input_hold.rpt"]),
        (raw, ""),
        (consumer, originals[consumer].replace("Found 2", "Found 1000")),
        (consumer, originals[consumer].replace("; 1 ;", "; -1 ;", 1)),
        (consumer, originals[consumer].replace("state.OPEN", "state.BAD")),
        (global_report, originals[global_report].replace("s0", "WRONG", 1)),
        (global_report, "Nothing to report.\n"),
    ]
    for path, content in mutations:
        path.write_text(content)
        try:
            execute()
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid probe accepted: {path.name}")
        path.write_text(originals[path])
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "scripts/constraints/hdmi_csync_input_candidate.sdc", "csync_input_probe_diagnostic.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("sta.rpt", "sta.summary", "rbf")]
    paths = names[:3] + ["scripts/quartus_hdmi_csync_input_probe.tcl"]
    values = [hashlib.sha256((repo / p).read_bytes()).hexdigest() for p in paths] + ["a" * 64, "b" * 64, "c" * 64]
    block = "".join(f"{value}  {name}\n" for value, name in zip(values, names))
    log.write_text(block * 2)
    checker.audit_sources(log, repo)
    for content in (block, block * 2 + block.splitlines(keepends=True)[0],
                    (block * 2).replace(values[0], "0" * 64),
                    (block * 2).replace(values[-1], "0" * 64, 1)):
        log.write_text(content)
        try:
            checker.audit_sources(log, repo)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid source/artifact provenance accepted")
print("PASS: synthetic 640-report preservation; 18 invalid scope/timing and four invalid source/artifact controls")
