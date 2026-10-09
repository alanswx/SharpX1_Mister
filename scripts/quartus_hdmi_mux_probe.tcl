# Development-only clock-mux constraint probe on a completed fitted database.
# Does not write QSF/SDC, refit, or qualify an RBF. Run ONLY after host idle:
# quartus_sta -t /path/to/quartus_hdmi_mux_probe.tcl sharpx1_turbo_z_video
# Quartus 17.0 create_generated_clock / set_clock_groups API references:
# https://resources.altera.com/quartushelp/17.0/tafs/tafs/tcl_pkg_sdc_ver_1.5_cmd_create_generated_clock.htm
# https://resources.altera.com/quartushelp/17.0/tafs/tafs/tcl_pkg_sdc_ver_1.5_cmd_set_clock_groups.htm
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ni {sharpx1_turbo_video sharpx1_turbo_z_video}} {
    error "expected an independent X3 video revision"
}
project_open sharpx1 -revision $revision
create_timing_netlist
read_sdc
update_timing_netlist
set hdmi [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|*|divclk}]
set video [get_clocks {*|turbo_video_pll|*|divclk}]
set system [get_clocks {*|pll|pll_inst|altera_pll_i|*|divclk}]
set mux [get_pins -compatibility_mode {hdmi_clk_sw|outclk}]
set hdmi_input [get_pins -compatibility_mode {hdmi_clk_sw|inclk[2]}]
set video_input [get_pins -compatibility_mode {hdmi_clk_sw|inclk[3]}]
foreach {label collection} [list hdmi $hdmi video $video system $system mux $mux hdmi_input $hdmi_input video_input $video_input] {
    if {[get_collection_size $collection] != 1} {
        error "expected exactly one $label object; refuse empty/ambiguous constraint"
    }
}
set prefix output_files/${revision}_mux_probe
report_timing -setup -from_clock $hdmi -to_clock $hdmi -npaths 30 -detail full_path -file ${prefix}_before_hdmi_same.rpt
report_timing -setup -from_clock $hdmi -to_clock $video -npaths 30 -detail full_path -file ${prefix}_before_cross.rpt
report_timing -setup -from_clock $system -to_clock $video -npaths 30 -detail full_path -file ${prefix}_before_system_video.rpt
report_timing -setup -from_clock $video -to_clock $system -npaths 30 -detail full_path -file ${prefix}_before_video_system.rpt

# The two PLLs run concurrently. Only their alternatives at the shared
# hdmi_tx_clk mux output are mutually exclusive; never exclude the original
# master clocks design-wide. Preserve all ordinary same-clock setup checks.
foreach_in_collection clock $hdmi { set hdmi_name [get_clock_info -name $clock] }
foreach_in_collection clock $video { set video_name [get_clock_info -name $clock] }
create_generated_clock -name x1_probe_hdmi_mux -master_clock $hdmi_name -source $hdmi_input -divide_by 1 $mux
create_generated_clock -name x1_probe_video_mux -master_clock $video_name -source $video_input -divide_by 1 -add $mux
set_clock_groups -logically_exclusive -group {x1_probe_hdmi_mux} -group {x1_probe_video_mux}
update_timing_netlist
report_clocks -file ${prefix}_clocks.rpt
report_timing -setup -from_clock [get_clocks x1_probe_hdmi_mux] -to_clock [get_clocks x1_probe_hdmi_mux] -npaths 30 -detail full_path -file ${prefix}_after_hdmi_same.rpt
report_timing -setup -from_clock [get_clocks x1_probe_video_mux] -to_clock [get_clocks x1_probe_video_mux] -npaths 30 -detail full_path -file ${prefix}_after_video_same.rpt
# Master-clock crossings outside the mux must remain visible, not become
# accidentally excluded by the alias groups.
report_timing -setup -from_clock $hdmi -to_clock $video -npaths 30 -detail full_path -file ${prefix}_after_master_cross.rpt
report_timing -setup -from_clock $system -to_clock $video -npaths 30 -detail full_path -file ${prefix}_after_system_video.rpt
report_timing -setup -from_clock $video -to_clock $system -npaths 30 -detail full_path -file ${prefix}_after_video_system.rpt
report_timing -setup -npaths 30 -detail full_path -file ${prefix}_after_global.rpt
delete_timing_netlist
project_close
