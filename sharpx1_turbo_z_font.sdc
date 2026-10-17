# External-font SYS32 revision only. Native Quartus 17 early synthesis retains
# all 74 logical dimensions bits; constant VGA_F1 bits 0/1 disappear before
# mapped/fitted timing. Validate that exact early inventory rather than making
# timing-driven synthesis fail the later physical 72-bit guard.
set x1_font_snapshot_source [get_registers {*dimensions_to_sys|held_data*}]
set x1_font_snapshot_target [get_registers {*dimensions_to_sys|destination_data*}]
set x1_font_snapshot_early 0
if {[info exists ::quartus(nameofexecutable)] && $::quartus(nameofexecutable) eq "quartus_map" &&
    [get_collection_size $x1_font_snapshot_source] == 74 &&
    [get_collection_size $x1_font_snapshot_target] == 74} {
    set x1_font_snapshot_early 1
}
if {$x1_font_snapshot_early} {
    set x1_font_snapshot_prefix {emu:emu|hps_io:hps_io|video_calc:video_calc|x1_cdc_snapshot:coherent_measurements.dimensions_to_sys|}
    foreach {x1_font_snapshot_field x1_font_snapshot_collection} [list \
        held_data $x1_font_snapshot_source destination_data $x1_font_snapshot_target] {
        set x1_font_snapshot_names {}
        foreach_in_collection x1_font_snapshot_reg $x1_font_snapshot_collection {
            lappend x1_font_snapshot_names [get_register_info -name $x1_font_snapshot_reg]
        }
        set x1_font_snapshot_expected {}
        for {set x1_font_snapshot_bit 0} {$x1_font_snapshot_bit < 74} {incr x1_font_snapshot_bit} {
            lappend x1_font_snapshot_expected [format {%s%s[%d]} \
                $x1_font_snapshot_prefix $x1_font_snapshot_field $x1_font_snapshot_bit]
        }
        if {[lsort $x1_font_snapshot_names] ne [lsort $x1_font_snapshot_expected]} {
            error "unexpected early font snapshot identity/alias; refuse all bounds"
        }
    }
    # Same stricter one-SYS-period payload bound. These include the two logical
    # constant bits during synthesis only; no first-stage or clock-group cut.
    set_max_delay -from $x1_font_snapshot_source -to $x1_font_snapshot_target 31.25
    set_min_delay -from $x1_font_snapshot_source -to $x1_font_snapshot_target 0
    puts "FONT SNAPSHOT EARLY PROFILE: exact logical bits 0..73; fitted scope must remain 2..73"
} else {
    # No fitted/STA relaxation: the original exact bits 2..73 and 72/72 counts
    # are mandatory, including when synthesis has already folded constants.
    source sharpx1_turbo_z_video.sdc
    puts "FONT SNAPSHOT MAPPED/FITTED PROFILE: original exact 72-bit payload bound"
}
