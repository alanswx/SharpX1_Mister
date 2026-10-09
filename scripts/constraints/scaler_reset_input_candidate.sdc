# Experimental Z only; native scope audited, fresh-fit/physical gates open.
# Only raw asynchronous CLRN pins of the three actual two-stage pipelines.
# Never select D/CLK/Q pins, whole registers or release-output fanout.
set x1_scaler_reset_pins [get_pins -compatibility_mode {*ascal*|*release_pipe*|clrn}]
set x1_scaler_reset_identities {}
foreach_in_collection x1_scaler_reset_pin $x1_scaler_reset_pins {
    set x1_scaler_reset_name [get_pin_info -name $x1_scaler_reset_pin]
    if {![regexp {^ascal\|\\x1_domain_reset:(input_release|output_release|avalon_release)\|release_pipe\[([01])\]\|clrn$} $x1_scaler_reset_name -> x1_scaler_reset_domain x1_scaler_reset_bit]} {
        error "unexpected scaler raw reset pin: $x1_scaler_reset_name"
    }
    lappend x1_scaler_reset_identities "$x1_scaler_reset_domain:$x1_scaler_reset_bit"
}
if {[get_collection_size $x1_scaler_reset_pins] != 6 || [lsort $x1_scaler_reset_identities] ne {avalon_release:0 avalon_release:1 input_release:0 input_release:1 output_release:0 output_release:1}} {
    error "expected exactly six primary scaler asynchronous input pins"
}
set_false_path -to $x1_scaler_reset_pins
