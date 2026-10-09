# Source-audited dimensions snapshot payload ONLY. This is not an asynchronous
# clock-group exception or full X3 timing closure. See
# docs/TURBO_Z_SNAPSHOT_TIMING_STATUS.md for protocol and fitted evidence.
# This revision runs SYS=32 MHz; capture is >=2 SYS periods after held_data.
set x1_bundle_source [get_registers {*dimensions_to_sys|held_data*}]
set x1_bundle_destination [get_registers {*dimensions_to_sys|destination_data*}]
foreach x1_bundle_collection [list $x1_bundle_source $x1_bundle_destination] {
    set x1_bundle_bits {}
    foreach_in_collection x1_bundle_reg $x1_bundle_collection {
        set x1_bundle_name [get_register_info -name $x1_bundle_reg]
        if {![regexp {\[([0-9]+)\]$} $x1_bundle_name -> x1_bundle_bit]} {
            error "unexpected snapshot endpoint: $x1_bundle_name"
        }
        lappend x1_bundle_bits $x1_bundle_bit
    }
    set x1_bundle_absent {}
    for {set x1_bundle_bit 0} {$x1_bundle_bit < 74} {incr x1_bundle_bit} {
        if {$x1_bundle_bit ni $x1_bundle_bits} {lappend x1_bundle_absent $x1_bundle_bit}
    }
    # VGA_F1=0 makes vid_int[1:0] configuration constants; inventory confirms
    # bits 0/1 absent in both banks, with every bit 2..73 retained exactly once.
    if {[get_collection_size $x1_bundle_collection] != 72 ||
        [llength [lsort -unique $x1_bundle_bits]] != 72 || $x1_bundle_absent ne {0 1}} {
        error "dimensions bundle differs from audited bits 2..73; refuse partial constraint"
    }
}
# One SYS period is stricter than the two-period protocol window. Quartus 17
# max/min delay include clock network latency; additionally audit real data
# delays in every fitted corner. First-stage synchronizers and all other buses
# retain existing timing checks. Never replace this bus limit with false_path.
set_max_delay -from $x1_bundle_source -to $x1_bundle_destination 31.25
set_min_delay -from $x1_bundle_source -to $x1_bundle_destination 0
