"""Synthetic auditor controls; does not execute native simulation."""
import contextlib
import hashlib
import io
import itertools
import pathlib
import sys
from unittest.mock import Mock

root = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "scripts"))
from audit_hdmi_handoff_policy_runs import audit

fixture_bytes = ("// sys_top SHA256 " + hashlib.sha256((root / "sys/sys_top.v").read_bytes()).hexdigest() + "\n").encode()
fixture = Mock()
fixture.read_bytes.return_value = fixture_bytes
fixture.read_text.return_value = fixture_bytes.decode()
sources = [(fixture_bytes, "hdmi-handoff-policy-native.sv")]
for path, name in [("rtl/x1_hdmi_clock_handoff.sv", "x1_hdmi_clock_handoff.sv"),
                   ("verilator/tests/hdmi_handoff_policy_tb.sv", "hdmi_handoff_policy_tb.sv"),
                   ("verilator/tests/hdmi_handoff_policy.do", "hdmi_handoff_policy.do")]:
    sources.append(((root / path).read_bytes(), name))
hashes = "".join(f"{hashlib.sha256(data).hexdigest()}  {name}\n" for data, name in sources)
profiles = ""
for v, h in itertools.product((11640, 17500), (3366, 6250, 10000)):
    profiles += f"# PASS: actual HDMI handoff policy video_half={v} hdmi_half={h} checks=700\n"
    profiles += "# MODE_HOLD_CHECKS=33 MINIMUM_MODE_HOLD_PS=169791\nPOLICY_COMPLETION=1\n# Errors: 0, Warnings: 7\n"
    profiles += "# ** Warning: (vsim-3116) Problem reading symbols from ABI library\n" * 7
text = hashes + profiles + hashes


def check(candidate):
    log = Mock()
    log.read_text.return_value = candidate
    with contextlib.redirect_stdout(io.StringIO()):
        audit(log, root, fixture)


check(text)
bad = [text.replace("checks=700", "checks=0", 1),
       text.replace("video_half=11640 hdmi_half=3366", "video_half=17500 hdmi_half=3366", 1),
       text.replace("POLICY_COMPLETION=1", "POLICY_COMPLETION=0", 1),
       text.replace("MODE_HOLD_CHECKS=33", "MODE_HOLD_CHECKS=19", 1),
       text.replace("MINIMUM_MODE_HOLD_PS=169791", "MINIMUM_MODE_HOLD_PS=156249", 1),
       text.replace("Errors: 0", "Errors: 1", 1),
       text.replace("(vsim-3116)", "(vsim-UNKNOWN)", 1),
       text[:-len(hashes)],
       text.replace(hashes[:64], "0" * 64, 1),
       text + "# ** Fatal: unsafe output\n"]
for candidate in bad:
    try:
        check(candidate)
    except AssertionError:
        continue
    raise AssertionError("invalid native-policy evidence accepted")
fixture.read_text.return_value = "// wrong framework source\n"
try:
    check(text)
except AssertionError:
    pass
else:
    raise AssertionError("wrong extracted source accepted")
print("PASS: synthetic six-profile policy positive and eleven invalid profile/settle/warning/completion/source controls")
