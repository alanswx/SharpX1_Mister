# Reporting-only exhaustive-budget request reconnaissance on a completed fit.
# No timing exceptions or project assignments. Review count vs 10000 cap.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ni {sharpx1_turbo_video sharpx1_turbo_z_video}} {
    error "expected independent X3 revision"
}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set video [get_clocks {*|turbo_video_pll|*|divclk}]
set system [get_clocks {*|pll|pll_inst|altera_pll_i|*|divclk}]
if {[get_collection_size $video] != 1 || [get_collection_size $system] != 1} {
    error "expected unique SYS and VID clocks"
}
set prefix output_files/${revision}_pcg_request_paths
foreach {label patterns} {
    address {*x1_pcg_access:cg_bus|frozen_addr* *x1_pcg_access:cg_bus|font_cpu_addr*}
    control {*x1_pcg_access:cg_bus|plane* *x1_pcg_access:cg_bus|write_request* *x1_pcg_access:cg_bus|high_speed_request* *x1_pcg_access:cg_bus|unsupported_request*}
    payload {*x1_pcg_access:cg_bus|payload*}
} {
    set sources [get_registers $patterns]
    puts "$label sources: [get_collection_size $sources]"
    foreach_in_collection reg $sources {puts "  [get_register_info -name $reg]"}
    if {[get_collection_size $sources] == 0} {error "missing $label sources"}
    foreach {domain clock} [list vid $video sys $system] {
        foreach check {setup hold} {
            report_timing -$check -from $sources -to_clock $clock -npaths 10000 -detail full_path -file ${prefix}_${label}_${domain}_${check}.rpt
        }
    }
}
delete_timing_netlist
project_close
