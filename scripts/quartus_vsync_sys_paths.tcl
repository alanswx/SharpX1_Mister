# Reporting only. Run sequentially after preserving original fitted reports.
# Does not declare an input exception or assert physical CDC acceptance.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
set candidate [lindex $quartus(args) 1]
if {$revision ne "sharpx1_turbo_z_video"} {error "expected experimental Z"}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set regs [get_registers {*hdmi_vsync_to_sys*|sample_pipe*}]
if {[get_collection_size $regs] != 2} {error "expected exactly two VSYNC stages"}
set stages [dict create]
set stage_names [dict create]
foreach_in_collection reg $regs {
    set name [get_register_info -name $reg]
    if {![regexp {\|sample_pipe\[([01])\]$} $name -> bit] || [dict exists $stages $bit]} {
        error "unexpected VSYNC stage/replica: $name"
    }
    set stage [get_registers [list $name]]
    if {[get_collection_size $stage] != 1} {error "VSYNC stage identity did not resolve uniquely"}
    dict set stages $bit $stage
    dict set stage_names $bit $name
    post_message "VSYNC SYS stage $bit $name"
}
if {[lsort [dict keys $stages]] ne {0 1}} {error "missing VSYNC stage"}
set first [dict get $stages 0]
set last [dict get $stages 1]
foreach {bit expected} [list 0 [list [dict get $stage_names 1]] 1 {vs_d0 vs_d1 vsd}] {
    set fanouts [get_fanouts [list [dict get $stage_names $bit]]]
    set names {}
    foreach_in_collection fanout $fanouts {
        if {[get_node_info -type $fanout] ne "reg"} {error "unexpected VSYNC non-register fanout"}
        lappend names [get_node_info -name $fanout]
    }
    if {[lsort $names] ne [lsort $expected]} {error "VSYNC stage $bit native fanout inventory changed: $names"}
    post_message "VSYNC SYS stage $bit native fanout $names"
}
set phases {baseline}
if {$candidate ne ""} {set phases {before after}}
foreach phase $phases {
if {$phase eq "after"} {source $candidate; update_timing_netlist}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set prefix output_files/${revision}_vsync_sys_${model}_${temperature}
        if {$candidate ne ""} {set prefix output_files/${revision}_vsync_sys_probe_${phase}_${model}_${temperature}}
        foreach check {setup hold} {
            # Raw input may fail. It is not a synchronous data transfer.
            report_timing -$check -to $first -npaths 10000 -detail full_path -file ${prefix}_input_${check}.rpt
            report_timing -$check -from $first -to $last -npaths 10000 -detail full_path -file ${prefix}_chain_${check}.rpt
            # Unbounded destination report helps expose unintended stage-0 use.
            # Native fanout inventory is still required; no-path is not a pass.
            report_timing -$check -from $first -npaths 10000 -detail full_path -file ${prefix}_first_fanout_${check}.rpt
            report_timing -$check -from $last -npaths 10000 -detail full_path -file ${prefix}_consumer_${check}.rpt
            if {$candidate ne ""} {
                report_timing -$check -npaths 100 -detail full_path -file ${prefix}_global_${check}.rpt
            }
        }
    }
}
}
delete_timing_netlist
project_close
