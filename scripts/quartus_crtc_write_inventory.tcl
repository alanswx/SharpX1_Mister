# Fitted inventory only. No SDC, clock/timing claims, or exceptions.
# Run on a completed idle Z fit to review aliases rejected by the strict probe.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1 || [lindex $quartus(args) 0] ne "sharpx1_turbo_z_video"} {
    error "expected experimental Z revision only"
}
project_open sharpx1 -revision [lindex $quartus(args) 0]
create_timing_netlist -model slow -temperature 100 -voltage 1100
foreach {label patterns} {
    transport {*x3_crtc.writes*|*}
    mpu {*display*|crtc6845s*|mpu_if*|*}
} {
    set regs [get_registers $patterns]
    if {![get_collection_size $regs]} {error "missing CRTC $label inventory"}
    puts "CRTC fitted $label count [get_collection_size $regs]"
    foreach_in_collection reg $regs {
        set name [get_register_info -name $reg]
        puts "CRTC fitted $label register $name"
        foreach {direction command} {fanin get_fanins fanout get_fanouts} {
            set nodes {}
            foreach_in_collection node [$command [list $name]] {
                lappend nodes [list [get_node_info -name $node] [get_node_info -type $node]]
            }
            puts "CRTC fitted $label $direction $name $nodes"
        }
    }
}
foreach_in_collection pin [get_pins -compatibility_mode {*x3_crtc.writes*|*}] {
    set name [get_pin_info -name $pin]
    puts "CRTC fitted pin $name"
    if {[regexp {\|(request_meta|acknowledgement_meta)\|(d|asdata)$} $name]} {
        foreach_in_collection node [get_fanins [list $name]] {
            puts "CRTC fitted first-data fanin $name [get_node_info -name $node] ([get_node_info -type $node])"
        }
    }
}
delete_timing_netlist
project_close
