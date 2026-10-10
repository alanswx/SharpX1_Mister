# Exact-scope mock, not native timing/placement acceptance.
set root [file normalize [file join [file dirname [info script]] ../..]]
set candidate [file join $root scripts constraints hdmi_csync_input_candidate.sdc]
set triples {
    {x1_hdmi_clock_handoff:hdmi_handoff|video_policy_epoch} dv_epoch_meta dv_epoch_sample
    {x1_hdmi_clock_handoff:hdmi_handoff|active_mode[2]} dv_csync_meta dv_csync_sample
    dv_policy_completed dv_policy_meta dv_policy_sample
    dv_csync_completed dv_csync_echo_meta dv_csync_echo_sample
}
set base {}
foreach {source first second} $triples {
    lappend base $source $first $second
    set drivers($first) $source;set consumers($first) $second
}
set fault {};set fault_leaf {}
proc get_registers {args} {
    if {[lindex $args 0] ne "-no_duplicates"} {
        if {$::fault eq "replica"} {return [concat $::base [list "$::fault_leaf~DUPLICATE"]]}
        return $::base
    }
    set name [lindex [lindex $args end] 0]
    if {$name eq $::fault_leaf} {
        switch $::fault {
            missing {return {}}
            ambiguous {return [list $name $name]}
            alias {return [list "${name}_substitute"]}
        }
    }
    return [list $name]
}
proc get_collection_size collection {return [llength $collection]}
proc foreach_in_collection {var collection body} {uplevel 1 [list foreach $var $collection $body]}
proc get_register_info {option reg} {return $reg}
proc get_node_info {option node} {
    if {$option eq "-name"} {return $node}
    if {$node eq "clock_pin"} {return pin}
    return reg
}
proc get_fanins {args} {
    if {[lindex $args 0] ne "-synch"} {error "driver query included clock-select edges"}
    set name [lindex [lindex $args end] 0]
    set result [list clock_pin $::drivers($name)]
    if {$name eq $::fault_leaf} {
        if {$::fault eq "wrong_driver"} {return {clock_pin wrong_source}}
        if {$::fault eq "extra_driver"} {lappend result extra_source}
    }
    return $result
}
proc get_fanouts collection {
    set name [lindex $collection 0]
    set result [list $::consumers($name)]
    if {$name eq $::fault_leaf} {
        switch $::fault {
            wrong_consumer {return {wrong_target}}
            extra_consumer {lappend result extra_target}
            no_consumer {return {}}
        }
    }
    return $result
}
proc set_false_path args {lappend ::cuts $args}
set rejected 0
foreach {source first second} $triples {
    foreach fault {missing ambiguous alias replica wrong_driver extra_driver wrong_consumer extra_consumer no_consumer} {
        set fault_leaf $first;set cuts {}
        if {![catch {source $candidate} message] || [llength $cuts]} {error "invalid $first/$fault allowed partial exclusions"}
        incr rejected
    }
    foreach fault_leaf [list $source $second] {
        set fault replica;set cuts {}
        if {![catch {source $candidate} message] || [llength $cuts]} {error "source/second replica accepted: $fault_leaf"}
        incr rejected
    }
}
set fault {};set cuts {}
source $candidate
set expected {}
foreach {from first second} $triples {lappend expected [list -from [list $from] -to [list $first]]}
if {$cuts ne $expected} {error "not exactly four source-to-first-stage proposals"}
foreach project [glob [file join $root *.qsf]] {
    set stream [open $project r];set text [read $stream];close $stream
    if {[string first hdmi_csync_input_candidate.sdc $text] >= 0} {error "analysis candidate selected by $project"}
}
puts "PASS: four exact unselected csync first-stage proposals; $rejected invalid scopes refuse all cuts (mocked)"
