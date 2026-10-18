# Single-clock X3 revisions only. The X3 PLL output is both the machine
# master and MiSTer CLK_VIDEO: the role stock sys_top.sdc gives to the core
# *|pll|pll_inst outputs, which it separates from HDMI, audio, SPI, I2C, HPS
# and 50-MHz clocks. Apply exactly that framework separation to this one
# clock. Every machine path, including former SYS<->VID transfers, is now a
# same-clock path and stays fully timed. The core PLL is deliberately not
# grouped with the X3 master; any path between them remains timed.
set x1_x3_master [get_clocks {emu|turbo_video_pll|oscillator|*|divclk}]
if {[get_collection_size $x1_x3_master] != 1} {
    error "expected exactly one X3 master clock; refuse framework grouping"
}
set_clock_groups -exclusive \
   -group $x1_x3_master \
   -group [get_clocks { pll_hdmi|pll_hdmi_inst|altera_pll_i|*[0].*|divclk}] \
   -group [get_clocks { pll_audio|pll_audio_inst|altera_pll_i|*[0].*|divclk}] \
   -group [get_clocks { spi_sck}] \
   -group [get_clocks { hdmi_sck}] \
   -group [get_clocks { *|h2f_user0_clk}] \
   -group [get_clocks { FPGA_CLK1_50 }] \
   -group [get_clocks { FPGA_CLK2_50 }] \
   -group [get_clocks { FPGA_CLK3_50 }]
