# Completed-fit analysis only: no project assignments or RBF changes.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
set candidate [lindex $quartus(args) 1]
if {$revision ni {sharpx1_turbo_video sharpx1_turbo_z_video} || $candidate eq ""} {
    error "usage: independent X3 revision and explicit request candidate SDC"
}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
source $candidate
update_timing_netlist
set prefix output_files/${revision}_pcg_request_probe
set system [get_clocks {*|pll|pll_inst|altera_pll_i|*|divclk}]
if {[get_collection_size $system] != 1} {error "expected one SYS clock"}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set corner ${prefix}_${model}_${temperature}
        foreach {label sources destinations} [list \
            address $x1_req_address $x1_req_addr_dest \
            control $x1_req_control $x1_req_ctrl_dest \
            payload $x1_req_payload $x1_req_data_dest] {
            foreach check {setup hold} {
                report_timing -$check -from $sources -to $destinations -npaths 10000 -detail full_path -file ${corner}_${label}_${check}.rpt
            }
        }
        report_timing -setup -npaths 30 -detail full_path -file ${corner}_global_setup.rpt
        report_timing -hold -npaths 30 -detail full_path -file ${corner}_global_hold.rpt
    }
}
# Preserve source-bound same-SYS comparison at the original Slow 100 C corner.
set_operating_conditions -model slow -temperature 100 -voltage 1100
update_timing_netlist
foreach {label sources} [list address $x1_req_address control $x1_req_control] {
    foreach check {setup hold} {
        report_timing -$check -from $sources -to_clock $system -npaths 10000 -detail full_path -file ${prefix}_${label}_sys_${check}.rpt
    }
}
delete_timing_netlist
project_close
