# Experimental Z revision only. SYS=32 MHz/X3 endpoint scope.
# Selected by its QSF; fresh-fit endpoint and all-corner gates remain mandatory.
# response remains held until a subsequent request; cpu_q consumes it at
# least two SYS periods after publication. Bound only this eight-bit bus.
set x1_pcg_response [get_registers {*x1_pcg_access:cg_bus|response*}]
set x1_pcg_cpu_q [get_registers {*x1_pcg_access:cg_bus|cpu_q*}]
foreach {x1_pcg_field x1_pcg_collection} [list response $x1_pcg_response cpu_q $x1_pcg_cpu_q] {
    set x1_pcg_bits {}
    set x1_pcg_clone_bits {}
    foreach_in_collection x1_pcg_reg $x1_pcg_collection {
        set x1_pcg_name [get_register_info -name $x1_pcg_reg]
        set x1_pcg_pattern [format {\|%s\[([0-7])\]$} $x1_pcg_field]
        # Quartus router duplication retains the CPU capture function. The
        # 3dc3727 fit explicitly maps cpu_q[0/3] to same-bit ~DUPLICATE nodes.
        # Accept at most one such replica per valid CPU bit, never missing
        # primary bits, other suffixes/fields, or unchecked source replicas.
        if {$x1_pcg_field eq "cpu_q" &&
            [regexp {\|cpu_q\[([0-7])\]~DUPLICATE$} $x1_pcg_name -> x1_pcg_bit]} {
            lappend x1_pcg_clone_bits $x1_pcg_bit
            continue
        }
        if {![regexp $x1_pcg_pattern $x1_pcg_name -> x1_pcg_bit]} {
            error "unexpected PCG response endpoint: $x1_pcg_name"
        }
        lappend x1_pcg_bits $x1_pcg_bit
    }
    if {[get_collection_size $x1_pcg_collection] != 8+[llength $x1_pcg_clone_bits] ||
        [llength [lsort -unique $x1_pcg_clone_bits]] != [llength $x1_pcg_clone_bits] ||
        [lsort -integer $x1_pcg_bits] ne {0 1 2 3 4 5 6 7}} {
        error "PCG response endpoint inventory differs from eight unique bits"
    }
    puts "PCG $x1_pcg_field: eight primary bits, replica bits=$x1_pcg_clone_bits"
}
# Stricter one-SYS-period bound vs measured 62.5 ns minimum capture window.
# Clock skew remains part of Quartus checks; separately audit physical delay.
set_max_delay -from $x1_pcg_response -to $x1_pcg_cpu_q 31.25
set_min_delay -from $x1_pcg_response -to $x1_pcg_cpu_q 0
