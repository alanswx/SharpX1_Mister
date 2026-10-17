# Reporting only, for a completed and idle external-font board fit.
# No new assignments, exceptions, generated-clock aliases or project rewrites.
# Run from its frozen source directory with a NEW output directory argument.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1} {error "expected NEW report directory"}
set destination [lindex $quartus(args) 0]
if {[file exists $destination]} {error "refusing to overwrite evidence"}
project_open sharpx1 -revision sharpx1_turbo_z_font
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
file mkdir $destination
report_clocks -file [file join $destination clocks.rpt]
report_ucp -file [file join $destination unconstrained.rpt]
set inventory [open [file join $destination cache-registers.txt] w]
# Optimization/duplication can change these counts. This is discovery, not a
# claim that every field/bit survives or that a broad prefix is safe to cut.
foreach field {request_toggle req_meta req_sync acknowledgement ack_meta ack_sync
               held_flush held_cell held_glyph held_descriptor target_bank visible} {
    set collection [get_registers "*x1_z_kanji_cache:cache|${field}*"]
    puts $inventory "$field [get_collection_size $collection]"
    foreach_in_collection reg $collection {
        puts $inventory "  [get_register_info -name $reg]"
    }
}
close $inventory
set system [get_clocks {*|pll|pll_inst|altera_pll_i|*|divclk}]
set video [get_clocks {*|turbo_video_pll|*|divclk}]
if {[get_collection_size $system] != 1 || [get_collection_size $video] != 1} {
    error "expected one SYS and one independent X3 VID clock; refuse partial reports"
}
set service [get_registers {*x1_z_kanji_machine:external_font.service|*}]
if {[get_collection_size $service] == 0} {error "external-font service is absent"}
foreach {model temperature} {slow 100 fast -40} {
    set_operating_conditions -model $model -temperature $temperature -voltage 1100
    update_timing_netlist
    set prefix ${model}_${temperature}
    foreach check {setup hold recovery removal} {
        report_timing -$check -npaths 30 -detail full_path \
            -file [file join $destination ${prefix}_global_${check}.rpt]
    }
    foreach check {setup hold} {
        report_timing -$check -to $service -npaths 30 -detail full_path \
            -file [file join $destination ${prefix}_font_${check}.rpt]
        foreach {label source target} [list sys $system $system vid $video $video \
                                             sys_vid $system $video vid_sys $video $system] {
            report_timing -$check -from_clock $source -to_clock $target \
                -npaths 30 -detail full_path \
                -file [file join $destination ${prefix}_${label}_${check}.rpt]
        }
    }
}
puts "EXTERNAL FONT PATH REPORTS COMPLETE: original SDC only; not timing acceptance"
delete_timing_netlist
project_close
