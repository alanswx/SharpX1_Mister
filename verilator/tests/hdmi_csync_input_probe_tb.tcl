# Execute the real probe orchestration against mocked Quartus collections.
# No native STA/exclusion semantics claim follows.
source [file join [file dirname [info script]] hdmi_csync_input_sdc_tb.tcl]
package provide ::quartus::project 1
package provide ::quartus::sta 1
namespace eval quartus {variable args}
foreach command {project_open create_timing_netlist read_sdc update_timing_netlist set_operating_conditions delete_timing_netlist project_close report_clocks} {
    proc $command {args} {}
}
rename get_fanouts guarded_fanouts
proc get_fanouts collection {
    set name [lindex $collection 0]
    if {[info exists ::consumers($name)]} {return [guarded_fanouts $collection]}
    return {x1_hdmi_clock_handoff:hdmi_handoff|mock_ready}
}
proc report_timing args {
    set path [lindex $args end]
    if {[string match {*before_*} $path]} {
        if {[llength $::cuts]} {error "candidate applied before baseline reports"}
    } elseif {[llength $::cuts] != 4} {error "after reports lack all four guarded proposals"}
    lappend ::reports $path
}
set cuts {};set reports {}
set quartus(args) [list [file join /tmp x1-csync-probe-scope-[pid]-[clock clicks]] $candidate]
source [file join $root scripts quartus_hdmi_csync_input_probe.tcl]
if {[llength $reports] != 640 || [llength [lsort -unique $reports]] != 640} {
    error "missing/duplicate before-after corner reports"
}
foreach phase {before after} {
    set count 0
    foreach path $reports {if {[string match "*${phase}_*" $path]} {incr count}}
    if {$count != 320} {error "wrong $phase enumeration"}
}
puts "PASS: mocked 640-report csync before/after orchestration; candidate only after original reports"
