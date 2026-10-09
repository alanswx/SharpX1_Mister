# Reporting only, on an idle completed experimental Z fit. No new exceptions.
# Preserve original flow and all-corner reports before supplemental STA.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ne "sharpx1_turbo_z_video" || [llength $quartus(args)] != 1} {error "expected experimental Z revision only"}
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set regs [get_registers {*x3_blink.video_blink*|*sample_pipe*}]
if {[get_collection_size $regs] != 2} {error "expected exactly two video blink registers"}
set stages [dict create]
set stage_names [dict create]
set prefixes {}
foreach_in_collection reg $regs {
    set name [get_register_info -name $reg]
    if {![regexp {^(.*\|crossing\.sample_pipe)\[([01])\]$} $name -> prefix bit] || [dict exists $stages $bit]} {
        error "unexpected blink stage/replica: $name"
    }
    lappend prefixes $prefix
    set stage [get_registers [list $name]]
    if {[get_collection_size $stage] != 1} {error "blink stage identity did not resolve uniquely"}
    dict set stages $bit $stage
    dict set stage_names $bit $name
    post_message "video blink stage $bit $name"
}
if {[lsort [dict keys $stages]] ne {0 1} || [llength [lsort -unique $prefixes]] != 1} {error "blink stages are not a unique pair"}
foreach bit {0 1} {
    set fanouts [get_fanouts [list [dict get $stage_names $bit]]]
    set names {}
    foreach_in_collection fanout $fanouts {
        if {[get_node_info -type $fanout] ne "reg"} {error "unexpected blink non-register fanout"}
        lappend names [get_node_info -name $fanout]
    }
    if {$bit == 0 && $names ne [list [dict get $stage_names 1]]} {error "blink stage zero has unexpected consumers"}
    if {$bit == 1 && (![llength $names] || [llength $names] != [llength [lsort -unique $names]])} {error "blink final fanout is empty/duplicated"}
    post_message "video blink stage $bit native fanout $names"
}
# Record actual physical pins/fanins without guessing first-stage D/ASDATA.
# These observations do not authorize an input exception or prove placement.
set pins [get_pins -compatibility_mode {*x3_blink.video_blink*|*sample_pipe*|*}]
foreach_in_collection pin $pins {
    set name [get_pin_info -name $pin]
    post_message "video blink native pin $name"
    if {[regexp {\|crossing\.sample_pipe\[0\]\|(d|asdata)$} $name]} {
        foreach_in_collection fanin [get_fanins [list $name]] {
            post_message "video blink first-data fanin [get_node_info -name $fanin] ([get_node_info -type $fanin])"
        }
    }
}
set first [dict get $stages 0]
set last [dict get $stages 1]
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set prefix output_files/${revision}_video_blink_${model}_${temperature}
        foreach check {setup hold} {
            report_timing -$check -to $first -npaths 10000 -detail full_path -file ${prefix}_input_${check}.rpt
            report_timing -$check -from $first -to $last -npaths 10000 -detail full_path -file ${prefix}_chain_${check}.rpt
            report_timing -$check -from $first -npaths 10000 -detail full_path -file ${prefix}_first_fanout_${check}.rpt
            report_timing -$check -from $last -npaths 10000 -detail full_path -file ${prefix}_consumer_${check}.rpt
        }
    }
}
delete_timing_netlist
project_close
