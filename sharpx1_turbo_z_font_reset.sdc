# External-font qualification revision only. Asynchronous assertion is allowed
# at these two raw reset inputs; release still traverses two local VID edges.
# No D/CLK/Q, stage-transfer or downstream release path is excluded. Physical
# pulse width, synchronizer placement and MTBF remain separate open gates.
set x1_font_reset_pins [get_pins -compatibility_mode \
    {*|video_reset_domain.release_reset|release_pipe*|clrn}]
set x1_font_reset_names {}
foreach_in_collection x1_font_reset_pin $x1_font_reset_pins {
    lappend x1_font_reset_names [get_pin_info -name $x1_font_reset_pin]
}
set x1_font_reset_expected {}
foreach x1_font_reset_bit {0 1} {
    lappend x1_font_reset_expected [format \
        {emu|sharpx1|video_reset_domain.release_reset|release_pipe[%d]|clrn} \
        $x1_font_reset_bit]
}
if {[get_collection_size $x1_font_reset_pins] != 2 ||
    [lsort $x1_font_reset_names] ne [lsort $x1_font_reset_expected]} {
    error "expected precisely the two external-font raw VID reset pins; refuse exception"
}
set_false_path -to $x1_font_reset_pins
