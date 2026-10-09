# Mock scope/reporting checks only. Does not run native Quartus or prove timing.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[llength $argv] != 1} {error "expected caller-owned temporary directory"}
set report_dir [file join [file normalize [lindex $argv 0]] handoff_reports]
set calls {}
set broken {}
set quartus(args) [list $report_dir]
rename package original_package
proc package {args} {return {}}
proc project_open {args} {
    if {$args ne {sharpx1 -revision sharpx1_turbo_z_handoff}} {error "wrong board revision"}
}
foreach command {project_close create_timing_netlist read_sdc update_timing_netlist delete_timing_netlist set_operating_conditions} {
    proc $command {args} {}
}
proc get_registers {args} {
    global broken
    if {[lindex $args 0] ne {-no_duplicates}} {return {}}
    set name [lindex [lindex $args end] 0]
    if {[string match "*|$broken" $name]} {
        if {$broken eq "ack_meta"} {return {}}
        if {$broken eq "blank_sample"} {return [list $name $name]}
        if {$broken eq "completed_meta"} {return [list ${name}_wrong_alias]}
    }
    return [list $name]
}
proc get_collection_size {collection} {llength $collection}
proc foreach_in_collection {variable collection body} {
    foreach item $collection {
        uplevel 1 [list set $variable $item]
        uplevel 1 $body
    }
}
proc get_register_info {option name} {return $name}
proc get_fanouts {collection} {return {}}
proc report_clocks {args} {global calls; lappend calls [list clocks $args]}
proc report_timing {args} {global calls; lappend calls [list timing $args]}
proc expect {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set reporter [file join $root scripts quartus_hdmi_handoff_board_inventory.tcl]
# Missing, duplicated, and substituted exact physical registers must fail
# before a report directory or any partial timing evidence is produced.
foreach broken {ack_meta blank_sample completed_meta} {
    expect {[catch {source $reporter} problem]} "invalid inventory accepted"
    expect {[llength $calls] == 0 && ![file exists $report_dir]} "partial report scope leaked"
}
set broken {}
source $reporter
expect {[llength $calls] == 145} "wrong eight-corner report enumeration"
set expected {}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        foreach check {setup hold} {
            foreach kind {enable ack completed gate_status blank generation witness native_gate global} {
                lappend expected [file join $report_dir ${model}_${temperature}_${kind}_${check}.rpt]
            }
        }
    }
}
set observed {}
foreach call [lrange $calls 1 end] {
    set arguments [lindex $call 1]
    set index [lsearch -exact $arguments -file]
    expect {$index >= 0} "report missing explicit evidence destination"
    lappend observed [lindex $arguments [expr {$index+1}]]
}
expect {$observed eq $expected} "missing/repeated/out-of-order corner/pair reports"
set before $calls
expect {[catch {source $reporter} problem]} "existing evidence destination accepted"
expect {$calls eq $before} "existing evidence overwritten"
file delete $report_dir
rename package {}
rename original_package package
puts "PASS: full-board inventory mock: 144 ordered corner/pair reports; missing/duplicate/alias/overwrite controls reject"
