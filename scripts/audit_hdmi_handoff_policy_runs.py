"""Audit native extracted-policy profiles; not upstream/PHY acceptance."""
import argparse
import hashlib
import itertools
import pathlib
import re


def audit(log, source_root, fixture):
    text = log.read_text()
    profiles = re.findall(r"^POLICY_DIAGNOSTIC_PROFILE=(\S+)$", text, re.M)
    assert len(profiles) == 1 and profiles[0] in {"normal", "skew"}, "wrong/missing qualification profile"
    found = re.findall(r"^# PASS: actual HDMI handoff policy video_half=(\d+) hdmi_half=(\d+) checks=(\d+)$", text, re.M)
    assert [(int(v), int(h)) for v, h, _ in found] == list(itertools.product((11640, 17500), (3366, 6250, 10000))), "missing/repeated/out-of-order native profiles"
    assert all(int(n) > 0 for _, _, n in found), "empty pixel checks"
    assert text.count("POLICY_COMPLETION=1") == 6 and "POLICY_COMPLETION=0" not in text
    holds = re.findall(r"^# MODE_HOLD_CHECKS=(\d+) MINIMUM_MODE_HOLD_PS=(\d+)$", text, re.M)
    assert len(holds) == 6 and all(int(n) >= 20 and int(t) >= 156250 for n, t in holds), "missing/short first-edge settling"
    native_hs = re.findall(r"^# NATIVE_HS_CHECKS=(\d+)$", text, re.M)
    assert len(native_hs) == 6 and all(int(n) >= 100 for n in native_hs), "missing native HS CE/consumed-policy coverage"
    assert len(re.findall(r"^# Errors: 0, Warnings: 7$", text, re.M)) == 6
    assert not re.search(r"\*\* (?:Fatal|Error):|Errors: [1-9]|^Error\b", text, re.M)
    warnings = re.findall(r"^# \*\* Warning: (.+)$", text, re.M)
    assert len(warnings) == 42 and all(w.startswith("(vsim-3116) Problem reading symbols") for w in warnings), "unreviewed native warning"
    sys_hash = hashlib.sha256((source_root / "sys/sys_top.v").read_bytes()).hexdigest()
    emitter_hash = hashlib.sha256((source_root / "verilator/tests/emit_hdmi_policy_fixture.py").read_bytes()).hexdigest()
    assert re.findall(r"^POLICY_SOURCE_HASH ([0-9a-f]{64}) (\S+)$", text, re.M) == [
        (sys_hash, "sys/sys_top.v"), (emitter_hash, "verilator/tests/emit_hdmi_policy_fixture.py")
    ] * 2, "changed/missing frozen framework/emitter hashes"
    assert f"// sys_top SHA256 {sys_hash}\n" in fixture.read_text(), "wrong extracted framework source"
    sources = [(fixture, "hdmi-handoff-policy-native.sv"),
               (source_root / "rtl/x1_hdmi_clock_handoff.sv", "x1_hdmi_clock_handoff.sv"),
               (source_root / "verilator/tests/hdmi_handoff_policy_tb.sv", "hdmi_handoff_policy_tb.sv"),
               (source_root / "verilator/tests/hdmi_handoff_policy.do", "hdmi_handoff_policy.do")]
    expected = [(hashlib.sha256(path.read_bytes()).hexdigest(), name) for path, name in sources]
    assert re.findall(r"^([0-9a-f]{64})  (\S+)$", text, re.M) == expected * 2, "frozen source mismatch/final hash missing"
    print(f"PASS: six ordered native policy profiles, {sum(int(n) for _, _, n in found)} exact output checks, {sum(int(n) for n, _ in holds)} first-edge holds, minimum {min(int(t) for _, t in holds)} ps")
    print(f"PASS: {sum(int(n) for n in native_hs)} extracted native HS CE/pipeline/consumed-policy checks")
    print(f"PROFILE: {profiles[0]}; skew is a synthetic transport-delay diagnostic, not routed timing")
    print("SCOPE: extracted policy only; native VID csync timing, full upstream/DDR/PHY and physical acceptance remain open")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    parser.add_argument("--fixture", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit(args.log, args.source_root, args.fixture)
