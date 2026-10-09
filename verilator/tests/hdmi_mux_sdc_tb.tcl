# Mocked scope only; no native clock propagation/timing qualification.
set candidate [file normalize [file join [file dirname [info script]] .. .. scripts constraints hdmi_mux_candidate.sdc]]
proc get_clocks {pattern} {
    if {[string match {*pll_hdmi*} $pattern]} {set label hdmi} elseif {[string match {*turbo_video_pll*} $pattern]} {set label video} else {set label system}
    return $::objects($label)
}
proc get_pins args {
    set pattern [lindex $args end]
    if {$pattern eq {hdmi_clk_sw|outclk}} {set label output} elseif {$pattern eq {hdmi_clk_sw|inclk[2]}} {set label hdmi_input} else {set label video_input}
    return $::objects($label)
}
proc get_collection_size {objects} {llength $objects}
proc get_clock_info {option clock} {return $clock}
proc get_pin_info {option pin} {return $pin}
proc foreach_in_collection {var objects body} {uplevel 1 [list foreach $var $objects $body]}
proc create_generated_clock args {lappend ::created $args}
proc set_clock_groups args {lappend ::cuts $args}
foreach label {hdmi video system output hdmi_input video_input} {
    foreach mode {valid missing duplicate wrong_pin merged_master} {
        array set objects {hdmi hdmi_master video video_master system system_master output {hdmi_clk_sw|outclk} hdmi_input {hdmi_clk_sw|inclk[2]} video_input {hdmi_clk_sw|inclk[3]}}
        if {$mode eq "missing"} {set objects($label) {}}
        if {$mode eq "duplicate"} {lappend objects($label) [lindex $objects($label) 0]}
        if {$mode eq "wrong_pin"} {
            if {$label in {hdmi video system}} {continue}
            set objects($label) {wrong_mux|outclk}
        }
        if {$mode eq "merged_master"} {
            if {$label ni {hdmi video system}} {continue}
            if {$label eq "hdmi"} {set objects($label) video_master} else {set objects($label) hdmi_master}
        }
        set created {}
        set cuts {}
        set failed [catch {source $candidate} message]
        if {$mode eq "valid"} {
            if {$failed || [llength $created] != 2 || $cuts ne {{-logically_exclusive -group x1_hdmi_mux -group x1_video_mux}}} {error "wrong mux scope: $message"}
            set expected {{-name x1_hdmi_mux -master_clock hdmi_master -source {hdmi_clk_sw|inclk[2]} -divide_by 1 {hdmi_clk_sw|outclk}} {-name x1_video_mux -master_clock video_master -source {hdmi_clk_sw|inclk[3]} -divide_by 1 -add {hdmi_clk_sw|outclk}}}
            for {set i 0} {$i < 2} {incr i} {
                if {[list {*}[lindex $created $i]] ne [list {*}[lindex $expected $i]]} {error "wrong alias masters/sources/target"}
            }
        } elseif {!$failed || [llength $created] || [llength $cuts]} {error "$label/$mode did not refuse constraints"}
    }
}
puts "PASS: aliases exclusive only at mux output; 18 invalid inventories/pins/master identities reject (mock only)"
