# Reporting-only diagnosis of MPU keeper/report coverage. No exceptions.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1 || [lindex $quartus(args) 0] ne "sharpx1_turbo_z_video"} {
    error "expected experimental Z revision only"
}
project_open sharpx1 -revision sharpx1_turbo_z_video
create_timing_netlist -model slow -temperature -40 -voltage 1100
read_sdc
update_timing_netlist
set prefix {emu:emu|sharpx1:sharpx1|x1_vid:display|crtc6845s:crtc6845s|mpu_if:mpu_if|}
foreach field {{R_ADR[0]} {R_ADR[0]~DUPLICATE}} {
    set name ${prefix}${field}
    set source [get_registers [list $name]]
    post_message "CRTC probe name lookup count $field [get_collection_size $source]"
    foreach_in_collection node $source {post_message "CRTC probe resolved source [get_register_info -name $node]"}
    # This is intentionally a name-alias group diagnostic, not exact physical
    # keeper coverage. Original names can resolve primary plus fitted clone.
    set count [get_collection_size $source]
    if {($field eq {R_ADR[0]} && $count != 2) ||
        ($field eq {R_ADR[0]~DUPLICATE} && $count != 1)} {
        error "unexpected native alias lookup profile"
    }
    foreach_in_collection node [get_fanins [list $name]] {
        post_message "CRTC probe input $field [get_node_info -name $node] ([get_node_info -type $node])"
    }
    foreach_in_collection node [get_fanouts [list $name]] {
        post_message "CRTC probe output $field [get_node_info -name $node] ([get_node_info -type $node])"
    }
    set label [expr {$field eq {R_ADR[0]} ? "primary" : "replica"}]
    foreach check {setup hold} {
        report_timing -$check -from $source -npaths 10000 -detail full_path -file output_files/crtc_replica_probe_${label}_${check}.rpt
        set target [get_registers [list ${prefix}R_Nadj\[0\]]]
        if {[get_collection_size $target] != 1} {error "missing probe consumer"}
        report_timing -$check -from $source -to $target -npaths 10000 -detail full_path -file output_files/crtc_replica_probe_${label}_nadj_${check}.rpt
    }
}
delete_timing_netlist
project_close
