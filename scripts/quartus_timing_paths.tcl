# Supplemental development reports; does not change assignments or constraints.
# Run inside an already-built isolated source tree:
# quartus_sta -t /path/to/quartus_timing_paths.tcl sharpx1_turbo_z_font_single
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
set analysis [lindex $quartus(args) 1]
if {$analysis ni {{} fast-hold}} {
    error "optional analysis must be fast-hold (Fast 1100 mV / -40 C)"
}
if {$revision ni {sharpx1 sharpx1_turbo_z_font_single sharpx1_turbo_z_video_single}} {
    error "expected a checked-in Sharp X1 project revision"
}
project_open sharpx1 -revision $revision
if {$analysis eq "fast-hold"} {
    create_timing_netlist -model fast -temperature -40 -voltage 1100
} else {
    create_timing_netlist
}
read_sdc
update_timing_netlist
if {$analysis eq "fast-hold"} {
    report_timing -hold -npaths 30 -detail full_path -file output_files/${revision}_sidecar_fast_n40_hold.rpt
} else {
report_timing -setup -npaths 30 -detail full_path -file output_files/${revision}_sidecar_setup.rpt
report_timing -hold -npaths 20 -detail full_path -file output_files/${revision}_sidecar_hold.rpt
report_timing -recovery -npaths 20 -detail full_path -file output_files/${revision}_sidecar_recovery.rpt
report_timing -setup -to [get_registers {*cg_bus*}] -npaths 20 -detail full_path -file output_files/${revision}_sidecar_pcg.rpt
report_timing -setup -to [get_registers {*sub_cpu*|cpu*}] -npaths 20 -detail full_path -file output_files/${revision}_sidecar_mr16.rpt
}
delete_timing_netlist
project_close
