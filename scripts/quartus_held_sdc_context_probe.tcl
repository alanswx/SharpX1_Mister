# Read-only SAME-FIT original-source/new-read_sdc context comparison.
# Recreates the timing netlist per phase; does not edit the snapshot's SDCs,
# assignments, fitter database or original reports. Not full-flow acceptance.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 3} {error "expected NEW report directory, repaired held SDC and inactive SDC"}
lassign $quartus(args) context_destination context_candidate context_inactive
if {[file exists $context_destination]} {error "refusing to overwrite context evidence"}
if {![file exists $context_candidate]} {error "missing repaired held SDC"}
if {![file exists $context_inactive]} {error "missing source-bound inactive SDC"}
set context_summary_file [open output_files/sharpx1_turbo_z_handoff.fit.summary r]
set context_summary [read $context_summary_file]
close $context_summary_file
if {![regexp -line {^Fitter Status : Successful( |$)} $context_summary]} {
    error "context probe requires a successful completed fit; no -post_map fallback"
}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
file mkdir $context_destination
foreach context_phase {before after} {
    unset -nocomplain ::x1_mode_inventory
    create_timing_netlist -model slow -temperature 100 -voltage 1100
    set context_replaced 0
    set context_inactive_count 0
    foreach_in_collection context_assignment [get_all_global_assignments -name SDC_FILE] {
        set context_path [lindex $context_assignment 2]
        if {$context_path eq ""} {error "empty context assigned SDC path"}
        puts "HELD CONTEXT ASSIGNED $context_phase $context_path"
        if {$context_path eq "scripts/constraints/hdmi_held_mode_candidate.sdc"} {
            incr context_replaced
            if {$context_phase eq "before"} {
                # The original helper works only when its source runs at Tcl
                # global scope. This is an explicit diagnostic baseline, not
                # a claim the failed full TimeQuest flow loaded it correctly.
                source $context_path
            } else {
                # Real native read_sdc context, with no stale global inventory.
                read_sdc $context_candidate
            }
        } elseif {$context_path eq "scripts/constraints/hdmi_inactive_data_candidate.sdc"} {
            incr context_inactive_count
            # Original fit's old inactive guard rejects its new physical bank.
            # Explicitly leave inactive paths TIMED in the diagnostic baseline.
            if {$context_phase eq "after"} {
                read_sdc $context_inactive
            } else {puts "HELD CONTEXT BASELINE INACTIVE OMITTED: paths remain timed"}
        } else {read_sdc $context_path}
    }
    if {$context_replaced != 1} {error "held context substitution not exactly once"}
    if {$context_inactive_count != 1} {error "inactive context substitution not exactly once"}
    update_timing_netlist
    set context_modes [get_registers -no_duplicates {*hdmi_handoff|active_mode*}]
    if {[get_collection_size $context_modes] != 3} {error "context mode scalar/replica inventory changed"}
    set context_hdmi {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
    set context_video {emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
    set context_routes [list inactive_hdmi [list $context_hdmi x1_video_handoff_mux] \
        inactive_video [list $context_video x1_hdmi_handoff_mux] \
        active_hdmi [list $context_hdmi x1_hdmi_handoff_mux] \
        active_video [list $context_video x1_video_handoff_mux] \
        pipe_hdmi {x1_hdmi_handoff_mux x1_hdmi_handoff_mux} \
        pipe_video {x1_video_handoff_mux x1_video_handoff_mux}]
    set context_raw_pairs {
        epoch_input {x1_hdmi_clock_handoff:hdmi_handoff|video_policy_epoch dv_epoch_meta}
        csync_input {{x1_hdmi_clock_handoff:hdmi_handoff|active_mode[2]} dv_csync_meta}
        epoch_echo_input {dv_policy_completed dv_policy_meta}
        csync_echo_input {dv_csync_completed dv_csync_echo_meta}
    }
    foreach context_model {slow fast} {
        foreach context_temperature {-40 0 85 100} {
            set_operating_conditions -model $context_model -temperature $context_temperature -voltage 1100
            update_timing_netlist
            set context_stem ${context_phase}_${context_model}_${context_temperature}
            puts "HELD CONTEXT CORNER $context_phase $context_model $context_temperature 1100"
            foreach context_check {setup hold} {
                report_timing -$context_check -from $context_modes -npaths 1000 -detail full_path \
                    -file [file join $context_destination ${context_stem}_mode_${context_check}.rpt]
                foreach {context_kind context_pair} $context_routes {
                    set context_launch [get_clocks [list [lindex $context_pair 0]]]
                    set context_capture [get_clocks [list [lindex $context_pair 1]]]
                    if {[get_collection_size $context_launch] != 1 || [get_collection_size $context_capture] != 1} {
                        error "missing/ambiguous context route clock"
                    }
                    report_timing -$context_check -from $context_launch -to $context_capture -npaths 5000 -detail full_path \
                        -file [file join $context_destination ${context_stem}_${context_kind}_${context_check}.rpt]
                }
                foreach {context_kind context_pair} $context_raw_pairs {
                    set context_launch [get_registers -no_duplicates [list [lindex $context_pair 0]]]
                    set context_capture [get_registers -no_duplicates [list [lindex $context_pair 1]]]
                    if {[get_collection_size $context_launch] != 1 || [get_collection_size $context_capture] != 1} {
                        error "missing/ambiguous context raw endpoint"
                    }
                    report_timing -$context_check -from $context_launch -to $context_capture -npaths 100 -detail full_path \
                        -file [file join $context_destination ${context_stem}_${context_kind}_${context_check}.rpt]
                }
                report_timing -$context_check -npaths 50 -detail full_path \
                    -file [file join $context_destination ${context_stem}_global_${context_check}.rpt]
            }
        }
    }
    delete_timing_netlist
}
puts "HELD CONTEXT PROBE COMPLETE: same-fit context comparison only; no full-flow or hardware acceptance"
project_close
