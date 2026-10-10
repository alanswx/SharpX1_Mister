# Mock scope/report enumeration only, not native Quartus or timing acceptance.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[llength $argv] != 1} {error "expected caller-owned temporary directory"}
set report_dir [file join [file normalize [lindex $argv 0]] csync_reports]
set calls {}
set broken {}
set quartus(args) [list $report_dir]
rename package original_package
proc package {args} {return {}}
proc project_open {args} {
    if {$args ne {sharpx1 -revision sharpx1_turbo_z_handoff}} {error "wrong revision"}
}
foreach command {project_close create_timing_netlist read_sdc update_timing_netlist delete_timing_netlist set_operating_conditions} {
    proc $command {args} {}
}
proc get_registers {args} {
    global broken
    set name [lindex [lindex $args end] 0]
    if {[lindex $args 0] ne {-no_duplicates}} {
        if {$broken eq "replica" && $name eq "dv_epoch_meta*"} {return {dv_epoch_meta~DUPLICATE}}
        return {}
    }
    if {$name eq "dv_epoch_meta"} {
        if {$broken eq "missing"} {return {}}
        if {$broken eq "duplicate"} {return [list $name $name]}
        if {$broken eq "alias"} {return {dv_epoch_meta_BAD}}
    }
    return [list $name]
}
proc get_collection_size {collection} {llength $collection}
proc foreach_in_collection {variable collection body} {
    foreach item $collection {uplevel 1 [list set $variable $item]; uplevel 1 $body}
}
proc get_register_info {option name} {return $name}
proc get_node_info {option name} {
    if {$option eq "-name"} {return $name}
    return reg
}
proc get_fanouts {collection} {
    global broken
    set name [lindex $collection 0]
    if {$broken eq "fanout" && $name eq "dv_epoch_meta"} {return {dv_epoch_sample EXTRA}}
    set second [dict create dv_epoch_meta dv_epoch_sample dv_csync_meta dv_csync_sample \
        dv_policy_meta dv_policy_sample dv_csync_echo_meta dv_csync_echo_sample]
    if {[dict exists $second $name]} {return [list [dict get $second $name]]}
    return {}
}
proc get_fanins {args} {
    global broken
    if {[lindex $args 0] ne "-synch"} {error "wrong data-edge driver query"}
    set target [lindex [lindex $args end] 0]
    if {$broken eq "driver" && $target eq "dv_epoch_meta"} {return {WRONG_SOURCE}}
    return [list [dict get [dict create \
        dv_epoch_meta {x1_hdmi_clock_handoff:hdmi_handoff|video_policy_epoch} \
        dv_csync_meta {x1_hdmi_clock_handoff:hdmi_handoff|active_mode[2]} \
        dv_policy_meta dv_policy_completed dv_csync_echo_meta dv_csync_completed] $target]]
}
proc report_clocks {args} {global calls; lappend calls [list clocks $args]}
proc report_timing {args} {global calls; lappend calls [list timing $args]}
proc expect {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
set reporter [file join $root scripts quartus_hdmi_csync_inventory.tcl]
foreach broken {missing duplicate alias replica fanout driver} {
    expect {[catch {source $reporter} problem]} "invalid csync inventory accepted: $broken"
    expect {[llength $calls] == 0 && ![file exists $report_dir]} "partial report scope leaked: $broken"
}
set broken {}
source $reporter
expect {[llength $calls] == 321} "wrong eight-corner report enumeration"
set expected {}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        foreach check {setup hold} {
            foreach kind {epoch_stage csync_stage epoch_capture csync_capture native_capture epoch_pipe1 epoch_pipe2 csync_pipe1 csync_pipe2 epoch_return csync_return native_pipe1 native_pipe2 epoch_input csync_input epoch_echo_input csync_echo_input epoch_consumer csync_consumer global} {
                lappend expected [file join $report_dir ${model}_${temperature}_${kind}_${check}.rpt]
            }
        }
    }
}
set observed {}
foreach call [lrange $calls 1 end] {
    set arguments [lindex $call 1]
    set index [lsearch -exact $arguments -file]
    expect {$index >= 0} "missing report destination"
    lappend observed [lindex $arguments [expr {$index+1}]]
}
expect {$observed eq $expected} "missing/repeated/out-of-order csync reports"
set before $calls
expect {[catch {source $reporter} problem]} "existing evidence accepted"
expect {$calls eq $before} "existing evidence overwritten"
file delete $report_dir
rename package {}
rename original_package package
puts "PASS: csync inventory mock: 320 ordered reports; six invalid scalar/replica/fanout/driver controls and overwrite reject"
