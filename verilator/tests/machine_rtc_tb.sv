// SPDX-License-Identifier: GPL-2.0-only
// Original IPL + source-derived controller firmware via ioctl, actual Z80.
// Ordinary profiles remain disabled. No RAM/CPU/RTC forcing or private IPL.
`timescale 1ps/1ps
module machine_rtc_tb #(parameter RTC_ENABLED=1);
    bit clk=0,video_clk=0,reset=1,download=0,upload_wr=0;
    always #15625 clk=~clk;
    always #17500 video_clk=~video_clk;
    logic [7:0] index=0,upload_data=0;
    logic [24:0] upload_address=0;
    wire upload_wait;
    logic [15:0] controller_rom[4096];
    logic [7:0] ipl[8192];
    string firmware_path,ipl_path;
    integer timer_acks=0;
    sharpx1 #(.RTC_ENABLE(RTC_ENABLED)) dut(
        .clk_sys(clk),.clk_28636(video_clk),.reset(reset),.pal(1'b0),.scandouble(1'b0),
        .ioctl_download(download),.ioctl_index(index),.ioctl_wr(upload_wr),
        .ioctl_addr(upload_address),.ioctl_dout(upload_data),.ioctl_wait(upload_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),.sio_rxd(2'b11),
        .sio_cts_n(2'b11),.sio_dcd_n(2'b11),.sio_txd(),.sio_rts_n(),.sio_dtr_n(),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_drive(),.sd_lba(),.sd_rd(),.sd_wr(),.sd_ack(1'b0),
        .sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_din(),.sd_buff_wr(1'b0),
        .ce_pix(),.HBlank(),.HSync(),.VBlank(),.VSync(),.video(),.rgb(),.rgb12(),
        .audio(),.audio_left(),.audio_right(),.audio_mono(),.audio_sample());
    always @(posedge clk) if(!dut.core_reset && dut.subCPU.sub_cpu.timer_ack) timer_acks++;
    task automatic tick;@(posedge clk);#1;endtask
    task automatic upload_byte(input [7:0] kind, input integer address, input [7:0] value);
        @(negedge clk);index=kind;upload_address=25'(address);upload_data=value;
        download=1;upload_wr=1;
        while(upload_wait) tick();
        tick();
        @(negedge clk);upload_wr=0;
    endtask
    initial begin
        assert($value$plusargs("ROM=%s",firmware_path) && $value$plusargs("IPL=%s",ipl_path))
            else $fatal(1,"machine RTC missing generated firmware/IPL");
        $readmemh(firmware_path,controller_rom);$readmemh(ipl_path,ipl);
        repeat(8) tick();upload_byte(7,0,1);
        for(integer a=0;a<8192;a++) upload_byte(6,a,a%2==0 ? controller_rom[a/2][7:0] : controller_rom[a/2][15:8]);
        for(integer a=0;a<8192;a++) upload_byte(0,a,ipl[a]);
        download=0;upload_wr=0;repeat(8) tick();
        @(negedge clk);reset=0;
        for(integer i=0;i<70400000 && dut.halt_n;i++) tick();
        assert(!dut.halt_n && timer_acks>10) else $fatal(1,"machine RTC actual CPU/MCU completion missing");
        assert(dut.RAM.mem['hf000]==8'h52 && dut.RAM.mem['hf001]==8'h54 &&
            dut.RAM.mem['hf002]==8'h43 && dut.RAM.mem['hf003]==8'h32)
            else $fatal(1,"machine RTC diagnostic marker missing");
        // No state injection; memory below is observation only.
        assert(dut.RAM.mem['hf010]==8'h31 && dut.RAM.mem['hf011]==8'hc6 && dut.RAM.mem['hf012]==8'h99 &&
            dut.RAM.mem['hf013]==8'h12 && dut.RAM.mem['hf014]==8'h34 && dut.RAM.mem['hf015]==8'h56)
            else $fatal(1,"machine RTC early command readback mismatch");
        assert(dut.RAM.mem['hf020]==8'h31 && dut.RAM.mem['hf021]==8'hc6 && dut.RAM.mem['hf022]==8'h99 &&
            dut.RAM.mem['hf023]==8'h12 && dut.RAM.mem['hf024]==8'h34 &&
            (dut.RAM.mem['hf025]==8'h57 || dut.RAM.mem['hf025]==8'h58))
            else $fatal(1,"machine RTC elapsed seconds mismatch sec=%h enabled=%0d",dut.RAM.mem['hf025],RTC_ENABLED);
        $display("PASS: shared machine real Z80 EC..EF IPL-driven elapsed seconds=%h, running MR16 timer IRQs=%0d, source-derived firmware uploaded through ioctl; native/year/reset/DMA/hardware separate",dut.RAM.mem['hf025],timer_acks);
        $finish;
    end
endmodule
