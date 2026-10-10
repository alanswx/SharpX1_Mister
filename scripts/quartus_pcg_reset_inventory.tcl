# Reporting-only PCG reset/WE discovery on a completed handoff fit.
# No exceptions, assignments or project rewrites. Empty raw-reset reports
# require independent review; they are not automatically a timing pass.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1} {error "expected NEW report directory"}
set destination [lindex $quartus(args) 0]
if {[file exists $destination]} {error "refusing to overwrite evidence"}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set names {}
array set planes {b 0 r 0 g 0}
foreach_in_collection reg [get_registers {*x1_video_ram:pcg_*|*}] {
    set name [get_register_info -name $reg]
    if {![string match {*porta_we_reg*} $name]} {continue}
    if {![regexp {^emu:emu\|sharpx1:sharpx1\|x1_video_ram:pcg_([brg])\|.+~porta_we_reg$} $name -> plane]} {
        error "unexpected PCG WE identity/alias: $name"
    }
    if {$name in $names} {error "duplicate physical PCG WE: $name"}
    lappend names $name
    incr planes($plane)
}
foreach plane {b r g} {
    if {$planes($plane) != 4} {error "expected four fitted WE keepers in plane $plane"}
}
set targets [get_registers -no_duplicates $names]
if {[get_collection_size $targets] != 12} {error "ambiguous fitted PCG WE collection"}
set pipe_names {}
foreach bit {0 1} {
    lappend pipe_names [format {emu:emu|sharpx1:sharpx1|x1_reset_release:video_reset_domain.release_reset|release_pipe[%d]} $bit]
}
set pipes [get_registers -no_duplicates $pipe_names]
if {[get_collection_size $pipes] != 2} {error "missing local VID reset pipeline"}
set actual_pipes {}
foreach_in_collection reg $pipes {lappend actual_pipes [get_register_info -name $reg]}
if {[lsort $actual_pipes] ne [lsort $pipe_names]} {error "unexpected local VID reset alias"}
set download_name {emu:emu|hps_io:hps_io|ioctl_download}
set download [get_registers {*hps_io:hps_io|ioctl_download*}]
if {[get_collection_size $download] != 1} {error "ambiguous raw download reset source"}
foreach_in_collection reg $download {
    if {[get_register_info -name $reg] ne $download_name} {error "unexpected raw download source alias"}
}
# Emit actual native synchronous fan-in names before timing interpretation.
foreach name $names {
    set inputs [get_fanins -synch [list $name]]
    if {[get_collection_size $inputs] == 0} {error "missing WE native fanins: $name"}
    foreach_in_collection node $inputs {
        puts "PCG RESET FANIN $name [get_node_info -name $node] ([get_node_info -type $node])"
    }
}
file mkdir $destination
report_clocks -file [file join $destination clocks.rpt]
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        puts "PCG RESET CORNER $model $temperature 1100"
        foreach check {setup hold} {
            foreach {kind source} [list download $download local $pipes] {
                report_timing -$check -from $source -to $targets -npaths 10000 -detail full_path \
                    -file [file join $destination ${model}_${temperature}_${kind}_${check}.rpt]
            }
            report_timing -$check -to $targets -npaths 10000 -detail full_path \
                -file [file join $destination ${model}_${temperature}_all_we_${check}.rpt]
        }
        foreach check {recovery removal} {
            report_timing -$check -from $pipes -npaths 10000 -detail full_path \
                -file [file join $destination ${model}_${temperature}_local_${check}.rpt]
        }
    }
}
puts "PCG RESET INVENTORY COMPLETE: original SDC only; not timing acceptance"
delete_timing_netlist
project_close
