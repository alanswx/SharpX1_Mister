# Coverage/order of the actual optional probe and actual candidate, mocked.
source [file join [file dirname [info script]] vsync_sys_paths_tb.tcl]
set candidate_path [file normalize [file join [file dirname [info script]] .. .. scripts constraints vsync_sys_input_candidate.sdc]]
proc get_pins {option query} {
    if {[string first "*" $query]<0} {return $query}
    return [list {hdmi_vsync_to_sys|sample_pipe[0]|asdata} {hdmi_vsync_to_sys|sample_pipe[0]|clk} {hdmi_vsync_to_sys|sample_pipe[0]|q} {hdmi_vsync_to_sys|sample_pipe[1]|d}]
}
proc get_pin_info {option pin} {return $pin}
proc get_fanins {query} {
    if {$query ne [list {hdmi_vsync_to_sys|sample_pipe[0]|asdata}]} {error "wrong fanin query"}
    return {hdmi_out_vs~_Duplicate_1}
}
proc set_false_path args {
    if {[dict size $::reports]!=80} {error "exception before complete baseline"}
    if {$args ne [list -from {hdmi_out_vs~_Duplicate_1} -to [list {hdmi_vsync_to_sys|sample_pipe[0]|asdata}]]} {error "wrong actual candidate cut"}
    lappend ::cuts $args
}
set mode valid
set quartus(args) [list sharpx1_turbo_z_video $candidate_path]
set corners {}; set reports {}; set cuts {}
run_tool
if {[llength $corners]!=16 || [dict size $reports]!=160 || [llength $cuts]!=1} {error "wrong paired report/cut coverage"}
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        foreach kind {input chain first_fanout consumer global} {
            foreach check {setup hold} {
                set before output_files/sharpx1_turbo_z_video_vsync_sys_probe_before_${model}_${temperature}_${kind}_${check}.rpt
                set after [string map {probe_before probe_after} $before]
                if {![dict exists $reports $before] || ![dict exists $reports $after]} {error "missing paired scope"}
                if {[string map {probe_before probe_after} [dict get $reports $before]] ne [dict get $reports $after]} {error "scope changed across probe"}
                if {$kind eq "global"} {
                    set args [dict get $reports $after]
                    if {[lsearch -exact $args -from]>=0 || [lsearch -exact $args -to]>=0 || [lindex $args [expr {[lsearch -exact $args -npaths]+1}]]!=100} {error "wrong global report scope"}
                }
            }
        }
    }
}
puts "PASS: 160 paired scopes, actual input-only candidate after 80 baseline reports; mock only"
