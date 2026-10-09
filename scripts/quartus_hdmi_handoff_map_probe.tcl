# Isolated native atom mapping ONLY; not a MiSTer build/timing acceptance.
# Run in a NEW ignored directory containing the frozen controller source.
package require ::quartus::project
if {$quartus(args) ni {{} pll}} {error "expected no arguments or pll harness"}
if {![file exists x1_hdmi_clock_handoff.sv]} {error "missing frozen controller"}
if {$quartus(args) eq "pll" && ![file exists hdmi_handoff_map_top.sv]} {error "missing frozen PLL harness"}
if {[llength [glob -nocomplain *.qpf *.qsf]] != 0 || [file exists db]} {
    error "probe refuses an existing project/database"
}
project_new x1_hdmi_handoff_probe
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEBA6U23I7
set_global_assignment -name TOP_LEVEL_ENTITY x1_hdmi_clock_handoff
if {$quartus(args) eq "pll"} {
    set_global_assignment -name TOP_LEVEL_ENTITY hdmi_handoff_map_top
    set_global_assignment -name SYSTEMVERILOG_FILE hdmi_handoff_map_top.sv
}
set_global_assignment -name SYSTEMVERILOG_FILE x1_hdmi_clock_handoff.sv
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
# Initial clock selector, blank and enable states are part of the protocol.
set_global_assignment -name ALLOW_POWER_UP_DONT_CARE OFF
set_global_assignment -name NUM_PARALLEL_PROCESSORS 4
export_assignments
project_close
puts "HDMI handoff isolated project prepared; mapping/fitting/timing not yet executed"
