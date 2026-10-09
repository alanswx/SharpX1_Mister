"""Synthetic parser controls only, not fitted timing evidence."""
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_video_blink_reports import audit, FIRST, LAST, SOURCE, SYS, VIDEO

with tempfile.TemporaryDirectory(prefix="blink-report-controls-") as directory:
    root = pathlib.Path(directory)
    native = root / "native.log"
    valid_log = (f"Info: video blink stage 0 native fanout {{{LAST}}}\n"
                 "Info: video blink stage 1 native fanout consumer_a {consumer_b}\n"
                 f"Info: video blink first-data fanin {SOURCE} (reg)\n"
                 "Info: Evaluation of Tcl script reporter.tcl was successful\n")
    native.write_text(valid_log)

    def row(src, dst, launch=VIDEO, latch=VIDEO, slack=0.5, data=1.0):
        return f"; {slack} ; {src} ; {dst} ; {launch} ; {latch} ; 23.280 ; 0.1 ; {data} ;\n"

    originals = {}
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            for check in ("setup", "hold"):
                prefix = f"sharpx1_turbo_z_video_video_blink_{model}_{temperature}"
                for kind, content in {
                    "input": row(SOURCE, FIRST, SYS, VIDEO, -7),
                    "chain": row(FIRST, LAST),
                    "first_fanout": row(FIRST, LAST),
                    "consumer": row(LAST, "consumer_a") + row(LAST, "consumer_b"),
                }.items():
                    p = root / f"{prefix}_{kind}_{check}.rpt"
                    p.write_text(content)
                    originals[p] = content
    assert audit(root, native) == (64, 0.5, -7)
    consumer = root / "sharpx1_turbo_z_video_video_blink_slow_100_consumer_setup.rpt"
    chain = root / "sharpx1_turbo_z_video_video_blink_slow_100_chain_setup.rpt"
    raw = root / "sharpx1_turbo_z_video_video_blink_slow_100_input_setup.rpt"
    changes = [
        (consumer, "Nothing to report."),
        (consumer, row(LAST, "consumer_a")),
        (consumer, originals[consumer] + row(LAST, "consumer_c")),
        (consumer, originals[consumer].replace(VIDEO, SYS, 1)),
        (consumer, originals[consumer].replace(LAST, FIRST)),
        (consumer, originals[consumer].replace("0.5", "-0.1", 1)),
        (consumer, originals[consumer].replace("1.0", "23.28", 1)),
        (consumer, originals[consumer].replace("1.0", "nan", 1)),
        (chain, originals[chain].replace(LAST, FIRST)),
        (raw, originals[raw].replace(SOURCE, "wrong_gpio")),
        (raw, "Nothing to report."),
        (native, valid_log.replace("consumer_b", "consumer_a")),
        (native, valid_log.replace(SOURCE, "wrong_gpio")),
        (native, valid_log.replace("was successful", "failed")),
        (native, valid_log.replace("{" + LAST + "}", "consumer_a")),
    ]
    for p, content in changes:
        p.write_text(content)
        try:
            audit(root, native)
        except (AssertionError, ValueError):
            pass
        else:
            raise AssertionError(f"invalid report accepted: {p.name}")
        p.write_text(valid_log if p == native else originals[p])
print("PASS: blink parser valid coverage and fifteen invalid scope/domain/data/native-log controls (synthetic only)")
