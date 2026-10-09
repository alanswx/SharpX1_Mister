# Read-only fitted held-mode discovery; adds NO timing exceptions.
# Reports all timing endpoints, not just already known output mux registers.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1} {error "expected NEW report directory"}
set destination [lindex $quartus(args) 0]
if {[file exists $destination]} {error "refusing to overwrite existing evidence"}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set prefix {x1_hdmi_clock_handoff:hdmi_handoff|}
foreach bit {0 1 2} {
    set name [format {%sactive_mode[%d]} $prefix $bit]
    set canonical [get_registers -no_duplicates [list $name]]
    if {[get_collection_size $canonical] != 1} {error "missing/ambiguous held mode $name"}
    foreach_in_collection reg $canonical {
        if {[get_register_info -name $reg] ne $name} {error "unexpected held-mode alias"}
    }
}
# Include physical replicas in discovery rather than silently dropping them.
set modes [get_registers -no_duplicates {*hdmi_handoff|active_mode*}]
if {[get_collection_size $modes] < 3} {error "incomplete held-mode inventory"}
puts [get_fanouts -long_help]
foreach_in_collection reg $modes {
    set name [get_register_info -name $reg]
    puts "HANDOFF MODE SOURCE $name"
    # Quartus 17 get_fanouts has no -synch/-clock options (unlike get_fanins).
    # Keep its combined clock/data reachability, explicitly labelled as such.
    set single [get_registers -no_duplicates [list $name]]
    foreach_in_collection node [get_fanouts $single] {
        puts "HANDOFF MODE COMBINED FANOUT $name -> [get_node_info -name $node] ([get_node_info -type $node])"
    }
}
file mkdir $destination
report_clocks -file [file join $destination clocks.rpt]
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        puts "HANDOFF MODE CORNER $model $temperature 1100"
        foreach check {setup hold} {
            report_timing -$check -from $modes -npaths 1000 -detail full_path \
                -file [file join $destination ${model}_${temperature}_${check}.rpt]
        }
    }
}
puts "HANDOFF MODE INVENTORY COMPLETE: discovery only; no new exceptions or acceptance"
delete_timing_netlist
project_close
