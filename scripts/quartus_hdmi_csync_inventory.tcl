# Read-only full-board csync/epoch synchronizer, capture and HS inventory.
# Existing revision SDC only: NO extra constraints or source assumptions.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1} {error "expected NEW report directory"}
set destination [lindex $quartus(args) 0]
if {[file exists $destination]} {error "refusing to overwrite evidence"}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
proc csync_scalar {name} {
    set physical [get_registers -no_duplicates [list $name]]
    if {[get_collection_size $physical] != 1} {error "missing/ambiguous csync scalar $name"}
    foreach_in_collection reg $physical {
        if {[get_register_info -name $reg] ne $name} {error "substituted csync scalar $name"}
    }
    # Refuse unreviewed replicas instead of qualifying only the easy copy.
    if {[string first {x1_hdmi_clock_handoff:hdmi_handoff|} $name] == 0} {
        set candidates [get_registers {*hdmi_handoff|*}]
    } else {
        set candidates [get_registers [list "$name*"]]
    }
    foreach_in_collection reg $candidates {
        set actual [get_register_info -name $reg]
        if {[string first "${name}~" $actual] == 0 ||
            [string first "${name}_Duplicate_" $actual] == 0} {
            error "unreviewed csync scalar replica $actual"
        }
    }
    return $physical
}
set pairs {
    epoch_stage {dv_epoch_meta dv_epoch_sample}
    csync_stage {dv_csync_meta dv_csync_sample}
    epoch_capture {dv_epoch_sample dv_policy_first}
    csync_capture {dv_csync_sample dv_csync_first}
    native_capture {dv_csync_sample dv_hs1}
    epoch_pipe1 {dv_policy_first dv_policy_second}
    epoch_pipe2 {dv_policy_second dv_policy_completed}
    csync_pipe1 {dv_csync_first dv_csync_second}
    csync_pipe2 {dv_csync_second dv_csync_completed}
    epoch_return {dv_policy_meta dv_policy_sample}
    csync_return {dv_csync_echo_meta dv_csync_echo_sample}
    native_pipe1 {dv_hs1 dv_hs2}
    native_pipe2 {dv_hs2 dv_hs}
    epoch_input {x1_hdmi_clock_handoff:hdmi_handoff|video_policy_epoch dv_epoch_meta}
    csync_input {x1_hdmi_clock_handoff:hdmi_handoff|active_mode[2] dv_csync_meta}
    epoch_echo_input {dv_policy_completed dv_policy_meta}
    csync_echo_input {dv_csync_completed dv_csync_echo_meta}
}
foreach {kind pair} $pairs {
    lassign $pair source target
    set sources($kind) [csync_scalar $source]
    set targets($kind) [csync_scalar $target]
    puts "CSYNC BOARD PAIR $kind $source $target"
}
foreach {first second} {
    dv_epoch_meta dv_epoch_sample
    dv_csync_meta dv_csync_sample
    dv_policy_meta dv_policy_sample
    dv_csync_echo_meta dv_csync_echo_sample
} {
    set physical [csync_scalar $first]
    set fanouts {}
    foreach_in_collection node [get_fanouts $physical] {
        lappend fanouts [list [get_node_info -name $node] [get_node_info -type $node]]
    }
    if {$fanouts ne [list [list $second reg]]} {error "unreviewed csync first-stage fanout $first: $fanouts"}
    puts "CSYNC BOARD FIRST FANOUT $first $second"
}
foreach kind {epoch_input csync_input epoch_echo_input csync_echo_input} {
    set expected_source [lindex [dict get $pairs $kind] 0]
    set drivers {}
    foreach_in_collection node [get_fanins -synch $targets($kind)] {
        if {[get_node_info -type $node] eq "reg"} {
            lappend drivers [get_node_info -name $node]
        }
    }
    if {$drivers ne [list $expected_source]} {error "unreviewed csync registered driver $kind: $drivers"}
    puts "CSYNC BOARD INPUT DRIVER $kind $expected_source"
}
# Include return-policy consumers, not just the four stage chains.
set epoch_consumer [csync_scalar dv_policy_sample]
set csync_consumer [csync_scalar dv_csync_echo_sample]
foreach name {dv_policy_sample dv_csync_echo_sample} {
    foreach_in_collection node [get_fanouts [csync_scalar $name]] {
        puts "CSYNC BOARD CONSUMER $name [get_node_info -name $node] ([get_node_info -type $node])"
    }
}
file mkdir $destination
report_clocks -file [file join $destination clocks.rpt]
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        puts "CSYNC BOARD CORNER $model $temperature 1100"
        foreach check {setup hold} {
            foreach {kind pair} $pairs {
                report_timing -$check -from $sources($kind) -to $targets($kind) \
                    -npaths 100 -detail full_path \
                    -file [file join $destination ${model}_${temperature}_${kind}_${check}.rpt]
            }
            foreach kind {epoch csync} {
                report_timing -$check -from [set ${kind}_consumer] -npaths 1000 -detail full_path \
                    -file [file join $destination ${model}_${temperature}_${kind}_consumer_${check}.rpt]
            }
            report_timing -$check -npaths 50 -detail full_path \
                -file [file join $destination ${model}_${temperature}_global_${check}.rpt]
        }
    }
}
puts "CSYNC BOARD INVENTORY COMPLETE: existing constraints only; not whole-board acceptance"
delete_timing_netlist
project_close
