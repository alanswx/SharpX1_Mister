# UNSELECTED completed-fit proposal, not native/MTBF/board acceptance.
# Four registered single-bit crossings in the acknowledged csync policy.
# Only source -> first-stage paths; every stage/consumer stays timed.
set x1_csync_triples {
    {x1_hdmi_clock_handoff:hdmi_handoff|video_policy_epoch} dv_epoch_meta dv_epoch_sample
    {x1_hdmi_clock_handoff:hdmi_handoff|active_mode[2]} dv_csync_meta dv_csync_sample
    dv_policy_completed dv_policy_meta dv_policy_sample
    dv_csync_completed dv_csync_echo_meta dv_csync_echo_sample
}
set x1_csync_inputs {}
foreach {x1_source x1_first x1_second} $x1_csync_triples {
    set x1_collections {}
    foreach x1_name [list $x1_source $x1_first $x1_second] {
        set x1_regs [get_registers -no_duplicates [list $x1_name]]
        if {[get_collection_size $x1_regs] != 1} {error "missing/ambiguous csync input scalar $x1_name"}
        foreach_in_collection x1_reg $x1_regs {
            if {[get_register_info -name $x1_reg] ne $x1_name} {error "substituted csync input scalar $x1_name"}
        }
        if {[string first {x1_hdmi_clock_handoff:hdmi_handoff|} $x1_name] == 0} {
            set x1_all [get_registers {*hdmi_handoff|*}]
        } else {
            set x1_all [get_registers [list "$x1_name*"]]
        }
        foreach_in_collection x1_reg $x1_all {
            set x1_actual [get_register_info -name $x1_reg]
            if {[string first "${x1_name}~" $x1_actual] == 0 ||
                [string first "${x1_name}_Duplicate_" $x1_actual] == 0} {
                error "unreviewed csync input replica $x1_actual"
            }
        }
        lappend x1_collections $x1_regs
    }
    lassign $x1_collections x1_source_reg x1_first_reg x1_second_reg
    set x1_drivers {}
    foreach_in_collection x1_node [get_fanins -synch $x1_first_reg] {
        if {[get_node_info -type $x1_node] eq "reg"} {lappend x1_drivers [get_node_info -name $x1_node]}
    }
    if {$x1_drivers ne [list $x1_source]} {error "unreviewed csync first-stage driver $x1_first"}
    set x1_fanouts {}
    foreach_in_collection x1_node [get_fanouts $x1_first_reg] {
        lappend x1_fanouts [list [get_node_info -name $x1_node] [get_node_info -type $x1_node]]
    }
    if {$x1_fanouts ne [list [list $x1_second reg]]} {error "unreviewed csync first-stage fanout $x1_first"}
    puts "CSYNC INPUT VERIFIED $x1_source $x1_first $x1_second"
    lappend x1_csync_inputs [list $x1_source_reg $x1_first_reg]
}
# All guards above must finish before the first proposed exclusion.
foreach x1_pair $x1_csync_inputs {
    lassign $x1_pair x1_source_reg x1_first_reg
    set_false_path -from $x1_source_reg -to $x1_first_reg
}
puts "CSYNC INPUT CANDIDATE: four exact first-stage inputs only"
