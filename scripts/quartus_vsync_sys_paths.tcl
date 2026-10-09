# Reporting only. Run sequentially after preserving original fitted reports.
# Does not declare an input exception or assert physical CDC acceptance.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ne "sharpx1_turbo_z_video"} {error "expected experimental Z"}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set regs [get_registers {*hdmi_vsync_to_sys*|sample_pipe*}]
if {[get_collection_size $regs] != 2} {error "expected exactly two VSYNC stages"}
set stages [dict create]
foreach_in_collection reg $regs {
    set name [get_register_info -name $reg]
    if {![regexp {\|sample_pipe\[([01])\]$} $name -> bit] || [dict exists $stages $bit]} {
        error "unexpected VSYNC stage/replica: $name"
    }
    set stage [get_registers [list $name]]
    if {[get_collection_size $stage] != 1} {error "VSYNC stage identity did not resolve uniquely"}
    dict set stages $bit $stage
    post_message "VSYNC SYS stage $bit $name"
}
if {[lsort [dict keys $stages]] ne {0 1}} {error "missing VSYNC stage"}
set first [dict get $stages 0]
set last [dict get $stages 1]
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set prefix output_files/${revision}_vsync_sys_${model}_${temperature}
        foreach check {setup hold} {
            # Raw input may fail. It is not a synchronous data transfer.
            report_timing -$check -to $first -npaths 10000 -detail full_path -file ${prefix}_input_${check}.rpt
            report_timing -$check -from $first -to $last -npaths 10000 -detail full_path -file ${prefix}_chain_${check}.rpt
            # Unbounded destination report helps expose unintended stage-0 use.
            # Native fanout inventory is still required; no-path is not a pass.
            report_timing -$check -from $first -npaths 10000 -detail full_path -file ${prefix}_first_fanout_${check}.rpt
            report_timing -$check -from $last -npaths 10000 -detail full_path -file ${prefix}_consumer_${check}.rpt
        }
    }
}
delete_timing_netlist
project_close
