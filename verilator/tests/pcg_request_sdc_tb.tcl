# Inventory/exception scope test using mocked Quartus collections, not STA.
set candidate [file normalize [file join [file dirname [info script]] .. .. scripts constraints pcg_request_candidate.sdc]]
proc get_registers {pattern} {
    if {[string match {*porta_datain*} $pattern]} {set group data_dest
    } elseif {[string match {*response*} $pattern]} {set group control_dest
    } elseif {[string match {*access_addr*} $pattern]} {set group address_dest
    } elseif {[string match {*plane*} $pattern]} {set group control
    } elseif {[string match {*payload*} $pattern]} {set group payload
    } else {set group address}
    return $::groups($group)
}
proc get_collection_size {collection} {return [llength $collection]}
proc get_register_info {option reg} {return $reg}
proc foreach_in_collection {var collection body} {uplevel 1 [list foreach $var $collection $body]}
proc set_max_delay {args} {lappend ::applied [list max {*}$args]}
proc set_min_delay {args} {lappend ::applied [list min {*}$args]}
set base {emu:emu|sharpx1:sharpx1|x1_pcg_access:cg_bus|}
foreach group {address control payload address_dest control_dest data_dest} {set valid($group) {}}
foreach leaf {plane[0] plane[1] write_request high_speed_request unsupported_request} {lappend valid(control) $base$leaf}
foreach leaf {seen stage.00 stage.01 stage.01~DUPLICATE stage.10} {lappend valid(control_dest) $base$leaf}
for {set i 0} {$i < 12} {incr i} {
    lappend valid(address) $base[format {font_cpu_addr[%d]} $i]
    if {$i < 4} {lappend valid(address) $base[format {frozen_addr[%d]} $i]}
    if {$i < 8} {
        lappend valid(payload) $base[format {payload[%d]} $i]
        lappend valid(control_dest) $base[format {response[%d]} $i]
    }
    if {$i < 11} {
        lappend valid(address_dest) $base[format {access_addr[%d]} $i]
        lappend valid(control_dest) $base[format {access_addr[%d]} $i]
    }
}
foreach color {b r g} {
    for {set i 0} {$i < 64} {incr i} {
        lappend valid(data_dest) "emu|x1_video_ram:pcg_${color}|mock${i}~porta_datain_reg0"
        if {$i < 4} {lappend valid(control_dest) "emu|x1_video_ram:pcg_${color}|mock${i}~porta_we_reg"}
    }
}
foreach group [array names valid] {
    foreach mode {valid missing duplicate extra wrong_identity} {
        array set groups [array get valid]
        switch $mode {
            missing {set groups($group) [lrange $groups($group) 1 end]}
            duplicate {lset groups($group) 0 [lindex $groups($group) 1]}
            extra {lappend groups($group) [lindex $groups($group) 0]}
            wrong_identity {lset groups($group) 0 {wrong|unexpected[0]}}
        }
        set applied {}
        set failed [catch {source $candidate} message]
        if {$mode eq "valid"} {
            if {$failed || [llength $applied] != 6} {error "valid inventory failed: $message"}
            foreach {max min} $applied {
                if {[lindex $max end] != 23.28 || [lindex $min end] != 0 ||
                    [lrange $max 1 end-1] ne [lrange $min 1 end-1]} {error "wrong request bounds"}
            }
        } elseif {!$failed || [llength $applied]} {error "$group/$mode did not refuse every bound"}
    }
}
puts "PASS: three explicit request bounds; 24 invalid inventories refuse all constraints"
