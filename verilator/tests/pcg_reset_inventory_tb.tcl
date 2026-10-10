# Mocked discovery/scope regression, not Quartus timing evidence.
package provide ::quartus::project 1
package provide ::quartus::sta 1
namespace eval quartus {variable args}
if {[llength $argv] != 1} {error "expected temporary test directory"}
set root [lindex $argv 0]
set reporter [file normalize [file join [file dirname [info script]] .. .. scripts quartus_pcg_reset_inventory.tcl]]
foreach command {project_open create_timing_netlist read_sdc update_timing_netlist set_operating_conditions delete_timing_netlist project_close} {
    proc $command {args} {}
}
proc get_collection_size collection {return [llength $collection]}
proc foreach_in_collection {var collection body} {uplevel 1 [list foreach $var $collection $body]}
proc get_register_info {option reg} {return $reg}
proc get_node_info {option node} {if {$option eq "-name"} {return $node};return reg}
proc get_fanins {args} {
    if {$::mode eq "no_fanins"} {return {}}
    if {[lindex $args 0] ne "-synch"} {error "missing registered fanin query"}
    return {mock_registered_source}
}
proc get_registers {args} {
    set query [lindex $args end]
    if {$query eq {*x1_video_ram:pcg_*|*}} {return $::ram}
    if {$query eq {*hps_io:hps_io|ioctl_download*}} {return $::raw}
    if {[string match {*release_pipe*} $query]} {return $::reset_pipes}
    if {$::mode eq "ambiguous_targets"} {return [lrange $query 1 end]}
    return $query
}
proc report_clocks {args} {incr ::clock_reports}
proc report_timing {args} {
    if {[lsearch -exact $args -npaths] < 0 || [lindex $args [expr {[lsearch -exact $args -npaths]+1}]] != 10000} {
        error "lost exhaustive report cap"
    }
    if {[lsearch -exact $args -to] >= 0 &&
        [llength [lindex $args [expr {[lsearch -exact $args -to]+1}]]] != 12} {
        error "partial RAM WE report scope"
    }
    lappend ::reports $args
}
set good_ram {}
foreach plane {b r g} {
    for {set n 0} {$n < 4} {incr n} {
        lappend good_ram "emu:emu|sharpx1:sharpx1|x1_video_ram:pcg_${plane}|mock${n}~porta_we_reg"
    }
}
set good_pipes {}
foreach bit {0 1} {lappend good_pipes [format {emu:emu|sharpx1:sharpx1|x1_reset_release:video_reset_domain.release_reset|release_pipe[%d]} $bit]}
set rejected 0
foreach mode {valid missing_we duplicate_we extra_we alias_we wrong_plane ambiguous_targets missing_reset alias_reset duplicate_raw alias_raw no_fanins} {
    set ram $good_ram;set reset_pipes $good_pipes
    set raw {emu:emu|hps_io:hps_io|ioctl_download}
    switch $mode {
        missing_we {set ram [lrange $ram 1 end]}
        duplicate_we {lset ram 0 [lindex $ram 1]}
        extra_we {lappend ram {emu:emu|sharpx1:sharpx1|x1_video_ram:pcg_b|extra~porta_we_reg}}
        alias_we {lset ram 0 {emu:emu|sharpx1:sharpx1|x1_video_ram:pcg_b|mock0~porta_we_reg~DUPLICATE}}
        wrong_plane {lset ram 0 {emu:emu|sharpx1:sharpx1|x1_video_ram:pcg_x|mock0~porta_we_reg}}
        missing_reset {set reset_pipes [lrange $reset_pipes 1 end]}
        alias_reset {lset reset_pipes 0 {wrong|release_pipe[0]}}
        duplicate_raw {lappend raw {emu:emu|hps_io:hps_io|ioctl_download~DUPLICATE}}
        alias_raw {set raw {wrong|ioctl_download}}
    }
    set quartus(args) [list [file join $root $mode]]
    set reports {};set clock_reports 0
    set failed [catch {source $reporter} message]
    if {$mode eq "valid"} {
        if {$failed || [llength $reports] != 64 || $clock_reports != 1} {error "valid discovery failed: $message"}
        set files {}
        foreach report $reports {lappend files [lindex $report end]}
        if {[llength [lsort -unique $files]] != 64} {error "duplicate report destinations"}
    } else {
        if {!$failed || [llength $reports] || $clock_reports || [file exists [lindex $quartus(args) 0]]} {
            error "invalid $mode did not reject before producing evidence"
        }
        incr rejected
    }
}
puts "PASS: 64-report PCG reset discovery plan; $rejected invalid scopes refuse all reports; mocked not STA"
