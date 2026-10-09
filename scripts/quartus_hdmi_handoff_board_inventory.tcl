# Supplemental FULL-BOARD handoff inventory and stage timing. No exceptions.
# A missing/duplicated physical scalar aborts rather than omitting its paths.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1} {error "expected a NEW report directory"}
set destination [lindex $quartus(args) 0]
if {[file exists $destination]} {error "refusing to overwrite existing evidence"}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
proc handoff_scalar {leaf} {
    set name "x1_hdmi_clock_handoff:hdmi_handoff|$leaf"
    set physical [get_registers -no_duplicates [list $name]]
    if {[get_collection_size $physical] != 1} {
        error "missing/ambiguous physical handoff scalar $name"
    }
    foreach_in_collection reg $physical {
        if {[get_register_info -name $reg] ne $name} {
            error "unexpected physical handoff alias for $name"
        }
    }
    return $physical
}
set pairs {
    enable {gate_request_meta gate_request_sample}
    ack {ack_meta ack_sample}
    completed {completed_meta completed_sample}
    gate_status {gate_meta gate_sample}
    blank {blank_meta blank_sample}
    generation {generation_meta generation_sample}
    witness {gate_request_sample gate_observed_enable}
    native_gate {gate_request_sample gate~FF_0}
}
# Validate every requested scalar before creating a report directory.
foreach {kind pair} $pairs {
    lassign $pair source target
    set sources($kind) [handoff_scalar $source]
    set targets($kind) [handoff_scalar $target]
    puts "HANDOFF BOARD PAIR $kind $source $target"
    foreach_in_collection node [get_fanouts $sources($kind)] {
        puts "HANDOFF BOARD FANOUT $source [get_node_info -name $node] ([get_node_info -type $node])"
    }
}
# Inventory the entire controller, including any fitted source replicas.
foreach_in_collection reg [get_registers {*hdmi_handoff|*}] {
    puts "HANDOFF BOARD REGISTER [get_register_info -name $reg]"
}
file mkdir $destination
report_clocks -file [file join $destination clocks.rpt]
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        puts "HANDOFF BOARD CORNER $model $temperature 1100"
        foreach check {setup hold} {
            foreach {kind pair} $pairs {
                report_timing -$check -from $sources($kind) -to $targets($kind) \
                    -npaths 100 -detail full_path \
                    -file [file join $destination ${model}_${temperature}_${kind}_${check}.rpt]
            }
            report_timing -$check -npaths 50 -detail full_path \
                -file [file join $destination ${model}_${temperature}_global_${check}.rpt]
        }
    }
}
puts "HANDOFF BOARD INVENTORY COMPLETE: original SDC only; not whole-board acceptance"
delete_timing_netlist
project_close
