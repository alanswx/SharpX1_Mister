# Reporting only for the new three-pipeline experimental Z profile.
# Run sequentially after the fitter is idle and originals are preserved.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
set candidate [lindex $quartus(args) 1]
if {$revision ne "sharpx1_turbo_z_video"} {error "expected experimental Z"}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set raw [get_registers {reset_req}]
if {[get_collection_size $raw] != 1} {error "expected one raw reset register"}
set domains [dict create]
foreach domain {input output avalon} {
    set regs [get_registers "*ascal*|*x1_domain_reset*${domain}_release*|release_pipe*"]
    if {[get_collection_size $regs] != 2} {error "expected two $domain scaler release stages"}
    set stages [dict create]
    foreach_in_collection reg $regs {
        set name [get_register_info -name $reg]
        if {![regexp {\|release_pipe\[([01])\]$} $name -> bit] || [dict exists $stages $bit]} {
            error "unexpected scaler stage/replica: $name"
        }
        set stage [get_registers [list $name]]
        if {[get_collection_size $stage] != 1} {error "stage identity did not resolve uniquely"}
        dict set stages $bit $stage
        post_message "Scaler local release stage $domain:$bit $name"
    }
    if {[lsort [dict keys $stages]] ne {0 1}} {error "missing scaler stage"}
    dict set domains $domain [list $regs [dict get $stages 0] [dict get $stages 1]]
}
set phases {baseline}
if {$candidate ne ""} {set phases {before after}}
foreach phase $phases {
if {$phase eq "after"} {source $candidate; update_timing_netlist}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set prefix output_files/${revision}_scaler_release_${model}_${temperature}
        if {$candidate ne ""} {set prefix output_files/${revision}_scaler_release_probe_${phase}_${model}_${temperature}}
        dict for {domain collections} $domains {
            lassign $collections regs first last
            foreach check {setup hold} {
                report_timing -$check -from $first -to $last -npaths 10000 -detail full_path -file ${prefix}_${domain}_chain_${check}.rpt
            }
            foreach check {recovery removal} {
                report_timing -$check -from $raw -to $regs -npaths 10000 -detail full_path -file ${prefix}_${domain}_input_${check}.rpt
                report_timing -$check -from $last -npaths 10000 -detail full_path -file ${prefix}_${domain}_output_${check}.rpt
            }
        }
        if {$candidate ne ""} {
            foreach check {recovery removal} {
                report_timing -$check -npaths 100 -detail full_path -file ${prefix}_global_${check}.rpt
            }
        }
    }
}
}
delete_timing_netlist
project_close
