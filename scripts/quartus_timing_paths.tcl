# Supplemental development reports; does not change assignments or constraints.
# Run inside an already-built isolated source tree:
# quartus_sta -t /path/to/quartus_timing_paths.tcl sharpx1_turbo_single
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ni {sharpx1 sharpx1_single sharpx1_turbo_single sharpx1_turbo_video sharpx1_turbo_dma_single sharpx1_turbo_fm}} {
    error "expected a checked-in Sharp X1 project revision"
}
project_open sharpx1 -revision $revision
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 30 -detail full_path -file output_files/${revision}_sidecar_setup.rpt
report_timing -hold -npaths 20 -detail full_path -file output_files/${revision}_sidecar_hold.rpt
report_timing -recovery -npaths 20 -detail full_path -file output_files/${revision}_sidecar_recovery.rpt
report_timing -setup -to [get_registers {*cg_bus*}] -npaths 20 -detail full_path -file output_files/${revision}_sidecar_pcg.rpt
report_timing -setup -to [get_registers {*sub_cpu*|cpu*}] -npaths 20 -detail full_path -file output_files/${revision}_sidecar_mr16.rpt
delete_timing_netlist
project_close
