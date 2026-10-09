# Mocked view/refusal behavior. Neither native mapped nor fitted evidence.
source [file join [file dirname [info script]] vsync_sys_input_sdc_tb.tcl]
package provide ::quartus::project 1
package provide ::quartus::sta 1
set tool [file normalize [file join [file dirname [info script]] .. .. scripts quartus_vsync_sys_inventory.tcl]]
set candidate_path $candidate
set test_root [file normalize [file join [lindex $argv 0] vsync-inventory-test-[pid]-[clock clicks]]]
file mkdir $test_root
set original_cwd [pwd]
proc project_open args {incr ::opened}
proc create_timing_netlist args {lappend ::created $args}
proc delete_timing_netlist args {}
proc project_close args {}
proc run_inventory {} {global tool quartus; source $tool}
foreach control {mapped fitted fit_rpt fit_summary sof bad_revision bad_view} {
    set directory [file join $test_root $control]
    file mkdir $directory
    cd $directory
    set view mapped
    if {$control eq "fitted"} {set view fitted}
    if {$control in {fit_rpt fit_summary sof}} {
        file mkdir output_files
        set suffix [string map {_ .} $control]
        set fixture [open output_files/sharpx1_turbo_z_video.$suffix w]
        puts $fixture "test-only stale fitter output marker"
        close $fixture
    }
    set revision sharpx1_turbo_z_video
    if {$control eq "bad_revision"} {set revision sharpx1}
    if {$control eq "bad_view"} {set view unknown}
    set quartus(args) [list $revision $view $candidate_path]
    set mode valid_asdata; set data_kind asdata
    set opened 0; set created {}; set applied {}
    set failed [catch {run_inventory} message]
    if {$control in {mapped fitted}} {
        if {$failed || $opened!=1 || [llength $created]!=1 || [llength $applied]!=1} {error "valid $control rejected: $message"}
        if {$view eq "mapped" && $created ne [list {-post_map}]} {error "wrong mapped view"}
        if {$view eq "fitted" && $created ne [list {-model slow -temperature 100 -voltage 1100}]} {error "wrong fitted view"}
    } elseif {!$failed || $opened || [llength $created] || [llength $applied]} {error "invalid $control reached netlist or exception"}
}
cd $original_cwd
puts "PASS: mapped/fitted view selection; stale fit.rpt/fit.summary/sof and invalid configuration rejected before netlist (mock only)"
