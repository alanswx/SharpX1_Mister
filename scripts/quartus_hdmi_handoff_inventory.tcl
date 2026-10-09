# Isolated fitted probe inventory and unwaived diagnostics; NOT board closure.
package require ::quartus::project
package require ::quartus::sta
if {$quartus(args) ni {{} mux-clocks mux-all-corners}} {error "expected no arguments, mux-clocks or mux-all-corners probe"}
project_open x1_hdmi_handoff_probe
create_timing_netlist -model slow -temperature 100 -voltage 1100
# Explicit probe reference only. Real board clocks/constraints remain separate.
create_clock -name probe_ref -period 20.0 [get_ports refclk]
derive_pll_clocks
derive_clock_uncertainty
set prefix output_files/handoff_probe
if {$quartus(args) ne ""} {
    # Two choices AFTER this mux only; concurrent PLL masters stay uncut.
    set hdmi [get_clocks {hdmi_pll|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
    set video [get_clocks {video_pll|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
    set output [get_pins -compatibility_mode {handoff|mux|outclk}]
    set hdmi_input [get_pins -compatibility_mode {handoff|mux|inclk[2]}]
    set video_input [get_pins -compatibility_mode {handoff|mux|inclk[3]}]
    foreach {name collection} [list hdmi $hdmi video $video output $output hdmi_input $hdmi_input video_input $video_input] {
        if {[get_collection_size $collection] != 1} {error "ambiguous/missing actual probe $name"}
    }
    foreach_in_collection clock $hdmi {set hdmi_name [get_clock_info -name $clock]}
    foreach_in_collection clock $video {set video_name [get_clock_info -name $clock]}
    create_generated_clock -name probe_mux_hdmi -master_clock $hdmi_name -source $hdmi_input -divide_by 1 $output
    create_generated_clock -name probe_mux_video -master_clock $video_name -source $video_input -divide_by 1 -add $output
    set_clock_groups -logically_exclusive -group {probe_mux_hdmi} -group {probe_mux_video}
    set prefix output_files/handoff_probe_mux
    puts "HANDOFF PROBE two generated mux choices only; PLL masters remain concurrent"
}
update_timing_netlist
report_clocks -file ${prefix}_clocks.rpt
set registers [get_registers {*handoff|*}]
if {![get_collection_size $registers]} {error "missing fitted handoff registers"}
foreach_in_collection reg $registers {
    puts "HANDOFF FITTED REGISTER [get_register_info -name $reg]"
}
foreach field {gate_request_meta gate_request_sample} {
    set physical [get_registers -no_duplicates [list "x1_hdmi_clock_handoff:handoff|$field"]]
    if {[get_collection_size $physical] != 1} {error "missing/ambiguous enable synchronizer $field"}
    foreach_in_collection node [get_fanouts $physical] {
        puts "HANDOFF ENABLE FANOUT $field [get_node_info -name $node] ([get_node_info -type $node])"
    }
}
set observed [get_registers -no_duplicates {x1_hdmi_clock_handoff:handoff|gate_observed_enable}]
set status_meta [get_registers -no_duplicates {x1_hdmi_clock_handoff:handoff|gate_meta}]
set native_enable [get_registers -no_duplicates {x1_hdmi_clock_handoff:handoff|gate~FF_0}]
if {[get_collection_size $observed] != 1 || [get_collection_size $status_meta] != 1} {
    error "missing/ambiguous explicit falling-edge witness/status sample"
}
if {[get_collection_size $native_enable] != 1} {error "missing/ambiguous fitted native gate enable register"}
foreach_in_collection node [get_fanins $status_meta] {
    puts "HANDOFF STATUS FANIN [get_node_info -name $node] ([get_node_info -type $node])"
}
foreach block {mux gate} {
    set pins [get_pins -compatibility_mode [list "*handoff|$block|*"]]
    puts "HANDOFF FITTED CLOCK BLOCK $block [get_collection_size $pins] pins"
    foreach_in_collection pin $pins {
        puts "HANDOFF FITTED CLOCK PIN [get_pin_info -name $pin]"
    }
}
# Keep raw CDC and unrelated violations visible; only mux choices exclusive.
set corners {{slow 100}}
if {$quartus(args) eq "mux-all-corners"} {
    set corners {}
    foreach model {slow fast} {
        foreach temperature {-40 0 85 100} {lappend corners [list $model $temperature]}
    }
}
set base_prefix $prefix
foreach corner $corners {
    lassign $corner model temperature
    set_operating_conditions -model $model -temperature $temperature -voltage 1100
    update_timing_netlist
    if {$quartus(args) eq "mux-all-corners"} {
        set prefix ${base_prefix}_${model}_${temperature}
        puts "HANDOFF PROBE CORNER $model $temperature 1100"
    }
foreach check {setup hold} {
    report_timing -$check -npaths 50 -detail full_path -file ${prefix}_global_${check}.rpt
    report_timing -$check -from [get_registers {*handoff|gate_request_meta}] \
        -to [get_registers {*handoff|gate_request_sample}] -npaths 10 -detail full_path \
        -file ${prefix}_enable_${check}.rpt
    report_timing -$check -from [get_registers {*handoff|gate_request_sample}] \
        -to [get_registers {*handoff|gate_observed_enable}] -npaths 10 -detail full_path \
        -file ${prefix}_witness_${check}.rpt
    report_timing -$check -from [get_registers {*handoff|gate_request_sample}] \
        -to $native_enable -npaths 10 -detail full_path \
        -file ${prefix}_native_gate_${check}.rpt
    report_timing -$check -from [get_registers {*handoff|gate_request *handoff|gate_request~DUPLICATE}] \
        -to [get_registers {*handoff|gate_request_meta}] -npaths 10 -detail full_path \
        -file ${prefix}_raw_enable_${check}.rpt
}
}
delete_timing_netlist
project_close
