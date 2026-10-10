"""Synthetic source/384-report integrity controls; never native STA acceptance."""
import contextlib
import hashlib
import io
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from audit_held_sdc_context_probe import audit, audit_sources_3c, CORNERS, KEYS
from audit_hdmi_inactive_data_probe import CLOCKS, PREFETCH
from audit_hdmi_inactive_data_inventory import OUTPUTS
from audit_hdmi_csync_reports import INPUTS, PAIRS, VID, SYS, PREFIX


def row(source, target, launch, latch, slack=1, relationship=10):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; {relationship} ; 0.1 ; 2 ;\n"


def report(check, body):
    return f"Report Timing: Found {len(body)} {check} paths\n" + "".join(body)


with tempfile.TemporaryDirectory(prefix="held-context-3c-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
             "scripts/constraints/hdmi_held_mode_candidate.sdc"]
    paths = names + ["scripts/constraints/hdmi_held_mode_candidate.sdc",
                     "scripts/constraints/hdmi_inactive_data_candidate.sdc",
                     "scripts/quartus_held_sdc_context_probe.tcl"]
    names += ["../held-context-3c6242e-v1/" + name for name in (
        "hdmi_held_mode_candidate.sdc", "hdmi_inactive_data_candidate.sdc",
        "quartus_held_sdc_context_probe.tcl")]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}"
              for ext in ("fit.rpt", "fit.summary", "sta.rpt", "sta.summary", "rbf")]
    # This fixture qualifies an old fitted database, not today's controller.
    # Keep its original fit and diagnostic inputs bound to immutable commits;
    # the auditor's independent literal hashes must not follow current RTL.
    revisions = ["3c6242e771446dc11843cc8f4b7d4c58430b8f17"] * 3 + [
        "cef2210c8609d7850dbc9a615d280514e66c52ba"] * 3
    historical = {name: subprocess.check_output(
        ["git", "show", f"{revision}:{name}"], cwd=ROOT)
        for revision, name in zip(revisions, paths)}
    source_root = root / "source"
    for name, contents in historical.items():
        copied = source_root / name
        copied.parent.mkdir(parents=True, exist_ok=True)
        copied.write_bytes(contents)
    values = [hashlib.sha256(historical[name]).hexdigest() for name in paths]
    values += [
        "1f1c32f1bbd0720cb30f6ef3424abde76c6b1ddc7998e54d7ff1d0ddbfd657e8",
        "f2e9648892464210ff30e08dc26d78eb1ac96a7c099a7805517dbda3e5811212",
        "1eb0fcc7ab73052e2541eb7fa6b1a325b29fc5d2933c1b60c8dfb9a81fcd6f2f",
        "e64eacd636a2543bcbd1c8fa95f50d2ae979a281dfea1a799662f9a6da07ad49",
        "7f6a2009cbebe2caa34fec785bd39a19da0ba58e4f970f2ca80b9f0384d5a993"]
    lines = [f"{value}  {name}\n" for value, name in zip(values, names)]
    log.write_text("".join(lines * 2))
    audit_sources_3c(log, source_root)
    mutations = [lines, lines * 3, lines + list(reversed(lines))]
    for index in range(11):
        wrong = list(lines)
        wrong[index] = "0" * 64 + "  " + names[index] + "\n"
        mutations += [wrong * 2, lines + wrong]
    mutations.append([line.replace("held-context-3c6242e-v1", "other-fit") for line in lines * 2])
    for bad in mutations:
        log.write_text("".join(bad))
        try:
            audit_sources_3c(log, source_root)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid 3c fit/source provenance accepted")

    log.write_text("".join(lines * 2))
    audit_sources_3c(log, source_root)
    for name in sorted(set(paths)):
        copied = source_root / name
        original = copied.read_bytes()
        copied.write_bytes(original + b"changed source")
        try:
            audit_sources_3c(log, source_root)
        except AssertionError:
            pass
        else:
            raise AssertionError("changed source accepted with unchanged provenance log")
        copied.unlink()
        try:
            audit_sources_3c(log, source_root)
        except FileNotFoundError:
            pass
        else:
            raise AssertionError("missing bound source accepted")
        copied.write_bytes(original)

    # An independent literal fifth pin profile; do not derive it from the auditor.
    packed = {"hdmi_dv_hs", "hdmi_dv_vs", "hdmi_dv_data[6]",
              "hdmi_dv_data[13]", "hdmi_dv_data[16]"}
    held = "HELD MUX CANDIDATE: 29 exact D-route pairs; max 31.25 ns/min -31.25; raw inputs and clock pins untouched\n"
    text = "HELD CONTEXT BASELINE INACTIVE OMITTED: paths remain timed\n" + held * 2
    text += "INACTIVE DATA PIN PROFILE fitted3c\n"
    for group, targets in (("output", OUTPUTS), ("prefetch", PREFETCH)):
        for name in sorted(targets):
            pins = ["d", "asdata"] if group == "output" and name != "vs" else [
                "asdata" if group == "prefetch" and name in packed else "d"]
            for pin in pins:
                text += f"INACTIVE DATA CUT {group} {name}|{pin}\n"
    originals = {}
    for phase in ("before", "after"):
        for model, temperature in CORNERS:
            text += f"HELD CONTEXT CORNER {phase} {model} {temperature} 1100\n"
            for check in ("setup", "hold"):
                stem = f"{phase}_{model}_{temperature}"
                for kind, clocks in CLOCKS.items():
                    if kind.startswith("inactive") and phase == "after":
                        content = "Nothing to report.\n"
                    elif kind.startswith("pipe"):
                        content = report(check, [row("hs", "hdmi_out_hs", *clocks)])
                    else:
                        targets = OUTPUTS if kind.endswith("hdmi") else PREFETCH
                        content = report(check, [row("osd:hdmi_osd|" + n if kind.endswith("hdmi")
                            else n.removeprefix("hdmi_"), n, *clocks) for n in sorted(targets)])
                    originals[root / f"{stem}_{kind}_{check}.rpt"] = content
                for kind in INPUTS:
                    clocks = [VID, SYS] if "echo" in kind else [SYS, VID]
                    originals[root / f"{stem}_{kind}_{check}.rpt"] = report(check, [row(*PAIRS[kind], *clocks, -3)])
                selected = [row(*key, relationship=31.25 if check == "setup" else -31.25) for key in sorted(KEYS)]
                selected += [row(PREFIX + "active_mode[0]", PREFIX + "state.RUN", SYS, SYS)]
                originals[root / f"{stem}_mode_{check}.rpt"] = report(check, selected)
                originals[root / f"{stem}_global_{check}.rpt"] = report(check, [row(f"s{i}", f"t{i}", SYS, SYS, -5) for i in range(50)])
    text += "HELD CONTEXT PROBE COMPLETE: same-fit context comparison only; no full-flow or hardware acceptance\n"
    text += "TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n"
    originals[log] = text
    for path, content in originals.items():
        path.write_text(content)
    def check():
        with contextlib.redirect_stdout(io.StringIO()):
            return audit(root, log, "fitted3c")
    result = check()
    assert result[1] == 816 and result[3] == 928 and result[4] == {"setup": -5, "hold": -5}
    active = root / "after_slow_-40_active_hdmi_setup.rpt"
    raw = root / "after_fast_100_epoch_input_hold.rpt"
    mode = root / "after_slow_0_mode_setup.rpt"
    invalid = [
        (log, text.replace("fitted3c", "fitted048")),
        (log, text.replace("hdmi_dv_vs|asdata", "hdmi_dv_vs|d")),
        (log, text + "INACTIVE DATA CUT output hs|d\n"),
        (log, text.replace("0 warnings", "1 warning")),
        (log, text + "Warning: ignored constraint\n"),
        (log, text.replace("after fast 100", "after fast 85")),
        (active, originals[active].replace("; 1 ;", "; 2 ;", 1)),
        (active, "Nothing to report.\n"),
        (raw, "Nothing to report.\n"),
        (raw, originals[raw].replace("; -3 ;", "; -2 ;", 1)),
        (mode, originals[mode].replace("; 31.25 ;", "; 100 ;", 1)),
        (mode, originals[mode].replace("d[0]", "unreviewed_target")),
        (root / "after_fast_100_inactive_video_hold.rpt", report("hold", [row("dv_hs", "hdmi_dv_hs", *CLOCKS["inactive_video"])])),
        (root / "after_fast_100_global_setup.rpt", row("s", "t", SYS, SYS))]
    for path, content in invalid:
        path.write_text(content)
        try:
            check()
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid 3c preservation accepted: {path}")
        finally:
            path.write_text(originals[path])
print(f"PASS synthetic 3c: 26 provenance and 10 actual-source rejections; 384-report positive and {len(invalid)} scope/preservation rejections; negative global slack stays reported")
