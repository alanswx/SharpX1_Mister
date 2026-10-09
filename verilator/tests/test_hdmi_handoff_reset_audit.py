"""Synthetic native-result audit controls, not HDL or physical reset proof."""
import contextlib
import hashlib
import io
import itertools
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
from audit_hdmi_handoff_reset_runs import audit, SOURCES

with tempfile.TemporaryDirectory(prefix="x1-handoff-reset-audit-") as temporary:
    root = pathlib.Path(temporary)
    hashes = []
    for name, relative in SOURCES.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        content = f"synthetic source {name}\n"
        path.write_text(content)
        hashes.append(f"{hashlib.sha256(content.encode()).hexdigest()}  {name}\n")
    runs = []
    for v, h, phase, ready in itertools.product((11640,17500), (3366,6250,10000), range(8), range(2)):
        runs.append(f"# PASS: native handoff reset phase={phase} stopped_ready={ready} video_half={v} hdmi_half={h}\n"
                    + "# ** Warning: (vsim-3116) Problem reading symbols from host library\n" * 7
                    + "RESET_COMPLETION=1\n# Errors: 0, Warnings: 7\n")
    valid = "".join(hashes) + "Errors: 0, Warnings: 0\n" + "".join(runs) + "".join(hashes)
    log = root / "native.log"
    log.write_text(valid)
    audit(log, root)
    invalid = [
        valid.replace(runs[-1], ""),
        valid + runs[0],
        valid.replace(runs[0]+runs[1], runs[1]+runs[0]),
        valid.replace("reset phase=0", "reset phase=8", 1),
        valid.replace("video_half=11640", "video_half=11641", 1),
        valid.replace("RESET_COMPLETION=1", "RESET_COMPLETION=0", 1),
        valid.replace("RESET_COMPLETION=1", "", 1),
        valid.replace("# Errors: 0, Warnings: 7", "# Errors: 1, Warnings: 7", 1),
        valid + "# ** Fatal: diagnostic failed\n",
        valid + "Error: compiler error\n",
        valid.replace("(vsim-3116)", "(vsim-unreviewed)", 1),
        valid.replace("# ** Warning: (vsim-3116) Problem reading symbols from host library\n", "", 1),
        valid.removesuffix("".join(hashes)),
        valid.replace(hashes[0], "0"*64+"  x1_hdmi_clock_handoff.sv\n", 1),
    ]
    for content in invalid:
        log.write_text(content)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                audit(log, root)
        except AssertionError:
            pass
        else:
            raise AssertionError("corrupt/incomplete source-bound reset matrix accepted")
    log.write_text(valid)
    (root / SOURCES["x1_hdmi_clock_handoff.sv"]).write_text("changed after native run\n")
    try:
        audit(log, root)
    except AssertionError:
        pass
    else:
        raise AssertionError("changed current source accepted")
print("PASS: reset-result positive and fifteen invalid matrix/source/warning controls")
