"""Synthetic exact-9cc binding/preservation controls; NOT native fit bytes."""
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from audit_held_sdc_context_probe import (
    audit, audit_provenance_9cc, audit_sources_9cc, verify_bound_files,
    CORNERS, KEYS)
from audit_hdmi_inactive_data_probe import CLOCKS, PREFETCH
from audit_hdmi_inactive_data_inventory import OUTPUTS
from audit_hdmi_csync_reports import INPUTS, PAIRS, VID, SYS, PREFIX

# Independent literals, never inferred from the auditor or current candidates.
NAMES = [
    "rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
    "scripts/constraints/hdmi_held_mode_candidate.sdc",
    "../held-context-9cc1141-v1/hdmi_held_mode_candidate.sdc",
    "../held-context-9cc1141-v1/hdmi_inactive_data_candidate.sdc",
    "../held-context-9cc1141-v1/quartus_held_sdc_context_probe.tcl",
    "output_files/sharpx1_turbo_z_handoff.fit.rpt",
    "output_files/sharpx1_turbo_z_handoff.fit.summary",
    "output_files/sharpx1_turbo_z_handoff.sta.rpt",
    "output_files/sharpx1_turbo_z_handoff.sta.summary",
    "output_files/sharpx1_turbo_z_handoff.rbf",
]
VALUES = [
    "1ea8f6f3c523efc8de5ecd176c7ff1bb4cf43f42bfb3641bcecf78798d91aeca",
    "939d6dd444a00efdfe8b06cb054817e858c31949f1a2f9cc2d934b50315aa609",
    "e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1",
    "e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1",
    "b80a0946ca3b310f8e87254f587c26d9414292df24ddf247fd283cc1ab2dd6ad",
    "980d9cb7523d6b556af0a2f65ba693b85374244b30e20634ff79ac96885cb37f",
    "2c1808d2dd56fb10b7122506f58a022043eeb1bbe6cf4a252b9ff9da48356f83",
    "c62641592aca5ea0dce9634a964f5976fba93b00947f1cc7212eec54f9e80cca",
    "7f1eaee6d531b7b05f332678084e7a3c2ebd4a2daad0bad0b70c07dbeefb7440",
    "a52789978cc7ab21fb40cd5bb442fa54d99720d380f5a483cd2e2c4b6fcc7037",
    "069c84661bdf0cb85da64db3d2f3b9fe203778122fa57cf83bc4d35effcb6b41",
]
PACKED = {"hdmi_dv_hs", "hdmi_dv_vs", "hdmi_dv_de",
          "hdmi_dv_data[0]", "hdmi_dv_data[1]", "hdmi_dv_data[5]",
          "hdmi_dv_data[7]", "hdmi_dv_data[12]", "hdmi_dv_data[16]",
          "hdmi_dv_data[17]", "hdmi_dv_data[19]", "hdmi_dv_data[23]"}


def rejects(call):
    try:
        call()
    except (AssertionError, FileNotFoundError):
        return
    raise AssertionError("invalid 9cc binding/preservation accepted")


def row(source, target, launch, latch, slack=1, relationship=10):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; {relationship} ; 0.1 ; 2 ;\n"


def report(check, body):
    return f"Report Timing: Found {len(body)} {check} paths\n" + "".join(body)


