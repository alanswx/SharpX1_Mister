# Reporting-only mapped/fitted discovery. No SDC, clock assumptions or exceptions.
# Run against an idle, preserved handoff synthesis database, including one
# whose fitter rejected source-bound D/ASDATA guards. This is not STA acceptance.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 2 || [lindex $quartus(args) 0] ne "sharpx1_turbo_z_handoff" ||
    [lindex $quartus(args) 1] ni {mapped fitted}} {error "expected handoff revision and mapped/fitted discovery stage"}
set stage [lindex $quartus(args) 1]
set summary_path output_files/sharpx1_turbo_z_handoff.fit.summary
set fitter_status {}
if {[file exists $summary_path]} {
    set summary_file [open $summary_path r]
    set summary [read $summary_file]
    close $summary_file
    if {![regexp -line {^Fitter Status : (Successful|Failed)( |$)} $summary -> fitter_status]} {
        error "unrecognized fitter summary; refusing ambiguous netlist stage"
    }
}
if {$stage eq "mapped" && $fitter_status eq "Successful"} {
    error "mapped discovery refuses a completed fit: Quartus can ignore -post_map"
}
if {$stage eq "fitted" && $fitter_status ne "Successful"} {
    error "fitted discovery requires successful fitter summary"
}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
if {$stage eq "mapped"} {create_timing_netlist -post_map} else {create_timing_netlist}
puts "HDMI DATA DISCOVERY REQUESTED STAGE $stage; reject any ignored-option warning"
set registers [get_registers -no_duplicates {hdmi_dv* d* hs* vs* de*}]
set pins [get_pins -compatibility_mode {hdmi_dv*|* d*|* hs*|* vs*|* de*|*}]
set count 0
foreach_in_collection register $registers {
    set name [get_register_info -name $register]
    if {![regexp {^(hdmi_dv_(hs|vs|de|data\[[0-9]+\])|hs|vs|de|d\[[0-9]+\])(~.*|_Duplicate_.*)?$} $name]} {
        continue
    }
    incr count
    puts "HDMI DATA TARGET $name"
    foreach_in_collection node [get_fanins -synch [list $name]] {
        puts "HDMI DATA DRIVER $name [get_node_info -name $node] ([get_node_info -type $node])"
    }
    foreach_in_collection pin $pins {
        set actual [get_pin_info -name $pin]
        if {[string first "${name}|" $actual] == 0} {
            puts "HDMI DATA PIN $name $actual"
        }
    }
}
if {!$count} {error "no mapped output/prefetch keepers found"}
puts "HDMI DATA INVENTORY COMPLETE: $count keepers; no SDC loaded, no cuts or timing acceptance"
delete_timing_netlist
project_close
