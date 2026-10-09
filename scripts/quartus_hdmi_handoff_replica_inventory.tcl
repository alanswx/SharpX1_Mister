# Read-only connectivity discovery after a guarded SDC refuses a new replica.
# Deliberately NO read_sdc or report_timing: this is not timing qualification.
package require ::quartus::project
package require ::quartus::sta
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
set nodes [get_registers -no_duplicates {*hdmi_handoff|gate_request*}]
if {[get_collection_size $nodes] < 3} {error "missing gate-request connectivity"}
foreach_in_collection reg $nodes {
    set name [get_register_info -name $reg]
    set single [get_registers -no_duplicates [list $name]]
    puts "HANDOFF REPLICA REGISTER $name"
    foreach_in_collection node [get_fanins -synch $single] {
        puts "HANDOFF REPLICA DATA FANIN $name <- [get_node_info -name $node] ([get_node_info -type $node])"
    }
    foreach_in_collection node [get_fanouts $single] {
        puts "HANDOFF REPLICA COMBINED FANOUT $name -> [get_node_info -name $node] ([get_node_info -type $node])"
    }
}
puts "HANDOFF REPLICA INVENTORY COMPLETE: no SDC, exceptions or timing acceptance"
delete_timing_netlist
project_close