with tempfile.TemporaryDirectory(prefix="held-context-9cc-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    records = list(zip(VALUES, NAMES))
    lines = [f"{value}  {name}\n" for value, name in records]
    log.write_text("".join(lines * 2))
    assert audit_provenance_9cc(log) == records
    mutations = [lines, lines * 3, lines + list(reversed(lines))]
    for index in range(11):
        wrong = list(lines)
        wrong[index] = "0" * 64 + "  " + NAMES[index] + "\n"
        mutations += [wrong * 2, lines + wrong]
    mutations.append([line.replace("held-context-9cc1141-v1", "other-fit") for line in lines * 2])
    for bad in mutations:
        log.write_text("".join(bad))
        rejects(lambda: audit_provenance_9cc(log))
    log.write_text("".join(lines * 2))

    # Hash only clearly marked synthetic files for the byte-verifier tests.
    # These are NOT preimages of, or substitutes for, actual native artifacts.
    source_root = root / "source"
    synthetic = []
    for index, name in enumerate(NAMES):
        path = source_root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        content = f"SYNTHETIC 9cc byte-verifier control {index}\n".encode()
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
    rejects(lambda: audit_sources_9cc(log, source_root))

    held = "HELD MUX CANDIDATE: 29 exact D-route pairs; max 31.25 ns/min -31.25; raw inputs and clock pins untouched\n"
    text = "HELD CONTEXT BASELINE INACTIVE OMITTED: paths remain timed\n" + held * 2
    text += "INACTIVE DATA PIN PROFILE fitted9cc\n"
    for group, targets in (("output", OUTPUTS), ("prefetch", PREFETCH)):
        for name in sorted(targets):
            pins = ["d", "asdata"] if group == "output" and name != "vs" else [
                "asdata" if group == "prefetch" and name in PACKED else "d"]
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
            return audit(root, log, "fitted9cc")

    result = check()
    # Synthetic scopes have 816 inactive rows, not the real fit's measured count.
    assert result[1] == 816 and result[3] == 928
    assert result[4] == {"setup": -5, "hold": -5}
    active = root / "after_slow_-40_active_hdmi_setup.rpt"
    raw = root / "after_fast_100_epoch_input_hold.rpt"
    mode = root / "after_slow_0_mode_setup.rpt"
    invalid = [
        (log, text.replace("fitted9cc", "fitted16fa")),
        (log, text.replace("hdmi_dv_data[7]|asdata", "hdmi_dv_data[7]|d")),
        (log, text.replace("hdmi_dv_data[6]|d", "hdmi_dv_data[6]|asdata")),
        (log, text + "INACTIVE DATA CUT output hs|d\n"),
        (log, text.replace("hdmi_dv_hs|asdata", "hdmi_dv_hs|clk")),
        (log, text.replace("hs|d\n", "hs|sload\n")),
        (log, text + "INACTIVE DATA CUT prefetch dv_epoch_meta|d\n"),
        (log, text.replace("0 warnings", "1 warning")),
        (log, text + "Warning: ignored constraint\n"),
        (log, text.replace("after fast 100", "after fast 85")),
        (log, text.replace("HELD CONTEXT BASELINE INACTIVE OMITTED: paths remain timed", "baseline cuts enabled")),
        (log, text.replace(held, "", 1)),
        (active, originals[active].replace("; 1 ;", "; 2 ;", 1)),
        (active, "Nothing to report.\n"),
        (active, originals[active].replace("osd:hdmi_osd|", "unreviewed_source|", 1)),
        (root / "after_slow_-40_pipe_video_hold.rpt", "Nothing to report.\n"),
        (raw, "Nothing to report.\n"),
        (raw, originals[raw].replace("; -3 ;", "; -2 ;", 1)),
        (raw, originals[raw].replace("dv_epoch_meta", "dv_epoch_sample")),
        (mode, originals[mode].replace("; 31.25 ;", "; 100 ;", 1)),
        (root / "after_fast_0_mode_hold.rpt", originals[root / "after_fast_0_mode_hold.rpt"].replace("; -31.25 ;", "; -100 ;", 1)),
        (mode, originals[mode].replace("d[0]", "unreviewed_target")),
        (root / "after_fast_100_inactive_video_hold.rpt", report("hold", [row("dv_hs", "hdmi_dv_hs", *CLOCKS["inactive_video"])])),
        (root / "before_fast_100_inactive_video_hold.rpt", "Nothing to report.\n"),
        (root / "after_fast_100_global_setup.rpt", row("s", "t", SYS, SYS)),
    ]
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
    extra.unlink()
    # Paired changes must still reject a new clock/domain scope, not just diffs.
    paired = [root / f"{p}_slow_-40_active_hdmi_setup.rpt" for p in ("before", "after")]
    for path in paired:
        path.write_text(originals[path].replace(CLOCKS["active_hdmi"][1], "unreviewed_clock"))
    rejects(check)
    for path in paired:
        path.write_text(originals[path])
    # Equality alone cannot validate forged sources or incomplete bank targets.
    # Change BOTH phases identically; native bank identities must reject them.
    paired_bank_negatives = 0
    for kind, old_source, new_source, old_target in (
        ("active_hdmi", "osd:hdmi_osd|", "unreviewed_source|", "d[0]"),
        ("active_video", "dv_data[0]", "unreviewed_source", "hdmi_dv_data[0]"),
    ):
        paths = [root / f"{phase}_slow_-40_{kind}_setup.rpt"
                 for phase in ("before", "after")]
        for old, new in ((old_source, new_source),
                         (old_target, "unreviewed_target")):
            for path in paths:
                assert old in originals[path], "paired fixture mutation did not match"
                path.write_text(originals[path].replace(old, new))
            rejects(check)
            paired_bank_negatives += 1
            for path in paths:
                path.write_text(originals[path])
    # Forge both phases alike: report completeness is independent of equality.
    paired_count_negatives = 0
    paths = [root / f"{phase}_slow_-40_active_hdmi_setup.rpt"
             for phase in ("before", "after")]
    header, body = originals[paths[0]].split("\n", 1)
    count = len(body.splitlines())
    capped_rows = body.splitlines(keepends=True)
    capped_body = [capped_rows[i % count] for i in range(5000)]
    bad_reports = [
        f"Report Timing: Found {count + 1} setup paths\n" + body,
        header + "\n" + "".join(body.splitlines(keepends=True)[:-1]),
        body,
        header + "\n" + header + "\n" + body,
        report("setup", capped_body),
    ]
    for bad in bad_reports:
        for path in paths:
            path.write_text(bad)
        rejects(check)
        paired_count_negatives += 1
        for path in paths:
            path.write_text(originals[path])
    assert check() == result
    check_count = len(invalid) + 3 + paired_bank_negatives + paired_count_negatives
print(f"PASS synthetic 9cc: {len(mutations)} provenance negatives; 22 actual-byte/missing-file negatives; substituted-fit rejection; 384-report positive and {check_count} scope/preservation negatives; negative global slack retained")
