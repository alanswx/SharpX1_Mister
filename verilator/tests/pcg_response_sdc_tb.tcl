# Fail-closed endpoint validation without Quartus. This does not validate STA.
set candidate [file normalize [file join [file dirname [info script]] .. .. scripts constraints pcg_response_candidate.sdc]]
proc get_registers {pattern} {
    if {[string match {*response*} $pattern]} {return $::response}
    return $::cpu_q
}
proc get_collection_size {collection} {return [llength $collection]}
proc get_register_info {option reg} {return $reg}
proc foreach_in_collection {var collection body} {
    uplevel 1 [list foreach $var $collection $body]
}
proc set_max_delay {args} {lappend ::applied [list max {*}$args]}
proc set_min_delay {args} {lappend ::applied [list min {*}$args]}
set valid_response {}
set valid_cpu_q {}
for {set bit 0} {$bit < 8} {incr bit} {
    lappend valid_response [format {emu:emu|sharpx1:sharpx1|x1_pcg_access:cg_bus|response[%d]} $bit]
    lappend valid_cpu_q [format {emu:emu|sharpx1:sharpx1|x1_pcg_access:cg_bus|cpu_q[%d]} $bit]
}
foreach field {response cpu_q} {
    foreach mode {valid missing duplicate extra wrong_bit wrong_field duplicate_suffix} {
        set response $valid_response
        set cpu_q $valid_cpu_q
        set collection [set $field]
        switch $mode {
            missing {set collection [lrange $collection 0 6]}
            duplicate {lset collection 7 [lindex $collection 0]}
            extra {lappend collection [lindex $collection 0]}
            wrong_bit {lset collection 7 "bad|${field}\[8\]"}
            wrong_field {lset collection 7 {bad|other[7]}}
            duplicate_suffix {lset collection 7 "[lindex $collection 7]~DUPLICATE"}
        }
        set $field $collection
        set applied {}
        set failed [catch {source $candidate} message]
        if {$mode eq "valid"} {
            if {$failed || [llength $applied] != 2 ||
                [lindex [lindex $applied 0] end] != 31.25 ||
                [lindex [lindex $applied 1] end] != 0} {
                error "valid inventory did not produce exact bounds: $message"
            }
        } elseif {!$failed || [llength $applied] != 0} {
            error "$field/$mode did not fail before constraints"
        }
    }
}
puts "PASS: PCG response candidate exact eight-bit inventory; 12 negative cases refuse all constraints"
