# Reporting only on an idle, completed experimental Z fit. No exceptions.
# Preserve original flow/global timing reports before supplemental STA.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1 || [lindex $quartus(args) 0] ne "sharpx1_turbo_z_video"} {
    error "expected experimental Z revision only"
}
set revision [lindex $quartus(args) 0]
project_open sharpx1 -revision $revision
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set fields [dict create]
set prefixes {}
set packet_bits {}; set data_bits {}
foreach_in_collection reg [get_registers {*x3_crtc.writes*|*}] {
    set name [get_register_info -name $reg]
    if {![regexp {^(.*x1_crtc_write:x3_crtc\.writes\|)([^|]+)$} $name -> prefix field]} {
        error "unexpected CRTC transport hierarchy/replica: $name"
    }
    if {$field ni {request request_meta request_sync acknowledgement acknowledgement_meta acknowledgement_sync video_rs pending_write busy done seen} &&
        ![regexp {^(held_packet|video_data)\[[0-9]+\]$} $field]} {
        error "unexpected/replicated CRTC transport field: $field"
    }
    lappend prefixes $prefix
    if {[dict exists $fields $field]} {error "duplicate CRTC transport field: $field"}
    dict set fields $field $name
    if {[regexp {^held_packet\[([0-9]+)\]$} $field -> bit]} {lappend packet_bits $bit}
    if {[regexp {^video_data\[([0-9]+)\]$} $field -> bit]} {lappend data_bits $bit}
    post_message "CRTC transport register $field $name"
}
if {[llength [lsort -unique $prefixes]] != 1 ||
    [lsort -integer $packet_bits] ne {0 1 2 3 4 5 6 7 8} ||
    [lsort -integer $data_bits] ne {0 1 2 3 4 5 6 7}} {
    error "expected unique nine-bit packet and eight-bit destination data"
}
foreach field {request request_meta request_sync acknowledgement acknowledgement_meta acknowledgement_sync video_rs pending_write} {
    if {![dict exists $fields $field]} {error "missing CRTC field $field"}
}
proc crtc_reg {field} {
    set name [dict get $::fields $field]
    set result [get_registers [list $name]]
    if {[get_collection_size $result] != 1} {error "CRTC endpoint lookup not unique: $name"}
    return $result
}
set packet_names {}; set capture_names [list [dict get $fields video_rs]]
for {set bit 0} {$bit < 9} {incr bit} {
    crtc_reg "held_packet\[$bit\]"
    lappend packet_names [dict get $fields "held_packet\[$bit\]"]
    if {$bit < 8} {
        crtc_reg "video_data\[$bit\]"
        lappend capture_names [dict get $fields "video_data\[$bit\]"]
    }
}
set packet [get_registers $packet_names]
set capture [get_registers $capture_names]
if {[get_collection_size $packet] != 9 || [get_collection_size $capture] != 9} {
    error "CRTC bundle group lookup changed width"
}
foreach pair {{request_meta request_sync} {acknowledgement_meta acknowledgement_sync}} {
    lassign $pair first last
    set nodes {}
    foreach_in_collection node [get_fanouts [list [dict get $fields $first]]] {
        if {[get_node_info -type $node] ne "reg"} {error "CRTC first stage has non-register fanout"}
        lappend nodes [get_node_info -name $node]
    }
    if {$nodes ne [list [dict get $fields $last]]} {error "CRTC first stage escapes its synchronizer"}
    post_message "CRTC native fanout $first $nodes"
    set nodes {}
    foreach_in_collection node [get_fanouts [list [dict get $fields $last]]] {
        if {[get_node_info -type $node] ne "reg"} {error "CRTC final stage has non-register fanout"}
        lappend nodes [get_node_info -name $node]
    }
    if {![llength $nodes] || [llength $nodes] != [llength [lsort -unique $nodes]]} {
        error "CRTC final-stage fanout missing/duplicated"
    }
    post_message "CRTC native fanout $last $nodes"
}
set mpu [get_registers {*display*|crtc6845s*|mpu_if*|*}]
if {![get_collection_size $mpu]} {error "missing actual CRTC MPU registers"}
set nadj {}; set nr {}; set mpu_names {}
foreach_in_collection reg $mpu {
    set name [get_register_info -name $reg]
    if {[lsearch -exact $mpu_names $name] >= 0} {error "duplicate MPU endpoint"}
    lappend mpu_names $name
    if {[regexp {\|R_Nadj\[([0-9]+)\]$} $name -> bit]} {lappend nadj $bit}
    if {[regexp {\|R_Nr\[([0-9]+)\]$} $name -> bit]} {lappend nr $bit}
    post_message "CRTC MPU register $name"
}
if {[lsort -integer $nadj] ne {0 1 2 3 4} || [lsort -integer $nr] ne {0 1 2 3 4}} {
    error "missing/replicated CRTC R5/R9 consumer bits"
}
# Native pin/fanin observations do not authorize exceptions or prove MTBF.
set data_pins [dict create request_meta 0 acknowledgement_meta 0]
foreach_in_collection pin [get_pins -compatibility_mode {*x3_crtc.writes*|*}] {
    set name [get_pin_info -name $pin]
    post_message "CRTC native pin $name"
    if {[regexp {\|(request_meta|acknowledgement_meta)\|(d|asdata)$} $name -> field pin_kind]} {
        dict incr data_pins $field
        set fanin_names {}
        foreach_in_collection node [get_fanins [list $name]] {
            lappend fanin_names [get_node_info -name $node]
            post_message "CRTC first-data fanin $name [get_node_info -name $node] ([get_node_info -type $node])"
        }
        set source [expr {$field eq "request_meta" ? "request" : "acknowledgement"}]
        if {$fanin_names ne [list [dict get $fields $source]]} {error "unexpected CRTC first-stage data source"}
    }
}
if {[dict get $data_pins request_meta] != 1 || [dict get $data_pins acknowledgement_meta] != 1} {
    error "missing/duplicate CRTC first-stage data pins"
}
set paths [dict create \
    request_input [list -from [crtc_reg request] -to [crtc_reg request_meta]] \
    request_chain [list -from [crtc_reg request_meta] -to [crtc_reg request_sync]] \
    request_first_fanout [list -from [crtc_reg request_meta]] \
    request_consumer [list -from [crtc_reg request_sync]] \
    ack_input [list -from [crtc_reg acknowledgement] -to [crtc_reg acknowledgement_meta]] \
    ack_chain [list -from [crtc_reg acknowledgement_meta] -to [crtc_reg acknowledgement_sync]] \
    ack_first_fanout [list -from [crtc_reg acknowledgement_meta]] \
    ack_consumer [list -from [crtc_reg acknowledgement_sync]] \
    packet [list -from $packet -to $capture] \
    capture_consumer [list -from $capture] \
    mpu_input [list -to $mpu] \
    mpu_consumer [list -from $mpu]]
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        foreach check {setup hold} {
            dict for {kind scope} $paths {
                set file output_files/${revision}_crtc_write_${model}_${temperature}_${kind}_${check}.rpt
                report_timing -$check {*}$scope -npaths 10000 -detail full_path -file $file
            }
        }
    }
}
delete_timing_netlist
project_close
