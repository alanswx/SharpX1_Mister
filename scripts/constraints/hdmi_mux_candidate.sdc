# Experimental Z only; native scope audited, fresh-fit/physical gates open.
# PLL masters remain concurrent. Only the two choices at hdmi_tx_clk's mux
# output are logically exclusive; no whole-master clock-domain cut.
set x1_mux_hdmi [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|*|divclk}]
set x1_mux_video [get_clocks {*|turbo_video_pll|*|divclk}]
set x1_mux_system [get_clocks {*|pll|pll_inst|altera_pll_i|*|divclk}]
set x1_mux_output [get_pins -compatibility_mode {hdmi_clk_sw|outclk}]
set x1_mux_hdmi_input [get_pins -compatibility_mode {hdmi_clk_sw|inclk[2]}]
set x1_mux_video_input [get_pins -compatibility_mode {hdmi_clk_sw|inclk[3]}]
foreach {x1_mux_label x1_mux_collection} [list hdmi $x1_mux_hdmi video $x1_mux_video system $x1_mux_system output $x1_mux_output hdmi_input $x1_mux_hdmi_input video_input $x1_mux_video_input] {
    if {[get_collection_size $x1_mux_collection] != 1} {error "ambiguous/missing $x1_mux_label clock-mux object"}
}
foreach_in_collection x1_mux_clock $x1_mux_hdmi {set x1_mux_hdmi_name [get_clock_info -name $x1_mux_clock]}
foreach_in_collection x1_mux_clock $x1_mux_video {set x1_mux_video_name [get_clock_info -name $x1_mux_clock]}
foreach_in_collection x1_mux_clock $x1_mux_system {set x1_mux_system_name [get_clock_info -name $x1_mux_clock]}
if {[llength [lsort -unique [list $x1_mux_hdmi_name $x1_mux_video_name $x1_mux_system_name]]] != 3} {error "mux masters/system must remain distinct"}
foreach {x1_mux_collection x1_mux_expected} [list $x1_mux_output {hdmi_clk_sw|outclk} $x1_mux_hdmi_input {hdmi_clk_sw|inclk[2]} $x1_mux_video_input {hdmi_clk_sw|inclk[3]}] {
    foreach_in_collection x1_mux_pin $x1_mux_collection {
        if {[get_pin_info -name $x1_mux_pin] ne $x1_mux_expected} {error "unexpected clock-mux pin identity"}
    }
}
create_generated_clock -name x1_hdmi_mux -master_clock $x1_mux_hdmi_name -source $x1_mux_hdmi_input -divide_by 1 $x1_mux_output
create_generated_clock -name x1_video_mux -master_clock $x1_mux_video_name -source $x1_mux_video_input -divide_by 1 -add $x1_mux_output
set_clock_groups -logically_exclusive -group {x1_hdmi_mux} -group {x1_video_mux}
