# Read-only discovery after an exact-input guard fails; no exceptions/reports.
package require ::quartus::project
package require ::quartus::sta
puts [get_fanins -long_help]
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
foreach first {gate_request_meta blank_meta generation_meta ack_meta completed_meta gate_meta} {
    set collection [get_registers -no_duplicates [list "x1_hdmi_clock_handoff:hdmi_handoff|$first"]]
    if {[get_collection_size $collection] != 1} {error "missing exact scalar $first"}
    foreach_in_collection node [get_fanins $collection] {
        puts "HANDOFF INPUT IMMEDIATE FANIN $first [get_node_info -name $node] ([get_node_info -type $node])"
    }
    foreach_in_collection node [get_fanins -synch $collection] {
        puts "HANDOFF INPUT DATA FANIN $first [get_node_info -name $node] ([get_node_info -type $node])"
    }
}
delete_timing_netlist
project_close
