# Completed-fit reconnaissance only: no SDC, clocks or exceptions loaded.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ne "sharpx1_turbo_z_video"} {error "expected experimental Z"}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
set regs [get_registers {*ascal*|*release_pipe*}]
puts "FITTED scaler release registers: [get_collection_size $regs]"
foreach_in_collection reg $regs {puts "  [get_register_info -name $reg]"}
set pins [get_pins -compatibility_mode {*ascal*|*release_pipe*|clrn}]
puts "FITTED scaler release async input pins: [get_collection_size $pins]"
foreach_in_collection pin $pins {puts "  [get_pin_info -name $pin]"}
delete_timing_netlist
project_close
