# Experimental Z only. The raw request asserts these reset
# synchronizers asynchronously; their output releases on two local edges.
# Cut ONLY the four raw asynchronous reset pins, not D inputs, clocks, stage
# transfer, or release output fanout. This is not pulse-width/MTBF signoff.
set x1_reset_input_pins [get_pins -compatibility_mode \
    {*|video_reset_domain.release_reset|release_pipe*|clrn *|local_release.video_release|release_pipe*|clrn}]
set x1_reset_input_identities {}
foreach_in_collection x1_reset_pin $x1_reset_input_pins {
    set x1_reset_pin_name [get_pin_info -name $x1_reset_pin]
    if {![regexp {\|(video_reset_domain\.release_reset|local_release\.video_release)\|release_pipe\[([01])\]\|clrn$} \
        $x1_reset_pin_name -> x1_reset_instance x1_reset_bit]} {
        error "unexpected video reset synchronizer input pin: $x1_reset_pin_name"
    }
    lappend x1_reset_input_identities "$x1_reset_instance:$x1_reset_bit"
}
if {[get_collection_size $x1_reset_input_pins] != 4 ||
    [lsort $x1_reset_input_identities] ne \
    {local_release.video_release:0 local_release.video_release:1 video_reset_domain.release_reset:0 video_reset_domain.release_reset:1}} {
    error "expected precisely two raw reset pins per video release pipeline"
}
set_false_path -to $x1_reset_input_pins
