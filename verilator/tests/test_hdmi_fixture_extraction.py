"""Extraction/profile guards only; native clocks require installed Intel tools."""
import hashlib
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[2]
emitter = root / "verilator/tests/emit_hdmi_policy_fixture.py"
original = (root / "sys/sys_top.v").read_bytes()
digest = hashlib.sha256(original).hexdigest()
with tempfile.TemporaryDirectory(prefix="x1-hdmi-extract-") as temporary:
    target = pathlib.Path(temporary) / "fixture.sv"
    for flags in ([], ["--wrong-clock"], ["--native-handoff"], ["--native-handoff", "--raw-policy"],
                  ["--native-handoff", "--csync-skew-ps", "3000000"],
                  ["--native-handoff", "--csync-skew-ps", "3000000", "--without-csync-echo"]):
        result = subprocess.run(["python3", str(emitter), str(target), *flags], capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        text = target.read_text()
        assert f"sys_top SHA256 {digest}" in text
        assert "reg hdmi_out_hs;" in text and "hdmi_out_d  <= d;" in text
        if "--native-handoff" in flags:
            assert text.count("x1_hdmi_clock_handoff hdmi_handoff(") == 1
            assert "dv_epoch_sample <= dv_epoch_meta;" in text
            assert "dv_policy_first <= dv_epoch_sample;" in text
            assert "dv_csync_first <= dv_csync_sample;" in text
            assert ("(dv_csync_echo_sample == hdmi_held_mode[2])" in text) == ("--without-csync-echo" not in flags)
            assert "assign hdmi_policy_csync = dv_csync_sample;" in text
            assert "if(ce_pix) dv_hs1 <= hdmi_policy_csync ? vga_cs_osd : vga_hs_osd;" in text
            assert "fixture_native_hs  <= dv_hs2;" in text
            assert "assign HDMI_TX_DE = !hdmi_transition_blank & hdmi_out_de;" in text
            if "--raw-policy" not in flags:
                assert "wire hdmi_select_video = hdmi_held_mode[0];" in text
            else:
                assert "wire hdmi_select_video = hdmi_held_mode[0];" not in text
            assert text.endswith("`undef X1_HDMI_HANDOFF_EXPERIMENT\n")
        else:
            assert "x1_hdmi_clock_handoff hdmi_handoff(" not in text
    for flags in (["--raw-policy"], ["--native-handoff", "--wrong-clock"],
                  ["--csync-skew-ps", "1"], ["--without-csync-echo"], ["--csync-skew-ps", "-1"]):
        result = subprocess.run(["python3", str(emitter), str(target), *flags], capture_output=True, text=True)
        assert result.returncode != 0 and "AssertionError" in result.stderr, "invalid extraction accepted"
assert (root / "sys/sys_top.v").read_bytes() == original
print("PASS: six source-bound HDMI extraction profiles and five invalid controls; not native simulation")
