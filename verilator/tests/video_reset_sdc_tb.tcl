# Mocked collection/scope test only, not native pin or timing qualification.
set candidate [file normalize [file join [file dirname [info script]] .. .. scripts constraints video_reset_input_candidate.sdc]]
proc get_pins {args} {
    if {[lindex $args 0] ne "-compatibility_mode"} {error "missing compatibility mode"}
    return $::pins
}
proc get_pin_info {option pin} {return $pin}
proc get_collection_size {collection} {return [llength $collection]}
proc foreach_in_collection {var collection body} {uplevel 1 [list foreach $var $collection $body]}
proc set_false_path {args} {lappend ::applied $args}
set valid {}
foreach instance {video_reset_domain.release_reset local_release.video_release} {
    foreach bit {0 1} {
        lappend valid [format {emu|sharpx1|%s|release_pipe[%d]|clrn} $instance $bit]
    }
}
foreach mode {valid missing duplicate extra d_pin clock_pin output_pin cpu_domain wrong_stage wrong_instance} {
    set pins $valid
    switch $mode {
        missing {set pins [lrange $pins 0 2]}
        duplicate {lset pins 3 [lindex $pins 0]}
        extra {lappend pins [lindex $pins 0]}
        d_pin {lset pins 0 {emu|sharpx1|video_reset_domain.release_reset|release_pipe[0]|d}}
        clock_pin {lset pins 0 {emu|sharpx1|video_reset_domain.release_reset|release_pipe[0]|clk}}
        output_pin {lset pins 0 {emu|sharpx1|video_reset_domain.release_reset|release_pipe[0]|q}}
        cpu_domain {lset pins 0 {emu|sharpx1|local_release.cpu_release|release_pipe[0]|clrn}}
        wrong_stage {lset pins 0 {emu|sharpx1|video_reset_domain.release_reset|release_pipe[2]|clrn}}
        wrong_instance {lset pins 0 {emu|sharpx1|unknown|release_pipe[0]|clrn}}
    }
    set applied {}
    set failed [catch {source $candidate} message]
    if {$mode eq "valid"} {
        if {$failed || $applied ne [list [list -to $valid]]} {error "invalid exception scope: $message"}
    } elseif {!$failed || [llength $applied]} {error "$mode did not refuse exception"}
}
puts "PASS: only four raw VID reset pins; nine invalid inventories reject exception"
