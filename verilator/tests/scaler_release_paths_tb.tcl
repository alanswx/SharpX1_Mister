# Mocked endpoint/coverage test, not native Quartus timing evidence.
set tool [file normalize [file join [file dirname [info script]] .. .. scripts quartus_scaler_release_paths.tcl]]
package provide ::quartus::project 1
package provide ::quartus::sta 1
foreach name {project_open create_timing_netlist read_sdc update_timing_netlist post_message delete_timing_netlist project_close} {proc $name args {}}
proc stage_names {domain} {
    set names {}
    foreach bit {0 1} {lappend names [format {ascal:ascal|x1_scaler_reset_release:\x1_domain_reset:%s_release|release_pipe[%d]} $domain $bit]}
    return $names
}
proc get_registers {query} {
    if {$query eq "reset_req"} {
        if {$::mode eq "missing_raw"} {return {}}
        return [list reset_req]
    }
    if {[string first "*" $query] < 0} {
        if {$::mode eq "lookup_missing"} {return {}}
        return $query
    }
    foreach domain {input output avalon} {
        if {[string first "${domain}_release" $query] >= 0} {
            set names [stage_names $domain]
            if {$domain eq "avalon"} {
                switch $::mode {
                    missing_stage {set names [lrange $names 0 0]}
                    duplicate_stage {lset names 1 [lindex $names 0]}
                    extra_stage {lappend names [lindex $names 0]}
                    wrong_bit {lset names 1 [string map {{[1]} {[2]}} [lindex $names 1]]}
                    replica {lset names 1 "[lindex $names 1]~DUPLICATE"}
                }
            }
            return $names
        }
    }
    error "unexpected query $query"
}
proc get_collection_size {regs} {llength $regs}
proc get_register_info {option reg} {return $reg}
proc foreach_in_collection {var regs body} {uplevel 1 [list foreach $var $regs $body]}
proc set_operating_conditions args {lappend ::corners $args}
proc report_timing args {
    set file [lindex $args [expr {[lsearch -exact $args -file]+1}]]
    if {[dict exists $::reports $file]} {error "duplicate report"}
    dict set ::reports $file $args
}
foreach name {set_false_path set_clock_groups set_max_delay set_min_delay set_multicycle_path} {proc $name args {error "must not add exceptions"}}
proc run_tool {} {global quartus tool; source $tool}
foreach mode {valid missing_raw missing_stage duplicate_stage extra_stage wrong_bit replica lookup_missing wrong_revision} {
    set quartus(args) sharpx1_turbo_z_video
    if {$mode eq "wrong_revision"} {set quartus(args) sharpx1}
    set corners {}
    set reports {}
    set failed [catch {run_tool} message]
    if {$mode ne "valid"} {
        if {!$failed || [dict size $reports] || [llength $corners]} {error "$mode accepted invalid profile"}
        continue
    }
    if {$failed} {error $message}
    if {[llength $corners] != 8 || [dict size $reports] != 144} {error "wrong report coverage"}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            foreach domain {input output avalon} {
                set names [stage_names $domain]
                foreach kind {chain input output} {
                    if {$kind eq "chain"} {set checks {setup hold}} else {set checks {recovery removal}}
                    foreach check $checks {
                        set file output_files/sharpx1_turbo_z_video_scaler_release_${model}_${temperature}_${domain}_${kind}_${check}.rpt
                        if {![dict exists $reports $file]} {error "missing report"}
                        set args [dict get $reports $file]
                        if {[lindex $args 0] ne "-$check"} {error "wrong check"}
                        set from [lindex $args [expr {[lsearch -exact $args -from]+1}]]
                        set to_index [lsearch -exact $args -to]
                        set to [lindex $args [expr {$to_index+1}]]
                        switch $kind {
                            chain {if {$from ne [list [lindex $names 0]] || $to ne [list [lindex $names 1]]} {error "wrong chain scope"}}
                            input {if {$from ne "reset_req" || $to ne $names} {error "wrong raw input scope"}}
                            output {if {$from ne [list [lindex $names 1]] || $to_index >= 0} {error "wrong release output scope"}}
                        }
                    }
                }
            }
        }
    }
}
puts "PASS: 144 reports, eight corners, six distinct scaler stages; eight invalid profiles reject (mock only)"
