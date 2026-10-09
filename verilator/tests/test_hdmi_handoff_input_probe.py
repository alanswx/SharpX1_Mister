"""Synthetic first-stage-only scope/preservation controls, not native timing."""
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_hdmi_handoff_input_probe import audit, audit_sources, INPUTS, CORNERS
from audit_hdmi_handoff_board_reports import PAIRS, PREFIX, MUX_CLOCKS, SYS


def row(source, target, launch, latch, slack=1):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; 10 ; 0.1 ; 1 ;\n"


with tempfile.TemporaryDirectory(prefix="handoff-input-probe-controls-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    originals = {log: "".join(f"HANDOFF INPUT VERIFIED {s} {f} {t}\n" for s, f, t in INPUTS.values())}
    originals[log] += "HANDOFF INPUT CANDIDATE: six exact first-stage inputs only\n"
    for phase in ("before", "after"):
        for model, temperature in CORNERS:
            originals[log] += f"HANDOFF INPUT PROBE CORNER {phase} {model} {temperature} 1100\n"
            for check in ("setup", "hold"):
                for kind, (source, target) in PAIRS.items():
                    clocks = {SYS} if kind in {"ack", "completed", "gate_status"} else MUX_CLOCKS
                    originals[root / f"{phase}_{model}_{temperature}_{kind}_chain_{check}.rpt"] = "".join(row(PREFIX+source, PREFIX+target, c, c) for c in sorted(clocks))
                for kind, (source, first, _) in INPUTS.items():
                    outgoing = kind in {"enable", "blank", "generation"}
                    originals[root / f"{phase}_{model}_{temperature}_{kind}_input_{check}.rpt"] = "Nothing to report.\n" if phase == "after" else "".join(
                        row(PREFIX+source, PREFIX+first, SYS if outgoing else c, c if outgoing else SYS, -3) for c in sorted(MUX_CLOCKS))
                held = row(PREFIX+"active_mode[0]", "hs", SYS, "x1_hdmi_handoff_mux", -2 if check == "setup" else 0.2)
                originals[root / f"{phase}_{model}_{temperature}_global_{check}.rpt"] = held + "".join(row(f"s{i}", f"t{i}", SYS, SYS, -1 if check == "setup" else 0.3) for i in range(49))
    originals[log] += "HANDOFF INPUT PROBE COMPLETE: before/after original fit; candidate not board-selected\nTimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n"
    for path, contents in originals.items():
        path.write_text(contents)
    with contextlib.redirect_stdout(io.StringIO()):
        result = audit(root, log)
        assert result[:2] == (416, 192)
    chain = root / "after_slow_-40_enable_chain_setup.rpt"
    raw = root / "after_fast_100_ack_input_hold.rpt"
    before_raw = root / "before_slow_0_enable_input_setup.rpt"
    global_report = root / "after_slow_0_global_setup.rpt"
    mutations = [
        (log, originals[log].replace("0 warnings", "1 warning")),
        (log, originals[log] + "Warning: ignored filter\n"),
        (log, originals[log].replace("HANDOFF INPUT VERIFIED blank_ack", "HANDOFF INPUT VERIFIED generation")),
        (log, originals[log].replace("before slow -40", "after slow -40", 1)),
        (log, originals[log].replace("HANDOFF INPUT PROBE CORNER after fast 100 1100\n", "")),
        (log, originals[log].replace("six exact first-stage inputs", "whole PLL domains")),
        (chain, "Nothing to report.\n"),
        (chain, originals[chain].splitlines(keepends=True)[0]),
        (chain, originals[chain].replace("; 1 ;", "; -1 ;", 1)),
        (chain, originals[chain].replace("; 1 ;", "; 2 ;", 1)),
        (chain, originals[chain].replace("gate_request_sample", "ack_sample")),
        (raw, row(PREFIX+"blank_ack", PREFIX+"ack_meta", "x1_hdmi_handoff_mux", SYS)),
        (raw, "corrupt excluded report\n"),
        (before_raw, originals[before_raw].splitlines(keepends=True)[0]),
        (before_raw, originals[before_raw].replace("gate_request_meta", "ack_meta")),
        (before_raw, originals[before_raw].replace("x1_video_handoff_mux", "x1_hdmi_handoff_mux")),
        (global_report, "Nothing to report.\n"),
        (global_report, originals[global_report].splitlines(keepends=True)[0]),
        (global_report, originals[global_report].replace("active_mode[0]", "unrelated")),
        (global_report, originals[global_report].replace("; -2 ;", "; -3 ;", 1)),
    ]
    for path, contents in mutations:
        path.write_text(contents)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit(root, log)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid input scope/preservation accepted: {path.name}")
        path.write_text(originals[path])
    # Bind the exact candidate and reporter, not merely the machine RTL.
    source_names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "scripts/quartus_hdmi_handoff_input_probe.tcl", "scripts/constraints/hdmi_handoff_input_candidate.sdc"]
    source_hashes = []
    for name in source_names:
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"synthetic {name}\n")
        source_hashes.append(hashlib.sha256(path.read_bytes()).hexdigest())
    native_names = source_names[:2] + ["handoff_input_probe_v1.tcl", "handoff_input_candidate_v3.sdc"] + [f"output_files/sharpx1_turbo_z_handoff.{extension}" for extension in ("sta.rpt", "sta.summary", "rbf")]
    lines = [f"{value}  {name}\n" for value, name in zip(source_hashes + ["a"*64, "b"*64, "c"*64], native_names)]
    valid = "".join(lines*2)
    log.write_text(valid)
    with contextlib.redirect_stdout(io.StringIO()):
        audit_sources(log, root)
    for invalid in ("".join(lines), valid+lines[0],
                    valid.replace(lines[3], "0"*64+"  "+native_names[3]+"\n"),
                    valid.replace(lines[-1], "0"*64+"  "+native_names[-1]+"\n", 1)):
        log.write_text(invalid)
        try:
            audit_sources(log, root)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid source/artifact preservation accepted")
print("PASS: synthetic eight-corner before/after positive; twenty invalid scope/timing and four invalid source/artifact controls")
