"""Synthetic inactive-bank report controls; not fitted/hardware evidence."""
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_hdmi_inactive_data_inventory import audit, audit_sources, CLOCKS, OUTPUTS


def row(source, target, launch, latch, slack):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; 1 ; 0.1 ; 2 ;\n"


with tempfile.TemporaryDirectory(prefix="inactive-bank-controls-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    prefetch = {"hdmi_dv_hs", "hdmi_dv_vs", "hdmi_dv_de"} | {f"hdmi_dv_data[{i}]" for i in range(24)}
    drivers = {t: "osd:hdmi_osd|" + t for t in OUTPUTS}
    drivers.update({t: t.removeprefix("hdmi_") for t in prefetch})
    originals = {log: "".join(f"INACTIVE DATA CLOCK PAIR {k} {a} {b}\n" for k, (a, b) in CLOCKS.items())}
    for target, source in sorted(drivers.items()):
        originals[log] += f"INACTIVE DATA TARGET {target}\nINACTIVE DATA DRIVER {target} {source} (reg)\nINACTIVE DATA PIN {target} {target}|d\n"
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            originals[log] += f"INACTIVE DATA CORNER {model} {temperature} 1100\n"
            for check in ("setup", "hold"):
                for kind, clocks in CLOCKS.items():
                    targets = OUTPUTS if kind == "hdmi_to_video" else prefetch
                    originals[root / f"{model}_{temperature}_{kind}_{check}.rpt"] = f"Report Timing: Found 27 {check} paths\n" + "".join(row(drivers[t], t, *clocks, -2 if check == "setup" else 1) for t in sorted(targets))
    originals[log] += "INACTIVE DATA INVENTORY COMPLETE: discovery only; no exclusions or timing acceptance\nTimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n"
    for path, content in originals.items():
        path.write_text(content)
    with contextlib.redirect_stdout(io.StringIO()):
        result = audit(root, log)
    assert result[0] == 864
    report = root / "slow_-40_hdmi_to_video_setup.rpt"
    video = root / "fast_100_video_to_hdmi_hold.rpt"
    mutations = [
        (log, originals[log].replace("0 warnings", "1 warning")),
        (log, originals[log] + "Warning: ignored filter\n"),
        (log, originals[log].replace("CORNER fast 100", "CORNER fast 85")),
        (log, originals[log].replace("INACTIVE DATA INVENTORY COMPLETE", "INCOMPLETE")),
        (log, originals[log] + "INACTIVE DATA TARGET hs\n"),
        (log, originals[log].replace("INACTIVE DATA TARGET hs\n", "")),
        (log, originals[log].replace("INACTIVE DATA PIN hs hs|d\n", "")),
        (log, originals[log].replace("hs|d", "hs|clk")),
        (log, originals[log].replace("(reg)", "(pin)", 1)),
        (log, originals[log].replace("hdmi_dv_data[23]", "hdmi_dv_data[24]")),
        (log, originals[log].replace("INACTIVE DATA CLOCK PAIR hdmi_to_video", "INACTIVE DATA CLOCK PAIR swapped")),
        (report, "Nothing to report.\n"),
        (report, originals[report].replace("Found 27", "Found 1000")),
        (report, originals[report].replace("d[0]", "other_keeper")),
        (report, originals[report].replace("osd:hdmi_osd|", "wrong_bank|")),
        (report, originals[report].replace("x1_video_handoff_mux", "x1_hdmi_handoff_mux")),
        (report, originals[report].replace("; 2 ;", "; -1 ;", 1)),
        (video, originals[video].replace("dv_data[0]", "dv_data[1]", 1)),
        (video, originals[video] + originals[video].splitlines(keepends=True)[1]),
    ]
    for path, content in mutations:
        path.write_text(content)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit(root, log)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid bank discovery accepted: {path}")
        finally:
            path.write_text(originals[path])
    repo = pathlib.Path(__file__).resolve().parents[2]
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "inactive_data_inventory_diagnostic.tcl"]
    paths = names[:2] + ["scripts/quartus_hdmi_inactive_data_inventory.tcl"]
    hashes = "".join(f"{hashlib.sha256((repo / p).read_bytes()).hexdigest()}  {n}\n" for n, p in zip(names, paths))
    hashes += "".join(f"{'a'*64}  output_files/sharpx1_turbo_z_handoff.{ext}\n" for ext in ("sta.rpt", "sta.summary", "rbf"))
    log.write_text(hashes * 2)
    audit_sources(log, repo)
    for bad in (hashes, hashes * 3, hashes + hashes.replace('a'*64, 'b'*64), (hashes * 2).replace("inactive_data_inventory_diagnostic.tcl", "other.tcl")):
        log.write_text(bad)
        try:
            audit_sources(log, repo)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid provenance accepted")
print(f"PASS: synthetic 32-report discovery positive; {len(mutations)} invalid scope/pin/driver/corner/report controls and four provenance controls")
