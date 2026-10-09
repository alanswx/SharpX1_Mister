# Mocked clock identity/coverage only, not native timing acceptance.
set tool [file normalize [file join [file dirname [info script]] .. .. scripts quartus_x3_clock_paths.tcl]]
package provide ::quartus::project 1
package provide ::quartus::sta 1
foreach name {project_open create_timing_netlist read_sdc update_timing_netlist delete_timing_netlist project_close report_clocks} {proc $name args {}}
proc get_clocks {pattern} {
    set label system
    if {[string match {*turbo_video_pll*} $pattern]} {set label video}
    if {[string match {*pll_hdmi*} $pattern]} {set label hdmi}
    if {$pattern eq "x1_hdmi_mux"} {set label mux_hdmi}
    if {$pattern eq "x1_video_mux"} {set label mux_video}
    return $::objects($label)
}
proc get_collection_size {clocks} {llength $clocks}
proc get_clock_info {option clock} {return $clock}
proc foreach_in_collection {var clocks body} {uplevel 1 [list foreach $var $clocks $body]}
proc set_operating_conditions args {lappend ::corners $args}
proc report_timing args {
    set file [lindex $args [expr {[lsearch -exact $args -file]+1}]]
    if {[dict exists $::reports $file]} {error "duplicate report"}
    dict set ::reports $file $args
}
foreach name {set_false_path set_clock_groups set_max_delay set_min_delay set_multicycle_path} {proc $name args {error "reporter must not add exceptions"}}
proc run_tool {} {global tool quartus; source $tool}
foreach label {system video hdmi mux_hdmi mux_video} {
    foreach mode {valid missing duplicate merged} {
        array set objects {system sys_clock video vid_clock hdmi hdmi_clock mux_hdmi x1_hdmi_mux mux_video x1_video_mux}
        switch $mode {
            missing {set objects($label) {}}
            duplicate {lappend objects($label) [lindex $objects($label) 0]}
            merged {if {$label eq "system"} {set objects($label) vid_clock} else {set objects($label) sys_clock}}
        }
        set quartus(args) sharpx1_turbo_z_video
        set corners {}
        set reports {}
        set failed [catch {run_tool} message]
        if {$mode ne "valid"} {
            if {!$failed || [llength $corners] || [dict size $reports]} {error "$label/$mode accepted partial coverage"}
            continue
        }
        if {$failed || [dict size $reports] != 320 || [llength $corners] != 8} {error "wrong coverage: $message"}
        foreach model {slow fast} {
            foreach temperature {-40 0 85 100} {
                set prefix output_files/sharpx1_turbo_z_video_x3_clock_${model}_${temperature}
                foreach domain {system video hdmi mux_hdmi mux_video} {
                    foreach check {setup hold recovery removal} {
                        set file ${prefix}_${domain}_same_${check}.rpt
                        if {![dict exists $reports $file]} {error "missing same-clock report"}
                        set args [dict get $reports $file]
                        set from [lindex $args [expr {[lsearch -exact $args -from_clock]+1}]]
                        set to [lindex $args [expr {[lsearch -exact $args -to_clock]+1}]]
                        if {[lindex $args 0] ne "-$check" || $from ne $objects($domain) || $to ne $objects($domain)} {error "wrong same-clock scope"}
                    }
                }
                foreach {pair from_label to_label} {system_video system video video_system video system mux_hdmi_system mux_hdmi system system_mux_hdmi system mux_hdmi mux_video_system mux_video system system_mux_video system mux_video hdmi_mux_hdmi hdmi mux_hdmi mux_hdmi_hdmi mux_hdmi hdmi video_mux_video video mux_video mux_video_video mux_video video} {
                    foreach check {setup hold} {
                        set args [dict get $reports ${prefix}_${pair}_${check}.rpt]
                        set from [lindex $args [expr {[lsearch -exact $args -from_clock]+1}]]
                        set to [lindex $args [expr {[lsearch -exact $args -to_clock]+1}]]
                        if {[lindex $args 0] ne "-$check" || $from ne $objects($from_label) || $to ne $objects($to_label)} {error "wrong crossing scope"}
                    }
                }
            }
        }
    }
}
puts "PASS: 320 reports, five clocks, six SYS crossing directions and four master/own-alias directions, eight corners; 15 invalid inventories reject (mock only)"
