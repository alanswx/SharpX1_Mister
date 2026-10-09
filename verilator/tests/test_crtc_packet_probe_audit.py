"""Synthetic probe audit controls, never native FPGA acceptance."""
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_crtc_packet_probe import audit, PACKET, PREFIX, SYS, VIDEO


def row(source, target, launch=SYS, latch=VIDEO, slack=-9, delay=2.5):
    return f"; {slack} ; {source} ; {target} ; {launch} ; {latch} ; 23.280 ; 0.1 ; {delay} ;\n"


with tempfile.TemporaryDirectory(prefix="crtc-packet-probe-controls-") as temp:
    root = pathlib.Path(temp)
    native = root / "native.log"
    valid_log = (f"Info: CRTC packet probe actual ACK source {PREFIX}acknowledgement\n"
                 "CRTC packet candidate: nine exact physical pairs; max 23.28 ns/min 0; raw inputs untouched\n"
                 "Info: Evaluation of Tcl script packet_probe.tcl was successful\n"
                 "Info: Quartus Prime TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n")
    native.write_text(valid_log)
    originals = {}
    for stage in ("before", "after"):
        contents = {
            "packet": "".join(row(s, t, slack=-8 if stage == "before" else 0.7) for s, t in PACKET.items()),
            "request_input": row(PREFIX + "request", PREFIX + "request_meta"),
            "ack_input": row(PREFIX + "acknowledgement", PREFIX + "acknowledgement_meta", VIDEO, SYS),
            "global": row("global_source", "global_target", slack=-12 if stage == "before" else -9),
        }
        for model in ("slow", "fast"):
            for temperature in (-40, 0, 85, 100):
                for check in ("setup", "hold"):
                    for kind, content in contents.items():
                        path = root / f"sharpx1_turbo_z_video_crtc_packet_probe_{stage}_{model}_{temperature}_{kind}_{check}.rpt"
                        path.write_text(content)
                        originals[path] = content
    result = audit(root, native)
    assert result[:4] == (128, 0.7, 2.5, -9)
    assert result[4] == {"before": {"setup": -12, "hold": -12}, "after": {"setup": -9, "hold": -9}}

    def path(kind, stage="after"):
        return root / f"sharpx1_turbo_z_video_crtc_packet_probe_{stage}_slow_100_{kind}_setup.rpt"

    packet, raw, ack, global_report = [path(kind) for kind in ("packet", "request_input", "ack_input", "global")]
    changes = [
        (native, valid_log.replace("successful. 0 errors", "unsuccessful. 1 error")),
        (native, valid_log + "Error: failed candidate scope\n"),
        (native, valid_log + "Warning (332174): Ignored filter: missing pin\n"),
        (native, valid_log.replace("nine exact physical pairs", "unknown scope")),
        (native, valid_log + "CRTC packet candidate: nine exact physical pairs; max 23.28 ns/min 0; raw inputs untouched\n"),
        (native, valid_log.replace("actual ACK source " + PREFIX + "acknowledgement", "actual ACK source wrong_keeper")),
        (packet, "Nothing to report.\n"),
        (packet, "".join(originals[packet].splitlines(keepends=True)[:-1])),
        (packet, originals[packet].replace("held_packet[8]", "held_packet[7]")),
        (packet, originals[packet].replace("video_rs", "video_data[7]")),
        (packet, originals[packet].replace("0.7", "-0.1", 1)),
        (packet, originals[packet].replace("2.5", "23.28", 1)),
        (packet, originals[packet].replace("2.5", "3.0", 1)),
        (packet, originals[packet].replace(SYS, VIDEO, 1)),
        (raw, "Nothing to report.\n"),
        (raw, originals[raw] + originals[raw]),
        (raw, originals[raw].replace("request ;", "other_source ;", 1)),
        (raw, originals[raw].replace("request_meta", "request_sync")),
        (raw, originals[raw].replace("-9", "-8", 1)),
        (raw, originals[raw].replace("2.5", "3.0", 1)),
        (ack, originals[ack].replace(SYS, VIDEO, 1)),
        (global_report, "Nothing to report.\n"),
    ]
    for p, content in changes:
        p.write_text(content)
        try:
            audit(root, native)
        except (AssertionError, ValueError):
            pass
        else:
            raise AssertionError(f"invalid packet probe accepted: {p.name}")
        p.write_text(valid_log if p == native else originals[p])
    alias = PREFIX + "acknowledgement~DUPLICATE"
    native.write_text(valid_log.replace("actual ACK source " + PREFIX + "acknowledgement", "actual ACK source " + alias))
    for p, content in originals.items():
        if "_ack_input_" in p.name:
            p.write_text(content.replace(PREFIX + "acknowledgement ;", alias + " ;"))
    assert audit(root, native)[:4] == (128, 0.7, 2.5, -9)
print(f"PASS: packet probe primary/replica matrices and {len(changes)} rejected scope/raw-change/physical-delay/native-log cases (synthetic only)")
