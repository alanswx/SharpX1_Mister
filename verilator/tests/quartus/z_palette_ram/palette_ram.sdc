# Resource probe only: these are synthetic input clocks, not fitted board PLLs.
create_clock -name cpu -period 31.250 [get_ports cpu_clk]
create_clock -name video -period 23.280 [get_ports video_clk]
# No global false paths, RAM-collision promise or physical I/O timing claim.
