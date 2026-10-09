# Analysis-only candidate, NOT selected by any QSF. SYS=32 MHz/X3 only.
# response remains held until a subsequent request; cpu_q consumes it at
# least two SYS periods after publication. Bound only this eight-bit bus.
set x1_pcg_response [get_registers {*x1_pcg_access:cg_bus|response*}]
set x1_pcg_cpu_q [get_registers {*x1_pcg_access:cg_bus|cpu_q*}]
foreach {x1_pcg_field x1_pcg_collection} [list response $x1_pcg_response cpu_q $x1_pcg_cpu_q] {
    set x1_pcg_bits {}
    foreach_in_collection x1_pcg_reg $x1_pcg_collection {
        set x1_pcg_name [get_register_info -name $x1_pcg_reg]
        set x1_pcg_pattern [format {\|%s\[([0-7])\]$} $x1_pcg_field]
        if {![regexp $x1_pcg_pattern $x1_pcg_name -> x1_pcg_bit]} {
            error "unexpected PCG response endpoint: $x1_pcg_name"
        }
        lappend x1_pcg_bits $x1_pcg_bit
    }
    if {[get_collection_size $x1_pcg_collection] != 8 ||
        [lsort -integer $x1_pcg_bits] ne {0 1 2 3 4 5 6 7}} {
        error "PCG response endpoint inventory differs from eight unique bits"
    }
}
# Stricter one-SYS-period bound vs measured 62.5 ns minimum capture window.
# Clock skew remains part of Quartus checks; separately audit physical delay.
set_max_delay -from $x1_pcg_response -to $x1_pcg_cpu_q 31.25
set_min_delay -from $x1_pcg_response -to $x1_pcg_cpu_q 0
