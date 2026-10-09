# Reporting-only completed-fitter inventory; deliberately does not read SDC.
# Useful when a strict final-STA endpoint gate has rejected new duplicates.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ne "sharpx1_turbo_z_video"} {error "expected experimental Z"}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
foreach field {response cpu_q stage frozen_addr font_cpu_addr} {
    set regs [get_registers "*x1_pcg_access:cg_bus|${field}*"]
    puts "FITTED $field: [get_collection_size $regs]"
    foreach_in_collection reg $regs {puts "  [get_register_info -name $reg]"}
}
foreach candidate [lrange $quartus(args) 1 end] {
    # Inventory and exception syntax only: no clock/physical timing claim.
    source $candidate
}
delete_timing_netlist
project_close
