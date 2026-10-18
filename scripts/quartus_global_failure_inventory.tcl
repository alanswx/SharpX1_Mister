# Reporting only: inventory every negative-slack path at all eight corners.
# Reads the project's assigned SDC; adds no exceptions. Run on an idle copy.
# Usage: quartus_sta -t quartus_global_failure_inventory.tcl REVISION OUTDIR [CANDIDATE]
package require ::quartus::project
package require ::quartus::sta
lassign $quartus(args) revision outdir candidate
if {$revision eq "" || $outdir eq ""} {error "usage: REVISION OUTDIR \[CANDIDATE\]"}
file mkdir $outdir
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
if {$candidate ne ""} {source $candidate}
update_timing_netlist
set limit 200000
proc clock_name {clock} {
    if {$clock eq ""} {return ""}
    return [get_clock_info -name $clock]
}
proc node_name {node} {
    if {$node eq ""} {return ""}
    return [get_node_info -name $node]
}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        foreach check {setup hold recovery removal} {
            set file [file join $outdir ${model}_${temperature}_${check}.csv]
            set fh [open $file w]
            puts $fh "slack,from_clock,to_clock,from,to,data_delay,skew"
            set paths [get_timing_paths -$check -npaths $limit -pairs_only -less_than_slack 0]
            set count 0
            foreach_in_collection path $paths {
                set from_clock [clock_name [get_path_info -from_clock $path]]
                set to_clock [clock_name [get_path_info -to_clock $path]]
                puts $fh [join [list [get_path_info -slack $path] $from_clock $to_clock \
                    [node_name [get_path_info -from $path]] [node_name [get_path_info -to $path]] \
                    [get_path_info -data_delay $path] [get_path_info -clock_skew $path]] ,]
                incr count
            }
            close $fh
            if {$count >= $limit} {error "path limit reached for $model $temperature $check"}
            post_message "GLOBAL FAILURES $model $temperature $check: $count"
        }
    }
}
delete_timing_netlist
project_close
