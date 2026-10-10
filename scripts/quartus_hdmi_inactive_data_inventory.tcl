# Discovery only: inherited inactive data branches, no new constraints.
package require ::quartus::project
package require ::quartus::sta
if {[llength $quartus(args)] != 1} {error "expected NEW report directory"}
set destination [lindex $quartus(args) 0]
if {[file exists $destination]} {error "refusing to overwrite evidence"}
project_open sharpx1 -revision sharpx1_turbo_z_handoff
create_timing_netlist -model slow -temperature 100 -voltage 1100
read_sdc
update_timing_netlist
set pairs {
    hdmi_to_video {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk x1_video_handoff_mux}
    video_to_hdmi {emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk x1_hdmi_handoff_mux}
}
foreach {kind pair} $pairs {
    foreach role {from to} name $pair {
        set clocks [get_clocks [list $name]]
        if {[get_collection_size $clocks] != 1} {error "missing/ambiguous data-branch clock"}
        foreach_in_collection clock $clocks {
            if {[get_clock_info -name $clock] ne $name} {error "substituted data-branch clock"}
        }
        set route_clocks($kind,$role) $clocks
    }
    puts "INACTIVE DATA CLOCK PAIR $kind [lindex $pair 0] [lindex $pair 1]"
}
set targets {hs vs de}
for {set bit 0} {$bit < 24} {incr bit} {
    lappend targets [format {d[%d]} $bit]
}
# Enumerate physical prefetch keepers: repeated logical RGB bits can merge.
# This is discovery, not permission to omit an optimized/replicated route.
set prefetch [get_registers -no_duplicates {hdmi_dv*}]
if {![get_collection_size $prefetch]} {error "missing physical DV prefetch bank"}
foreach_in_collection reg $prefetch {
    set name [get_register_info -name $reg]
    if {![regexp {^hdmi_dv_(hs|vs|de|data\[([0-9]+)\])(~.*|_Duplicate_.*)?$} $name -> field bit]} {
        error "unreviewed physical prefetch keeper $name"
    }
    if {$bit ne "" && $bit > 23} {error "out-of-range physical prefetch bit"}
    lappend targets $name
}
set pins [get_pins -compatibility_mode {hdmi_dv*|* d*|* hs*|* vs*|* de*|*}]
foreach name $targets {
    set regs [get_registers -no_duplicates [list $name]]
    if {[get_collection_size $regs] != 1} {error "missing/ambiguous data-branch register $name"}
    foreach_in_collection reg $regs {
        if {[get_register_info -name $reg] ne $name} {error "substituted data-branch register"}
    }
    puts "INACTIVE DATA TARGET $name"
    foreach_in_collection node [get_fanins -synch $regs] {
        puts "INACTIVE DATA DRIVER $name [get_node_info -name $node] ([get_node_info -type $node])"
    }
    foreach_in_collection pin $pins {
        set actual [get_pin_info -name $pin]
        if {[string first "${name}|" $actual] == 0} {puts "INACTIVE DATA PIN $name $actual"}
    }
}
file mkdir $destination
foreach model {slow fast} {
    foreach temperature {-40 0 85 100} {
        set_operating_conditions -model $model -temperature $temperature -voltage 1100
        update_timing_netlist
        puts "INACTIVE DATA CORNER $model $temperature 1100"
        foreach check {setup hold} {
            foreach {kind pair} $pairs {
                report_timing -$check -from $route_clocks($kind,from) -to $route_clocks($kind,to) \
                    -npaths 1000 -detail full_path \
                    -file [file join $destination ${model}_${temperature}_${kind}_${check}.rpt]
            }
        }
    }
}
puts "INACTIVE DATA INVENTORY COMPLETE: discovery only; no exclusions or timing acceptance"
delete_timing_netlist
project_close
