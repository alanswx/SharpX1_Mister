# Separate handoff revision ONLY. Only six registered, single-bit inputs
# to verified two-stage synchronizers. No clock groups or held-data exceptions.
# Guard the complete inventory before applying even the first false path.
set x1_handoff_input_pairs {
    gate_request gate_request_meta gate_request_sample
    blank_request blank_meta blank_sample
    generation generation_meta generation_sample
    blank_ack ack_meta ack_sample
    completed_generation completed_meta completed_sample
    gate_observed_enable gate_meta gate_sample
}
set x1_handoff_input_prefix {x1_hdmi_clock_handoff:hdmi_handoff|}
set x1_handoff_all [get_registers {*hdmi_handoff|*}]
set x1_handoff_inputs {}
foreach {x1_source x1_first x1_second} $x1_handoff_input_pairs {
    set x1_collections {}
    foreach x1_leaf [list $x1_source $x1_first $x1_second] {
        set x1_name "$x1_handoff_input_prefix$x1_leaf"
        set x1_registers [get_registers -no_duplicates [list $x1_name]]
        if {[get_collection_size $x1_registers] != 1} {
            error "missing/ambiguous exact handoff input scalar $x1_name"
        }
        foreach_in_collection x1_register $x1_registers {
            if {[get_register_info -name $x1_register] ne $x1_name} {
                error "substituted handoff input scalar $x1_name"
            }
        }
        # Fitted duplicates of any of these keepers require a new inventory,
        # not silently leaving an unreviewed replica out of the scope claim.
        foreach_in_collection x1_register $x1_handoff_all {
            set x1_physical [get_register_info -name $x1_register]
            if {[string first "${x1_name}~" $x1_physical] == 0 ||
                [string first "${x1_name}_Duplicate_" $x1_physical] == 0} {
                error "unreviewed handoff input replica $x1_physical"
            }
        }
        lappend x1_collections $x1_registers
    }
    lassign $x1_collections x1_source_reg x1_first_reg x1_second_reg
    set x1_register_fanins {}
    # Default get_fanins also traverses the clock-select cone. Restrict this
    # DRIVER check to synchronous data edges; do not mistake active_mode[0]
    # on the mux clock-select pin for an extra D-input source.
    foreach_in_collection x1_node [get_fanins -synch $x1_first_reg] {
        if {[get_node_info -type $x1_node] eq "reg"} {
            lappend x1_register_fanins [get_node_info -name $x1_node]
        }
    }
    if {$x1_register_fanins ne [list "$x1_handoff_input_prefix$x1_source"]} {
        error "unreviewed registered driver of $x1_first"
    }
    set x1_fanouts {}
    foreach_in_collection x1_node [get_fanouts $x1_first_reg] {
        lappend x1_fanouts [list [get_node_info -name $x1_node] [get_node_info -type $x1_node]]
    }
    if {$x1_fanouts ne [list [list "$x1_handoff_input_prefix$x1_second" reg]]} {
        error "unreviewed first-stage fanout of $x1_first"
    }
    puts "HANDOFF INPUT VERIFIED $x1_source $x1_first $x1_second"
    lappend x1_handoff_inputs [list $x1_source_reg $x1_first_reg]
}
foreach x1_pair $x1_handoff_inputs {
    lassign $x1_pair x1_source_reg x1_first_reg
    set_false_path -from $x1_source_reg -to $x1_first_reg
}
puts "HANDOFF INPUT CANDIDATE: six exact first-stage inputs only"
