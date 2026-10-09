# Reuse the exact stage fixtures; add candidate before/after orchestration.
source [file join [file dirname [info script]] scaler_release_paths_tb.tcl]
set pins {}
foreach domain {input output avalon} {
    foreach bit {0 1} {lappend pins [format {ascal|\x1_domain_reset:%s_release|release_pipe[%d]|clrn} $domain $bit]}
}
proc get_pins args {return $::pins}
proc get_pin_info {option pin} {return $pin}
proc set_false_path args {
    if {[dict size $::reports] != 160 || [llength $::cuts]} {error "candidate not applied exactly once after complete before reports"}
    if {$args ne [list -to $::pins]} {error "wrong raw pin scope"}
    lappend ::cuts $args
}
set mode valid
set quartus(args) [list sharpx1_turbo_z_video [file normalize [file join [file dirname [info script]] .. .. scripts constraints scaler_reset_input_candidate.sdc]]]
set reports {}
set corners {}
set cuts {}
run_tool
if {[dict size $reports] != 320 || [llength $corners] != 16 || [llength $cuts] != 1} {error "wrong before/after report coverage"}
dict for {file args} $reports {
    if {[string first "_before_" $file] < 0} {continue}
    set after [string map {_before_ _after_} $file]
    if {![dict exists $reports $after]} {error "missing paired report"}
    set index [expr {[lsearch -exact $args -file]+1}]
    lset args $index $after
    if {$args ne [dict get $reports $after]} {error "changed paired report scope"}
}
puts "PASS: 320 paired reports, all eight corners before/after, cut only after complete baseline (mock only)"
