# Synthetic candidate-scope controls only; not native timing acceptance.
set candidate [file normalize [file join [file dirname [info script]] .. .. scripts constraints crtc_packet_candidate.sdc]]
set prefix {emu:emu|sharpx1:sharpx1|x1_crtc_write:x3_crtc.writes|}
set sys {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set vid {emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set valid_src {}; set valid_dst [list ${prefix}video_rs]
for {set bit 0} {$bit < 9} {incr bit} {
    lappend valid_src "${prefix}held_packet\[$bit\]"
    if {$bit < 8} {lappend valid_dst "${prefix}video_data\[$bit\]"}
}
proc get_registers args {
    set query [lindex $args end]
    if {$query eq "*x1_crtc_write:x3_crtc.writes|held_packet*"} {return $::src}
    if {$query eq "*x1_crtc_write:x3_crtc.writes|video_data* *x1_crtc_write:x3_crtc.writes|video_rs*"} {return $::dst}
    if {[llength $args] != 2 || [lindex $args 0] ne "-no_duplicates"} {error "physical lookup required"}
    if {$::mode eq "lookup_missing"} {return {}}
    if {$::mode eq "lookup_duplicate"} {return [concat $query $query]}
    if {$::mode eq "lookup_identity"} {return other_keeper}
    return $query
}
proc get_clocks query {
    if {$::mode eq "clock_missing"} {return {}}
    if {$::mode eq "clock_duplicate"} {return [concat $query $query]}
    if {$::mode eq "clock_identity"} {return wrong_clock}
    return $query
}
proc get_clock_info {option clock} {
    if {$option eq "-name"} {return $clock}
    if {$::mode eq "clock_nan"} {return NaN}
    if {$::mode eq "clock_inf"} {return Inf}
    if {$::mode eq "clock_nonnumeric"} {return bogus}
    if {$::mode eq "clock_sys_slow" && $clock eq $::sys} {return 35}
    if {$::mode eq "clock_vid_slow" && $clock eq $::vid} {return 35}
    return [expr {$clock eq $::sys ? 31.25 : 23.280423}]
}
proc get_fanins collection {
    set target [lindex $collection 0]
    set bit 8
    regexp {video_data\[([0-7])\]$} $target -> bit
    set input "${::prefix}held_packet\[$bit\]"
    if {$::mode eq "route_missing"} {return {}}
    if {$::mode eq "route_wrong"} {return [list "${::prefix}held_packet\[9\]"]}
    if {$::mode eq "route_duplicate"} {return [list $input $input]}
    if {$::mode eq "route_crossbit"} {return [list $input "${::prefix}held_packet\[9\]"]}
    if {$::mode eq "route_replica"} {return [list $input ${input}~DUPLICATE]}
    return [list $input control_keeper]
}
proc get_node_info {option node} {
    if {$option eq "-name"} {return $node}
    return [expr {$::mode eq "route_nonreg" ? "port" : "reg"}]
}
proc get_register_info {option node} {return $node}
proc get_collection_size collection {llength $collection}
proc add_to_collection {a b} {return [lsort -unique [concat $a $b]]}
proc foreach_in_collection {var collection body} {uplevel 1 [list foreach $var $collection $body]}
proc set_max_delay args {lappend ::applied [list max {*}$args]}
proc set_min_delay args {lappend ::applied [list min {*}$args]}
foreach cmd {set_false_path set_clock_groups set_multicycle_path} {proc $cmd args {error "forbidden CDC waiver"}}
set rejected 0
foreach field {src dst} {
    foreach mode {valid missing duplicate extra replica wrong_bit wrong_hierarchy wrong_field} {
        set src $valid_src; set dst $valid_dst
        set value [set $field]
        switch $mode {
            missing {set value [lrange $value 1 end]}
            duplicate {lset value 0 [lindex $value 1]}
            extra {lappend value [lindex $value 0]}
            replica {lset value 0 [lindex $value 0]~DUPLICATE}
            wrong_bit {lset value 0 "${prefix}held_packet\[9\]"}
            wrong_hierarchy {lset value 0 "other_instance|held_packet\[0\]"}
            wrong_field {lset value 0 ${prefix}request}
        }
        set $field $value; set applied {}
        set failed [catch {source $candidate} message]
        if {$mode ne "valid"} {
            if {!$failed || [llength $applied]} {error "$field/$mode accepted or partially applied: $message"}
            incr rejected
        } else {
            if {$failed || [llength $applied] != 18} {error "valid profile failed: $message"}
            for {set bit 0} {$bit < 9} {incr bit} {
                set target [expr {$bit < 8 ? "${prefix}video_data\[$bit\]" : "${prefix}video_rs"}]
                foreach {label bound offset} {max 23.28 0 min 0 1} {
                    set expected [list $label -from [list "${prefix}held_packet\[$bit\]"] -to [list $target] $bound]
                    if {[lindex $applied [expr {2*$bit+$offset}]] ne $expected} {error "wrong exact pair/bound"}
                }
            }
        }
    }
}
foreach mode {lookup_missing lookup_duplicate lookup_identity clock_missing clock_duplicate clock_identity clock_nan clock_inf clock_nonnumeric clock_sys_slow clock_vid_slow route_missing route_wrong route_duplicate route_crossbit route_replica route_nonreg} {
    set src $valid_src; set dst $valid_dst; set applied {}
    if {![catch {source $candidate}] || [llength $applied]} {error "$mode accepted or partially applied"}
    incr rejected
}
puts "PASS: CRTC packet candidate nine exact pairs/clocks/native bit routes; $rejected rejected profiles before any constraint (mock only)"
