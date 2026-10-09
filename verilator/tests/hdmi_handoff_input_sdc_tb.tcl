# Exact-scope mock only; native before/after fitting and timing are separate.
set candidate [file normalize [file join [file dirname [info script]] ../.. scripts constraints hdmi_handoff_input_candidate.sdc]]
set prefix {x1_hdmi_clock_handoff:hdmi_handoff|}
set triples {
    gate_request gate_request_meta gate_request_sample
    blank_request blank_meta blank_sample
    generation generation_meta generation_sample
    blank_ack ack_meta ack_sample
    completed_generation completed_meta completed_sample
    gate_observed_enable gate_meta gate_sample
}
set base {}
foreach {from first second} $triples {
    foreach leaf [list $from $first $second] {lappend base "$prefix$leaf"}
    set drivers($prefix$first) "$prefix$from"
    set consumers($prefix$first) "$prefix$second"
}
set base [lsort -unique $base]
set fault {}
proc get_registers {args} {
    global fault base prefix
    if {[lindex $args 0] ne {-no_duplicates}} {
        if {$fault eq "replica"} {return [concat $base [list "${prefix}ack_meta~DUPLICATE"]]}
        return $base
    }
    set name [lindex [lindex $args end] 0]
    if {$name eq "${prefix}completed_meta"} {
        if {$fault eq "missing"} {return {}}
        if {$fault eq "ambiguous"} {return [list $name $name]}
        if {$fault eq "alias"} {return [list ${name}_substitute]}
    }
    return [list $name]
}
proc get_collection_size {collection} {llength $collection}
proc foreach_in_collection {variable collection body} {
    uplevel 1 [list foreach $variable $collection $body]
}
proc get_register_info {option node} {return $node}
proc get_node_info {option node} {
    if {$option eq "-name"} {return $node}
    if {$node eq "clock_pin"} {return pin}
    return reg
}
proc get_fanins {args} {
    global drivers fault prefix
    if {[lindex $args 0] ne {-synch}} {error "data-driver guard included unrelated clock edges"}
    set name [lindex [lindex $args end] 0]
    set result [list clock_pin $drivers($name)]
    if {$name eq "${prefix}completed_meta"} {
        if {$fault eq "wrong_driver"} {return [list clock_pin "${prefix}blank_ack"]}
        if {$fault eq "extra_driver"} {lappend result "${prefix}generation"}
    }
    return $result
}
proc get_fanouts {collection} {
    global consumers fault prefix
    set name [lindex $collection 0]
    set result [list $consumers($name)]
    if {$name eq "${prefix}completed_meta"} {
        if {$fault eq "wrong_consumer"} {return [list "${prefix}ack_sample"]}
        if {$fault eq "extra_consumer"} {lappend result "${prefix}consumer"}
        if {$fault eq "no_consumer"} {return {}}
    }
    return $result
}
proc set_false_path {args} {lappend ::cuts $args}
foreach fault {missing ambiguous alias replica wrong_driver extra_driver wrong_consumer extra_consumer no_consumer} {
    set cuts {}
    if {![catch {source $candidate} problem]} {error "invalid candidate scope accepted: $fault"}
    if {[llength $cuts]} {error "partial candidate exceptions applied: $fault"}
}
set fault {}
set cuts {}
source $candidate
set expected {}
foreach {from first second} $triples {
    lappend expected [list -from [list "$prefix$from"] -to [list "$prefix$first"]]
}
if {$cuts ne $expected} {error "candidate cut more/less than six exact first-stage inputs"}
puts "PASS: mock first-stage candidate; six exact cuts, nine invalid inventories reject before any exceptions"
