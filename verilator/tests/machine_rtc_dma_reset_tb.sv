// SPDX-License-Identifier: GPL-2.0-only
// Public uploads, real Z80 programming/grants, observer-only result checks.
`timescale 1ps/1ps
module machine_rtc_dma_reset_tb;
    bit clk=0,video_clk=0,sys_running=1,reset=1,download=0,upload_wr=0;
    always begin #15625; if(sys_running) clk=~clk; end
    always #17500 video_clk=~video_clk;
    logic [7:0] index=0,upload_data=0;
    logic [24:0] upload_address=0;
    wire upload_wait;
    logic [15:0] controller_rom[4096];
    logic [7:0] ipl[8192];
    string firmware_path,ipl_path;
    integer reads=0,writes=0,grants=0,phase=0,kind=0;
    bit old_read=0,old_write=0,old_owner=0;
    sharpx1 #(.RTC_ENABLE(1),.TURBO(1),.TURBO_DMA(1)) dut(
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
    wire read_active=dut.dma_owner && !dut.rd && (!dut.mreq || !dut.iorq);
    wire write_active=dut.dma_owner && !dut.wr && (!dut.mreq || !dut.iorq);
    always @(posedge clk) begin
        if(read_active && !old_read) reads++;
        if(write_active && !old_write) writes++;
        if(dut.dma_owner && !old_owner) grants++;
        old_read=read_active;old_write=write_active;old_owner=dut.dma_owner;
    end
    task automatic tick;@(posedge clk);#1;endtask
    task automatic upload_byte(input [7:0] which,input integer address,input [7:0] value);
        @(negedge clk);index=which;upload_address=25'(address);upload_data=value;
        download=1;upload_wr=1;
        while(upload_wait) tick();tick();
        @(negedge clk);download=0;upload_wr=0;
    endtask
    task automatic intact;
        for(integer i=0;i<4096;i++)
            assert(dut.subCPU.experimental_rtc.rtc_program[i]==controller_rom[i])
                else $fatal(1,"RTC DMA drain modified controller firmware word=%0d",i);
        for(integer i=0;i<8192;i++) assert(dut.IPL.mem[i]==ipl[i])
            else $fatal(1,"RTC DMA drain modified retained IPL byte=%0d",i);
    endtask
    initial begin
        assert($value$plusargs("ROM=%s",firmware_path) && $value$plusargs("IPL=%s",ipl_path))
            else $fatal(1,"missing generated assets");
        if(!$value$plusargs("PHASE=%d",phase)) phase=0;
        if(!$value$plusargs("KIND=%d",kind)) kind=0;
        assert(phase>=0 && phase<=1 && kind>=0 && kind<=2) else $fatal(1,"invalid RTC DMA case");
        $readmemh(firmware_path,controller_rom);$readmemh(ipl_path,ipl);
        repeat(8) tick();upload_byte(7,0,1);
        for(integer i=0;i<8192;i++) upload_byte(6,i,i%2==0?controller_rom[i/2][7:0]:controller_rom[i/2][15:8]);
        for(integer i=0;i<8192;i++) upload_byte(0,i,ipl[i]);
        intact();repeat(8) tick();@(negedge clk);reset=0;
        if(phase!=0) wait(write_active);else wait(read_active);
        @(negedge clk);#2000;sys_running=0;reset=1;#2000;
        assert(upload_wait && dut.dma_draining && !dut.core_reset && !dut.cpu_busak_n && !dut.cpu_ce)
            else $fatal(1,"RTC DMA reset discarded real ownership");
        // Deliberately hostile host traffic during backpressure. No actual
        // firmware/clock write may occur before the owned pair drains.
        index=kind==0?6:kind==1?7:0;upload_address=0;
        upload_data=kind==0?~controller_rom[0][7:0]:kind==1?1:~ipl[0];
        download=1;upload_wr=1;
        #1250000;
        intact();
        assert(upload_wait && !dut.core_reset && !dut.cpu_busak_n)
            else $fatal(1,"stopped SYS discarded RTC upload drain");
        sys_running=1;
        // Keep selected through one real blocked edge, then remove before
        // drain finishes. A host holding it beyond wait would be a legal load.
        tick();
        assert(upload_wait && !dut.core_reset && !dut.rtc_firmware_load && !dut.rtc_power_reset)
            else $fatal(1,"RTC asset admitted while real DMA owner retained");
        intact();
        assert(dut.subCPU.experimental_rtc.oscillator.phase!=0)
            else $fatal(1,"RTC clock storage lost during DMA drain");
        @(negedge clk);download=0;upload_wr=0;reset=0;
        wait(dut.core_reset);#1;
        assert(reads==1 && writes==1) else $fatal(1,"RTC reset did not drain exactly one pair r=%0d w=%0d",reads,writes);
        intact();
        // These witnesses use now-admissible traffic after actual ownership
        // release. They must fail the same immutable/retained-clock oracles.
        if($test$plusargs("NEGATIVE_AFTER_DRAIN")) begin
            upload_byte(6,0,~controller_rom[0][7:0]);intact();
            $fatal(1,"post-drain firmware negative missed oracle");
        end
        if($test$plusargs("NEGATIVE_AFTER_POWER")) upload_byte(7,0,1);
        wait(!dut.core_reset);
        wait(!dut.halt_n && writes==17 && dut.dma_busrq_n && dut.cpu_busak_n);
        repeat(16) tick();intact();
        assert(grants==2 && reads==17 && dut.RAM.mem['hf100]==2)
            else $fatal(1,"RTC native DMA reboot/count mismatch");
        for(integer i=0;i<16;i++) assert(dut.RAM.mem['h9100+i]==8'h31+8'(i*13))
            else $fatal(1,"RTC reboot DMA payload mismatch %0d",i);
        assert(dut.RAM.mem['hf020]==8'h31 && dut.RAM.mem['hf021]==8'hc6 && dut.RAM.mem['hf022]==0 &&
               dut.RAM.mem['hf023]==8'h12 && dut.RAM.mem['hf024]==8'h34 && dut.RAM.mem['hf025]==8'h56)
            else $fatal(1,"RTC actual second CPU read lost retained clock");
        $display("PASS: RTC actual DMA owned %0d phase, blocked asset kind %0d, stopped SYS recovery, retained firmware/IPL/calendar and second native CPU DMA payload",phase,kind);
        $finish;
    end
    initial begin #10000000000;$fatal(1,"RTC DMA watchdog");end
endmodule
