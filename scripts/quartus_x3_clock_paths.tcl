# Reporting only: selected independent-X3 Z profile with output mux aliases.
# Run sequentially on an idle completed fit after preserving original reports.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ne "sharpx1_turbo_z_video"} {error "expected selected experimental Z profile"}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set clocks [dict create]
set identities {}
foreach {label pattern} {
    system {*|pll|pll_inst|altera_pll_i|*|divclk}
    video {*|turbo_video_pll|*|divclk}
    hdmi {pll_hdmi|pll_hdmi_inst|altera_pll_i|*|divclk}
    mux_hdmi {x1_hdmi_mux}
    mux_video {x1_video_mux}
} {
    set collection [get_clocks $pattern]
    if {[get_collection_size $collection] != 1} {error "expected one $label clock; refuse partial clock coverage"}
    foreach_in_collection clock $collection {lappend identities [get_clock_info -name $clock]}
    dict set clocks $label $collection
}
if {[llength [lsort -unique $identities]] != 5} {error "expected five distinct clock identities"}
report_clocks -file output_files/${revision}_x3_clock_inventory.rpt
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set prefix output_files/${revision}_x3_clock_${model}_${temperature}
        dict for {label clock} $clocks {
            foreach check {setup hold recovery removal} {
                report_timing -$check -from_clock $clock -to_clock $clock -npaths 100 -detail full_path -file ${prefix}_${label}_same_${check}.rpt
            }
        }
        foreach {label from to} {
            system_video system video
            video_system video system
            mux_hdmi_system mux_hdmi system
            system_mux_hdmi system mux_hdmi
            mux_video_system mux_video system
            system_mux_video system mux_video
            hdmi_mux_hdmi hdmi mux_hdmi
            mux_hdmi_hdmi mux_hdmi hdmi
            video_mux_video video mux_video
            mux_video_video mux_video video
        } {
            foreach check {setup hold} {
                report_timing -$check -from_clock [dict get $clocks $from] -to_clock [dict get $clocks $to] -npaths 100 -detail full_path -file ${prefix}_${label}_${check}.rpt
            }
        }
    }
}
delete_timing_netlist
project_close
