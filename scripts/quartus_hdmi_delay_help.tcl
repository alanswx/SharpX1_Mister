# Read installed tool semantics; no project, netlist, constraints or writes.
package require ::quartus::sta
puts [set_max_delay -long_help]
puts [set_min_delay -long_help]
puts [set_false_path -long_help]
