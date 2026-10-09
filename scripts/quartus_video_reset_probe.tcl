# Analysis-only reset-input experiment on a completed, idle Z fit.
# Does not change QSF/SDC, RTL or RBF. Keep D-chain and output timing visible.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
set candidate [lindex $quartus(args) 1]
if {$revision ne "sharpx1_turbo_z_video" || $candidate eq ""} {
    error "usage: experimental Z revision and explicit reset-input candidate"
}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set pipes [get_registers {*x1_reset_release:video_reset_domain.release_reset|release_pipe* *x1_reset_release:local_release.video_release|release_pipe*}]
if {[get_collection_size $pipes] != 4} {error "expected four VID reset pipeline registers"}
set prefix output_files/${revision}_video_reset_probe
foreach check {setup hold} {
    report_timing -$check -from $pipes -to $pipes -npaths 10000 -detail full_path -file ${prefix}_before_chain_${check}.rpt
}
report_timing -recovery -from $pipes -npaths 10000 -detail full_path -file ${prefix}_before_output_recovery.rpt
report_timing -recovery -npaths 50 -detail full_path -file ${prefix}_before_global_recovery.rpt
source $candidate
update_timing_netlist
foreach check {setup hold} {
    report_timing -$check -from $pipes -to $pipes -npaths 10000 -detail full_path -file ${prefix}_after_chain_${check}.rpt
}
report_timing -recovery -from $pipes -npaths 10000 -detail full_path -file ${prefix}_after_output_recovery.rpt
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set corner ${prefix}_${model}_${temperature}
        foreach check {setup hold} {
            report_timing -$check -from $pipes -to $pipes -npaths 10000 -detail full_path -file ${corner}_chain_${check}.rpt
        }
        foreach check {recovery removal} {
            report_timing -$check -from $pipes -npaths 10000 -detail full_path -file ${corner}_output_${check}.rpt
            report_timing -$check -npaths 50 -detail full_path -file ${corner}_global_${check}.rpt
        }
    }
}
delete_timing_netlist
project_close
