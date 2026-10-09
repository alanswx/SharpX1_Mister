# Analysis-only experiment. Never writes QSF/SDC or changes the fitted RBF.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
set candidate [lindex $quartus(args) 1]
if {$revision ni {sharpx1_turbo_video sharpx1_turbo_z_video} || $candidate eq ""} {
    error "usage: X3 revision and explicit PCG response candidate SDC"
}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set response [get_registers {*x1_pcg_access:cg_bus|response*}]
set cpu_q [get_registers {*x1_pcg_access:cg_bus|cpu_q*}]
set prefix output_files/${revision}_pcg_response_probe
report_timing -setup -from $response -to $cpu_q -npaths 100 -detail full_path -file ${prefix}_before_setup.rpt
report_timing -hold -from $response -to $cpu_q -npaths 100 -detail full_path -file ${prefix}_before_hold.rpt
source $candidate
update_timing_netlist
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set corner ${prefix}_${model}_${temperature}
        foreach check {setup hold} {
            report_timing -$check -from $response -to $cpu_q -npaths 100 -detail full_path -file ${corner}_response_${check}.rpt
            # Keep all other checks visible; no clock-group or blanket CDC cut.
            report_timing -$check -npaths 30 -detail full_path -file ${corner}_global_${check}.rpt
        }
    }
}
delete_timing_netlist
project_close
