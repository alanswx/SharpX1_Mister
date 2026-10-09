# Analysis-only again: completed-fit 32 MHz SYS / X3 endpoint scope.
# Early fitting uses a different RAM representation; not selected by any QSF.
# Requests are frozen before the toggle crosses two VID synchronizers.
# Address/control admission is >=2 VID periods later; RAM writes are later.
set x1_req_address [get_registers {*x1_pcg_access:cg_bus|frozen_addr* *x1_pcg_access:cg_bus|font_cpu_addr*}]
set x1_req_control [get_registers {*x1_pcg_access:cg_bus|plane* *x1_pcg_access:cg_bus|write_request* *x1_pcg_access:cg_bus|high_speed_request* *x1_pcg_access:cg_bus|unsupported_request*}]
set x1_req_payload [get_registers {*x1_pcg_access:cg_bus|payload*}]
set x1_req_addr_dest [get_registers {*x1_pcg_access:cg_bus|access_addr*}]
set x1_req_ctrl_dest [get_registers {*x1_pcg_access:cg_bus|access_addr* *x1_pcg_access:cg_bus|response* *x1_pcg_access:cg_bus|seen *x1_pcg_access:cg_bus|stage* *x1_video_ram:pcg_*|*~porta_we_reg}]
set x1_req_data_dest [get_registers {*x1_video_ram:pcg_*|*~PORT_A_DATA_IN_* *x1_video_ram:pcg_*|*~porta_datain_reg*}]
# Map merges frozen_addr[4..10] into font_cpu_addr[5..11]. Inventory must be
# reviewed anew after each fit; these counts do not support other revisions.
# No constraint is issued until every collection passes the inventory gate.
foreach {x1_req_label x1_req_collection x1_req_count} [list \
    address $x1_req_address 16 control $x1_req_control 5 payload $x1_req_payload 8 \
    address_dest $x1_req_addr_dest 11 control_dest $x1_req_ctrl_dest 36 data_dest $x1_req_data_dest 192] {
    set x1_req_names {}
    foreach_in_collection x1_req_reg $x1_req_collection {
        lappend x1_req_names [get_register_info -name $x1_req_reg]
    }
    puts "PCG candidate $x1_req_label: [get_collection_size $x1_req_collection] endpoints"
    if {[get_collection_size $x1_req_collection] != $x1_req_count ||
        [llength [lsort -unique $x1_req_names]] != $x1_req_count} {
        error "unexpected $x1_req_label endpoint inventory; refuse all request bounds"
    }
}
# Validate identities as well as counts, before any exception is applied.
set x1_req_expected(address) {}
set x1_req_expected(payload) {}
set x1_req_expected(address_dest) {}
set x1_req_expected(control) {plane[0] plane[1] write_request high_speed_request unsupported_request}
set x1_req_expected(control_dest) {seen stage.00 stage.01 stage.01~DUPLICATE stage.10}
for {set x1_req_i 0} {$x1_req_i < 12} {incr x1_req_i} {
    lappend x1_req_expected(address) [format {font_cpu_addr[%d]} $x1_req_i]
    if {$x1_req_i < 4} {lappend x1_req_expected(address) [format {frozen_addr[%d]} $x1_req_i]}
    if {$x1_req_i < 8} {
        lappend x1_req_expected(payload) [format {payload[%d]} $x1_req_i]
        lappend x1_req_expected(control_dest) [format {response[%d]} $x1_req_i]
    }
    if {$x1_req_i < 11} {
        lappend x1_req_expected(address_dest) [format {access_addr[%d]} $x1_req_i]
        lappend x1_req_expected(control_dest) [format {access_addr[%d]} $x1_req_i]
    }
}
foreach {x1_req_label x1_req_collection} [list \
    address $x1_req_address control $x1_req_control payload $x1_req_payload \
    address_dest $x1_req_addr_dest control_dest $x1_req_ctrl_dest data_dest $x1_req_data_dest] {
    set x1_req_leaves {}
    array set x1_req_ram_counts {b 0 r 0 g 0}
    foreach_in_collection x1_req_reg $x1_req_collection {
        set x1_req_name [get_register_info -name $x1_req_reg]
        if {[regexp {x1_video_ram:pcg_([brg])\|} $x1_req_name -> x1_req_color]} {
            incr x1_req_ram_counts($x1_req_color)
        } else {
            lappend x1_req_leaves [lindex [split $x1_req_name |] end]
        }
    }
    if {$x1_req_label ne "data_dest" &&
        [lsort $x1_req_leaves] ne [lsort $x1_req_expected($x1_req_label)]} {
        error "unexpected $x1_req_label bit identities; refuse all request bounds"
    }
    if {$x1_req_label eq "control_dest" || $x1_req_label eq "data_dest"} {
        set x1_req_plane_count [expr {$x1_req_label eq "control_dest" ? 4 : 64}]
        foreach x1_req_color {b r g} {
            if {$x1_req_ram_counts($x1_req_color) != $x1_req_plane_count} {
                error "unexpected $x1_req_label RAM plane inventory"
            }
        }
    }
}
# One nominal VID period is stricter than the two-period admission window.
# Physical delay must also be audited; Quartus retains clock skew/latency.
# Explicit destinations ensure font/other SYS paths are not excepted.
foreach {x1_req_from x1_req_to} [list \
    $x1_req_address $x1_req_addr_dest \
    $x1_req_control $x1_req_ctrl_dest \
    $x1_req_payload $x1_req_data_dest] {
    set_max_delay -from $x1_req_from -to $x1_req_to 23.28
    set_min_delay -from $x1_req_from -to $x1_req_to 0
}
