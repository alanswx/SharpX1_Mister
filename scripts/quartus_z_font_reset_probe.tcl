# Completed external-font fit only. Probe changes constraints in memory;
# integrated mode reads only assigned SDCs. Always operate on a private copy.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] ni {2 3}} {error "expected NEW report directory, explicit reset SDC, optional integrated"}
set destination [lindex $quartus(args) 0]
set candidate [file normalize [lindex $quartus(args) 1]]
set integrated [expr {[llength $quartus(args)] == 3}]
if {$integrated && [lindex $quartus(args) 2] ne "integrated"} {error "unknown mode"}
if {[file exists $destination] || ![file isfile $candidate]} {error "existing evidence or missing candidate"}
set f [open output_files/sharpx1_turbo_z_font.fit.summary r]
set summary [read $f]
close $f
if {![regexp -line {^Fitter Status : Successful( |$)} $summary]} {error "completed successful fit required"}
project_open sharpx1 -revision sharpx1_turbo_z_font
set assigned 0
foreach_in_collection assignment [get_all_global_assignments -name SDC_FILE] {
    if {[file tail [lindex $assignment 2]] eq "sharpx1_turbo_z_font_reset.sdc"} {
        incr assigned
        if {[file normalize [lindex $assignment 2]] ne $candidate} {error "assigned reset SDC differs"}
    }
}
if {$assigned != $integrated} {error "reset SDC assignment disagrees with probe/integrated mode"}
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
file mkdir $destination
set inventory [open [file join $destination inventory.txt] w]
set pipes [get_registers {*x1_reset_release:*|release_pipe*}]
set pins [get_pins -compatibility_mode {*|video_reset_domain.release_reset|release_pipe*|clrn}]
foreach {kind collection} [list register $pipes pin $pins] {
    puts $inventory "$kind [get_collection_size $collection]"
    foreach_in_collection node $collection {puts $inventory "  [get_node_info -name $node]"}
}
foreach_in_collection reg $pipes {
    set name [get_register_info -name $reg]
    foreach direction {fanins fanouts} {
        if {$direction eq "fanins"} {
            set nodes [get_fanins -synch [list $name]]
        } else {
            # Quartus 17 fanout traversal ends at registers without -synch;
            # that option belongs only to get_fanins in this tool version.
            set nodes [get_fanouts [list $name]]
        }
        foreach_in_collection node $nodes {
            puts $inventory "$direction $name [get_node_info -name $node] ([get_node_info -type $node])"
        }
    }
}
close $inventory
set expected {}
foreach bit {0 1} {
    lappend expected [format {emu:emu|sharpx1:sharpx1|x1_reset_release:video_reset_domain.release_reset|release_pipe[%d]} $bit]
}
set actual {}
foreach_in_collection reg $pipes {lappend actual [get_register_info -name $reg]}
if {[lsort $actual] ne [lsort $expected]} {error "unexpected fitted reset register inventory"}
report_clocks -file [file join $destination clocks.rpt]
set phases [expr {$integrated ? [list integrated] : [list before after]}]
foreach phase $phases {
    if {$phase eq "after"} {source $candidate}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            set_operating_conditions -model $model -temperature $temperature -voltage 1100
            update_timing_netlist
            puts "FONT RESET CORNER $phase $model $temperature 1100"
            set prefix ${phase}_${model}_${temperature}
            foreach check {setup hold} {
                report_timing -$check -from $pipes -to $pipes -npaths 10000 -detail full_path \
                    -file [file join $destination ${prefix}_chain_${check}.rpt]
            }
            foreach check {recovery removal} {
                report_timing -$check -to $pins -npaths 10000 -detail full_path \
                    -file [file join $destination ${prefix}_raw_${check}.rpt]
                report_timing -$check -from $pipes -npaths 10000 -detail full_path \
                    -file [file join $destination ${prefix}_output_${check}.rpt]
            }
            foreach check {setup hold recovery removal} {
                report_timing -$check -npaths 30 -detail full_path \
                    -file [file join $destination ${prefix}_global_${check}.rpt]
            }
        }
    }
}
puts "FONT RESET REPORT COMPLETE: raw asynchronous inputs are not physical acceptance"
delete_timing_netlist
project_close -dont_export_assignments
