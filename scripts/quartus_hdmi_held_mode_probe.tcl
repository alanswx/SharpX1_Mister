# Read-only BEFORE/AFTER probe of an unselected held-mux candidate.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 2} {error "expected NEW directory and candidate SDC"}
lassign $quartus(args) destination candidate
if {[file exists $destination]} {error "refusing to overwrite evidence"}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set modes [get_registers -no_duplicates {*hdmi_handoff|active_mode*}]
set raw_pairs {
    epoch_input {x1_hdmi_clock_handoff:hdmi_handoff|video_policy_epoch dv_epoch_meta}
    csync_input {{x1_hdmi_clock_handoff:hdmi_handoff|active_mode[2]} dv_csync_meta}
    epoch_echo_input {dv_policy_completed dv_policy_meta}
    csync_echo_input {dv_csync_completed dv_csync_echo_meta}
}
foreach {kind pair} $raw_pairs {
    foreach role {from to} name $pair {
        set nodes [get_registers -no_duplicates [list $name]]
        if {[get_collection_size $nodes] != 1} {error "missing raw input keeper $name"}
        foreach_in_collection node $nodes {
            if {[get_register_info -name $node] ne $name} {error "substituted raw input keeper"}
        }
        set raw($kind,$role) $nodes
    }
}
file mkdir $destination
foreach phase {before after} {
    if {$phase eq "after"} {source $candidate}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            set_operating_conditions -model $model -temperature $temperature -voltage 1100
            update_timing_netlist
            puts "HELD MUX PROBE CORNER $phase $model $temperature 1100"
            foreach check {setup hold} {
                set stem ${phase}_${model}_${temperature}
                report_timing -$check -from $modes -npaths 1000 -detail full_path \
                    -file [file join $destination ${stem}_mode_${check}.rpt]
                foreach {kind pair} $raw_pairs {
                    report_timing -$check -from $raw($kind,from) -to $raw($kind,to) \
                        -npaths 100 -detail full_path \
                        -file [file join $destination ${stem}_${kind}_${check}.rpt]
                }
                report_timing -$check -npaths 50 -detail full_path \
                    -file [file join $destination ${stem}_global_${check}.rpt]
            }
        }
    }
}
puts "HELD MUX PROBE COMPLETE: diagnostic only; original SDC/artifacts unchanged"
delete_timing_netlist
project_close
