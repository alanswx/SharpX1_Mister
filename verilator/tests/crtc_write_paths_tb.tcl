# Strict reporter coverage mock, not native FPGA timing or MTBF acceptance.
set tool [file normalize [file join [file dirname [info script]] .. .. scripts quartus_crtc_write_paths.tcl]]
package provide ::quartus::project 1
package provide ::quartus::sta 1
foreach name {project_open create_timing_netlist read_sdc update_timing_netlist post_message delete_timing_netlist project_close} {proc $name args {}}
set prefix {emu:emu|sharpx1:sharpx1|x1_crtc_write:x3_crtc.writes|}
set mpu_prefix {emu:emu|sharpx1:sharpx1|x1_vid:display|crtc6845s:crtc6845s|mpu_if:mpu_if|}
set reset_name {emu:emu|sharpx1:sharpx1|x1_reset_release:video_reset_domain.release_reset|release_pipe[1]}
set names {}
foreach field {request request_meta request_sync acknowledgement acknowledgement_meta acknowledgement_sync video_rs pending_write busy done seen} {lappend names ${prefix}$field}
for {set bit 0} {$bit < 9} {incr bit} {lappend names "${prefix}held_packet\[$bit\]"}
for {set bit 0} {$bit < 8} {incr bit} {lappend names "${prefix}video_data\[$bit\]"}
set mpu_names {}
foreach field {R_Nadj R_Nr} {
    for {set bit 0} {$bit < 5} {incr bit} {lappend mpu_names "${mpu_prefix}${field}\[$bit\]"}
}
proc get_registers args {
    set exact [expr {[llength $args] == 2 && [lindex $args 0] eq "-no_duplicates"}]
    if {[llength $args] != 1 && !$exact} {error "unsupported register lookup options"}
    set query [lindex $args end]
    if {$query eq "*x3_crtc.writes*|*"} {
        set result $::names
        if {$::ack_replica} {lappend result ${::prefix}acknowledgement~DUPLICATE}
        switch $::mode {
            missing_request {set result [lreplace $result 0 0]}
            missing_pending {set result [lreplace $result 7 7]}
            duplicate {lappend result [lindex $result 0]}
            extra_packet {lappend result "${::prefix}held_packet\[9\]"}
            missing_packet {set result [lsearch -all -inline -not -exact $result "${::prefix}held_packet\[8\]"]}
            missing_data {set result [lsearch -all -inline -not -exact $result "${::prefix}video_data\[7\]"]}
            wrong_hierarchy {lset result 0 other_path}
            replica {lappend result "${::prefix}request~DUPLICATE"}
        }
        return $result
    }
    if {$query eq "*display*|crtc6845s*|mpu_if*|*"} {
        set result $::mpu_names
        switch $::mode {
            mpu_missing {return {}}
            r5_missing {set result [lrange $result 1 end]}
            r9_missing {set result [lrange $result 0 end-1]}
            mpu_duplicate {lappend result [lindex $result 0]}
        }
        return $result
    }
    if {$::mode eq "lookup_missing"} {return {}}
    if {$::mode eq "lookup_duplicate"} {return [concat $query $query]}
    if {$query eq [list $::reset_name]} {
        if {!$exact} {error "reset keeper lookup not physical"}
        if {$::mode eq "reset_missing"} {return {}}
        return $query
    }
    foreach name $query {
        if {[lsearch -exact $::names $name]<0 && [lsearch -exact $::mpu_names $name]<0 && !($::ack_replica && $name eq "${::prefix}acknowledgement~DUPLICATE")} {error "unexpected exact query $query"}
    }
    if {$::ack_replica && !$exact && $query eq [list ${::prefix}acknowledgement]} {
        return [list ${::prefix}acknowledgement ${::prefix}acknowledgement~DUPLICATE]
    }
    return $query
}
proc get_collection_size regs {llength $regs}
proc get_register_info {option reg} {return $reg}
proc get_fanouts query {
    set name [lindex $query 0]
    if {$name eq $::reset_name} {
        if {$::mode eq "reset_fanout_missing"} {return {}}
        if {$::mode eq "reset_fanout_duplicate"} {return [concat $::mpu_names $::mpu_names]}
        return $::mpu_names
    }
    foreach field {request acknowledgement} {
        if {$name eq "${::prefix}${field}_meta"} {
            if {$::mode eq "fanout_missing"} {return {}}
            if {$::mode eq "fanout_extra"} {return [list ${::prefix}${field}_sync unrelated]}
            if {$::mode eq "fanout_wrong"} {return unrelated}
            return [list ${::prefix}${field}_sync]
        }
        if {$name eq "${::prefix}${field}_sync"} {
            if {$::mode eq "consumer_missing"} {return {}}
            if {$::mode eq "consumer_duplicate"} {return {consumer consumer}}
            return [list ${::prefix}busy ${::prefix}seen]
        }
    }
    if {$name eq "${::prefix}video_rs" || [regexp {\|video_data\[[0-7]\]$} $name] || [lsearch -exact $::mpu_names $name]>=0} {
        if {$::mode eq "endpoint_fanout_missing"} {return {}}
        if {$::mode eq "endpoint_fanout_duplicate"} {return {consumer consumer}}
        return [list ${::mpu_prefix}R_Nr\[0\]]
    }
    error "unexpected fanout source $query"
}
proc get_node_info {option node} {
    if {$option eq "-name"} {return $node}
    if {$::mode eq "fanout_nonreg"} {return pin}
    if {$::mode eq "firstdata_nonreg" && $node eq "${::prefix}request"} {return pin}
    return reg
}
proc get_pins args {
    set result [list ${::prefix}request_meta|d ${::prefix}acknowledgement_meta|asdata]
    if {$::ack_replica} {set result {emu|sharpx1|x3_crtc.writes|request_meta|asdata emu|sharpx1|x3_crtc.writes|acknowledgement_meta|asdata}}
    if {$::mode eq "pin_missing"} {return [lrange $result 0 0]}
    if {$::mode eq "pin_duplicate"} {lappend result [lindex $result 0]}
    return $result
}
proc get_pin_info {option pin} {return $pin}
proc get_fanins query {
    set name [lindex $query 0]
    if {$name eq "${::prefix}acknowledgement" || $name eq "${::prefix}acknowledgement~DUPLICATE"} {
        if {$::mode eq "alias_inputs_missing"} {return {}}
        if {$::mode eq "alias_inputs_differ" && $name eq "${::prefix}acknowledgement~DUPLICATE"} {return wrong_feedback}
        return [list ${::prefix}seen ${::prefix}acknowledgement video_clock]
    }
    if {$::mode eq "data_source_wrong"} {return unrelated}
    if {$::mode eq "data_source_missing"} {return {}}
    if {[string first request_meta [lindex $query 0]]>=0} {return [list ${::prefix}request]}
    if {$::ack_replica && $::mode ne "valid_ack_primary"} {return [list ${::prefix}acknowledgement~DUPLICATE]}
    return [list ${::prefix}acknowledgement]
}
proc foreach_in_collection {var regs body} {uplevel 1 [list foreach $var $regs $body]}
proc set_operating_conditions args {lappend ::corners $args}
proc report_timing args {
    set file [lindex $args [expr {[lsearch -exact $args -file]+1}]]
    if {[dict exists $::reports $file]} {error "duplicate report"}
    dict set ::reports $file $args
}
foreach name {set_false_path set_clock_groups set_max_delay set_min_delay set_multicycle_path} {proc $name args {error "no exceptions allowed"}}
proc run_tool {} {global quartus tool fields; source $tool}
foreach mode {valid valid_ack_replica valid_ack_primary alias_inputs_missing alias_inputs_differ wrong_revision extra_arg missing_request missing_pending duplicate extra_packet missing_packet missing_data wrong_hierarchy replica lookup_missing lookup_duplicate fanout_missing fanout_extra fanout_wrong consumer_missing consumer_duplicate fanout_nonreg firstdata_nonreg mpu_missing r5_missing r9_missing mpu_duplicate endpoint_fanout_missing endpoint_fanout_duplicate pin_missing pin_duplicate data_source_wrong data_source_missing reset_missing reset_fanout_missing reset_fanout_duplicate} {
    set ack_replica [expr {$mode in {valid_ack_replica valid_ack_primary alias_inputs_missing alias_inputs_differ}}]
    set quartus(args) sharpx1_turbo_z_video
    if {$mode eq "wrong_revision"} {set quartus(args) sharpx1}
    if {$mode eq "extra_arg"} {lappend quartus(args) candidate.sdc}
    set reports {}; set corners {}
    set failed [catch {run_tool} message]
    if {$mode ni {valid valid_ack_replica valid_ack_primary}} {
        if {!$failed || [dict size $reports] || [llength $corners]} {error "$mode accepted invalid inventory: $message"}
        continue
    }
    if {$failed} {error $message}
    if {[dict size $reports]!=192 || [llength $corners]!=8} {error "wrong coverage"}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {
            foreach check {setup hold} {
                foreach kind {request_input request_chain request_first_fanout request_consumer ack_input ack_chain ack_first_fanout ack_consumer packet capture_consumer mpu_input mpu_consumer} {
                    set file output_files/sharpx1_turbo_z_video_crtc_write_${model}_${temperature}_${kind}_${check}.rpt
                    if {![dict exists $reports $file]} {error "missing report"}
                    set args [dict get $reports $file]
                    if {[lindex $args 0] ne "-$check" || [lindex $args [expr {[lsearch -exact $args -npaths]+1}]]!=10000} {error "wrong check/cap"}
                    set fi [lsearch -exact $args -from]; set ti [lsearch -exact $args -to]
                    set from [lindex $args [expr {$fi+1}]]; set to [lindex $args [expr {$ti+1}]]
                    switch $kind {
                        request_input {if {$from ne [list ${prefix}request] || $to ne [list ${prefix}request_meta]} {error "wrong request source"}}
                        request_chain {if {$from ne [list ${prefix}request_meta] || $to ne [list ${prefix}request_sync]} {error "wrong request chain"}}
                        ack_input {
                            set expected acknowledgement
                            if {$mode eq "valid_ack_replica"} {set expected acknowledgement~DUPLICATE}
                            if {$from ne [list ${prefix}$expected] || $to ne [list ${prefix}acknowledgement_meta]} {error "wrong ACK source"}
                        }
                        ack_chain {if {$from ne [list ${prefix}acknowledgement_meta] || $to ne [list ${prefix}acknowledgement_sync]} {error "wrong ACK chain"}}
                        packet {
                            if {[llength $from]!=9 || [llength $to]!=9} {error "wrong packet width"}
                            for {set bit 0} {$bit<9} {incr bit} {
                                if {[lsearch -exact $from "${prefix}held_packet\[$bit\]"]<0} {error "missing source bit"}
                            }
                            if {[lsearch -exact $to ${prefix}video_rs]<0} {error "missing RS target"}
                            for {set bit 0} {$bit<8} {incr bit} {
                                if {[lsearch -exact $to "${prefix}video_data\[$bit\]"]<0} {error "missing data target"}
                            }
                        }
                        mpu_input {if {$fi>=0 || $to ne $mpu_names} {error "wrong MPU input"}}
                        mpu_consumer {if {$ti>=0 || $from ne $mpu_names} {error "wrong MPU consumers"}}
                        request_first_fanout {if {$ti>=0 || $from ne [list ${prefix}request_meta]} {error "wrong first request fanout"}}
                        request_consumer {if {$ti>=0 || $from ne [list ${prefix}request_sync]} {error "wrong request consumer"}}
                        ack_first_fanout {if {$ti>=0 || $from ne [list ${prefix}acknowledgement_meta]} {error "wrong first ACK fanout"}}
                        ack_consumer {if {$ti>=0 || $from ne [list ${prefix}acknowledgement_sync]} {error "wrong ACK consumer"}}
                        capture_consumer {
                            if {$ti>=0 || [llength $from]!=9 || [lsearch -exact $from ${prefix}video_rs]<0} {error "wrong capture consumer width/RS"}
                            for {set bit 0} {$bit<8} {incr bit} {
                                if {[lsearch -exact $from "${prefix}video_data\[$bit\]"]<0} {error "missing captured data bit"}
                            }
                        }
                    }
                }
            }
        }
    }
}
puts "PASS: CRTC reporter 192 scopes/eight corners, physical primary/replica and local reset profiles, 34 rejected inventories; no exceptions (mock only)"
