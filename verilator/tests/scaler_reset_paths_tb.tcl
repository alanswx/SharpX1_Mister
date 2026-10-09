# Mocked orchestration only; no native Quartus pin/timing qualification.
set tool [file normalize [file join [file dirname [info script]] .. .. scripts quartus_scaler_reset_paths.tcl]]
package provide ::quartus::project 1
package provide ::quartus::sta 1
foreach name {project_open create_timing_netlist read_sdc update_timing_netlist post_message delete_timing_netlist project_close} {proc $name args {}}
proc get_registers {name} {
    if {$::mode eq "missing_raw" && $name eq "reset_req"} {return {}}
    if {$::mode eq "duplicate_raw" && $name eq "reset_req"} {return [list $name $name]}
    if {$::mode eq "missing_input" && $name eq "ascal:ascal|i_reset_na"} {return {}}
    if {$::mode eq "duplicate_output" && $name eq "ascal:ascal|o_reset_na"} {return [list $name $name]}
    if {$::mode eq "missing_avalon" && $name eq "ascal:ascal|avl_reset_na"} {return {}}
    return [list $name]
}
proc get_collection_size {regs} {llength $regs}
proc get_register_info {option reg} {
    if {$::mode eq "wrong_identity" && $reg eq "ascal:ascal|avl_reset_na"} {return "other|avl_reset_na"}
    return $reg
}
proc foreach_in_collection {var regs body} {uplevel 1 [list foreach $var $regs $body]}
proc set_operating_conditions args {lappend ::corners $args}
proc report_timing args {
    set file [lindex $args [expr {[lsearch -exact $args -file]+1}]]
    if {[dict exists $::reports $file]} {error "duplicate report"}
    dict set ::reports $file $args
}
foreach name {set_false_path set_clock_groups set_max_delay set_min_delay set_multicycle_path} {proc $name args {error "must not add timing exceptions"}}
proc run_tool {} {global quartus tool; source $tool}
foreach mode {valid missing_raw duplicate_raw missing_input duplicate_output missing_avalon wrong_identity wrong_revision} {
    set quartus(args) sharpx1_turbo_z_video
    if {$mode eq "wrong_revision"} {set quartus(args) sharpx1}
    set corners {}
    set reports {}
    set failed [catch {run_tool} message]
    if {$mode ne "valid"} {
        if {!$failed || [dict size $reports] || [llength $corners]} {error "$mode did not refuse reporting"}
        continue
    }
    if {$failed} {error $message}
    if {[llength $corners] != 8 || [dict size $reports] != 96} {error "wrong report coverage"}
    set expected_corners {}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            lappend expected_corners [list -model $model -temperature $temperature -voltage 1100]
            foreach domain {i o avl} {
                foreach direction {input output} {
                    foreach check {recovery removal} {
                        set file output_files/sharpx1_turbo_z_video_scaler_reset_${model}_${temperature}_${domain}_${direction}_${check}.rpt
                        if {![dict exists $reports $file]} {error "missing $file"}
                        set args [dict get $reports $file]
                        if {[lindex $args 0] ne "-$check"} {error "wrong check"}
                        set from [lindex $args [expr {[lsearch -exact $args -from]+1}]]
                        if {$direction eq "input"} {
                            set to [lindex $args [expr {[lsearch -exact $args -to]+1}]]
                            if {$from ne "reset_req" || $to ne "ascal:ascal|${domain}_reset_na"} {error "wrong input endpoints"}
                        } elseif {$from ne "ascal:ascal|${domain}_reset_na" || [lsearch -exact $args -to] >= 0} {error "wrong output scope"}
                    }
                }
            }
        }
    }
    if {$corners ne $expected_corners} {error "wrong operating conditions"}
}
puts "PASS: 96 reports/eight corners/three domains; seven invalid inventories/profiles reject (mock only)"
