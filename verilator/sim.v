`timescale 1ps/1ps
// Instantiate the same machine as the MiSTer wrapper.
module top #(parameter SINGLE_CLOCK = 0, MASTER_HZ = 28636364) (
    input clk_sys, clk_28636, reset,
    input ioctl_download,
    input [7:0] ioctl_index,
    input ioctl_wr,
    input [24:0] ioctl_addr,
    input [7:0] ioctl_dout,
    input ps2_clk_in, ps2_data_in,
    input [7:0] joya_n, joyb_n,
    input disk_ready, img_mounted, disk_wp,
    input [23:0] img_size,
    output [31:0] sd_lba,
    output sd_rd, sd_wr,
    input sd_ack,
    input [8:0] sd_buff_addr,
    input [7:0] sd_buff_dout,
    output [7:0] sd_buff_din,
    input sd_buff_wr,
    input [15:0] debug_addr,
    output [7:0] debug_ram,
    output [7:0] debug_text, debug_attr,
    output [15:0] sub_pc, sub_address, sub_control,
    output sub_wait, sub_tx, sub_rx,
    output [15:0] cpu_address,
    output [7:0] cpu_in, cpu_out,
    output cpu_mreq_n, cpu_iorq_n, cpu_rd_n, cpu_wr_n, cpu_halt_n,
    output [7:0] video,
    output [2:0] rgb,
    output [15:0] audio,
    output ce_pix,
    output HSync, VSync, HBlank, VBlank,
    output reg [63:0] sys_edges = 0,
    output reg [63:0] video_edges = 0,
    output reg [63:0] reset_edges = 0,
    output reg [63:0] cpu_enables = 0,
    output reg [63:0] delayed_sys_edges = 0
);
    sharpx1 #(.SINGLE_CLOCK(SINGLE_CLOCK), .MASTER_HZ(MASTER_HZ)) machine (
        .clk_sys(clk_sys), .clk_28636(clk_28636), .reset(reset),
        .pal(1'b0), .scandouble(1'b0),
        .ioctl_download(ioctl_download), .ioctl_index(ioctl_index),
        .ioctl_wr(ioctl_wr), .ioctl_addr(ioctl_addr), .ioctl_dout(ioctl_dout),
        .ps2_clk_in(ps2_clk_in), .ps2_data_in(ps2_data_in), .joya_n(joya_n), .joyb_n(joyb_n),
        .disk_ready(disk_ready), .img_mounted(img_mounted), .disk_wp(disk_wp), .img_size(img_size),
        .sd_lba(sd_lba), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
        .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout),
        .sd_buff_din(sd_buff_din), .sd_buff_wr(sd_buff_wr),
        .video(video), .rgb(rgb), .audio(audio), .ce_pix(ce_pix),
        .HSync(HSync), .VSync(VSync), .HBlank(HBlank), .VBlank(VBlank)
    );
    assign debug_ram = machine.RAM.mem[debug_addr];
    assign debug_text = machine.text_ram.mem[debug_addr[10:0]];
    assign debug_attr = machine.attr_ram.mem[debug_addr[10:0]];
    assign sub_pc = {machine.subCPU.sub_cpu.cpu.reg_pc,1'b0};
    assign sub_address = machine.subCPU.sub_addr;
    assign sub_control = machine.subCPU.OP1;
    assign sub_wait = machine.subCPU.scpu_wait_n;
    assign sub_tx = machine.sub_tx_busy;
    assign sub_rx = machine.sub_rx_busy;
    assign cpu_address = machine.a;
    assign cpu_in = machine.di;
    assign cpu_out = machine.data_out;
    assign cpu_mreq_n = machine.mreq;
    assign cpu_iorq_n = machine.iorq;
    assign cpu_rd_n = machine.rd;
    assign cpu_wr_n = machine.wr;
    assign cpu_halt_n = machine.halt_n;
    // Simulation instrumentation, not substitute machine behavior.
    reg was_reset = 0;
    always @(posedge clk_sys) begin
        assert (machine.Cpu.reset_n == !reset)
            else $fatal(1, "CPU reset polarity mismatch");
        assert (machine.subCPU.I_reset == reset)
            else $fatal(1, "Sub-CPU reset polarity mismatch");
        // Skip the initial edge; allow the CPU's delayed reset assignments.
        if (reset && was_reset) begin
            assert (machine.a == 16'h0000)
                else $fatal(1, "CPU reset address is not zero");
            assert (machine.mreq && machine.iorq && machine.rd && machine.wr)
                else $fatal(1, "CPU bus strobes active during reset");
        end
        sys_edges <= sys_edges + 1;
        was_reset <= reset;
        if (reset) reset_edges <= reset_edges + 1;
        if (!reset && machine.pe4M4) cpu_enables <= cpu_enables + 1;
        // Exercise --timing: must settle one ns after each rising edge.
        delayed_sys_edges <= #1000 sys_edges + 1;
    end
    always @(posedge clk_28636) video_edges <= video_edges + 1;
endmodule
