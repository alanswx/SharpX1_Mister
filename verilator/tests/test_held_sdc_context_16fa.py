"""Synthetic exact-16fa binding/preservation negatives; not native acceptance."""
import collections
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from audit_held_sdc_context_probe import (
    audit, audit_provenance_16fa, audit_sources_16fa, verify_bound_files, CORNERS, KEYS)
from audit_hdmi_inactive_data_probe import CLOCKS, PREFETCH
from audit_hdmi_inactive_data_inventory import OUTPUTS
from audit_hdmi_csync_reports import INPUTS, PAIRS, VID, SYS, PREFIX

# Independent literals: do not derive the expected fit/proposal from the auditor
# or current RTL. The five artifacts belong to the failed original full flow.
NAMES = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
         "scripts/constraints/hdmi_held_mode_candidate.sdc"]
NAMES += ["../held-context-16fa816-v1/" + name for name in (
    "hdmi_held_mode_candidate.sdc", "hdmi_inactive_data_candidate.sdc",
    "quartus_held_sdc_context_probe.tcl")]
NAMES += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in (
    "fit.rpt", "fit.summary", "sta.rpt", "sta.summary", "rbf")]
VALUES = [
    "1ea8f6f3c523efc8de5ecd176c7ff1bb4cf43f42bfb3641bcecf78798d91aeca",
    "583dd6f99967b8fc10df7f83ae92e6206f7c0874c51985669609831fcb800630",
    "e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1",
    "e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1",
    "208e236c48d5305ffe585dae9641e51a4b02f3dc0868c5ae6c4495d1599ad61f",
    "980d9cb7523d6b556af0a2f65ba693b85374244b30e20634ff79ac96885cb37f",
    "709c5d21abb2b045f53ee21ba37b93decf5e2e459b3b7f90e27529b5bbeb84d2",
    "21182a678ded966e9177777c758096c17ff54d23879d78b457ea72b4b60784b8",
    "8e79bcb271c9cd58c7afbac914956a52d601374178aa166b7a6b4c2449d91e89",
    "2838ece4f86af3367728e30fe013fa908c7b011fe82d7a774fdff36fd6ae9782",
    "45110cb947f00fa690e2b28a24cf666fc363bf9b37513d151c270645dbb6f483"]


def rejects(call):
    try:
        call()
    except (AssertionError, FileNotFoundError):
        return
    raise AssertionError("invalid binding/preservation accepted")


def row(source, target, launch, latch, slack=1, relationship=10):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; {relationship} ; 0.1 ; 2 ;\n"


def report(check, body):
    return f"Report Timing: Found {len(body)} {check} paths\n" + "".join(body)


with tempfile.TemporaryDirectory(prefix="held-context-16fa-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    records = list(zip(VALUES, NAMES))
    lines = [f"{value}  {name}\n" for value, name in records]
    log.write_text("".join(lines * 2))
    assert audit_provenance_16fa(log) == records
    mutations = [lines, lines * 3, lines + list(reversed(lines))]
    for index in range(11):
        wrong = list(lines)
        wrong[index] = "0" * 64 + "  " + NAMES[index] + "\n"
        mutations += [wrong * 2, lines + wrong]
    mutations.append([line.replace("held-context-16fa816-v1", "other-fit") for line in lines * 2])
    for bad in mutations:
        log.write_text("".join(bad))
        rejects(lambda: audit_provenance_16fa(log))
    log.write_text("".join(lines * 2))

    # Independently exercise the actual-byte verifier across all eleven paths.
    # Synthetic artifact bytes are NOT claimed to be the real fitted artifacts.
    source_root = root / "source"
    synthetic = []
    for index, name in enumerate(NAMES):
        path = source_root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        content = f"synthetic binding control {index}\n".encode()
        path.write_bytes(content)
        synthetic.append((hashlib.sha256(content).hexdigest(), name))
    verify_bound_files(source_root, synthetic)
    for _, name in synthetic:
        path = source_root / name
        original = path.read_bytes()
        path.write_bytes(original + b"mutation")
        rejects(lambda: verify_bound_files(source_root, synthetic))
        path.unlink()
        rejects(lambda: verify_bound_files(source_root, synthetic))
        path.write_bytes(original)
    # Equal before/after log records cannot validate substituted actual files.
    rejects(lambda: audit_sources_16fa(log, source_root))

    packed = {"hdmi_dv_hs", "hdmi_dv_vs", "hdmi_dv_data[5]",
              "hdmi_dv_data[6]", "hdmi_dv_data[9]", "hdmi_dv_data[11]"}
    held = "HELD MUX CANDIDATE: 29 exact D-route pairs; max 31.25 ns/min -31.25; raw inputs and clock pins untouched\n"
    text = "HELD CONTEXT BASELINE INACTIVE OMITTED: paths remain timed\n" + held * 2
    text += "INACTIVE DATA PIN PROFILE fitted16fa\n"
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
            return audit(root, log, "fitted16fa")

    result = check()
    assert result[1] == 816 and result[3] == 928 and result[4] == {"setup": -5, "hold": -5}
    active = root / "after_slow_-40_active_hdmi_setup.rpt"
    raw = root / "after_fast_100_epoch_input_hold.rpt"
    mode = root / "after_slow_0_mode_setup.rpt"
    invalid = [
        (log, text.replace("fitted16fa", "fitted3c")),
        (log, text.replace("hdmi_dv_data[5]|asdata", "hdmi_dv_data[5]|d")),
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
        rejects(check)
        path.write_text(originals[path])
    removed = root / "after_fast_100_active_video_hold.rpt"
    removed.unlink()
    rejects(check)
    removed.write_text(originals[removed])
    extra = root / "extra.rpt"
    extra.write_text("Nothing to report.\n")
    rejects(check)
    check_count = len(invalid) + 2
print(f"PASS synthetic 16fa: {len(mutations)} provenance negatives; 22 actual-byte/missing-file negatives; substituted-fit rejection; 384-report positive and {check_count} scope/preservation negatives; negative global slack retained")
