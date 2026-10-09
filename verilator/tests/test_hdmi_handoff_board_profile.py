"""Static QSF profile isolation, not native synthesis or constraint acceptance."""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[2]


def assignments(path, stack=()):
    assert path not in stack, "cyclic QSF inclusion"
    values = []
    for line in path.read_text().splitlines():
        if line.startswith("source ") and line.endswith(".qsf"):
            values.extend(assignments(root / line.split()[1], (*stack, path)))
        match = re.fullmatch(r'set_global_assignment -name (\w+) (.+)', line)
        if match:
            values.append((match[1], match[2].strip('"')))
    return values


new = root / "sharpx1_turbo_z_handoff.qsf"
for path in root.glob("*.qsf"):
    if path != new:
        assert not any(key == "VERILOG_MACRO" and "X1_HDMI_HANDOFF_EXPERIMENT" in value
                       for key, value in assignments(path)), "ordinary revision enabled handoff"
baseline = assignments(root / "sharpx1_turbo_z_video.qsf")
candidate = assignments(new)
old_sdc = [value for key, value in baseline if key == "SDC_FILE"]
new_sdc = [value for key, value in candidate if key == "SDC_FILE"]
assert new_sdc == [value.replace("hdmi_mux_candidate.sdc", "hdmi_handoff_mux_candidate.sdc") for value in old_sdc]
old_macros = [value for key, value in baseline if key == "VERILOG_MACRO"]
new_macros = [value for key, value in candidate if key == "VERILOG_MACRO"]
assert new_macros == old_macros + ["X1_HDMI_HANDOFF_EXPERIMENT=1"]
assert [value for key, value in candidate if key == "ALLOW_POWER_UP_DONT_CARE"][-1] == "OFF"
print("PASS: separate handoff QSF preserves Z features/other constraints; ordinary revisions remain disabled")
