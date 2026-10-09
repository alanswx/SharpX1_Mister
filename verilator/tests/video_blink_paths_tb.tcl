# Mock reporting coverage only; no native timing or physical claims.
set tool [file normalize [file join [file dirname [info script]] .. .. scripts quartus_video_blink_paths.tcl]]
package provide ::quartus::project 1
package provide ::quartus::sta 1
foreach name {project_open create_timing_netlist read_sdc update_timing_netlist post_message delete_timing_netlist project_close} {proc $name args {}}
set names [list {emu:emu|sharpx1:sharpx1|x1_video_blink:x3_blink.video_blink|crossing.sample_pipe[0]} {emu:emu|sharpx1:sharpx1|x1_video_blink:x3_blink.video_blink|crossing.sample_pipe[1]}]
proc get_registers {query} {
    if {[string first "*" $query]<0} {
        if {$::mode eq "lookup_missing"} {return {}}
        if {$::mode eq "lookup_duplicate"} {return [concat $query $query]}
        return $query
    }
    if {$query ne "*x3_blink.video_blink*|*sample_pipe*"} {error "unexpected query"}
    set result $::names
    switch $::mode {
        missing {set result [lrange $result 0 0]}
        extra {lappend result [lindex $result 0]}
        duplicate {lset result 1 [lindex $result 0]}
        wrong_bit {lset result 1 [string map {{[1]} {[2]}} [lindex $result 1]]}
        wrong_pair {lset result 1 [string map {video_blink: other:} [lindex $result 1]]}
        replica {lset result 1 "[lindex $result 1]~DUPLICATE"}
    }
    return $result
}
proc get_collection_size regs {llength $regs}
proc get_register_info {option reg} {return $reg}
proc get_fanouts query {
    if {$query eq [list [lindex $::names 0]]} {
        switch $::mode {
            fanout_missing {return {}}
            fanout_extra {return [list [lindex $::names 1] consumer_a]}
            fanout_wrong {return consumer_a}
        }
        return [list [lindex $::names 1]]
    }
    if {$query eq [list [lindex $::names 1]]} {
        if {$::mode eq "consumer_missing"} {return {}}
        if {$::mode eq "consumer_duplicate"} {return {consumer_a consumer_a}}
        return {consumer_a consumer_b}
    }
    error "unexpected fanout source"
}
proc get_node_info {option node} {
    if {$option eq "-name"} {return $node}
    if {$::mode eq "fanout_nonreg"} {return pin}
    return reg
}
proc get_pins args {return [list {video_blink|crossing.sample_pipe[0]|d} {video_blink|crossing.sample_pipe[1]|asdata}]}
proc get_pin_info {option pin} {return $pin}
proc get_fanins args {incr ::data_observations; return source_blink}
proc foreach_in_collection {var regs body} {uplevel 1 [list foreach $var $regs $body]}
proc set_operating_conditions args {lappend ::corners $args}
proc report_timing args {
    set file [lindex $args [expr {[lsearch -exact $args -file]+1}]]
    if {[dict exists $::reports $file]} {error "duplicate report"}
    dict set ::reports $file $args
}
foreach name {set_false_path set_clock_groups set_max_delay set_min_delay set_multicycle_path} {proc $name args {error "no exceptions allowed"}}
proc run_tool {} {global quartus tool; source $tool}
foreach mode {valid missing extra duplicate wrong_bit wrong_pair replica lookup_missing lookup_duplicate wrong_revision extra_arg fanout_missing fanout_extra fanout_wrong consumer_missing consumer_duplicate fanout_nonreg} {
    set quartus(args) sharpx1_turbo_z_video
    if {$mode eq "wrong_revision"} {set quartus(args) sharpx1}
    if {$mode eq "extra_arg"} {lappend quartus(args) candidate.sdc}
    set corners {}; set reports {}; set data_observations 0
    set failed [catch {run_tool} message]
    if {$mode ne "valid"} {
        if {!$failed || [dict size $reports] || [llength $corners]} {error "$mode accepted invalid inventory"}
        continue
    }
    if {$failed} {error $message}
    if {[dict size $reports]!=64 || [llength $corners]!=8 || $data_observations!=1} {error "wrong coverage"}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            foreach kind {input chain first_fanout consumer} {
                foreach check {setup hold} {
                    set file output_files/sharpx1_turbo_z_video_video_blink_${model}_${temperature}_${kind}_${check}.rpt
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
puts "PASS: video blink reporter 64 scopes/eight corners, sixteen rejected inventories; no new exceptions (mock only)"
