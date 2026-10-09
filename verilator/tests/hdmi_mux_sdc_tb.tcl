# Mocked scope only; no native clock propagation/timing qualification.
set candidate [file normalize [file join [file dirname [info script]] .. .. scripts constraints hdmi_mux_candidate.sdc]]
set mux hdmi_clk_sw
set hdmi_alias x1_hdmi_mux
set video_alias x1_video_mux
if {$argv eq "handoff"} {
    set candidate [file normalize [file join [file dirname [info script]] .. .. scripts constraints hdmi_handoff_mux_candidate.sdc]]
    set mux hdmi_handoff|mux
    set hdmi_alias x1_hdmi_handoff_mux
    set video_alias x1_video_handoff_mux
} elseif {$argv ne ""} {error "expected no arguments or handoff"}
proc get_clocks {pattern} {
    if {[string match {*pll_hdmi*} $pattern]} {set label hdmi} elseif {[string match {*turbo_video_pll*} $pattern]} {set label video} else {set label system}
    return $::objects($label)
}
proc get_pins args {
    set pattern [lindex $args end]
    if {$pattern eq "$::mux|outclk"} {set label output} elseif {$pattern eq "$::mux|inclk\[2\]"} {set label hdmi_input} else {set label video_input}
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
        array set objects [list hdmi hdmi_master video video_master system system_master output "$mux|outclk" hdmi_input "$mux|inclk\[2\]" video_input "$mux|inclk\[3\]"]
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
            if {$failed || [llength $created] != 2 || $cuts ne [list [list -logically_exclusive -group $hdmi_alias -group $video_alias]]} {error "wrong mux scope: $message"}
            set expected [list [list -name $hdmi_alias -master_clock hdmi_master -source "$mux|inclk\[2\]" -divide_by 1 "$mux|outclk"] [list -name $video_alias -master_clock video_master -source "$mux|inclk\[3\]" -divide_by 1 -add "$mux|outclk"]]
            for {set i 0} {$i < 2} {incr i} {
                if {[list {*}[lindex $created $i]] ne [list {*}[lindex $expected $i]]} {error "wrong alias masters/sources/target"}
            }
        } elseif {!$failed || [llength $created] || [llength $cuts]} {error "$label/$mode did not refuse constraints"}
    }
}
puts "PASS: aliases exclusive only at mux output; 18 invalid inventories/pins/master identities reject (mock only)"
