# Standalone resource probe, not a board PLL, I/O or physical CDC contract.
create_clock -name sys -period 31.250 [get_ports clk_sys]
create_clock -name vid -period 23.280 [get_ports clk_vid]
# Keep cross-domain paths visible. No blanket false paths or RAM collision promise.
