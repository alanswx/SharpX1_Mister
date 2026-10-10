# Mocked scope/guard tests; not native timing or physical CDC qualification.
set candidate [file normalize [file join [file dirname [info script]] .. .. scripts constraints vsync_sys_input_candidate.sdc]]
set first {x1_vsync_sys:hdmi_vsync_to_sys|sample_pipe[0]}
set last {x1_vsync_sys:hdmi_vsync_to_sys|sample_pipe[1]}
set raw {hdmi_out_vs~_Duplicate_1}
proc get_registers {query} {
    if {[string first "*" $query]<0} {
        if {$::mode eq "source_lookup_missing"} {return {}}
        if {$::mode eq "source_lookup_duplicate"} {return [concat $query $query]}
        return $query
    }
    switch $::mode {
        missing_stage {return [list $::first]}
        duplicate_stage {return [list $::first $::first]}
        extra_stage {return [list $::first $::last $::last]}
        wrong_stage {return [list $::first {x1_vsync_sys:hdmi_vsync_to_sys|sample_pipe[2]}]}
        replica {return [list $::first "$::last~DUPLICATE"]}
    }
    return [list $::first $::last]
}
proc get_fanouts {query} {
    if {$query eq [list $::first]} {
        if {$::mode eq "first_leak"} {return [list $::last vsd]}
        return [list $::last]
    }
    if {$::mode eq "consumer_missing"} {return {vs_d0 vsd}}
    if {$::mode eq "consumer_replica"} {return {vs_d0 vs_d1 vsd vs_d1~DUPLICATE}}
    return {vs_d0 vs_d1 vsd}
}
proc get_pins {option query} {
    if {[string first "*" $query]<0} {
        if {$::mode eq "pin_lookup_missing"} {return {}}
        if {$::mode eq "pin_lookup_duplicate"} {return [concat $query $query]}
        return $query
    }
    set data [format {hdmi_vsync_to_sys|sample_pipe[0]|%s} $::data_kind]
    set result [list $data {hdmi_vsync_to_sys|sample_pipe[0]|clk} {hdmi_vsync_to_sys|sample_pipe[0]|q} {hdmi_vsync_to_sys|sample_pipe[1]|d}]
    switch $::mode {
        missing_pin {set result [lrange $result 1 end]}
        duplicate_pin {lappend result $data}
        double_data {lappend result {hdmi_vsync_to_sys|sample_pipe[0]|d}}
        wrong_bit {lset result 0 {hdmi_vsync_to_sys|sample_pipe[2]|asdata}}
    }
    return $result
}
proc get_fanins {query} {
    if {$::mode eq "fanin_missing"} {return {}}
    if {$::mode eq "clock_fanin"} {return [list $::raw FPGA_CLK2_50]}
    if {$::mode eq "wrong_source"} {return {some_other_data}}
    return [list $::raw]
}
proc get_node_info {option node} {
    if {$option eq "-name"} {return $node}
    if {$::mode eq "wrong_type"} {return port}
    return reg
}
proc get_collection_size {collection} {llength $collection}
proc get_pin_info {option pin} {return $pin}
proc get_register_info {option reg} {return $reg}
proc foreach_in_collection {var collection body} {uplevel 1 [list foreach $var $collection $body]}
proc post_message args {}
proc set_false_path args {lappend ::applied $args}
foreach name {set_clock_groups set_max_delay set_min_delay set_multicycle_path} {proc $name args {error "unexpected exception"}}
foreach mode {valid_asdata valid_d valid_primary missing_stage duplicate_stage extra_stage wrong_stage replica first_leak consumer_missing consumer_replica missing_pin duplicate_pin double_data wrong_bit pin_lookup_missing pin_lookup_duplicate fanin_missing clock_fanin wrong_source wrong_type source_lookup_missing source_lookup_duplicate} {
    set data_kind asdata
    set raw {hdmi_out_vs~_Duplicate_1}
    if {$mode eq "valid_d"} {set data_kind d}
    if {$mode eq "valid_primary"} {set data_kind d; set raw hdmi_out_vs}
    set applied {}
    set failed [catch {source $candidate} message]
    if {[string match "valid_*" $mode]} {
        set pin [format {hdmi_vsync_to_sys|sample_pipe[0]|%s} $data_kind]
        if {$failed || $applied ne [list [list -from [list $raw] -to [list $pin]]]} {error "wrong input-only scope: $message"}
    } elseif {!$failed || [llength $applied]} {error "$mode accepted invalid scope"}
    if {$mode eq "consumer_replica" && $message ne "VSYNC fanout identity changed"} {
        error "exact four-consumer replica did not hit fanout identity guard before cuts"
    }
}
puts "PASS: VSYNC source-to-one-data-pin scope, d/asdata; 20 invalid inventories reject (mock only)"
