# Exact scope mock only; native before/after and physical gates are separate.
set candidate [file normalize [file join [file dirname [info script]] ../.. scripts constraints hdmi_inactive_data_candidate.sdc]]
set prefix {x1_hdmi_clock_handoff:hdmi_handoff|}
set outputs {hs vs de}
set prefetch {hdmi_dv_hs hdmi_dv_vs hdmi_dv_de}
for {set bit 0} {$bit < 24} {incr bit} {
    lappend outputs [format {d[%d]} $bit]
    if {$bit ni {4 8 20}} {lappend prefetch [format {hdmi_dv_data[%d]} $bit]}
}
set inventory [concat $outputs $prefetch]
set pins {}
foreach name $outputs {
    lappend pins ${name}|d
    if {$name ne "vs"} {lappend pins ${name}|asdata}
    lappend pins ${name}|clk ${name}|q ${name}|sload
}
set packed_prefetch {hdmi_dv_data[0] hdmi_dv_data[1] hdmi_dv_data[10] hdmi_dv_data[12] hdmi_dv_data[15] hdmi_dv_data[16] hdmi_dv_data[21]}
foreach name $prefetch {
    set port [expr {$name in $packed_prefetch ? "asdata" : "d"}]
    lappend pins ${name}|$port ${name}|clk ${name}|q
}
set fault {}
proc get_collection_size {collection} {llength $collection}
proc foreach_in_collection {variable collection body} {uplevel 1 [list foreach $variable $collection $body]}
proc get_clocks {names} {
    if {$::fault eq "missing_clock"} {return {}}
    if {$::fault eq "duplicate_clock"} {return [concat $names $names]}
    return $names
}
proc get_clock_info {option node} {
    if {$option eq "-name"} {return [expr {$::fault eq "clock_alias" ? "wrong_clock" : $node}]}
    if {$::fault eq "clock_period"} {return 99}
    if {$node eq "x1_video_handoff_mux" || [string first "turbo_video_pll" $node] >= 0} {return 23.280}
    return 6.732
}
proc get_registers {args} {
    set names [lindex $args end]
    if {[llength $names] > 1} {
        if {$::fault eq "prefetch_change"} {return [concat $::inventory {{hdmi_dv_data[4]}}]}
        if {$::fault eq "replica"} {return [concat $::inventory {{d[0]~DUPLICATE}}]}
        return $::inventory
    }
    if {[lindex $names 0] eq {d[23]}} {
        if {$::fault eq "missing"} {return {}}
        if {$::fault eq "duplicate"} {return [concat $names $names]}
        if {$::fault eq "keeper_alias"} {return {{d[23]_substitute}}}
    }
    return $names
}
proc get_register_info {option node} {return $node}
proc get_node_info {option node} {
    if {$option eq "-name"} {return $node}
    return [expr {$::fault eq "driver_type" ? "pin" : "reg"}]
}
proc get_fanins {args} {
    if {[lindex $args 0] ne "-synch"} {error "included clock cone in driver guard"}
    set name [lindex [lindex $args end] 0]
    if {$name in $::prefetch} {
        if {$::fault eq "bad_prefetch_driver"} {return wrong_bank}
        if {$::fault eq "multiple_prefetch_drivers"} {return {dv_data[0] dv_data[1]}}
        return [list [string range $name 5 end]]
    }
    set field $name
    if {[regexp {^d\[([0-9]+)\]$} $name -> bit]} {
        if {$bit in {4 8 20}} {set bit 0}
        set field [format {data[%d]} $bit]
    }
    set result [list ${::prefix}active_mode\[0\] osd:hdmi_osd|$name hdmi_dv_$field]
    if {$name eq "hs"} {lappend result ${::prefix}active_mode\[1\] ${::prefix}active_mode\[2\]}
    if {$name eq {d[23]}} {
        if {$::fault eq "wrong_driver"} {lappend result unrelated_source}
        if {$::fault eq "missing_bank"} {return [list ${::prefix}active_mode\[0\] hdmi_dv_$field]}
        if {$::fault eq "wrong_mode"} {return [list ${::prefix}active_mode\[1\] osd:hdmi_osd|$name hdmi_dv_$field]}
    }
    return $result
}
proc get_pins {args} {
    set names [lindex $args end]
    if {[llength $names] > 1} {
        if {$::fault eq "missing_pin"} {return [lsearch -all -inline -not -exact $::pins {d[23]|d}]}
        if {$::fault eq "duplicated_pin"} {return [concat $::pins {{d[23]|d}}]}
        if {$::fault eq "prefetch_pin_change"} {
            set old [expr {{hdmi_dv_data[0]} in $::packed_prefetch ? {hdmi_dv_data[0]|asdata} : {hdmi_dv_data[0]|d}}]
            set new [expr {{hdmi_dv_data[0]} in $::packed_prefetch ? {hdmi_dv_data[0]|d} : {hdmi_dv_data[0]|asdata}}]
            set index [lsearch -exact $::pins $old]
            return [lreplace $::pins $index $index $new]
        }
        return $::pins
    }
    if {[lindex $names 0] eq {d[23]|d} && $::fault eq "ambiguous_pin"} {return [concat $names $names]}
    return $names
}
proc get_pin_info {option pin} {
    if {$pin eq {d[23]|d} && $::fault eq "pin_alias"} {return {d[23]|clk}}
    return $pin
}
proc set_false_path {args} {lappend ::cuts $args}
set original_pins $pins
set original_packed $packed_prefetch
set new_packed {hdmi_dv_hs hdmi_dv_de hdmi_dv_data[0] hdmi_dv_data[6] hdmi_dv_data[17]}
foreach profile {packed direct fitted4cd} {
set pins $original_pins
set packed_prefetch $original_packed
if {$profile eq "direct"} {set packed_prefetch {}}
if {$profile eq "fitted4cd"} {set packed_prefetch $new_packed}
foreach name $prefetch {
    set old [expr {$name in $original_packed ? "asdata" : "d"}]
    set new [expr {$name in $packed_prefetch ? "asdata" : "d"}]
    set index [lsearch -exact $pins ${name}|$old]
    set pins [lreplace $pins $index $index ${name}|$new]
}
foreach fault {missing_clock duplicate_clock clock_alias clock_period prefetch_change replica missing duplicate keeper_alias driver_type bad_prefetch_driver multiple_prefetch_drivers wrong_driver missing_bank wrong_mode missing_pin duplicated_pin ambiguous_pin pin_alias prefetch_pin_change} {
    set cuts {}
    if {![catch {source $candidate} problem]} {error "invalid inactive-data scope accepted: $fault"}
    if {[llength $cuts]} {error "partial constraints applied before scope rejection: $fault"}
}
set fault {}
set cuts {}
source $candidate
set expected {}
foreach group {output prefetch} targets [list $outputs $prefetch] {
    foreach name $targets {
        set data_pins [list ${name}|d]
        if {$group eq "output" && $name ne "vs"} {lappend data_pins ${name}|asdata}
        if {$group eq "prefetch" && $name in $packed_prefetch} {set data_pins [list ${name}|asdata]}
        foreach pin $data_pins {
            set from [expr {$group eq "output" ? {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} : {emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}}]
            set to [expr {$group eq "output" ? "x1_video_handoff_mux" : "x1_hdmi_handoff_mux"}]
            lappend expected [list -from [list $from] -through [list $pin] -to [list $to]]
        }
    }
}
if {$cuts ne $expected || [llength $cuts] != 77} {error "inactive-data candidate cut unintended clocks/pins"}
puts "PASS: 77 exact inactive DATA-pin cuts; twenty invalid clock/keeper/driver/pin scopes reject before constraints"
}
# Exhaust all combinations over the union of the eleven changing keepers.
set fault {}
set changed_keepers [lsort -unique [concat $original_packed $new_packed]]
if {[llength $changed_keepers] != 11} {error "mixed-profile coverage union changed"}
set rejected 0
for {set mask 0} {$mask < (1 << 11)} {incr mask} {
    set pins $original_pins
    set bit 0
    set selected {}
    foreach name $changed_keepers {
        set old [expr {$name in $original_packed ? "asdata" : "d"}]
        set new [expr {$mask & (1 << $bit) ? "asdata" : "d"}]
        if {$new eq "asdata"} {lappend selected $name}
        set index [lsearch -exact $pins ${name}|$old]
        set pins [lreplace $pins $index $index ${name}|$new]
        incr bit
    }
    if {$selected eq {} || $selected eq [lsort $original_packed] || $selected eq [lsort $new_packed]} {continue}
    set cuts {}
    if {![catch {source $candidate} problem]} {error "mixed unreviewed packing accepted: $mask"}
    if {[llength $cuts]} {error "partial constraints applied for mixed packing: $mask"}
    incr rejected
}
if {$rejected != 2045} {error "incomplete mixed-profile rejection matrix"}
puts "PASS: three exact native pin profiles; 2045 unreviewed mixed profiles reject before any cut"
