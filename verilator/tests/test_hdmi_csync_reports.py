"""Synthetic report/provenance controls, not native timing evidence."""
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile

repo = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(repo / "scripts"))
from audit_hdmi_csync_reports import audit, audit_sources, PAIRS, FIRST, INPUTS, CONSUMERS, PREFIX, SYS, VID


def row(source, target, launch, latch, slack=1):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; 10 ; 0.1 ; 1 ;\n"


with tempfile.TemporaryDirectory(prefix="x1-csync-report-controls-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    originals = {log: "".join(f"CSYNC BOARD PAIR {kind} {source} {target}\n" for kind, (source, target) in PAIRS.items())}
    originals[log] += "".join(f"CSYNC BOARD FIRST FANOUT {first} {second}\n" for first, second in FIRST)
    originals[log] += "".join(f"CSYNC BOARD INPUT DRIVER {kind} {PAIRS[kind][0]}\n" for kind in INPUTS)
    for source in CONSUMERS.values():
        for target in (PREFIX + "state.OPEN", PREFIX + "state.SWITCH"):
            originals[log] += f"CSYNC BOARD CONSUMER {source} {target} (reg)\n"
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            originals[log] += f"CSYNC BOARD CORNER {model} {temperature} 1100\n"
            for check in ("setup", "hold"):
                for kind, (source, target) in PAIRS.items():
                    if kind in INPUTS:
                        clocks = (VID, SYS) if "echo" in kind else (SYS, VID)
                    else:
                        clock = SYS if kind.endswith("return") else VID
                        clocks = (clock, clock)
                    originals[root / f"{model}_{temperature}_{kind}_{check}.rpt"] = row(source, target, *clocks, -2 if kind in INPUTS else 1)
                for kind, source in CONSUMERS.items():
                    originals[root / f"{model}_{temperature}_{kind}_consumer_{check}.rpt"] = f"Report Timing: Found 2 {check} paths\n" + "".join(row(source, PREFIX + target, SYS, SYS) for target in ("state.OPEN", "state.SWITCH"))
                originals[root / f"{model}_{temperature}_global_{check}.rpt"] = "".join(row(f"s{i}", f"t{i}", SYS, SYS, -3) for i in range(50))
    originals[log] += "CSYNC BOARD INVENTORY COMPLETE: existing constraints only; not whole-board acceptance\nTimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n"
    for path, text in originals.items():
        path.write_text(text)
    with contextlib.redirect_stdout(io.StringIO()):
        assert audit(root, log)[0] == 272
    stage = root / "slow_-40_epoch_stage_setup.rpt"
    raw = root / "fast_100_csync_input_hold.rpt"
    consumer = root / "slow_100_csync_consumer_setup.rpt"
    global_report = root / "fast_0_global_hold.rpt"
    mutations = [
        (log, originals[log].replace("0 warnings", "1 warning")),
        (log, originals[log] + "Warning: ignored register\n"),
        (log, originals[log].replace("existing constraints only", "new whole-domain exception")),
        (log, originals[log].replace("PAIR epoch_stage dv_epoch_meta", "PAIR epoch_stage WRONG")),
        (log, originals[log].replace("FIRST FANOUT dv_epoch_meta dv_epoch_sample", "FIRST FANOUT dv_epoch_meta WRONG")),
        (log, originals[log].replace("INPUT DRIVER csync_input " + PREFIX, "INPUT DRIVER csync_input WRONG")),
        (log, originals[log].replace("CSYNC BOARD CORNER fast 100 1100\n", "")),
        (log, originals[log] + "CSYNC BOARD CORNER slow -40 1100\n"),
        (log, originals[log].replace("CONSUMER dv_policy_sample", "CONSUMER WRONG", 1)),
        (log, originals[log].replace("state.OPEN (reg)", "state.BAD (reg)", 1)),
        (stage, originals[stage].replace("; 1 ;", "; -1 ;", 1)),
        (stage, originals[stage] * 2),
        (stage, originals[stage].replace("dv_epoch_sample", "WRONG")),
        (stage, originals[stage].replace(VID, SYS)),
        (raw, originals[raw].replace(VID, SYS)),
        (raw, originals[raw].replace("dv_csync_meta", "WRONG")),
        (consumer, originals[consumer].replace("Found 2", "Found 1000")),
        (consumer, originals[consumer].replace("; 1 ;", "; -1 ;", 1)),
        (consumer, originals[consumer].replace("dv_csync_echo_sample", "WRONG")),
        (consumer, "Nothing to report.\n"),
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
            raise AssertionError(f"invalid csync evidence accepted: {path.name}")
        path.write_text(originals[path])
    inputs = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "scripts/quartus_hdmi_csync_inventory.tcl"]
    names = inputs[:2] + ["csync_board_inventory_diagnostic.tcl"] + [f"output_files/sharpx1_turbo_z_handoff.{e}" for e in ("sta.rpt", "sta.summary", "rbf")]
    values = [hashlib.sha256((repo / path).read_bytes()).hexdigest() for path in inputs] + ["a" * 64, "b" * 64, "c" * 64]
    hashes = "".join(f"{value}  {name}\n" for value, name in zip(values, names))
    log.write_text(hashes * 2)
    audit_sources(log, repo)
    for candidate in (hashes, hashes * 2 + hashes.splitlines(keepends=True)[0],
                      (hashes * 2).replace(values[0], "0" * 64),
                      (hashes * 2).replace(values[3], "0" * 64, 1)):
        log.write_text(candidate)
        try:
            audit_sources(log, repo)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid csync provenance accepted")
print("PASS: synthetic 320-report csync positive; 22 invalid scope/timing controls and four invalid provenance controls")
