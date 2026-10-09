# Native structural inventory only. Optional candidate syntax/scope validation
# does not imply timing acceptance, especially in the no-clock post-map view.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
set view [lindex $quartus(args) 1]
set candidate [lindex $quartus(args) 2]
if {$revision ne "sharpx1_turbo_z_video" || $view ni {mapped fitted}} {error "expected experimental Z and mapped/fitted view"}
if {$view eq "mapped"} {
    # Quartus otherwise warns and silently substitutes the fitted netlist.
    foreach suffix {fit.rpt fit.summary sof} {
        if {[file exists output_files/${revision}.${suffix}]} {error "mapped inventory requires a fresh unfitted tree; found $suffix"}
    }
}
project_open sharpx1 -revision $revision
if {$view eq "mapped"} {
    create_timing_netlist -post_map
} else {
    create_timing_netlist -model slow -temperature 100 -voltage 1100
}
set regs [get_registers {*hdmi_vsync_to_sys*|sample_pipe*}]
puts "VSYNC $view register count [get_collection_size $regs]"
foreach_in_collection reg $regs {
    set name [get_register_info -name $reg]
    puts "VSYNC $view register $name"
    set fanouts [get_fanouts [list $name]]
    foreach_in_collection fanout $fanouts {puts "VSYNC $view fanout $name -> [get_node_info -name $fanout] ([get_node_info -type $fanout])"}
}
set pins [get_pins -compatibility_mode {*hdmi_vsync_to_sys*|sample_pipe*|*}]
puts "VSYNC $view pin count [get_collection_size $pins]"
foreach_in_collection pin $pins {
    set name [get_pin_info -name $pin]
    puts "VSYNC $view pin $name"
    if {[regexp {\|sample_pipe\[0\]\|(d|asdata)$} $name]} {
        set fanins [get_fanins [list $name]]
        foreach_in_collection fanin $fanins {puts "VSYNC $view data fanin [get_node_info -name $fanin] ([get_node_info -type $fanin])"}
    }
}
if {$candidate ne ""} {source $candidate}
delete_timing_netlist
project_close
