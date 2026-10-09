# Reporting only: run sequentially on a completed, idle experimental Z fit.
# Read the project's real SDC; do not add exceptions or modify the project.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ne "sharpx1_turbo_z_video"} {
    error "usage: quartus_sta -t scripts/quartus_scaler_reset_paths.tcl sharpx1_turbo_z_video"
}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set raw [get_registers {reset_req}]
if {[get_collection_size $raw] != 1} {error "expected one raw reset_req register"}
set releases [dict create]
foreach domain {i o avl} {
    set expected "ascal:ascal|${domain}_reset_na"
    set regs [get_registers $expected]
    if {[get_collection_size $regs] != 1} {
        error "expected exactly one scaler $domain release register"
    }
    foreach_in_collection reg $regs {
        if {[get_register_info -name $reg] ne $expected} {
            error "unexpected scaler reset register identity"
        }
    }
    dict set releases $domain $regs
    post_message "Scaler reset inventory: $expected"
}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set prefix output_files/${revision}_scaler_reset_${model}_${temperature}
        dict for {domain regs} $releases {
            foreach check {recovery removal} {
                report_timing -$check -from $raw -to $regs -npaths 10000 -detail full_path -file ${prefix}_${domain}_input_${check}.rpt
                report_timing -$check -from $regs -npaths 10000 -detail full_path -file ${prefix}_${domain}_output_${check}.rpt
            }
        }
    }
}
delete_timing_netlist
project_close
