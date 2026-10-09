# Completed-fit before/after diagnostic. Does not select the candidate in QSF.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 2} {error "expected NEW report directory and candidate path"}
lassign $quartus(args) destination candidate
if {[file exists $destination]} {error "refusing to overwrite existing evidence"}
if {![file isfile $candidate]} {error "missing unselected candidate"}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set prefix {x1_hdmi_clock_handoff:hdmi_handoff|}
proc input_probe_scalar {leaf} {
    set name "$::prefix$leaf"
    set collection [get_registers -no_duplicates [list $name]]
    if {[get_collection_size $collection] != 1} {error "missing/ambiguous input probe scalar $name"}
    foreach_in_collection reg $collection {
        if {[get_register_info -name $reg] ne $name} {error "unexpected input probe alias $name"}
    }
    return $collection
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
set inputs {
    enable {gate_request gate_request_meta}
    blank {blank_request blank_meta}
    generation {generation generation_meta}
    ack {blank_ack ack_meta}
    completed {completed_generation completed_meta}
    gate_status {gate_observed_enable gate_meta}
}
foreach {kind pair} $pairs {
    lassign $pair source target
    set stage_source($kind) [input_probe_scalar $source]
    set stage_target($kind) [input_probe_scalar $target]
}
foreach {kind pair} $inputs {
    lassign $pair source target
    set input_source($kind) [input_probe_scalar $source]
    set input_target($kind) [input_probe_scalar $target]
}
file mkdir $destination
foreach phase {before after} {
    if {$phase eq "after"} {source $candidate; update_timing_netlist}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            set_operating_conditions -model $model -temperature $temperature -voltage 1100
            update_timing_netlist
            puts "HANDOFF INPUT PROBE CORNER $phase $model $temperature 1100"
            foreach check {setup hold} {
                foreach {kind pair} $pairs {
                    report_timing -$check -from $stage_source($kind) -to $stage_target($kind) \
                        -npaths 100 -detail full_path \
                        -file [file join $destination ${phase}_${model}_${temperature}_${kind}_chain_${check}.rpt]
                }
                foreach {kind pair} $inputs {
                    report_timing -$check -from $input_source($kind) -to $input_target($kind) \
                        -npaths 100 -detail full_path \
                        -file [file join $destination ${phase}_${model}_${temperature}_${kind}_input_${check}.rpt]
                }
                report_timing -$check -npaths 50 -detail full_path \
                    -file [file join $destination ${phase}_${model}_${temperature}_global_${check}.rpt]
            }
        }
    }
}
puts "HANDOFF INPUT PROBE COMPLETE: before/after original fit; candidate not board-selected"
delete_timing_netlist
project_close
