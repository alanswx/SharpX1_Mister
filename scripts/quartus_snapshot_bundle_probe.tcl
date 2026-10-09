# Reporting-only bounded-payload experiment, never writes project SDC/QSF.
# Run against the completed independent-X3 fit, only when the host is idle.
# Intended scope: video_calc's dimensions_to_sys held bus, not entire clocks.
package require ::quartus::project
package require ::quartus::sta
set revision [lindex $quartus(args) 0]
if {$revision ni {sharpx1_turbo_video sharpx1_turbo_z_video}} {
    error "expected an independent X3 video revision"
}
project_open sharpx1 -revision $revision
create_timing_netlist -model fast -temperature -40 -voltage 1100
read_sdc
update_timing_netlist
set source [get_registers {*dimensions_to_sys|held_data*}]
set destination [get_registers {*dimensions_to_sys|destination_data*}]
set source_count [get_collection_size $source]
set destination_count [get_collection_size $destination]
puts "dimensions_to_sys payload registers: source=$source_count destination=$destination_count"
foreach {label collection} [list source $source destination $destination] {
    set bits {}
    foreach_in_collection reg $collection {
        set name [get_register_info -name $reg]
        puts "$label endpoint: $name"
        if {![regexp {\[([0-9]+)\]$} $name -> bit]} {error "unindexed bundle register"}
        lappend bits $bit
    }
    set absent {}
    for {set bit 0} {$bit < 74} {incr bit} {
        if {$bit ni $bits} {lappend absent $bit}
    }
    puts "$label absent bits: $absent"
    if {$absent ne {0 1} || [llength [lsort -unique $bits]] != 72} {
        error "expected exactly bits 2..73: interlace bits 0/1 are tied low by VGA_F1=0"
    }
}
if {$source_count != 72 || $destination_count != 72} {
    error "expected the audited 72 retained dimensions bits on both sides"
}
set prefix output_files/${revision}_snapshot_probe
report_timing -hold -from $source -to $destination -npaths 74 -detail full_path -file ${prefix}_before_hold.rpt
report_timing -setup -from $source -to $destination -npaths 74 -detail full_path -file ${prefix}_before_setup.rpt
# Source holds this publication until the capture launches a new request and
# completes a two-source-period roundtrip. Capture follows at least two SYS
# periods. Try a stricter ONE SYS period (31.25 ns) maximum, not an unlimited
# false path. Quartus 17 max/min delay retain clock latency/skew in the checks;
# full data-delay tables must ALSO be audited against the physical 62.5 ns
# protocol window. Zero minimum removes the arbitrary cross-clock edge
# relationship, not the hold-data requirement of the handshake.
# Optional external copy tests the exact new project constraint on an older
# fit. Default is the checked-in root SDC, relative to this script's directory.
set constraint [lindex $quartus(args) 1]
if {$constraint eq ""} {
    set constraint [file join [file dirname [info script]] .. sharpx1_turbo_z_video.sdc]
}
source $constraint
update_timing_netlist
report_timing -hold -from $source -to $destination -npaths 74 -detail full_path -file ${prefix}_after_hold.rpt
report_timing -setup -from $source -to $destination -npaths 74 -detail full_path -file ${prefix}_after_setup.rpt
report_timing -hold -npaths 30 -detail full_path -file ${prefix}_after_global_hold.rpt
report_timing -setup -npaths 30 -detail full_path -file ${prefix}_after_global_setup.rpt
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        set corner ${prefix}_${model}_${temperature}
        report_timing -setup -from $source -to $destination -npaths 74 -detail full_path -file ${corner}_bundle_setup.rpt
        report_timing -hold -from $source -to $destination -npaths 74 -detail full_path -file ${corner}_bundle_hold.rpt
        report_timing -setup -npaths 10 -detail full_path -file ${corner}_global_setup.rpt
        report_timing -hold -npaths 10 -detail full_path -file ${corner}_global_hold.rpt
    }
}
delete_timing_netlist
project_close
