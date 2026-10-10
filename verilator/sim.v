`timescale 1ps/1ps
// Instantiate the same machine as the MiSTer wrapper.
module top #(parameter SINGLE_CLOCK = 0, MASTER_HZ = 28636364, TURBO = 0, TURBO_VIDEO_MASTER = 0, TURBO_DMA = 0, TURBO_DMA_IRQ = 0, TURBO_KANJI = 0, TURBO_KANJI_RENDER = 0, TURBO_DSW = 241, TURBO_DMA_RESTART_IRQ = 0, TURBO_Z_PALETTE_CPU = 0, TURBO_Z_VIDEO = 0, TURBO_Z_MULTIMODE = 0, TURBO_Z_INTERNAL8 = 0, TURBO_Z_TEXT_CPU = 0, TURBO_FM_CPU = 0, RTC_ENABLE = 0, TURBO_DMA_KANJI_EXPERIMENT = 0, D88_ADDRESS_BITS = 20, TURBO_HD_SELECT = 0, TURBO_HD_MEDIA = 0,
    TURBO_FDC_TIMING = 0, FDC_CLOCK_HZ = 1000000) (
    input clk_sys, clk_28636, reset,
    input ioctl_download,
    input [7:0] ioctl_index,
    input ioctl_wr,
    input [24:0] ioctl_addr,
    input [7:0] ioctl_dout,
    output ioctl_wait,
    input ps2_clk_in, ps2_data_in,
    input [7:0] joya_n, joyb_n,
    input disk_ready, img_mounted, disk_wp,
    input [23:0] img_size,
    input disk_ready_b, img_mounted_b, disk_wp_b,
    input [23:0] img_size_b,
    output sd_drive,
    output [7:0] debug_disk_control,
    output debug_disk_motor, debug_disk_ready,
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
    output [11:0] rgb12,
    output [15:0] audio,
    output signed [15:0] audio_left,audio_right,audio_mono,
    output audio_sample,
    output ce_pix,
    output HSync, VSync, HBlank, VBlank,
    output reg [63:0] sys_edges = 0,
    output reg [63:0] video_edges = 0,
    output reg [63:0] reset_edges = 0,
    output reg [63:0] cpu_enables = 0,
    output reg [63:0] delayed_sys_edges = 0,
    output reg [63:0] dma_grants = 0, dma_reads = 0, dma_writes = 0,
    cpu_fdc_data_reads = 0, cpu_fdc_data_writes = 0
);
    sharpx1 #(.SINGLE_CLOCK(SINGLE_CLOCK), .MASTER_HZ(MASTER_HZ), .TURBO(TURBO), .TURBO_VIDEO_MASTER(TURBO_VIDEO_MASTER), .TURBO_DMA(TURBO_DMA), .TURBO_DMA_IRQ(TURBO_DMA_IRQ), .TURBO_KANJI(TURBO_KANJI), .TURBO_KANJI_RENDER(TURBO_KANJI_RENDER), .TURBO_DSW(TURBO_DSW), .TURBO_DMA_RESTART_IRQ(TURBO_DMA_RESTART_IRQ), .TURBO_Z_PALETTE_CPU(TURBO_Z_PALETTE_CPU), .TURBO_Z_VIDEO(TURBO_Z_VIDEO), .TURBO_Z_MULTIMODE(TURBO_Z_MULTIMODE), .TURBO_Z_INTERNAL8(TURBO_Z_INTERNAL8), .TURBO_Z_TEXT_CPU(TURBO_Z_TEXT_CPU), .TURBO_FM_CPU(TURBO_FM_CPU), .RTC_ENABLE(RTC_ENABLE), .TURBO_DMA_KANJI_EXPERIMENT(TURBO_DMA_KANJI_EXPERIMENT), .D88_ADDRESS_BITS(D88_ADDRESS_BITS), .TURBO_HD_SELECT(TURBO_HD_SELECT), .TURBO_HD_MEDIA(TURBO_HD_MEDIA), .TURBO_FDC_TIMING(TURBO_FDC_TIMING), .FDC_CLOCK_HZ(FDC_CLOCK_HZ)) machine (
        .clk_sys(clk_sys), .clk_28636(clk_28636), .reset(reset),
        .pal(1'b0), .scandouble(1'b0),
        .ioctl_download(ioctl_download), .ioctl_index(ioctl_index),
        .ioctl_wr(ioctl_wr), .ioctl_addr(ioctl_addr), .ioctl_dout(ioctl_dout),
        .ioctl_wait(ioctl_wait),
        .ps2_clk_in(ps2_clk_in), .ps2_data_in(ps2_data_in), .joya_n(joya_n), .joyb_n(joyb_n),
        .sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),
        .sio_rxd(2'b11),.sio_cts_n(2'b11),.sio_dcd_n(2'b11),
        .sio_txd(),.sio_rts_n(),.sio_dtr_n(),
        .disk_ready(disk_ready), .img_mounted(img_mounted), .disk_wp(disk_wp), .img_size(img_size),
        .disk_ready_b(disk_ready_b), .img_mounted_b(img_mounted_b), .disk_wp_b(disk_wp_b), .img_size_b(img_size_b), .sd_drive(sd_drive),
        .sd_lba(sd_lba), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
        .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout),
        .sd_buff_din(sd_buff_din), .sd_buff_wr(sd_buff_wr),
        .video(video), .rgb(rgb), .rgb12(rgb12), .audio(audio), .ce_pix(ce_pix),
        .audio_left(audio_left),.audio_right(audio_right),.audio_mono(audio_mono),.audio_sample(audio_sample),
        .HSync(HSync), .VSync(VSync), .HBlank(HBlank), .VBlank(VBlank)
    );
    assign debug_ram = machine.RAM.mem[debug_addr];
    assign debug_disk_control = machine.disk_control.control;
    assign debug_disk_motor = machine.disk_motor;
    assign debug_disk_ready = machine.fdc.media_ready;
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
    reg was_dma_owner = 0, was_dma_read = 0, was_dma_write = 0;
    reg was_cpu_fdc_read = 0, was_cpu_fdc_write = 0;
    wire dma_read_active = machine.dma_owner && !machine.rd && (!machine.mreq || !machine.iorq);
    wire dma_write_active = machine.dma_owner && !machine.wr && (!machine.mreq || !machine.iorq);
    wire cpu_fdc_read = !machine.dma_owner && machine.io_read && !machine.dam && machine.a == 16'h0ffb;
    wire cpu_fdc_write = !machine.dma_owner && machine.io_write && !machine.dam && machine.a == 16'h0ffb;
    always @(posedge clk_sys) begin
        if (machine.dma_owner && !was_dma_owner) dma_grants <= dma_grants + 1;
        if (dma_read_active && !was_dma_read) dma_reads <= dma_reads + 1;
        if (dma_write_active && !was_dma_write) dma_writes <= dma_writes + 1;
        if (cpu_fdc_read && !was_cpu_fdc_read) cpu_fdc_data_reads <= cpu_fdc_data_reads + 1;
        if (cpu_fdc_write && !was_cpu_fdc_write) cpu_fdc_data_writes <= cpu_fdc_data_writes + 1;
        was_dma_owner <= machine.dma_owner;
        was_dma_read <= dma_read_active; was_dma_write <= dma_write_active;
        was_cpu_fdc_read <= cpu_fdc_read; was_cpu_fdc_write <= cpu_fdc_write;
        assert (machine.Cpu.reset_n == !machine.core_reset)
            else $fatal(1, "CPU reset polarity mismatch");
        assert (machine.subCPU.I_reset == machine.core_reset)
            else $fatal(1, "Sub-CPU reset polarity mismatch");
        // Skip the first sampled edge of each reset pulse; allow the CPU's
        // delayed reset assignments before checking the idle bus/address.
        if (!(TURBO && TURBO_DMA))
            assert (machine.core_reset == reset)
                else $fatal(1, "Default reset policy changed");
        if (machine.dma_draining) begin
            assert (!machine.cpu_ce && !machine.core_reset && !machine.cpu_busak_n)
                else $fatal(1, "Reset discarded an owned DMA pair");
        end
        if (machine.core_reset && was_reset) begin
            assert (machine.a == 16'h0000)
                else $fatal(1, "CPU reset address is not zero");
            assert (machine.mreq && machine.iorq && machine.rd && machine.wr)
                else $fatal(1, "CPU bus strobes active during reset");
        end
        sys_edges <= sys_edges + 1;
        was_reset <= machine.core_reset;
        if (reset) reset_edges <= reset_edges + 1;
        if (machine.cpu_ce) cpu_enables <= cpu_enables + 1;
        // Exercise --timing: must settle one ns after each rising edge.
        delayed_sys_edges <= #1000 sys_edges + 1;
    end
    always @(posedge clk_28636) video_edges <= video_edges + 1;
endmodule
