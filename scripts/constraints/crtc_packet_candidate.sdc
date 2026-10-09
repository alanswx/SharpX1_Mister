# Unselected experimental X3 candidate, not a whole-clock-domain waiver.
# Original x1_crtc_write handshake holds {RS,data} until consumed and ACKed.
# Destination capture is at least two VID periods after publication; use a
# stricter one-period physical budget. Raw request/ACK inputs are untouched.
set x1_crtc_packet_src [get_registers {*x1_crtc_write:x3_crtc.writes|held_packet*}]
set x1_crtc_packet_dst [get_registers {*x1_crtc_write:x3_crtc.writes|video_data* *x1_crtc_write:x3_crtc.writes|video_rs*}]
set x1_crtc_packet_fields [dict create]
set x1_crtc_packet_prefixes {}
foreach_in_collection x1_crtc_packet_node [add_to_collection $x1_crtc_packet_src $x1_crtc_packet_dst] {
    set x1_crtc_packet_name [get_register_info -name $x1_crtc_packet_node]
    if {![regexp {^(.*x1_crtc_write:x3_crtc\.writes\|)(held_packet\[[0-8]\]|video_data\[[0-7]\]|video_rs)$} \
        $x1_crtc_packet_name -> x1_crtc_packet_prefix x1_crtc_packet_field]} {
        error "unexpected CRTC packet keeper/replica: $x1_crtc_packet_name"
    }
    if {[dict exists $x1_crtc_packet_fields $x1_crtc_packet_field]} {error "duplicate CRTC packet field"}
    dict set x1_crtc_packet_fields $x1_crtc_packet_field $x1_crtc_packet_name
    lappend x1_crtc_packet_prefixes $x1_crtc_packet_prefix
}
if {[get_collection_size $x1_crtc_packet_src] != 9 ||
    [get_collection_size $x1_crtc_packet_dst] != 9 ||
    [dict size $x1_crtc_packet_fields] != 18 ||
    [llength [lsort -unique $x1_crtc_packet_prefixes]] != 1} {
    error "expected eighteen unique CRTC packet keepers in one transport"
}
foreach {x1_crtc_packet_clock_name x1_crtc_packet_lo x1_crtc_packet_hi} {
    {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} 31.249 31.251
    {emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} 23.27 23.29
} {
    set x1_crtc_packet_clock [get_clocks [list $x1_crtc_packet_clock_name]]
    if {[get_collection_size $x1_crtc_packet_clock] != 1} {error "missing/ambiguous CRTC packet clock"}
    foreach_in_collection x1_crtc_packet_node $x1_crtc_packet_clock {
        set x1_crtc_packet_period [get_clock_info -period $x1_crtc_packet_node]
        if {[get_clock_info -name $x1_crtc_packet_node] ne $x1_crtc_packet_clock_name ||
            ![string is double -strict $x1_crtc_packet_period] ||
            !($x1_crtc_packet_period >= $x1_crtc_packet_lo && $x1_crtc_packet_period <= $x1_crtc_packet_hi)} {
            error "unexpected CRTC packet clock identity/period"
        }
    }
}
set x1_crtc_packet_pairs {}
for {set x1_crtc_packet_bit 0} {$x1_crtc_packet_bit < 9} {incr x1_crtc_packet_bit} {
    set x1_crtc_packet_source [dict get $x1_crtc_packet_fields "held_packet\[$x1_crtc_packet_bit\]"]
    set x1_crtc_packet_target [dict get $x1_crtc_packet_fields \
        [expr {$x1_crtc_packet_bit < 8 ? "video_data\[$x1_crtc_packet_bit\]" : "video_rs"}]]
    set x1_crtc_packet_pair {}
    foreach x1_crtc_packet_name [list $x1_crtc_packet_source $x1_crtc_packet_target] {
        set x1_crtc_packet_keeper [get_registers -no_duplicates [list $x1_crtc_packet_name]]
        if {[get_collection_size $x1_crtc_packet_keeper] != 1} {error "ambiguous CRTC packet physical keeper"}
        foreach_in_collection x1_crtc_packet_node $x1_crtc_packet_keeper {
            if {[get_register_info -name $x1_crtc_packet_node] ne $x1_crtc_packet_name} {error "wrong CRTC packet keeper identity"}
        }
        lappend x1_crtc_packet_pair $x1_crtc_packet_keeper
    }
    set x1_crtc_packet_inputs {}
    foreach_in_collection x1_crtc_packet_node [get_fanins [lindex $x1_crtc_packet_pair 1]] {
        set x1_crtc_packet_name [get_node_info -name $x1_crtc_packet_node]
        if {[string first "[lindex $x1_crtc_packet_prefixes 0]held_packet" $x1_crtc_packet_name] == 0} {
            if {[get_node_info -type $x1_crtc_packet_node] ne "reg"} {error "non-register CRTC packet source"}
            lappend x1_crtc_packet_inputs $x1_crtc_packet_name
        }
    }
    if {$x1_crtc_packet_inputs ne [list $x1_crtc_packet_source]} {error "wrong/missing native CRTC packet bit route"}
    lappend x1_crtc_packet_pairs $x1_crtc_packet_pair
}
# All inventory, clock and native bit-route checks finish before any exception.
foreach x1_crtc_packet_pair $x1_crtc_packet_pairs {
    set_max_delay -from [lindex $x1_crtc_packet_pair 0] -to [lindex $x1_crtc_packet_pair 1] 23.28
    set_min_delay -from [lindex $x1_crtc_packet_pair 0] -to [lindex $x1_crtc_packet_pair 1] 0
}
puts "CRTC packet candidate: nine exact physical pairs; max 23.28 ns/min 0; raw inputs untouched"
