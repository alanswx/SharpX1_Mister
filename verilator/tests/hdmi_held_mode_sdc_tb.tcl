# Scope mock only: native before/after timing and hardware remain separate.
set candidate [file normalize [file join [file dirname [info script]] ../.. scripts constraints hdmi_held_mode_candidate.sdc]]
set prefix {x1_hdmi_clock_handoff:hdmi_handoff|}
set targets {hs vs de}
for {set bit 0} {$bit < 24} {incr bit} {lappend targets [format {d[%d]} $bit]}
set sources {}
foreach bit {0 1 2} {lappend sources [format {%sactive_mode[%d]} $prefix $bit]}
set inventory [concat $sources $targets]
set fault {}
proc get_registers {args} {
    if {[lindex $args 0] ne "-no_duplicates"} {
        if {$::fault eq "replica"} {return [concat $::inventory {{d[0]~DUPLICATE}}]}
        return $::inventory
    }
    set name [lindex [lindex $args end] 0]
    if {$name eq {d[23]}} {
        if {$::fault eq "missing"} {return {}}
        if {$::fault eq "duplicate"} {return [list $name $name]}
        if {$::fault eq "alias"} {return [list ${name}_substitute]}
    }
    return [list $name]
}
proc foreach_in_collection {variable collection body} {uplevel 1 [list foreach $variable $collection $body]}
proc get_collection_size {collection} {llength $collection}
proc get_register_info {option node} {return $node}
proc get_clocks {pattern} {
    if {$::fault eq "missing_clock"} {return {}}
    return $pattern
}
proc get_clock_info {option node} {
    if {$option eq "-name"} {
        if {$::fault eq "clock_alias"} {return wrong_clock}
        return $node
    }
    if {$::fault eq "clock_period"} {return 99}
    if {$node eq "x1_hdmi_handoff_mux"} {return 6.732}
    if {$node eq "x1_video_handoff_mux"} {return 23.280}
    return 31.250
}
proc get_fanins {args} {
    if {[lindex $args 0] ne "-synch"} {error "included clock cone in D-route check"}
    set name [lindex [lindex $args end] 0]
    set result [expr {$name eq "hs" ? $::sources : [list [lindex $::sources 0]]}]
    if {$name eq {d[23]}} {
        if {$::fault eq "missing_driver"} {return {}}
        if {$::fault eq "wrong_driver"} {return [list [lindex $::sources 1]]}
        if {$::fault eq "extra_driver"} {lappend result [lindex $::sources 2]}
    }
    return [concat $result private_pixel_data]
}
proc get_node_info {option node} {
    if {$option eq "-name"} {return $node}
    if {$::fault eq "nonreg_driver" && $node eq [lindex $::sources 0]} {return pin}
    return reg
}
proc set_max_delay {args} {lappend ::constraints [list max {*}$args]}
proc set_min_delay {args} {lappend ::constraints [list min {*}$args]}
proc source_local_candidate {candidate} {source $candidate}
proc load_candidate {context} {
    unset -nocomplain ::x1_mode_inventory
    switch $context {
        global {uplevel #0 [list source $::candidate]}
        procedure {source_local_candidate $::candidate}
        namespace {
            namespace eval x1_scope [list source $::candidate]
        }
        default {error "unknown mock load context"}
    }
}
set mock_expected_constraints {}
foreach target $targets {
    set bits [expr {$target eq "hs" ? {0 1 2} : {0}}]
    foreach bit $bits {
        lappend mock_expected_constraints [list max -from [list [lindex $sources $bit]] -to [list $target] 31.25]
        lappend mock_expected_constraints [list min -from [list [lindex $sources $bit]] -to [list $target] -31.25]
    }
}
foreach context {global procedure namespace} {
    foreach fault {missing duplicate alias replica missing_clock clock_alias clock_period missing_driver wrong_driver extra_driver nonreg_driver} {
        set constraints {}
        if {![catch {load_candidate $context} problem]} {error "invalid scope accepted: $context $fault"}
        if {[llength $constraints]} {error "partial constraints applied: $context $fault"}
    }
    set fault {}
    set constraints {}
    load_candidate $context
    if {$constraints ne $mock_expected_constraints} {error "candidate changed scope or delay bounds: $context"}
}
namespace delete x1_scope
puts "PASS: held-mux candidate: 29 exact pairs and eleven rejecting scope/clock/route controls at global/procedure/namespace loads"
