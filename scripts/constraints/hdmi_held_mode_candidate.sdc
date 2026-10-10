# Experimental handoff-only candidate: held output-mux DATA controls only.
# Controller changes the bundle with output blanked and clock closed, then
# waits five 31.25 ns CTRL periods before reopening. The native bench also
# requires three CTRL periods since the last output transition at publication.
# Quartus 17 max/min delays INCLUDE clock network latency (no datapath-only
# option). Use one CTRL period for setup and negative one period for hold,
# conservatively inside those five-/three-period stopped-clock windows.
# this does NOT qualify mux clock-selection pins, pixel data or raw CDC inputs.
# Exact scope/route/clock checks finish before any constraint is applied.
set x1_mode_prefix {x1_hdmi_clock_handoff:hdmi_handoff|}
set x1_mode_inventory [get_registers {*hdmi_handoff|active_mode* d* hs* vs* de*}]
proc x1_mode_scalar {name inventory} {
    set result [get_registers -no_duplicates [list $name]]
    if {[get_collection_size $result] != 1} {error "missing/ambiguous held mux keeper $name"}
    foreach_in_collection node $result {
        if {[get_register_info -name $node] ne $name} {error "substituted held mux keeper $name"}
    }
    # read_sdc may evaluate this file in a procedure/namespace. Pass the held
    # inventory explicitly rather than depending on a global Tcl variable.
    foreach_in_collection node $inventory {
        set actual [get_register_info -name $node]
        if {[string first "${name}~" $actual] == 0 ||
            [string first "${name}_Duplicate_" $actual] == 0} {
            error "unreviewed held mux keeper replica $actual"
        }
    }
    return $result
}
foreach {name lo hi} {
    {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} 31.249 31.251
    x1_hdmi_handoff_mux 6.731 6.733
    x1_video_handoff_mux 23.279 23.281
} {
    set clock [get_clocks [list $name]]
    if {[get_collection_size $clock] != 1} {error "missing/ambiguous held mux clock $name"}
    foreach_in_collection node $clock {
        set period [get_clock_info -period $node]
        if {[get_clock_info -name $node] ne $name ||
            ![string is double -strict $period] || $period < $lo || $period > $hi} {
            error "unexpected held mux clock identity/period"
        }
    }
}
set x1_mode_sources {}
foreach bit {0 1 2} {
    lappend x1_mode_sources [x1_mode_scalar [format {%sactive_mode[%d]} $x1_mode_prefix $bit] $x1_mode_inventory]
}
set x1_mode_targets {hs vs de}
for {set bit 0} {$bit < 24} {incr bit} {lappend x1_mode_targets [format {d[%d]} $bit]}
set x1_mode_pairs {}
foreach name $x1_mode_targets {
    set target [x1_mode_scalar $name $x1_mode_inventory]
    set actual {}
    # Clock-cone reachability is deliberately excluded from this D-route check.
    foreach_in_collection node [get_fanins -synch $target] {
        set driver [get_node_info -name $node]
        if {[string first "${x1_mode_prefix}active_mode" $driver] == 0} {
            if {[get_node_info -type $node] ne "reg"} {error "nonregister held mux driver"}
            lappend actual $driver
        }
    }
    set bits [expr {$name eq "hs" ? {0 1 2} : {0}}]
    set expected {}
    foreach bit $bits {
        lappend expected [format {%sactive_mode[%d]} $x1_mode_prefix $bit]
        lappend x1_mode_pairs [list [lindex $x1_mode_sources $bit] $target]
    }
    if {[lsort $actual] ne [lsort $expected]} {error "unexpected held mux D drivers $name"}
}
foreach pair $x1_mode_pairs {
    set_max_delay -from [lindex $pair 0] -to [lindex $pair 1] 31.25
    set_min_delay -from [lindex $pair 0] -to [lindex $pair 1] -31.25
}
puts "HELD MUX CANDIDATE: 29 exact D-route pairs; max 31.25 ns/min -31.25; raw inputs and clock pins untouched"
