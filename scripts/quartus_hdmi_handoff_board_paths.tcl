# Read-only fitted timing diagnostic for the separate full-board revision.
# No extra exceptions; reports go into a NEW directory, never flow reports.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1} {error "expected a new report directory"}
set destination [lindex $quartus(args) 0]
if {[file exists $destination]} {error "refusing to overwrite existing evidence"}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
file mkdir $destination
report_clocks -file [file join $destination clocks.rpt]
# Full-board worst paths, not the smaller isolated-controller timing scope.
foreach check {setup hold recovery removal} {
    report_timing -$check -npaths 30 -detail full_path \
        -file [file join $destination global_${check}.rpt]
}
puts "HANDOFF BOARD PATHS COMPLETE: slow 100 C 1100 mV; original constraints only"
delete_timing_netlist
project_close
