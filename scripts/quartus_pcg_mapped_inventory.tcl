# Reporting-only early-netlist inventory, no SDC loaded or exceptions added.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ne "sharpx1_turbo_z_video"} {error "expected experimental Z"}
project_open sharpx1 -revision $revision
create_timing_netlist -post_map
foreach {label patterns} {
    state {*x1_pcg_access:cg_bus|access_addr* *x1_pcg_access:cg_bus|response* *x1_pcg_access:cg_bus|seen *x1_pcg_access:cg_bus|stage*}
    ram {*x1_video_ram:pcg_*|*}
} {
    set collection [get_registers $patterns]
    puts "MAPPED $label: [get_collection_size $collection]"
    foreach_in_collection reg $collection {puts "  [get_register_info -name $reg]"}
}
delete_timing_netlist
project_close
