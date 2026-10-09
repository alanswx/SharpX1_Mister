# Experimental Z only; audited input scope, fresh-fit/physical gates open.
# Only the asynchronous source -> stage-0
# data input is excluded; CLK/Q, stage 1 and all consumer timing stay active.
# Native fanin/fanout and the two-stage identity must validate before any cut.
set x1_vsync_regs [get_registers {*hdmi_vsync_to_sys*|sample_pipe*}]
if {[get_collection_size $x1_vsync_regs] != 2} {error "expected two primary VSYNC stages"}
set x1_vsync_names [dict create]
foreach_in_collection x1_vsync_reg $x1_vsync_regs {
    set x1_vsync_name [get_register_info -name $x1_vsync_reg]
    if {![regexp {^x1_vsync_sys:hdmi_vsync_to_sys\|sample_pipe\[([01])\]$} $x1_vsync_name -> x1_vsync_bit] || [dict exists $x1_vsync_names $x1_vsync_bit]} {
        error "unexpected VSYNC stage identity: $x1_vsync_name"
    }
    dict set x1_vsync_names $x1_vsync_bit $x1_vsync_name
}
if {[lsort [dict keys $x1_vsync_names]] ne {0 1}} {error "missing VSYNC stage"}
foreach {x1_vsync_bit x1_vsync_expected} [list 0 [list [dict get $x1_vsync_names 1]] 1 {vs_d0 vs_d1 vsd}] {
    set x1_vsync_fanouts [get_fanouts [list [dict get $x1_vsync_names $x1_vsync_bit]]]
    set x1_vsync_actual {}
    foreach_in_collection x1_vsync_fanout $x1_vsync_fanouts {
        if {[get_node_info -type $x1_vsync_fanout] ne "reg"} {error "unexpected VSYNC fanout type"}
        lappend x1_vsync_actual [get_node_info -name $x1_vsync_fanout]
    }
    if {[lsort $x1_vsync_actual] ne [lsort $x1_vsync_expected]} {error "VSYNC fanout identity changed"}
}
set x1_vsync_all_pins [get_pins -compatibility_mode {*hdmi_vsync_to_sys*|sample_pipe*|*}]
set x1_vsync_data_names {}
foreach_in_collection x1_vsync_pin $x1_vsync_all_pins {
    set x1_vsync_pin_name [get_pin_info -name $x1_vsync_pin]
    if {[regexp {^hdmi_vsync_to_sys\|sample_pipe\[0\]\|(d|asdata)$} $x1_vsync_pin_name]} {
        lappend x1_vsync_data_names $x1_vsync_pin_name
    }
}
if {[llength $x1_vsync_data_names] != 1} {error "expected exactly one first-stage data input"}
set x1_vsync_data_pin [get_pins -compatibility_mode $x1_vsync_data_names]
if {[get_collection_size $x1_vsync_data_pin] != 1} {error "VSYNC data pin identity did not resolve uniquely"}
set x1_vsync_fanins [get_fanins $x1_vsync_data_names]
if {[get_collection_size $x1_vsync_fanins] != 1} {error "expected one VSYNC data-source keeper, not register clock fanin"}
foreach_in_collection x1_vsync_fanin $x1_vsync_fanins {
    set x1_vsync_source_name [get_node_info -name $x1_vsync_fanin]
    if {[get_node_info -type $x1_vsync_fanin] ne "reg" || ![regexp {^hdmi_out_vs(~_Duplicate_[0-9]+)?$} $x1_vsync_source_name]} {
        error "unexpected VSYNC data source: $x1_vsync_source_name"
    }
}
set x1_vsync_source [get_registers [list $x1_vsync_source_name]]
if {[get_collection_size $x1_vsync_source] != 1} {error "VSYNC source identity did not resolve uniquely"}
post_message "VSYNC input-only scope: $x1_vsync_source_name -> $x1_vsync_data_names"
set_false_path -from $x1_vsync_source -to $x1_vsync_data_pin
