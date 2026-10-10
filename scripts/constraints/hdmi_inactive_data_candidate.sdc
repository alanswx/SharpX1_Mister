# Experimental handoff-only source-bound proposal; not timing/hardware accepted.
# Exclude only opposite-parent data at exact first-stage D/ASDATA pins, under
# the inactive output clock alias. SYS mode, CLK/SLOAD, raw CDC, DDR/I/O and
# same-parent transfers remain timed. Native X poisoning is functional evidence,
# not physical MTBF. Fitted bank identities must be rediscovered if they change.
set x1_inactive_clock_names {
    hdmi {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} 6.731 6.733
    video {emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} 23.279 23.281
    hdmi_alias x1_hdmi_handoff_mux 6.731 6.733
    video_alias x1_video_handoff_mux 23.279 23.281
}
foreach {kind name lo hi} $x1_inactive_clock_names {
    set clocks [get_clocks [list $name]]
    if {[get_collection_size $clocks] != 1} {error "missing/ambiguous inactive-data clock $name"}
    foreach_in_collection node $clocks {
        set period [get_clock_info -period $node]
        if {[get_clock_info -name $node] ne $name ||
            ![string is double -strict $period] || $period < $lo || $period > $hi} {
            error "unexpected inactive-data clock identity/period"
        }
    }
    set x1_inactive_clocks($kind) $clocks
}
set x1_inactive_outputs {hs vs de}
set x1_inactive_prefetch {hdmi_dv_hs hdmi_dv_vs hdmi_dv_de}
for {set bit 0} {$bit < 24} {incr bit} {
    lappend x1_inactive_outputs [format {d[%d]} $bit]
    # Exact ce2eba8 physical bank, not a general logical RGB-width rule.
    if {$bit ni {4 8 20}} {lappend x1_inactive_prefetch [format {hdmi_dv_data[%d]} $bit]}
}
set x1_inactive_inventory [get_registers -no_duplicates {hdmi_dv* d* hs* vs* de*}]
set x1_inactive_actual_prefetch {}
foreach_in_collection node $x1_inactive_inventory {
    set name [get_register_info -name $node]
    if {[string first hdmi_dv_ $name] == 0} {lappend x1_inactive_actual_prefetch $name}
    foreach keeper $x1_inactive_outputs {
        if {[string first "${keeper}~" $name] == 0 ||
            [string first "${keeper}_Duplicate_" $name] == 0} {error "unreviewed output keeper replica"}
    }
}
if {[lsort $x1_inactive_actual_prefetch] ne [lsort $x1_inactive_prefetch]} {
    error "physical DV bank changed; repeat discovery before updating scope"
}
set x1_inactive_pin_inventory [get_pins -compatibility_mode {hdmi_dv*|* d*|* hs*|* vs*|* de*|*}]
# Six complete observed profiles, never independent per-bit alternatives.
# Fresh ce2eba8/db2dc8c synthesis has all prefetch DATA on D. The completed
# ce2eba8 fit packs exactly seven onto ASDATA. All other topology guards stay
# unchanged; reject partial packing, replicas, missing or duplicated pins.
set x1_inactive_packed_prefetch {
    hdmi_dv_data[0] hdmi_dv_data[1] hdmi_dv_data[10] hdmi_dv_data[12]
    hdmi_dv_data[15] hdmi_dv_data[16] hdmi_dv_data[21]
}
# Completed 4cd18ed fit: five exact keepers use ASDATA. This separately named
# whole-bank inventory is not a generic allowance for arbitrary packing.
set x1_inactive_fitted4cd_prefetch {
    hdmi_dv_hs hdmi_dv_de hdmi_dv_data[0] hdmi_dv_data[6] hdmi_dv_data[17]
}
# Reporting-only 048d996 completed fit: seven exact ASDATA keepers. Native
# discovery proves all 51 keepers/205 pins, matching DV drivers and no target
# replicas. This profile still requires native active-path preservation.
set x1_inactive_fitted048_prefetch {
    hdmi_dv_hs hdmi_dv_de hdmi_dv_data[3] hdmi_dv_data[12]
    hdmi_dv_data[13] hdmi_dv_data[16] hdmi_dv_data[17]
}
# Reporting-only 3c6242e fit: five exact ASDATA keepers. Independent native
# inventory preserves all 51 keepers/205 pins and logical driver connectivity.
# This exact profile still requires same-fit active-path preservation.
set x1_inactive_fitted3c_prefetch {
    hdmi_dv_hs hdmi_dv_vs hdmi_dv_data[6] hdmi_dv_data[13] hdmi_dv_data[16]
}
# Reporting-only 16fa816 fit: six exact ASDATA keepers. Same-fit preservation
# is separate evidence, not timing closure or permission for arbitrary packing.
set x1_inactive_fitted16fa_prefetch {
    hdmi_dv_hs hdmi_dv_vs hdmi_dv_data[5] hdmi_dv_data[6] hdmi_dv_data[9] hdmi_dv_data[11]
}
set x1_inactive_direct_pins {}
set x1_inactive_packed_pins {}
set x1_inactive_fitted4cd_pins {}
set x1_inactive_fitted048_pins {}
set x1_inactive_fitted3c_pins {}
set x1_inactive_fitted16fa_pins {}
set x1_inactive_actual_pins {}
foreach name $x1_inactive_prefetch {
    lappend x1_inactive_direct_pins "${name}|d"
    set port [expr {$name in $x1_inactive_packed_prefetch ? "asdata" : "d"}]
    lappend x1_inactive_packed_pins "${name}|$port"
    set port [expr {$name in $x1_inactive_fitted4cd_prefetch ? "asdata" : "d"}]
    lappend x1_inactive_fitted4cd_pins "${name}|$port"
    set port [expr {$name in $x1_inactive_fitted048_prefetch ? "asdata" : "d"}]
    lappend x1_inactive_fitted048_pins "${name}|$port"
    set port [expr {$name in $x1_inactive_fitted3c_prefetch ? "asdata" : "d"}]
    lappend x1_inactive_fitted3c_pins "${name}|$port"
    set port [expr {$name in $x1_inactive_fitted16fa_prefetch ? "asdata" : "d"}]
    lappend x1_inactive_fitted16fa_pins "${name}|$port"
    foreach_in_collection pin $x1_inactive_pin_inventory {
        set actual [get_pin_info -name $pin]
        if {$actual in [list "${name}|d" "${name}|asdata"]} {lappend x1_inactive_actual_pins $actual}
    }
}
if {[lsort $x1_inactive_actual_pins] eq [lsort $x1_inactive_direct_pins]} {
    set x1_inactive_pin_profile direct
} elseif {[lsort $x1_inactive_actual_pins] eq [lsort $x1_inactive_packed_pins]} {
    set x1_inactive_pin_profile packed
} elseif {[lsort $x1_inactive_actual_pins] eq [lsort $x1_inactive_fitted4cd_pins]} {
    set x1_inactive_pin_profile fitted4cd
} elseif {[lsort $x1_inactive_actual_pins] eq [lsort $x1_inactive_fitted048_pins]} {
    set x1_inactive_pin_profile fitted048
} elseif {[lsort $x1_inactive_actual_pins] eq [lsort $x1_inactive_fitted3c_pins]} {
    set x1_inactive_pin_profile fitted3c
} elseif {[lsort $x1_inactive_actual_pins] eq [lsort $x1_inactive_fitted16fa_pins]} {
    set x1_inactive_pin_profile fitted16fa
} else {error "unreviewed whole-prefetch D/ASDATA profile; repeat discovery"}
set x1_inactive_cuts {}
foreach group {output prefetch} targets [list $x1_inactive_outputs $x1_inactive_prefetch] {
    foreach name $targets {
        set regs [get_registers -no_duplicates [list $name]]
        if {[get_collection_size $regs] != 1} {error "missing/ambiguous inactive-data keeper $name"}
        foreach_in_collection node $regs {
            if {[get_register_info -name $node] ne $name} {error "substituted inactive-data keeper"}
        }
        set mode_bits {}
        set bank_drivers 0
        set other_drivers 0
        foreach_in_collection node [get_fanins -synch $regs] {
            set driver [get_node_info -name $node]
            if {[get_node_info -type $node] ne "reg"} {error "unreviewed inactive-data driver type"}
            if {$group eq "prefetch"} {
                if {![regexp {^dv_(data\[([0-9]+)\]|hs|vs|de)(~.*|_Duplicate_.*)?$} $driver]} {
                    error "unreviewed physical DV prefetch driver"
                }
                incr bank_drivers
            } elseif {[regexp {^x1_hdmi_clock_handoff:hdmi_handoff\|active_mode\[([012])\]$} $driver -> bit]} {
                lappend mode_bits $bit
            } elseif {[regexp {^(osd:hdmi_osd|csync:csync_hdmi)\|.+$} $driver]} {
                incr bank_drivers
            } elseif {$driver in $x1_inactive_prefetch} {
                incr other_drivers
            } else {error "unreviewed output-mux data driver"}
        }
        if {$group eq "output"} {
            set expected [expr {$name eq "hs" ? {0 1 2} : {0}}]
            if {[lsort $mode_bits] ne $expected || !$bank_drivers || !$other_drivers} {
                error "missing held selector or either data bank"
            }
        } elseif {$bank_drivers != 1} {error "ambiguous DV prefetch route"}
        set names {}
        foreach_in_collection pin $x1_inactive_pin_inventory {
            set actual [get_pin_info -name $pin]
            if {$actual in [list "${name}|d" "${name}|asdata"]} {lappend names $actual}
        }
        set expected_pins [list "${name}|d"]
        if {$group eq "output" && $name ne "vs"} {lappend expected_pins "${name}|asdata"}
        if {$group eq "prefetch" && $x1_inactive_pin_profile eq "packed" &&
            $name in $x1_inactive_packed_prefetch} {set expected_pins [list "${name}|asdata"]}
        if {$group eq "prefetch" && $x1_inactive_pin_profile eq "fitted4cd" &&
            $name in $x1_inactive_fitted4cd_prefetch} {set expected_pins [list "${name}|asdata"]}
        if {$group eq "prefetch" && $x1_inactive_pin_profile eq "fitted048" &&
            $name in $x1_inactive_fitted048_prefetch} {set expected_pins [list "${name}|asdata"]}
        if {$group eq "prefetch" && $x1_inactive_pin_profile eq "fitted3c" &&
            $name in $x1_inactive_fitted3c_prefetch} {set expected_pins [list "${name}|asdata"]}
        if {$group eq "prefetch" && $x1_inactive_pin_profile eq "fitted16fa" &&
            $name in $x1_inactive_fitted16fa_prefetch} {set expected_pins [list "${name}|asdata"]}
        if {[lsort $names] ne [lsort $expected_pins]} {
            error "inactive-data D/ASDATA pin topology changed at $name: actual $names expected $expected_pins; repeat discovery"
        }
        foreach pin_name $names {
            set pin [get_pins -compatibility_mode [list $pin_name]]
            if {[get_collection_size $pin] != 1} {error "ambiguous inactive-data pin"}
            foreach_in_collection node $pin {
                if {[get_pin_info -name $node] ne $pin_name} {error "substituted inactive-data pin"}
            }
            lappend x1_inactive_cuts [list $group $pin $pin_name]
        }
    }
}
# All guards complete before any cut. -through is a DATA input, not CLK/Q or
# SLOAD; -to is the opposite alias, not either master or all destination clocks.
puts "INACTIVE DATA PIN PROFILE $x1_inactive_pin_profile"
foreach cut $x1_inactive_cuts {
    lassign $cut group pin pin_name
    if {$group eq "output"} {
        set_false_path -from $x1_inactive_clocks(hdmi) -through $pin -to $x1_inactive_clocks(video_alias)
    } else {
        set_false_path -from $x1_inactive_clocks(video) -through $pin -to $x1_inactive_clocks(hdmi_alias)
    }
    puts "INACTIVE DATA CUT $group $pin_name"
}
puts "INACTIVE DATA CANDIDATE: opposite-parent exact DATA pins only; active routes and raw inputs untouched"
