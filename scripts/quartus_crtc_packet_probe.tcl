# Completed-fit before/after analysis only. No project or RBF changes.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 2 || [lindex $quartus(args) 0] ne "sharpx1_turbo_z_video" ||
    [file tail [lindex $quartus(args) 1]] ne "crtc_packet_candidate.sdc"} {
    error "expected experimental Z revision and explicit CRTC packet candidate"
}
set revision [lindex $quartus(args) 0]
set candidate [lindex $quartus(args) 1]
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set transport {emu:emu|sharpx1:sharpx1|x1_crtc_write:x3_crtc.writes|}
set packet_names {}; set capture_names [list ${transport}video_rs]
for {set bit 0} {$bit < 9} {incr bit} {
    lappend packet_names "${transport}held_packet\[$bit\]"
    if {$bit < 8} {lappend capture_names "${transport}video_data\[$bit\]"}
}
set packet [get_registers $packet_names]; set capture [get_registers $capture_names]
if {[get_collection_size $packet] != 9 || [get_collection_size $capture] != 9} {error "unexpected packet width/replicas"}
set request [get_registers -no_duplicates [list ${transport}request]]
set request_meta [get_registers -no_duplicates [list ${transport}request_meta]]
set ack_meta [get_registers -no_duplicates [list ${transport}acknowledgement_meta]]
set ack_pin_names {}
foreach_in_collection pin [get_pins -compatibility_mode {*x3_crtc.writes*|acknowledgement_meta|*}] {
    set name [get_pin_info -name $pin]
    if {[regexp {\|(d|asdata)$} $name]} {lappend ack_pin_names $name}
}
if {[llength $ack_pin_names] != 1} {error "missing/ambiguous native ACK data pin identity"}
set ack_pin [get_pins -compatibility_mode $ack_pin_names]
if {[get_collection_size $ack_pin] != 1} {error "missing/ambiguous actual ACK data pin"}
set ack_names {}
foreach_in_collection node [get_fanins $ack_pin] {
    if {[get_node_info -type $node] ne "reg"} {error "ACK first-data source is not a register"}
    lappend ack_names [get_node_info -name $node]
}
if {[llength $ack_names] != 1 || [lindex $ack_names 0] ni [list ${transport}acknowledgement ${transport}acknowledgement~DUPLICATE]} {
    error "unexpected actual ACK source"
}
set ack [get_registers -no_duplicates $ack_names]
foreach collection [list $request $request_meta $ack $ack_meta] {
    if {[get_collection_size $collection] != 1} {error "ambiguous input endpoint"}
}
post_message "CRTC packet probe actual ACK source [lindex $ack_names 0]"
set scopes [dict create packet [list -from $packet -to $capture] \
    request_input [list -from $request -to $request_meta] \
    ack_input [list -from $ack -to $ack_meta] global {}]
foreach stage {before after} {
    if {$stage eq "after"} {source $candidate; update_timing_netlist}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            set_operating_conditions -model $model -temperature $temperature -voltage 1100
            update_timing_netlist
            foreach check {setup hold} {
                dict for {kind scope} $scopes {
                    report_timing -$check {*}$scope -npaths 100 -detail full_path \
                        -file output_files/${revision}_crtc_packet_probe_${stage}_${model}_${temperature}_${kind}_${check}.rpt
                }
            }
        }
    }
}
delete_timing_netlist
project_close
