onerror {quit -code 1}
onbreak {}
onfinish stop
run -all
set completed [examine -radix decimal sim:/hdmi_handoff_vendor_tb/qualification_complete]
puts "HANDOFF_COMPLETION=$completed"
if {$completed != 1} {
    quit -code 1
}
quit -code 0
