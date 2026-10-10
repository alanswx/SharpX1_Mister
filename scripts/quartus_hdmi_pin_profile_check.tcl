# Native scope check only, not fitted timing or hardware acceptance.
# Load the project's assigned SDCs in order, substituting only the candidate
# in memory. Never export assignments or overwrite the failed-source snapshot.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1} {error "expected candidate SDC path"}
set candidate [lindex $quartus(args) 0]
if {![file exists $candidate]} {error "missing candidate SDC"}
set summary_path output_files/sharpx1_turbo_z_handoff.fit.summary
if {[file exists $summary_path]} {
    set summary_file [open $summary_path r]
    set summary [read $summary_file]
    close $summary_file
    if {![regexp -line {^Fitter Status : (Successful|Failed)( |$)} $summary -> fitter_status]} {
        error "unrecognized fitter summary; refusing ambiguous netlist stage"
    }
    if {$fitter_status eq "Successful"} {
        error "mapped profile check refuses a completed fit: Quartus can ignore -post_map"
    }
}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -post_map
puts "HDMI PROFILE REQUESTED STAGE mapped; reject any ignored-option warning"
set replaced 0
foreach_in_collection assignment [get_all_global_assignments -name SDC_FILE] {
    set path [lindex $assignment 2]
    if {$path eq ""} {error "empty assigned SDC path"}
    puts "HDMI PROFILE ASSIGNED SDC $path"
    if {$path eq "scripts/constraints/hdmi_inactive_data_candidate.sdc"} {
        incr replaced
        read_sdc $candidate
    } else {read_sdc $path}
}
if {$replaced != 1} {error "candidate not substituted exactly once"}
update_timing_netlist
puts "HDMI PIN PROFILE CHECK COMPLETE: native guard loading only, not path preservation or timing acceptance"
delete_timing_netlist
project_close
