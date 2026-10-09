# Supported ModelSim macro, not an inline console error-handler command.
onerror {quit -code 1}
onbreak {quit -code 1}
onfinish exit
vcd file vendor-clock.vcd
vcd add -r /*
run -all
# Normal $finish exits; caller must require the 48-check PASS marker and
# zero errors as well as process exit. A stop/fatal takes onbreak/onerror.
