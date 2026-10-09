# Fitted routing inventory only; no SDC/case analysis/exceptions or timing pass.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1 || [lindex $quartus(args) 0] ne "sharpx1_turbo_z_video"} {
    error "expected experimental Z revision only"
}
project_open sharpx1 -revision sharpx1_turbo_z_video
create_timing_netlist -model slow -temperature 100 -voltage 1100
puts "HDMI mode inventory case-analysis commands: [info commands *case_analysis*]"
foreach bit {10 12} {
    set name "cfg\[$bit\]"
    set regs [get_registers [list $name]]
    if {![get_collection_size $regs]} {error "missing actual HDMI mode configuration register"}
    foreach_in_collection reg $regs {
        set physical_name [get_register_info -name $reg]
        set physical [get_registers -no_duplicates [list $physical_name]]
        if {[get_collection_size $physical] != 1} {error "ambiguous physical HDMI selector keeper"}
        puts "HDMI mode inventory selector $bit $physical_name"
        foreach_in_collection node [get_fanouts $physical] {
            puts "HDMI mode inventory selector fanout $physical_name [get_node_info -name $node] ([get_node_info -type $node])"
        }
    }
}
set pins [get_pins -compatibility_mode {hdmi_clk_sw|*}]
if {![get_collection_size $pins]} {error "missing actual HDMI clock mux pins"}
foreach_in_collection pin $pins {
    set name [get_pin_info -name $pin]
    puts "HDMI mode inventory clock-mux pin $name"
    if {[string first "clkselect" $name] >= 0} {
        set exact [get_pins -compatibility_mode [list $name]]
        if {[get_collection_size $exact] != 1} {error "ambiguous actual clock selector pin"}
        foreach_in_collection node [get_fanins $exact] {
            puts "HDMI mode inventory clock-select source $name [get_node_info -name $node] ([get_node_info -type $node])"
        }
    }
}
delete_timing_netlist
project_close
