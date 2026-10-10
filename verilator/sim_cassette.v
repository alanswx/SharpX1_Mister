// SPDX-License-Identifier: GPL-2.0-only
// Original non-savable top. Hierarchy is read-only observation.
`timescale 1ps/1ps
module cassette_top (
    input clk_sys, clk_28636, reset,
    input ioctl_download, ioctl_wr,
    input [7:0] ioctl_index, ioctl_dout,
    input [24:0] ioctl_addr,
    output ioctl_wait, core_reset,
    input ps2_clk_in, ps2_data_in,
    input tape_mount, tape_present, tape_empty,
    input tape_sample_valid, tape_sample_level, tape_sample_last,
    output tape_sample_ready, tape_underflow, tape_waveform,
    output [7:0] tape_mode, tape_sensor,
    output ce_pix, HSync, VSync, HBlank, VBlank, sd_rd, sd_wr,
    output [11:0] rgb12,
    input [15:0] debug_addr,
    output [7:0] debug_ram, debug_text, debug_attr,
    output [7:0] debug_pcgb, debug_pcgr, debug_pcgg,
    output [7:0] debug_gramb, debug_gramr, debug_gramg,
    output [15:0] cpu_address, sub_pc,
    output cpu_halt_n
);
    sharpx1 #(.CASSETTE_ENABLE(1)) machine (
        .clk_sys(clk_sys), .clk_28636(clk_28636), .reset(reset),
        .pal(1'b0), .scandouble(1'b0),
        .ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr),
        .ioctl_index(ioctl_index), .ioctl_addr(ioctl_addr),
        .ioctl_dout(ioctl_dout), .ioctl_wait(ioctl_wait),
        .ps2_clk_in(ps2_clk_in), .ps2_data_in(ps2_data_in),
        .joya_n(8'hff), .joyb_n(8'hff),
        .tape_mount(tape_mount), .tape_present(tape_present), .tape_empty(tape_empty),
        .tape_sample_valid(tape_sample_valid), .tape_sample_level(tape_sample_level),
        .tape_sample_last(tape_sample_last), .tape_sample_ready(tape_sample_ready),
        .tape_underflow(tape_underflow), .tape_mode(tape_mode), .tape_sensor(tape_sensor),
        .sio_external_rx_clock(1'b0), .sio_external_tx_clock(1'b0),
        .sio_rxd(2'b11), .sio_cts_n(2'b11), .sio_dcd_n(2'b11),
        .sio_txd(), .sio_rts_n(), .sio_dtr_n(),
        .disk_ready(1'b0), .img_mounted(1'b0), .disk_wp(1'b1), .img_size(24'd0),
        .disk_ready_b(1'b0), .img_mounted_b(1'b0), .disk_wp_b(1'b1), .img_size_b(24'd0),
        .sd_drive(), .sd_lba(), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(1'b0),
        .sd_buff_addr(9'd0), .sd_buff_dout(8'd0), .sd_buff_din(), .sd_buff_wr(1'b0),
        .ce_pix(ce_pix), .HSync(HSync), .VSync(VSync), .HBlank(HBlank), .VBlank(VBlank),
        .rgb12(rgb12), .video(), .rgb(), .audio(),
        .audio_left(), .audio_right(), .audio_mono(), .audio_sample()
    );
    assign core_reset = machine.core_reset;
    assign tape_waveform = machine.cassette_waveform;
    assign debug_ram = machine.RAM.mem[debug_addr];
    assign debug_text = machine.text_ram.mem[debug_addr[10:0]];
    assign debug_attr = machine.attr_ram.mem[debug_addr[10:0]];
    assign debug_pcgb = machine.pcg_b.mem[debug_addr[10:0]];
    assign debug_pcgr = machine.pcg_r.mem[debug_addr[10:0]];
    assign debug_pcgg = machine.pcg_g.mem[debug_addr[10:0]];
    // This top is base X1 only: each physical GRAM plane is 16 KiB.
    // Passive inspection never clocks, writes or supplies CPU bus data.
    assign debug_gramb = machine.gram_b.mem[debug_addr[13:0]];
    assign debug_gramr = machine.gram_r.mem[debug_addr[13:0]];
    assign debug_gramg = machine.gram_g.mem[debug_addr[13:0]];
    assign cpu_address = machine.a;
    assign cpu_halt_n = machine.halt_n;
    assign sub_pc = {machine.subCPU.sub_cpu.cpu.reg_pc, 1'b0};
endmodule
