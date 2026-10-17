# Reporting only: synchronous data fanout of the font VID reset release.
# Assigned constraints only. Run on a private copy of a completed font fit.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1} {error "expected NEW report directory"}
set destination [lindex $quartus(args) 0]
if {[file exists $destination]} {error "refusing to overwrite evidence"}
set f [open output_files/sharpx1_turbo_z_font.fit.summary r]
set summary [read $f]
close $f
if {![regexp -line {^Fitter Status : Successful( |$)} $summary]} {error "completed successful fit required"}
project_open sharpx1 -revision sharpx1_turbo_z_font
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set name {emu:emu|sharpx1:sharpx1|x1_reset_release:video_reset_domain.release_reset|release_pipe[1]}
set source [get_registers -no_duplicates [list $name]]
if {[get_collection_size $source] != 1} {error "missing unique second-stage release"}
foreach_in_collection reg $source {
    if {[get_register_info -name $reg] ne $name} {error "unexpected release alias"}
}
file mkdir $destination
set f [open [file join $destination inventory.txt] w]
foreach_in_collection node [get_fanouts $source] {
    puts $f "[get_node_info -name $node] ([get_node_info -type $node])"
}
close $f
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        puts "FONT RELEASE DATA CORNER $model $temperature 1100"
        foreach check {setup hold} {
            report_timing -$check -from $source -npaths 10000 -detail full_path \
                -file [file join $destination ${model}_${temperature}_${check}.rpt]
        }
    }
}
puts "FONT RELEASE DATA COMPLETE: assigned SDC only; not physical fanout acceptance"
delete_timing_netlist
project_close -dont_export_assignments
