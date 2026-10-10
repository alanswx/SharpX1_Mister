"""Synthetic exclusion/preservation integrity controls, not native timing."""
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_hdmi_inactive_data_probe import audit, audit_sources, CLOCKS, OUTPUTS, PREFETCH, PACKED_PREFETCH, INPUTS, PAIRS, SYS, VID, PREFIX, HELD_KEYS


def row(source, target, launch, latch, slack=1, relationship=10):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; {relationship} ; 0.1 ; 2 ;\n"


def report(check, body):
    return f"Report Timing: Found {len(body)} {check} paths\n" + "".join(body)


with tempfile.TemporaryDirectory(prefix="inactive-probe-controls-") as temporary:
    root = pathlib.Path(temporary)
    log = root / "native.log"
    originals = {log: ""}
    for group, names in (("output", OUTPUTS), ("prefetch", PREFETCH)):
        for name in sorted(names):
            ports = ("d", "asdata") if group == "output" and name != "vs" else ("asdata",) if name in PACKED_PREFETCH else ("d",)
            for port in ports:
                originals[log] += f"INACTIVE DATA CUT {group} {{{name}|{port}}}\n"
    originals[log] += "INACTIVE DATA CANDIDATE: opposite-parent exact DATA pins only; active routes and raw inputs untouched\n"
    for phase in ("before", "after"):
        for model in ("slow", "fast"):
            for temperature in (-40, 0, 85, 100):
                originals[log] += f"INACTIVE PROBE CORNER {phase} {model} {temperature} 1100\n"
                for check in ("setup", "hold"):
                    stem = f"{phase}_{model}_{temperature}"
                    for kind, clocks in CLOCKS.items():
                        if kind.startswith("inactive") and phase == "after":
                            contents = "Nothing to report.\n"
                        elif kind.startswith("pipe"):
                            contents = report(check, [row("hs", "hdmi_out_hs", *clocks)])
                        else:
                            names = OUTPUTS if kind.endswith("hdmi") else PREFETCH
                            contents = report(check, [row("osd:hdmi_osd|" + n if kind.endswith("hdmi") else n.removeprefix("hdmi_"), n, *clocks) for n in sorted(names)])
                        originals[root / f"{stem}_{kind}_{check}.rpt"] = contents
                    for kind in INPUTS:
                        clocks = [VID, SYS] if "echo" in kind else [SYS, VID]
                        originals[root / f"{stem}_{kind}_{check}.rpt"] = report(check, [row(*PAIRS[kind], *clocks, -3)])
                    originals[root / f"{stem}_mode_{check}.rpt"] = report(check, [row(PREFIX+"active_mode[0]", "hs", SYS, "x1_hdmi_handoff_mux", -3)])
                    originals[root / f"{stem}_global_{check}.rpt"] = "".join(row(f"s{i}", f"t{i}", SYS, SYS, -3) for i in range(50))
    originals[log] += "INACTIVE PROBE COMPLETE: diagnostic only; no board selection or timing acceptance\nTimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n"
    for path, content in originals.items():
        path.write_text(content)
    with contextlib.redirect_stdout(io.StringIO()):
        result = audit(root, log)
    assert result[:2] == (816, 928)
    active = root / "after_slow_-40_active_hdmi_setup.rpt"
    inactive = root / "after_fast_100_inactive_video_hold.rpt"
    pipe = root / "after_slow_0_pipe_video_hold.rpt"
    raw = root / "after_slow_0_epoch_echo_input_hold.rpt"
    mode = root / "after_fast_0_mode_setup.rpt"
    before = root / "before_slow_0_inactive_hdmi_setup.rpt"
    mutations = [
        (log, originals[log].replace("0 warnings", "1 warning")),
        (log, originals[log] + "Warning: ignored pin\n"),
        (log, originals[log].replace("after fast 100", "after fast 85")),
        (log, originals[log].replace("INACTIVE PROBE COMPLETE", "INCOMPLETE")),
        (log, originals[log].replace("{hs|asdata}", "{hs|clk}")),
        (log, originals[log] + "INACTIVE DATA CUT output {hs|d}\n"),
        (log, originals[log].replace("INACTIVE DATA CUT output {hs|d}\n", "")),
        (inactive, "corrupt empty report\n"),
        (inactive, report("hold", [row("dv_hs", "hdmi_dv_hs", *CLOCKS["inactive_video"])])),
        (before, originals[before].replace("Found 27", "Found 5000")),
        (before, originals[before].replace("d[0]", "unreviewed_target")),
        (active, "Nothing to report.\n"),
        (active, originals[active].replace("; 1 ;", "; 2 ;", 1)),
        (active, originals[active].replace("osd:hdmi_osd|", "wrong_bank|")),
        (active, originals[active].replace("x1_hdmi_handoff_mux", "x1_video_handoff_mux")),
        (pipe, originals[pipe].replace("; 2 ;", "; 3 ;", 1)),
        (raw, originals[raw].replace("; -3 ;", "; 1 ;", 1)),
        (raw, "Nothing to report.\n"),
        (mode, originals[mode].replace("; -3 ;", "; -2 ;", 1)),
        (mode, originals[mode].replace("active_mode[0]", "active_mode[3]")),
        (root / "after_fast_100_global_setup.rpt", row("s", "t", SYS, SYS)),
    ]
    for path, content in mutations:
        path.write_text(content)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit(root, log)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid preservation accepted: {path}")
        finally:
            path.write_text(originals[path])
    repo = pathlib.Path(__file__).resolve().parents[2]
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "hdmi_inactive_data_candidate.sdc", "quartus_hdmi_inactive_data_probe.tcl"]
    paths = names[:2] + ["scripts/constraints/hdmi_inactive_data_candidate.sdc", "scripts/quartus_hdmi_inactive_data_probe.tcl"]
    hashes = "".join(f"{hashlib.sha256((repo / p).read_bytes()).hexdigest()}  {n}\n" for n, p in zip(names, paths))
    hashes += "".join(f"{'a'*64}  output_files/sharpx1_turbo_z_handoff.{ext}\n" for ext in ("sta.rpt", "sta.summary", "rbf"))
    log.write_text(hashes * 2)
    audit_sources(log, repo)
    for bad in (hashes, hashes * 3, hashes + hashes.replace('a'*64, 'b'*64), (hashes * 2).replace("hdmi_inactive_data_candidate.sdc", "other.sdc")):
        log.write_text(bad)
        try:
            audit_sources(log, repo)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid provenance accepted")
    # Separate joint protocol: full held-mux scope, with all other mode rows
    # still compared exactly. No relaxed standalone evidence is accepted.
    joint_originals = originals.copy()
    held_label = "HELD MUX CANDIDATE: 29 exact D-route pairs; max 31.25 ns/min -31.25; raw inputs and clock pins untouched\n"
    joint_originals[log] = held_label + originals[log]
    for phase in ("before", "after"):
        for model in ("slow", "fast"):
            for temperature in (-40, 0, 85, 100):
                for check in ("setup", "hold"):
                    relationship = (31.25 if check == "setup" else -31.25) if phase == "after" else 10
                    selected = [row(*key, 1 if phase == "after" else -3, relationship) for key in sorted(HELD_KEYS)]
                    other = row(PREFIX + "active_mode[0]", PREFIX + "state.RUN", SYS, SYS)
                    joint_originals[root / f"{phase}_{model}_{temperature}_mode_{check}.rpt"] = report(check, selected + [other])
    for path, content in joint_originals.items():
        path.write_text(content)
    with contextlib.redirect_stdout(io.StringIO()):
        result = audit(root, log, joint=True)
    assert result[:2] == (816, 928) and result[4] == 928
    budget = root / "after_slow_-40_mode_setup.rpt"
    joint_mutations = [
        (log, joint_originals[log].replace(held_label, "")),
        (log, joint_originals[log] + held_label),
        (budget, joint_originals[budget].replace("; 1 ;", "; -1 ;", 1)),
        (budget, joint_originals[budget].replace("; 31.25 ;", "; 100 ;", 1)),
        (budget, joint_originals[budget].replace("; 2 ;", "; 3 ;", 1)),
        (budget, joint_originals[budget].replace("d[0]", "unreviewed_target")),
        (budget, joint_originals[budget].replace("state.RUN", "state.RELEASE")),
        (active, joint_originals[active].replace("; 1 ;", "; 2 ;", 1)),
        (raw, joint_originals[raw].replace("; -3 ;", "; -2 ;", 1)),
    ]
    for path, content in joint_mutations:
        path.write_text(content)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit(root, log, joint=True)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid joint proposal accepted: {path}")
        finally:
            path.write_text(joint_originals[path])
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            audit(root, log)
    except AssertionError:
        pass
    else:
        raise AssertionError("joint evidence accepted as standalone")
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "joint-proposal-v1/hdmi_inactive_data_candidate.sdc", "quartus_hdmi_inactive_data_probe.tcl",
             "joint-proposal-v1/hdmi_held_mode_candidate.sdc", "joint-proposal-v1/hdmi_output_joint_probe.sdc"]
    paths = names[:2] + ["scripts/constraints/hdmi_inactive_data_candidate.sdc", "scripts/quartus_hdmi_inactive_data_probe.tcl",
                        "scripts/constraints/hdmi_held_mode_candidate.sdc", "scripts/constraints/hdmi_output_joint_probe.sdc"]
    hashes = "".join(f"{hashlib.sha256((repo / p).read_bytes()).hexdigest()}  {n}\n" for n, p in zip(names, paths))
    hashes += "".join(f"{'a'*64}  output_files/sharpx1_turbo_z_handoff.{ext}\n" for ext in ("sta.rpt", "sta.summary", "rbf"))
    log.write_text(hashes * 2)
    audit_sources(log, repo, joint=True)
    for bad in (hashes, hashes * 3, hashes + hashes.replace('a'*64, 'b'*64), (hashes * 2).replace("hdmi_held_mode_candidate.sdc", "other.sdc")):
        log.write_text(bad)
        try:
            audit_sources(log, repo, joint=True)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid joint provenance accepted")
print(f"PASS: synthetic 384-report preservation positive; {len(mutations)} invalid scope/report/active/raw/mode controls and four provenance controls")
print("PASS: separate joint 384-report positive; ten invalid scope/budget/preservation/protocol controls and four provenance controls")
