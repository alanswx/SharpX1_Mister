"""Extract actual inherited output policy; ideal clock mux, not Intel simulation."""
import argparse
import hashlib
import pathlib
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=pathlib.Path)
parser.add_argument("--wrong-clock", action="store_true", help="intentional negative control")
parser.add_argument("--native-handoff", action="store_true", help="extract experimental native clock/handoff block too")
parser.add_argument("--raw-policy", action="store_true", help="native negative: bypass held data selectors")
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
raw = (root / "sys/sys_top.v").read_bytes()
source = raw.decode()
start = "reg hdmi_out_hs;"
end = "assign HDMI_TX_D  = hdmi_out_d;\n`endif"
assert source.count(start) == source.count(end) == 1, "ambiguous inherited policy block"
policy = source[source.index(start):source.index(end) + len(end)]
assert policy.count("hdmi_select_video ?") == 4, "unreviewed data selection policy"
assert "wire hdmi_select_video = ~vga_fb & direct_video;" in policy
assert "wire hdmi_select_csync = direct_video & csync_en;" in policy
if args.raw_policy:
    assert args.native_handoff, "raw-policy control requires native handoff"
    policy = policy.replace("wire hdmi_select_video = hdmi_held_mode[0];",
                            "wire hdmi_select_video = ~vga_fb & direct_video;")
    policy = policy.replace("wire hdmi_select_csync = hdmi_held_mode[1] & hdmi_held_mode[2];",
                            "wire hdmi_select_csync = direct_video & csync_en;")
selectors = re.findall(r"\.clkselect\(\{1'b1, ([^}]+)\}\)", source)
assert selectors == ["~vga_fb & direct_video"], "unreviewed native clock selection policy"
assert source.count(".inclk({clk_vid, hdmi_clk_out, 2'b00})") == 1, "unreviewed native clock ordering"
license_header = source[:source.index("module ")]
clocks = "clk_hdmi : clk_vid" if args.wrong_clock else "clk_vid : clk_hdmi"
text = license_header + f"\n// sys_top SHA256 {hashlib.sha256(raw).hexdigest()}\n"
text += "// Extracted policy only; no Cyclone V switching/CDC/physical acceptance.\n"
text += "module hdmi_policy_fixture(\n"
text += "input wire clk_vid,clk_hdmi,direct_video,vga_fb,csync_en,\n"
text += "input wire [23:0] dv_data,hdmi_data_osd,\n"
text += "input wire dv_hs,dv_vs,dv_de,hdmi_cs_osd,hdmi_hs_osd,hdmi_vs_osd,hdmi_de_osd,\n"
if args.native_handoff:
    assert not args.wrong_clock, "native controller is not an ideal wrong-clock fixture"
    text += "input wire clk_control,reset_request,ce_pix, output wire [2:0] fixture_mode, output wire fixture_blank,fixture_busy,\n"
text += "output wire HDMI_TX_HS,HDMI_TX_VS,HDMI_TX_DE, output wire [23:0] HDMI_TX_D, output wire fixture_clk);\n"
text += "timeunit 1ps; timeprecision 1ps;\n"
if args.native_handoff:
    begin = source.index("wire hdmi_tx_clk;")
    stop = source.index("\naltddio_out", begin)
    native = source[begin:stop]
    assert native.count("x1_hdmi_clock_handoff hdmi_handoff(") == 1
    native = native.replace(".busy()", ".busy(fixture_busy)")
    text = "`define X1_HDMI_HANDOFF_EXPERIMENT\n" + text
    text += "wire clk_sys=clk_control, hdmi_clk_out=clk_hdmi, reset_req=reset_request;\nwire hdmi_policy_csync;\n"
    token_start = source.index("// Follow the SAME ce_pix")
    token_stop = source.index("`endif", token_start)
    text += source[token_start:token_stop] + "\n"
    text += native + "\nassign fixture_clk=hdmi_tx_clk;\nassign fixture_mode=hdmi_held_mode;\nassign fixture_blank=hdmi_transition_blank;\n"
else:
    text += f"wire hdmi_tx_clk = ({selectors[0]}) ? {clocks};\nassign fixture_clk=hdmi_tx_clk;\n"
text += policy + "\nendmodule\n"
if args.native_handoff:
    text += "`undef X1_HDMI_HANDOFF_EXPERIMENT\n"
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(text)
assert (root / "sys/sys_top.v").read_bytes() == raw, "policy source changed during extraction"
print("HDMI extracted sys_top SHA256", hashlib.sha256(raw).hexdigest(),
      "negative" if args.wrong_clock or args.raw_policy else "positive")
