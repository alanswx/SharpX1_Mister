"""Synthetic report/parser controls only, never fitted FPGA evidence."""
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_crtc_write_reports import audit, PREFIX, MPU_PREFIX, MPU_RESET, PACKET, SYS, VIDEO

with tempfile.TemporaryDirectory(prefix="crtc-report-controls-") as directory:
    root = pathlib.Path(directory)
    native = root / "native.log"
    mpu = [MPU_PREFIX + f"{field}[{bit}]" for field in ("R_Nadj", "R_Nr") for bit in range(5)]
    fields = ["request", "request_meta", "request_sync", "acknowledgement", "acknowledgement_meta",
              "acknowledgement_sync", "video_rs", "pending_write", "busy", "done", "seen"]
    fields += [f"held_packet[{i}]" for i in range(9)] + [f"video_data[{i}]" for i in range(8)]
    stages = {"request_meta": [PREFIX + "request_sync"],
              "request_sync": [PREFIX + "pending_write", PREFIX + "seen"],
              "acknowledgement_meta": [PREFIX + "acknowledgement_sync"],
              "acknowledgement_sync": [PREFIX + "busy", PREFIX + "done"]}
    fanouts = {source: [mpu[0]] for source in PACKET.values()}
    fanouts.update({source: ["display_consumer"] for source in mpu})
    log_lines = [f"Info: CRTC transport register {field} {PREFIX}{field}" for field in fields]
    log_lines += [f"Info: CRTC native fanout {field} " + " ".join(targets) for field, targets in stages.items()]
    log_lines += [f"Info: CRTC first-data fanin {PREFIX}{meta}|d {PREFIX}{source} (reg)"
                  for source, meta in (("request", "request_meta"), ("acknowledgement", "acknowledgement_meta"))]
    log_lines += [f"Info: CRTC actual input source {meta} {PREFIX}{source}"
                  for source, meta in (("request", "request_meta"), ("acknowledgement", "acknowledgement_meta"))]
    log_lines += ["Info: CRTC MPU register " + name for name in mpu]
    log_lines += ["Info: CRTC endpoint native fanout " + source + " " + " ".join(targets) for source, targets in fanouts.items()]
    log_lines += ["Info: CRTC endpoint physical scope " + source for source in fanouts]
    log_lines += ["Info: CRTC local reset source " + MPU_RESET,
                  "Info: CRTC local reset native fanout " + " ".join(mpu)]
    log_lines += ["Info: Evaluation of Tcl script crtc_reporter.tcl was successful"]
    log_lines += ["Info: Quartus Prime TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings"]
    valid_log = "\n".join(log_lines) + "\n"
    native.write_text(valid_log)

    def row(source, target, launch=VIDEO, latch=VIDEO, slack=0.5, data=1.0):
        return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; 23.280 ; 0.1 ; {data} ;\n"

    originals = {}
    contents = {}
    for label, source, meta, sync, clock, other in (
        ("request", "request", "request_meta", "request_sync", VIDEO, SYS),
        ("ack", "acknowledgement", "acknowledgement_meta", "acknowledgement_sync", SYS, VIDEO)):
        contents[label + "_input"] = row(PREFIX + source, PREFIX + meta, other, clock, -7)
        contents[label + "_chain"] = row(PREFIX + meta, PREFIX + sync, clock, clock)
        contents[label + "_first_fanout"] = contents[label + "_chain"]
        contents[label + "_consumer"] = "".join(row(PREFIX + sync, target, clock, clock) for target in stages[sync])
    contents["packet"] = "".join(row(source, target, SYS, VIDEO, -8, 2.5) for source, target in PACKET.items())
    for kind, sources in (("capture_consumer", PACKET.values()), ("mpu_consumer", mpu)):
        contents[kind] = "".join(row(source, target) for source in sources for target in fanouts[source])
    contents["mpu_input"] = "".join(row(PREFIX + f"video_data[{i % 5}]", target) for i, target in enumerate(mpu))
    contents["mpu_input"] += "".join(row(MPU_RESET, target) for target in mpu)
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            for check in ("setup", "hold"):
                prefix = f"sharpx1_turbo_z_video_crtc_write_{model}_{temperature}"
                for kind, content in contents.items():
                    p = root / f"{prefix}_{kind}_{check}.rpt"
                    p.write_text(content)
                    originals[p] = content
    assert audit(root, native) == (192, 0.5, 2.5, -7)

    def path(kind):
        return root / f"sharpx1_turbo_z_video_crtc_write_slow_100_{kind}_setup.rpt"

    packet, chain, raw, ack = (path(k) for k in ("packet", "request_chain", "request_input", "ack_consumer"))
    capture, mpu_input, mpu_output = (path(k) for k in ("capture_consumer", "mpu_input", "mpu_consumer"))
    changes = [
        (native, valid_log.replace("CRTC endpoint physical scope", "unqualified alias-group scope")),
        (native, valid_log + "Info: CRTC endpoint physical scope " + mpu[0] + "\n"),
        (native, valid_log.replace("CRTC local reset source " + MPU_RESET, "CRTC local reset source raw_reset")),
        (native, valid_log.replace("CRTC local reset native fanout", "missing reset fanout")),
        (native, valid_log.replace("Info: CRTC local reset native fanout " + " ".join(mpu), "Info: CRTC local reset native fanout unrelated")),
        (mpu_input, originals[mpu_input].replace(MPU_RESET, "raw_reset", 1)),
        (mpu_input, originals[mpu_input].replace(row(MPU_RESET, mpu[0]), "")),
        (mpu_input, originals[mpu_input].replace(row(MPU_RESET, mpu[0]), row(MPU_RESET, mpu[0], SYS, VIDEO))),
        (packet, "Nothing to report."),
        (packet, "".join(originals[packet].splitlines(keepends=True)[:-1])),
        (packet, originals[packet].replace("held_packet[8]", "held_packet[7]")),
        (packet, originals[packet].replace("video_rs", "video_data[7]")),
        (packet, originals[packet].replace(SYS, VIDEO, 1)),
        (packet, originals[packet].replace("2.5", "23.28", 1)),
        (packet, originals[packet].replace("2.5", "nan", 1)),
        (chain, originals[chain].replace("request_sync", "request_meta")),
        (chain, originals[chain].replace("0.5", "-0.1", 1)),
        (chain, originals[chain].replace(VIDEO, SYS, 1)),
        (raw, originals[raw].replace(PREFIX + "request ;", "wrong_gpio ;")),
        (raw, "Nothing to report."),
        (ack, originals[ack].replace(SYS, VIDEO, 1)),
        (ack, "".join(originals[ack].splitlines(keepends=True)[:-1])),
        (capture, "".join(originals[capture].splitlines(keepends=True)[:-1])),
        (capture, originals[capture] + row("unexpected", mpu[0])),
        (mpu_input, originals[mpu_input].replace("video_data[0]", "cpu_a[0]")),
        (mpu_input, "".join(originals[mpu_input].splitlines(keepends=True)[:-1])),
        (mpu_output, "".join(originals[mpu_output].splitlines(keepends=True)[:-1])),
        (mpu_output, originals[mpu_output].replace("display_consumer", "other_clock_consumer", 1)),
        (native, valid_log.replace("was successful", "failed")),
        (native, valid_log.replace("successful. 0 errors", "unsuccessful. 1 error")),
        (native, valid_log + "Error (332000): failed SDC inventory\n"),
        (native, valid_log + log_lines[0] + "\n"),
        (native, valid_log.replace(f"request_meta {PREFIX}request_sync", f"request_meta {PREFIX}busy")),
        (native, valid_log.replace(f"request_meta|d {PREFIX}request", f"request_meta|d wrong_gpio")),
        (native, valid_log.replace(f"acknowledgement_meta|d {PREFIX}acknowledgement", f"acknowledgement_meta|d wrong_gpio")),
        (native, valid_log.replace(f"Info: CRTC MPU register {mpu[-1]}\n", "")),
        (native, valid_log.replace("Info: CRTC endpoint native fanout " + mpu[-1] + " display_consumer\n", "")),
        (native, valid_log.replace("display_consumer\n", "display_consumer display_consumer\n", 1)),
    ]
    for p, content in changes:
        p.write_text(content)
        try:
            audit(root, native)
        except (AssertionError, ValueError):
            pass
        else:
            raise AssertionError(f"invalid CRTC report accepted: {p.name}")
        p.write_text(valid_log if p == native else originals[p])

    alias = PREFIX + "acknowledgement~DUPLICATE"
    keeper_list = f"{{video_clock port}} {{{PREFIX}seen reg}} {{{PREFIX}acknowledgement reg}}"
    primary_input = "Info: CRTC acknowledgement native inputs acknowledgement " + keeper_list + "\n"
    alias_input = "Info: CRTC acknowledgement native inputs acknowledgement~DUPLICATE " + keeper_list + "\n"
    clone_log = valid_log + f"Info: CRTC transport register acknowledgement~DUPLICATE {alias}\n"
    clone_log += primary_input + alias_input
    clone_log += f"Info: CRTC acknowledgement replica native fanins match {PREFIX}acknowledgement {alias}\n"
    clone_log = clone_log.replace(f"acknowledgement_meta|d {PREFIX}acknowledgement (reg)", f"acknowledgement_meta|d {alias} (reg)")
    clone_log = clone_log.replace(f"CRTC actual input source acknowledgement_meta {PREFIX}acknowledgement\n", f"CRTC actual input source acknowledgement_meta {alias}\n")
    for field in ("request_meta", "acknowledgement_meta"):
        clone_log = clone_log.replace(f"CRTC first-data fanin {PREFIX}{field}|d", f"CRTC first-data fanin emu|sharpx1|x3_crtc.writes|{field}|asdata")
    clone_originals = {}
    for p, content in originals.items():
        if "_ack_input_" in p.name:
            clone_originals[p] = content.replace(f"{PREFIX}acknowledgement ;", f"{alias} ;")
            p.write_text(clone_originals[p])
    native.write_text(clone_log)
    assert audit(root, native) == (192, 0.5, 2.5, -7)
    clone_raw = path("ack_input")
    clone_changes = [
        (native, clone_log.replace(alias_input, "")),
        (native, clone_log.replace(alias_input, alias_input.replace("seen reg", "busy reg"))),
        (native, clone_log + alias_input),
        (native, clone_log.replace(f"acknowledgement_meta|asdata {alias} (reg)", f"acknowledgement_meta|asdata {PREFIX}acknowledgement (reg)")),
        (native, clone_log.replace("CRTC actual input source acknowledgement_meta " + alias, "CRTC actual input source acknowledgement_meta wrong_gpio")),
        (native, clone_log.replace("emu|sharpx1|x3_crtc.writes|", "unrelated_module|")),
        (native, clone_log.replace("CRTC acknowledgement replica native fanins match", "unvalidated clone")),
        (clone_raw, clone_originals[clone_raw].replace(alias, PREFIX + "acknowledgement")),
    ]
    for p, content in clone_changes:
        p.write_text(content)
        try:
            audit(root, native)
        except (AssertionError, ValueError):
            pass
        else:
            raise AssertionError(f"invalid CRTC alias report accepted: {p.name}")
        p.write_text(clone_log if p == native else clone_originals[p])
print("PASS: CRTC parser physical/native-alias/reset coverage and 46 invalid scope/domain/payload/native-log controls; not fitted evidence")
