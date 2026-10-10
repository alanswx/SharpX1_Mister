"""Synthetic held-mode probe integrity controls; not native timing."""
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_hdmi_held_mode_probe import audit, audit_sources, CORNERS, KEYS, PREFIX, SYS, VID, PAIRS, INPUTS


def row(source, target, launch, latch, slack=1, data=2, relationship=10):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; {relationship} ; 0.1 ; {data} ;\n"


with tempfile.TemporaryDirectory(prefix="held-mux-probe-controls-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    originals = {log: "HELD MUX CANDIDATE: 29 exact D-route pairs; max 31.25 ns/min -31.25; raw inputs and clock pins untouched\n"}
    for phase in ("before", "after"):
        for model, temperature in CORNERS:
            originals[log] += f"HELD MUX PROBE CORNER {phase} {model} {temperature} 1100\n"
            for check in ("setup", "hold"):
                stem = f"{phase}_{model}_{temperature}"
                relationship = (31.25 if check == "setup" else -31.25) if phase == "after" else 10
                selected = "".join(row(*key, -3 if phase == "before" and check == "setup" else 1,
                                       relationship=relationship) for key in sorted(KEYS))
                other = row(PREFIX + "active_mode[0]", PREFIX + "state.RUN", SYS, SYS)
                other += row(PREFIX + "active_mode[2]", "dv_csync_meta", SYS, VID, -3)
                originals[root / f"{stem}_mode_{check}.rpt"] = f"Report Timing: Found 60 {check} paths\n" + selected + other
                for kind in INPUTS:
                    clocks = [VID, SYS] if "echo" in kind else [SYS, VID]
                    originals[root / f"{stem}_{kind}_{check}.rpt"] = row(*PAIRS[kind], *clocks, -3)
                originals[root / f"{stem}_global_{check}.rpt"] = "".join(row(f"s{i}", f"t{i}", SYS, SYS, -3) for i in range(50))
    originals[log] += "HELD MUX PROBE COMPLETE: diagnostic only; original SDC/artifacts unchanged\nTimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n"
    for path, contents in originals.items():
        path.write_text(contents)
    with contextlib.redirect_stdout(io.StringIO()):
        result = audit(root, log)
    assert result[:3] == (928, 32, 64)
    mode = root / "after_slow_-40_mode_setup.rpt"
    raw = root / "after_fast_100_csync_input_hold.rpt"
    global_report = root / "after_fast_100_global_setup.rpt"
    mutations = [
        (log, originals[log].replace("0 warnings", "1 warning")),
        (log, originals[log] + "Warning: ignored scope\n"),
        (log, originals[log].replace("max 31.25 ns/min -31.25", "max 100 ns/min 0")),
        (log, originals[log].replace("after fast 100", "after fast 85")),
        (log, originals[log].replace("HELD MUX PROBE COMPLETE", "PROBE INCOMPLETE")),
        (mode, originals[mode].replace("Found 60", "Found 1000")),
        (mode, originals[mode].replace("d[0]", "unreviewed_target")),
        (mode, originals[mode].replace("; 1 ;", "; -1 ;", 1)),
        (mode, originals[mode].replace("; 2 ;", "; 32 ;", 1)),
        (mode, originals[mode].replace("; 2 ;", "; 3 ;", 1)),
        (mode, originals[mode].replace("; 31.25 ;", "; 100 ;", 1)),
        (mode, originals[mode].replace("x1_video_handoff_mux", "wrong_clock")),
        (mode, originals[mode].replace("state.RUN", "state.SWITCH")),
        (mode, originals[mode].replace("; -3 ;", "; -2 ;")),
        (raw, "Nothing to report.\n"),
        (raw, originals[raw].replace("dv_csync_meta", "dv_csync_sample")),
        (raw, originals[raw].replace("; -3 ;", "; 1 ;")),
        (global_report, "Nothing to report.\n"),
        (global_report, originals[global_report].splitlines(keepends=True)[0]),
    ]
    for path, contents in mutations:
        path.write_text(contents)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit(root, log)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid probe accepted: {path}")
        finally:
            path.write_text(originals[path])
    repo = pathlib.Path(__file__).resolve().parents[2]
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "hdmi_held_mode_candidate.sdc", "quartus_hdmi_held_mode_probe.tcl"]
    paths = names[:2] + ["scripts/constraints/hdmi_held_mode_candidate.sdc", "scripts/quartus_hdmi_held_mode_probe.tcl"]
    hashes = "".join(f"{hashlib.sha256((repo / path).read_bytes()).hexdigest()}  {name}\n" for name, path in zip(names, paths))
    hashes += "".join(f"{'a'*64}  output_files/sharpx1_turbo_z_handoff.{ext}\n" for ext in ("sta.rpt", "sta.summary", "rbf"))
    log.write_text(hashes * 2)
    audit_sources(log, repo)
    for invalid in (hashes, hashes * 2 + hashes, hashes + hashes.replace('a'*64, 'b'*64), (hashes * 2).replace("hdmi_held_mode_candidate.sdc", "wrong.sdc")):
        log.write_text(invalid)
        try:
            audit_sources(log, repo)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid source/artifact provenance accepted")
print("PASS: synthetic held-mux probe positive; nineteen scope/timing/preservation controls and four provenance controls")
