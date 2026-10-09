"""Synthetic auditor controls only; native fitting is a separate gate."""
import pathlib
import sys
import tempfile
import contextlib
import io

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_hdmi_handoff_probe import audit, audit_all_corners, PREFIX, CLOCKS, PAIRS


def row(source, target, launch, latch, slack=1):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; 10 ; 0.1 ; 1 ;\n"


with tempfile.TemporaryDirectory(prefix="hdmi-handoff-probe-controls-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    originals = {log: (
        "HANDOFF PROBE two generated mux choices only; PLL masters remain concurrent\n"
        f"HANDOFF ENABLE FANOUT gate_request_meta {PREFIX}gate_request_sample (reg)\n"
        f"HANDOFF ENABLE FANOUT gate_request_sample {PREFIX}gate~FF_0 (reg)\n"
        f"HANDOFF ENABLE FANOUT gate_request_sample {PREFIX}gate_observed_enable (reg)\n"
        "HANDOFF STATUS FANIN refclk (port)\n"
        f"HANDOFF STATUS FANIN {PREFIX}gate_observed_enable (reg)\n"
        "TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n")}
    for kind, (source, target) in PAIRS.items():
        for check in ("setup", "hold"):
            originals[root / f"handoff_probe_mux_{kind}_{check}.rpt"] = "".join(
                row(PREFIX+source, PREFIX+target, clock, clock) for clock in sorted(CLOCKS))
    raw = root / "handoff_probe_mux_raw_enable_setup.rpt"
    originals[raw] = "".join(row(PREFIX+"gate_request", PREFIX+"gate_request_meta", "probe_ref", clock, -2) for clock in sorted(CLOCKS))
    for check in ("setup", "hold"):
        originals[root / f"handoff_probe_mux_global_{check}.rpt"] = "".join(
            row(f"source{i}", f"target{i}", "probe_ref", "probe_mux_video", -3) for i in range(50))
    for path, content in originals.items():
        path.write_text(content)
    audit(root, log)
    enable = root / "handoff_probe_mux_enable_setup.rpt"
    native = root / "handoff_probe_mux_native_gate_hold.rpt"
    global_report = root / "handoff_probe_mux_global_setup.rpt"
    changes = [
        (log, originals[log].replace("0 warnings", "1 warning")),
        (log, originals[log] + "Warning: Ignored filter\n"),
        (log, originals[log].replace("two generated mux choices only", "whole PLL exclusion")),
        (log, originals[log] + f"HANDOFF ENABLE FANOUT gate_request_meta {PREFIX}consumer (reg)\n"),
        (log, originals[log] + f"HANDOFF ENABLE FANOUT gate_request_sample {PREFIX}consumer (reg)\n"),
        (log, originals[log].replace("STATUS FANIN " + PREFIX + "gate_observed_enable", "STATUS FANIN " + PREFIX + "gate_request_sample")),
        (enable, originals[enable].splitlines(keepends=True)[0]),
        (enable, originals[enable] + originals[enable]),
        (enable, originals[enable].replace("probe_mux_hdmi ; probe_mux_hdmi", "probe_mux_hdmi ; probe_mux_video")),
        (native, originals[native].replace("gate~FF_0", "gate_request_sample")),
        (native, originals[native].replace("; 1 ;", "; -1 ;", 1)),
        (raw, "Nothing to report.\n"),
        (raw, originals[raw].replace("probe_ref", "probe_mux_video")),
        (raw, originals[raw].replace("; -2 ;", "; 2 ;")),
        (global_report, "Nothing to report.\n"),
    ]
    for path, content in changes:
        path.write_text(content)
        try:
            audit(root, log)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid probe accepted: {path.name}")
        path.write_text(originals[path])
    corners = [(model, temperature) for model in ("slow", "fast") for temperature in (-40, 0, 85, 100)]
    markers = [f"HANDOFF PROBE CORNER {model} {temperature} 1100\n" for model, temperature in corners]
    all_log = originals[log] + "".join(markers)
    for model, temperature in corners:
        for path, content in originals.items():
            if path != log:
                target = root / path.name.replace("handoff_probe_mux_", f"handoff_probe_mux_{model}_{temperature}_")
                target.write_text(content)
    log.write_text(all_log)
    with contextlib.redirect_stdout(io.StringIO()):
        assert len(audit_all_corners(root, log)) == 8
    for invalid in (originals[log], all_log.replace(markers[0], ""),
                    all_log + markers[0], all_log.replace("1100", "1000"),
                    originals[log] + "".join(reversed(markers))):
        log.write_text(invalid)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit_all_corners(root, log)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid corner enumeration accepted")
    log.write_text(all_log)
    final = root / "handoff_probe_mux_fast_100_native_gate_hold.rpt"
    final.write_text("Nothing to report.\n")
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            audit_all_corners(root, log)
    except AssertionError:
        pass
    else:
        raise AssertionError("missing final-corner native gate report accepted")
print("PASS: one/eight-corner probe positives, fifteen invalid scope controls and six invalid corner controls")
