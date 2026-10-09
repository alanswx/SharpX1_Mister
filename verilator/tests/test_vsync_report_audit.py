"""Synthetic parser/scope controls, not native timing evidence."""
import contextlib
import io
import pathlib
import shutil
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_vsync_sys_reports import audit, FIRST, LAST, SYS
from audit_vsync_sys_probe import audit_probe

RAW = "hdmi_out_vs~_Duplicate_1"


def row(source, destination, launch=SYS, latch=SYS, slack="0.250", data="0.500"):
    # Large skew is intentional: physical delay is the final column, not skew.
    return [slack, source, destination, launch, latch, "31.250", "999.000", data]


def write(path, rows):
    path.write_text("\n".join("; " + " ; ".join(r) + " ;" for r in rows) + "\n")


with tempfile.TemporaryDirectory(prefix="x1-vsync-audit-") as temporary:
    root = pathlib.Path(temporary)
    valid = root / "valid"
    valid.mkdir()
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            for check in ("setup", "hold"):
                prefix = f"sharpx1_turbo_z_video_vsync_sys_{model}_{temperature}"
                for kind in ("chain", "first_fanout"):
                    write(valid / f"{prefix}_{kind}_{check}.rpt", [row(FIRST, LAST)])
                write(valid / f"{prefix}_consumer_{check}.rpt", [row(LAST, c) for c in ("vsd", "vs_d0", "vs_d1")])
                write(valid / f"{prefix}_input_{check}.rpt", [row(RAW, FIRST, c, slack="-40.000") for c in ("x1_hdmi_mux", "x1_video_mux")])
    with contextlib.redirect_stdout(io.StringIO()):
        assert audit(valid, RAW) == (80, .25, 32, -40)
    probe = root / "probe"
    probe.mkdir()
    for file in valid.iterdir():
        before_name = file.name.replace("vsync_sys_", "vsync_sys_probe_before_")
        after_name = before_name.replace("probe_before", "probe_after")
        shutil.copyfile(file, probe / before_name)
        if "_input_" in file.name:
            (probe / after_name).write_text("; Report Timing ;\nNothing to report.\n")
        else:
            shutil.copyfile(file, probe / after_name)
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            for phase in ("before", "after"):
                for check in ("setup", "hold"):
                    slack = {("before", "setup"): "-40.000", ("before", "hold"): "-1.800",
                             ("after", "setup"): "-12.017", ("after", "hold"): "0.017"}[phase, check]
                    path = probe / f"sharpx1_turbo_z_video_vsync_sys_probe_{phase}_{model}_{temperature}_global_{check}.rpt"
                    write(path, [row(LAST, "vsd", slack=slack)])
    with contextlib.redirect_stdout(io.StringIO()):
        assert audit_probe(probe, RAW)["after", "hold"] == .017
    for control in ("changed_sync", "retained_raw", "empty_global", "missing_pair", "malformed_excluded"):
        directory = root / ("probe-" + control)
        shutil.copytree(probe, directory)
        prefix = "sharpx1_turbo_z_video_vsync_sys_probe_after_fast_100_"
        consumer = directory / (prefix + "consumer_hold.rpt")
        if control == "changed_sync":
            write(consumer, [row(LAST, c, data="0.600") for c in ("vsd", "vs_d0", "vs_d1")])
        elif control == "retained_raw":
            write(directory / (prefix + "input_hold.rpt"), [row(RAW, FIRST, "x1_hdmi_mux")])
        elif control == "empty_global":
            (directory / (prefix + "global_hold.rpt")).write_text("Nothing to report.\n")
        elif control == "missing_pair":
            consumer.unlink()
        else:
            (directory / (prefix + "input_hold.rpt")).write_text("")
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit_probe(directory, RAW)
        except (AssertionError, FileNotFoundError, ValueError):
            pass
        else:
            raise AssertionError(f"probe control passed: {control}")
    for control in ("missing", "empty", "first_leak", "fanout_extra", "wrong_chain",
                    "negative_chain", "negative_consumer", "wrong_clock", "duplicate_consumer",
                    "missing_alias", "wrong_raw", "large_data", "nonfinite_data"):
        directory = root / control
        shutil.copytree(valid, directory)
        prefix = "sharpx1_turbo_z_video_vsync_sys_fast_100_"
        consumer = directory / (prefix + "consumer_hold.rpt")
        chain = directory / (prefix + "chain_hold.rpt")
        if control == "missing":
            consumer.unlink()
        elif control == "empty":
            consumer.write_text("No paths\n")
        elif control == "first_leak":
            write(consumer, [row(FIRST, c) for c in ("vsd", "vs_d0", "vs_d1")])
        elif control == "fanout_extra":
            write(directory / (prefix + "first_fanout_hold.rpt"), [row(FIRST, LAST), row(FIRST, "vsd")])
        elif control == "wrong_chain":
            write(chain, [row(FIRST, "unknown")])
        elif control == "negative_chain":
            write(chain, [row(FIRST, LAST, slack="-0.001")])
        elif control == "negative_consumer":
            write(consumer, [row(LAST, c, slack="-0.001") for c in ("vsd", "vs_d0", "vs_d1")])
        elif control == "wrong_clock":
            write(consumer, [row(LAST, c, launch="wrong") for c in ("vsd", "vs_d0", "vs_d1")])
        elif control == "duplicate_consumer":
            write(consumer, [row(LAST, c) for c in ("vsd", "vs_d0", "vs_d0")])
        elif control == "missing_alias":
            write(directory / (prefix + "input_hold.rpt"), [row(RAW, FIRST, "x1_hdmi_mux")])
        elif control == "wrong_raw":
            write(directory / (prefix + "input_hold.rpt"), [row("wrong", FIRST, c) for c in ("x1_hdmi_mux", "x1_video_mux")])
        else:
            data = "31.250" if control == "large_data" else "nan"
            write(consumer, [row(LAST, c, data=data) for c in ("vsd", "vs_d0", "vs_d1")])
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit(directory, RAW)
        except (AssertionError, FileNotFoundError, ValueError):
            pass
        else:
            raise AssertionError(f"negative control passed: {control}")
print("PASS: VSYNC report parser/scope and 13 rejecting controls; mock only")
print("PASS: paired-probe preservation/exclusion audit and five rejecting controls; mock only")
