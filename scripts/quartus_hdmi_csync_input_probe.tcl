# Unselected completed-fit csync input probe. No QSF/source/RBF writes.
# Run the separate native csync inventory as well: this is not its replacement.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 2} {error "expected NEW report directory and explicit candidate"}
lassign $quartus(args) destination candidate
if {[file exists $destination]} {error "refusing to overwrite evidence"}
if {![file isfile $candidate]} {error "missing unselected candidate"}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
proc csync_probe_scalar name {
    set regs [get_registers -no_duplicates [list $name]]
    if {[get_collection_size $regs] != 1} {error "missing/ambiguous csync probe scalar $name"}
    foreach_in_collection reg $regs {
        if {[get_register_info -name $reg] ne $name} {error "substituted csync probe scalar $name"}
    }
    return $regs
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
    set sources($kind) [csync_probe_scalar $source]
    set targets($kind) [csync_probe_scalar $target]
}
foreach name {dv_policy_sample dv_csync_echo_sample} {
    set consumers($name) [csync_probe_scalar $name]
    foreach_in_collection node [get_fanouts $consumers($name)] {
        puts "CSYNC INPUT PROBE CONSUMER $name [get_node_info -name $node] ([get_node_info -type $node])"
    }
}
file mkdir $destination
report_clocks -file [file join $destination clocks.rpt]
foreach phase {before after} {
    if {$phase eq "after"} {source $candidate;update_timing_netlist}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            set_operating_conditions -model $model -temperature $temperature -voltage 1100
            update_timing_netlist
            puts "CSYNC INPUT PROBE CORNER $phase $model $temperature 1100"
            foreach check {setup hold} {
                foreach {kind pair} $pairs {
                    report_timing -$check -from $sources($kind) -to $targets($kind) \
                        -npaths 100 -detail full_path \
                        -file [file join $destination ${phase}_${model}_${temperature}_${kind}_${check}.rpt]
                }
                foreach {kind name} {epoch dv_policy_sample csync dv_csync_echo_sample} {
                    report_timing -$check -from $consumers($name) -npaths 1000 -detail full_path \
                        -file [file join $destination ${phase}_${model}_${temperature}_${kind}_consumer_${check}.rpt]
                }
                report_timing -$check -npaths 50 -detail full_path \
                    -file [file join $destination ${phase}_${model}_${temperature}_global_${check}.rpt]
            }
        }
    }
}
puts "CSYNC INPUT PROBE COMPLETE: before/after original fit; candidate not board-selected"
delete_timing_netlist
project_close
