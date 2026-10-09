# Mock scope/guard coverage only; not native timing evidence.
set tool [file normalize [file join [file dirname [info script]] .. .. scripts quartus_vsync_sys_paths.tcl]]
package provide ::quartus::project 1
package provide ::quartus::sta 1
foreach name {project_open create_timing_netlist read_sdc update_timing_netlist post_message delete_timing_netlist project_close} {proc $name args {}}
set names [list {x1_vsync_sys:hdmi_vsync_to_sys|sample_pipe[0]} {x1_vsync_sys:hdmi_vsync_to_sys|sample_pipe[1]}]
proc get_registers {query} {
    if {[string first "*" $query]<0} {
        if {$::mode eq "lookup_missing"} {return {}}
        if {$::mode eq "lookup_duplicate"} {return [concat $query $query]}
        return $query
    }
    if {$query ne "*hdmi_vsync_to_sys*|sample_pipe*"} {error "unexpected query"}
    set result $::names
    switch $::mode {
        missing {set result [lrange $result 0 0]}
        extra {lappend result [lindex $result 0]}
        duplicate {lset result 1 [lindex $result 0]}
        wrong_bit {lset result 1 [string map {{[1]} {[2]}} [lindex $result 1]]}
        replica {lset result 1 "[lindex $result 1]~DUPLICATE"}
    }
    return $result
}
proc get_collection_size {regs} {llength $regs}
proc get_register_info {option reg} {return $reg}
proc foreach_in_collection {var regs body} {uplevel 1 [list foreach $var $regs $body]}
proc set_operating_conditions args {lappend ::corners $args}
proc report_timing args {
    set file [lindex $args [expr {[lsearch -exact $args -file]+1}]]
    if {[dict exists $::reports $file]} {error "duplicate report"}
    dict set ::reports $file $args
}
foreach name {set_false_path set_clock_groups set_max_delay set_min_delay set_multicycle_path} {proc $name args {error "no exceptions allowed"}}
proc run_tool {} {global quartus tool; source $tool}
foreach mode {valid missing extra duplicate wrong_bit replica lookup_missing lookup_duplicate wrong_revision} {
    set quartus(args) sharpx1_turbo_z_video
    if {$mode eq "wrong_revision"} {set quartus(args) sharpx1}
    set corners {}; set reports {}
    set failed [catch {run_tool} message]
    if {$mode ne "valid"} {
        if {!$failed || [dict size $reports] || [llength $corners]} {error "$mode accepted invalid inventory"}
        continue
    }
    if {$failed} {error $message}
    if {[dict size $reports]!=64 || [llength $corners]!=8} {error "wrong coverage"}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            foreach kind {input chain first_fanout consumer} {
                foreach check {setup hold} {
                    set file output_files/sharpx1_turbo_z_video_vsync_sys_${model}_${temperature}_${kind}_${check}.rpt
                    if {![dict exists $reports $file]} {error "missing report"}
                    set args [dict get $reports $file]
                    if {[lindex $args 0] ne "-$check"} {error "wrong check"}
                    set fi [lsearch -exact $args -from]; set ti [lsearch -exact $args -to]
                    set from [lindex $args [expr {$fi+1}]]; set to [lindex $args [expr {$ti+1}]]
                    set first [list [lindex $names 0]]; set last [list [lindex $names 1]]
                    switch $kind {
                        input {if {$fi>=0 || $to ne $first} {error "wrong input scope"}}
                        chain {if {$from ne $first || $to ne $last} {error "wrong chain scope"}}
                        first_fanout {if {$from ne $first || $ti>=0} {error "wrong first fanout scope"}}
                        consumer {if {$from ne $last || $ti>=0} {error "wrong consumer scope"}}
                    }
                    if {[lindex $args [expr {[lsearch -exact $args -npaths]+1}]]!=10000} {error "wrong cap"}
                }
            }
        }
    }
}
puts "PASS: VSYNC reporter 64 scopes/eight corners; eight invalid inventories reject (mock only)"
