# Reporting-only PCG endpoint/path inventory. No new timing exceptions.
# Run only on a completed, idle independent-X3 fit; reports include the
# original project constraints and intentionally leave violations visible.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ni {sharpx1_turbo_video sharpx1_turbo_z_video}} {
    error "expected an independent X3 video revision"
}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set prefix output_files/${revision}_pcg_inventory
foreach field {request request_meta request_sync ack ack_meta ack_sync plane
               write_request payload high_speed_request frozen_addr response
               font_cpu_addr access_addr stage cpu_q} {
    set collection [get_registers "*x1_pcg_access:cg_bus|${field}*"]
    puts "PCG prefix $field: [get_collection_size $collection] fitted registers (prefix matches listed below)"
    foreach_in_collection reg $collection {
        puts "  [get_register_info -name $reg]"
    }
    if {[get_collection_size $collection] == 0} {
        error "missing PCG field $field; review fitted scope before using reports"
    }
}
# Response is held in VID until the next transaction. The CPU's ACK
# synchronizers gate cpu_q capture. This is not the font's SYS-only path.
set response [get_registers {*x1_pcg_access:cg_bus|response*}]
set cpu_q [get_registers {*x1_pcg_access:cg_bus|cpu_q*}]
# Request registers feed address capture, response selection, and actual RAM
# write/data pins. Do not assume the cg_bus hierarchy contains all endpoints.
set request_fields [get_registers {*x1_pcg_access:cg_bus|plane* *x1_pcg_access:cg_bus|write_request* *x1_pcg_access:cg_bus|payload* *x1_pcg_access:cg_bus|high_speed_request* *x1_pcg_access:cg_bus|frozen_addr* *x1_pcg_access:cg_bus|font_cpu_addr*}]
puts "Retained request-group registers: [get_collection_size $request_fields]"
# This is inventory, not an exception: optimization may merge some request
# bits with other state. Do not claim complete request coverage from a prefix
# search; resolve missing/merged bits before any production constraint.
# This source-bound map report merges frozen_addr[4..10] into
# font_cpu_addr[5..11]. Include the entire font bank for reporting, including
# its CPU-only paths; never turn this broad source group into an exception.
if {[get_collection_size $response] != 8 || [get_collection_size $cpu_q] != 8} {
    error "expected exactly 8 response and 8 cpu_q registers"
}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set corner ${prefix}_${model}_${temperature}
        foreach check {setup hold} {
            report_timing -$check -from $response -to $cpu_q -npaths 100 -detail full_path -file ${corner}_response_${check}.rpt
            report_timing -$check -from $request_fields -npaths 100 -detail full_path -file ${corner}_request_${check}.rpt
        }
    }
}
delete_timing_netlist
project_close
