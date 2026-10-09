# Mocked raw-pin scope only; not native timing or physical reset acceptance.
set candidate [file normalize [file join [file dirname [info script]] .. .. scripts constraints scaler_reset_input_candidate.sdc]]
proc get_pins args {return $::pins}
proc get_pin_info {option pin} {return $pin}
proc get_collection_size {pins} {llength $pins}
proc foreach_in_collection {var pins body} {uplevel 1 [list foreach $var $pins $body]}
proc set_false_path args {lappend ::applied $args}
set valid {}
foreach domain {input output avalon} {
    foreach bit {0 1} {lappend valid [format {ascal|\x1_domain_reset:%s_release|release_pipe[%d]|clrn} $domain $bit]}
}
foreach mode {valid missing duplicate extra d_pin clk_pin q_pin wrong_stage wrong_domain wrong_instance legacy_one_stage unknown_replica} {
    set pins $valid
    switch $mode {
        missing {set pins [lrange $pins 1 end]}
        duplicate {lset pins 1 [lindex $pins 0]}
        extra {lappend pins [lindex $pins 0]}
        d_pin {lset pins 0 [string map {|clrn |d} [lindex $pins 0]]}
        clk_pin {lset pins 0 [string map {|clrn |clk} [lindex $pins 0]]}
        q_pin {lset pins 0 [string map {|clrn |q} [lindex $pins 0]]}
        wrong_stage {lset pins 0 [string map {{[0]} {[2]}} [lindex $pins 0]]}
        wrong_domain {lset pins 0 [string map {input_release cpu_release} [lindex $pins 0]]}
        wrong_instance {lset pins 0 [string map {ascal| other|} [lindex $pins 0]]}
        legacy_one_stage {lset pins 0 {ascal|i_reset_na|clrn}}
        unknown_replica {lset pins 0 [string map {|clrn ~DUPLICATE|clrn} [lindex $pins 0]]}
    }
    set applied {}
    set failed [catch {source $candidate} message]
    if {$mode eq "valid"} {
        if {$failed || $applied ne [list [list -to $valid]]} {error "wrong pin-only scope: $message"}
    } elseif {!$failed || [llength $applied]} {error "$mode accepted invalid pin inventory"}
}
puts "PASS: only six primary scaler raw CLRN pins; 11 invalid inventories refuse cuts (mock only)"
