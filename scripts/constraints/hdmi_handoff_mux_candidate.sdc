# New handoff revision ONLY. Two mux-output choices, not whole PLL domains.
# No raw input, held-mode bundle, data-bank or output-DDR exceptions here.
set x1_handoff_hdmi [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|*|divclk}]
set x1_handoff_video [get_clocks {*|turbo_video_pll|*|divclk}]
set x1_handoff_system [get_clocks {*|pll|pll_inst|altera_pll_i|*|divclk}]
set x1_handoff_output [get_pins -compatibility_mode {hdmi_handoff|mux|outclk}]
set x1_handoff_hdmi_input [get_pins -compatibility_mode {hdmi_handoff|mux|inclk[2]}]
set x1_handoff_video_input [get_pins -compatibility_mode {hdmi_handoff|mux|inclk[3]}]
foreach {x1_handoff_label x1_handoff_collection} [list hdmi $x1_handoff_hdmi video $x1_handoff_video system $x1_handoff_system output $x1_handoff_output hdmi_input $x1_handoff_hdmi_input video_input $x1_handoff_video_input] {
    if {[get_collection_size $x1_handoff_collection] != 1} {error "ambiguous/missing $x1_handoff_label handoff clock object"}
}
foreach_in_collection x1_handoff_clock $x1_handoff_hdmi {set x1_handoff_hdmi_name [get_clock_info -name $x1_handoff_clock]}
foreach_in_collection x1_handoff_clock $x1_handoff_video {set x1_handoff_video_name [get_clock_info -name $x1_handoff_clock]}
foreach_in_collection x1_handoff_clock $x1_handoff_system {set x1_handoff_system_name [get_clock_info -name $x1_handoff_clock]}
if {[llength [lsort -unique [list $x1_handoff_hdmi_name $x1_handoff_video_name $x1_handoff_system_name]]] != 3} {
    error "handoff masters/system must remain distinct"
}
foreach {x1_handoff_collection x1_handoff_expected} [list $x1_handoff_output {hdmi_handoff|mux|outclk} $x1_handoff_hdmi_input {hdmi_handoff|mux|inclk[2]} $x1_handoff_video_input {hdmi_handoff|mux|inclk[3]}] {
    foreach_in_collection x1_handoff_pin $x1_handoff_collection {
        if {[get_pin_info -name $x1_handoff_pin] ne $x1_handoff_expected} {error "unexpected handoff clock pin identity"}
    }
}
create_generated_clock -name x1_hdmi_handoff_mux -master_clock $x1_handoff_hdmi_name -source $x1_handoff_hdmi_input -divide_by 1 $x1_handoff_output
create_generated_clock -name x1_video_handoff_mux -master_clock $x1_handoff_video_name -source $x1_handoff_video_input -divide_by 1 -add $x1_handoff_output
set_clock_groups -logically_exclusive -group {x1_hdmi_handoff_mux} -group {x1_video_handoff_mux}
