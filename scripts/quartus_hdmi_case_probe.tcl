# Diagnostic only: command existence does not prove case-analysis support.
# Separate before/after reports, no project edits or accepted input waiver.
# The local Quartus 17 rejects the conventional positional SDC call below;
# this retained reproducer is not a supported case-analysis acceptance tool.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 2 || [lindex $quartus(args) 0] ne "sharpx1_turbo_z_video" ||
    [lindex $quartus(args) 1] ni {0 1}} {
    error "expected experimental Z revision and static direct-mode value 0/1"
}
set mode [lindex $quartus(args) 1]
project_open sharpx1 -revision sharpx1_turbo_z_video
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set direct [get_registers -no_duplicates {cfg[10]}]
set fb [get_registers -no_duplicates {cfg[12]}]
set hdmi [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|*|divclk}]
set vid [get_clocks {*|turbo_video_pll|*|divclk}]
set mux_video [get_clocks {x1_video_mux}]
set mux_hdmi [get_clocks {x1_hdmi_mux}]
foreach object [list $direct $fb $hdmi $vid $mux_video $mux_hdmi] {
    if {[get_collection_size $object] != 1} {error "missing/ambiguous case-probe object"}
}
foreach stage {before after} {
    if {$stage eq "after"} {
        post_message "HDMI case probe requesting cfg10=$mode cfg12=0; effectiveness unproven"
        set_case_analysis $mode $direct
        set_case_analysis 0 $fb
        update_timing_netlist
    }
    foreach {label source target} [list hdmi_video $hdmi $mux_video video_hdmi $vid $mux_hdmi] {
        foreach check {setup hold} {
            report_timing -$check -from_clock $source -to_clock $target -npaths 100 -detail full_path \
                -file output_files/sharpx1_turbo_z_video_hdmi_case_${mode}_${stage}_${label}_${check}.rpt
        }
    }
}
delete_timing_netlist
project_close
