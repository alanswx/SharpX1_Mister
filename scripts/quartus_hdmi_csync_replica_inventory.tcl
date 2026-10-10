# Read-only fitted connectivity after the csync scalar/first-fanout guard stops.
# NO SDC/timing reports; discovery is not sequential equivalence or acceptance.
package require ::quartus::project
package require ::quartus::sta
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
set nodes [get_registers -no_duplicates {dv_csync*}]
if {[get_collection_size $nodes] < 7} {error "incomplete fitted csync inventory"}
foreach_in_collection reg $nodes {
    set name [get_register_info -name $reg]
    set single [get_registers -no_duplicates [list $name]]
    puts "CSYNC REPLICA REGISTER $name"
    foreach_in_collection node [get_fanins -synch $single] {
        puts "CSYNC REPLICA DATA FANIN $name <- [get_node_info -name $node] ([get_node_info -type $node])"
    }
    foreach_in_collection node [get_fanouts $single] {
        puts "CSYNC REPLICA COMBINED FANOUT $name -> [get_node_info -name $node] ([get_node_info -type $node])"
    }
}
puts "CSYNC REPLICA INVENTORY COMPLETE: no SDC, exceptions or timing acceptance"
delete_timing_netlist
project_close
