"""Synthetic independent report controls. Not native timing evidence."""
import contextlib
import io
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_hdmi_handoff_board_reports import audit, PAIRS, PREFIX, MUX_CLOCKS, SYS


def row(source, target, clock, slack=1):
    return f"; {slack} ; {source} ; {target} ; {clock} ; {clock} ; 10 ; 0.1 ; 1 ;\n"


with tempfile.TemporaryDirectory(prefix="handoff-board-report-controls-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    originals = {log: "".join(f"HANDOFF BOARD PAIR {kind} {source} {target}\n" for kind, (source, target) in PAIRS.items())}
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            originals[log] += f"HANDOFF BOARD CORNER {model} {temperature} 1100\n"
            for check in ("setup", "hold"):
                for kind, (source, target) in PAIRS.items():
                    clocks = {SYS} if kind in {"ack", "completed", "gate_status"} else MUX_CLOCKS
                    originals[root / f"{model}_{temperature}_{kind}_{check}.rpt"] = "".join(row(PREFIX + source, PREFIX + target, clock) for clock in sorted(clocks))
                originals[root / f"{model}_{temperature}_global_{check}.rpt"] = "".join(row(f"s{i}", f"t{i}", SYS, -2 if check == "setup" else 0.2) for i in range(50))
    originals[log] += "HANDOFF BOARD INVENTORY COMPLETE: original SDC only; not whole-board acceptance\nTimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n"
    for path, text in originals.items():
        path.write_text(text)
    with contextlib.redirect_stdout(io.StringIO()):
        assert audit(root, log)[0] == 208
    enabled = root / "slow_-40_enable_setup.rpt"
    ack = root / "fast_100_ack_hold.rpt"
    global_report = root / "slow_0_global_setup.rpt"
    mutations = [
        (log, originals[log].replace("0 warnings", "1 warning")),
        (log, originals[log] + "Warning: ignored filter\n"),
        (log, originals[log].replace("PAIR ack ack_meta", "PAIR ack gate_meta")),
        (log, originals[log].replace("HANDOFF BOARD CORNER fast 100 1100\n", "")),
        (log, originals[log] + "HANDOFF BOARD CORNER slow -40 1100\n"),
        (log, originals[log].replace("1100", "1000")),
        (log, originals[log].replace("original SDC only", "whole PLL exception")),
        (enabled, originals[enabled].splitlines(keepends=True)[0]),
        (enabled, originals[enabled] * 2),
        (enabled, originals[enabled].replace("; 1 ;", "; -1 ;", 1)),
        (enabled, originals[enabled].replace("x1_video_handoff_mux", "x1_hdmi_handoff_mux")),
        (ack, originals[ack].replace("ack_sample", "blank_sample")),
        (ack, "Nothing to report.\n"),
        (ack, originals[ack].replace(f"; {SYS} ; {SYS} ;", f"; {SYS} ; x1_hdmi_handoff_mux ;")),
        (global_report, "Nothing to report.\n"),
        (global_report, originals[global_report].splitlines(keepends=True)[0]),
    ]
    for path, text in mutations:
        path.write_text(text)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit(root, log)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid full-board evidence accepted: {path.name}")
        path.write_text(originals[path])
print("PASS: full-board 208-row synthetic positive and sixteen invalid scope/corner/timing controls")
