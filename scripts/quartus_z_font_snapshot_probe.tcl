# Reporting/probe only on a COPY of a completed external-font fit.
# An explicit, already-reviewed payload SDC is applied in memory only in probe
# mode. Optional 'integrated' mode requires it already assigned, and adds none.
# No QSF assignment, fitter run, RBF change or full timing acceptance here.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] ni {2 3}} {error "expected NEW report directory, explicit snapshot SDC, optional integrated"}
set destination [lindex $quartus(args) 0]
set candidate [file normalize [lindex $quartus(args) 1]]
set integrated [expr {[llength $quartus(args)] == 3}]
if {$integrated && [lindex $quartus(args) 2] ne "integrated"} {error "unknown timing mode"}
if {[file exists $destination]} {error "refusing to overwrite evidence"}
if {![file isfile $candidate]} {error "missing snapshot SDC"}
set summary_file [open output_files/sharpx1_turbo_z_font.fit.summary r]
set fit_summary [read $summary_file]
close $summary_file
if {![regexp -line {^Fitter Status : Successful( |$)} $fit_summary]} {
    error "reporter requires a successful completed fit, never mapped fallback"
}
project_open sharpx1 -revision sharpx1_turbo_z_font
if {$integrated} {
    set assigned 0
    set allowed {sharpx1_turbo_z_video.sdc sharpx1_turbo_z_font.sdc}
    if {[file tail $candidate] ni $allowed} {error "unrecognized integrated snapshot SDC"}
    foreach_in_collection assignment [get_all_global_assignments -name SDC_FILE] {
        set path [lindex $assignment 2]
        if {$path in $allowed} {
            incr assigned
            if {[file normalize $path] ne $candidate} {error "integrated SDC differs from assigned file"}
        }
    }
    if {$assigned != 1} {error "integrated snapshot SDC must be assigned exactly once"}
    puts "FONT SNAPSHOT MODE integrated: original assigned SDC only, no added exceptions"
}
create_timing_netlist -model fast -temperature -40 -voltage 1100
read_sdc
update_timing_netlist
set source [get_registers {*dimensions_to_sys|held_data*}]
set target [get_registers {*dimensions_to_sys|destination_data*}]
# The exact candidate also validates each retained bit before any bound.
# Record identities independently before loading it, including clock periods.
file mkdir $destination
set inventory [open [file join $destination inventory.txt] w]
foreach {kind collection} [list source $source target $target] {
    puts $inventory "$kind [get_collection_size $collection]"
    foreach_in_collection reg $collection {puts $inventory "  [get_register_info -name $reg]"}
}
close $inventory
report_clocks -file [file join $destination clocks.rpt]
foreach check {setup hold} {
    report_timing -$check -from $source -to $target -npaths 100 -detail full_path \
        -file [file join $destination before_${check}.rpt]
}
if {!$integrated} {
    source $candidate
    update_timing_netlist
}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        puts "FONT SNAPSHOT CORNER $model $temperature 1100"
        foreach check {setup hold} {
            report_timing -$check -from $source -to $target -npaths 100 -detail full_path \
                -file [file join $destination ${model}_${temperature}_bundle_${check}.rpt]
        }
        foreach check {setup hold recovery removal} {
            report_timing -$check -npaths 30 -detail full_path \
                -file [file join $destination ${model}_${temperature}_global_${check}.rpt]
        }
    }
}
puts "FONT SNAPSHOT PROBE COMPLETE: selected bus remains timed; other violations remain open"
delete_timing_netlist
project_close -dont_export_assignments
