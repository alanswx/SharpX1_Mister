// SPDX-License-Identifier: GPL-2.0-only
// Original public-ioctl admission test. Hierarchical memory is observation only.
`timescale 1ps/1ps
module machine_rtc_transport_tb;
    bit clk=0,video_clk=0,reset=1,download=0,upload_wr=0;
    always #15625 clk=~clk;
    always #17500 video_clk=~video_clk;
    logic [7:0] index=0,upload_data=0;
    logic [24:0] upload_address=0;
    wire upload_wait;
    logic [15:0] controller_rom[4096];
    string firmware_path;
    integer rejected=0;
    sharpx1 #(.RTC_ENABLE(1)) dut(
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
    task automatic tick;@(posedge clk);#1;endtask
    task automatic transfer(input [7:0] kind,input [24:0] address,input [7:0] value,
                            input bit downloading,input bit writing);
        @(negedge clk);index=kind;upload_address=address;upload_data=value;
        download=downloading;upload_wr=writing;
        assert(!upload_wait) else $fatal(1,"unexpected non-DMA transport wait");
        tick();
        @(negedge clk);download=0;upload_wr=0;
    endtask
    task automatic intact;
        for(integer w=0;w<4096;w++)
            assert(dut.subCPU.experimental_rtc.rtc_program[w]==controller_rom[w])
                else $fatal(1,"RTC transport firmware corruption word=%0d",w);
    endtask
    task automatic no_power(input [7:0] kind,input [24:0] address,input [7:0] value,
                            input bit downloading,input bit writing);
        transfer(kind,address,value,downloading,writing);
        assert(dut.subCPU.experimental_rtc.oscillator.phase!=0)
            else $fatal(1,"RTC transport unexpected clock-storage loss");
        rejected++;
    endtask
    initial begin
        assert($value$plusargs("ROM=%s",firmware_path)) else $fatal(1,"missing firmware");
        $readmemh(firmware_path,controller_rom);
        repeat(8) tick();transfer(7,0,1,1,1);
        for(integer a=0;a<8192;a++)
            transfer(6,25'(a),a%2==0?controller_rom[a/2][7:0]:controller_rom[a/2][15:8],1,1);
        intact();
        // Exercise every high address bit with low aliases at both image ends.
        for(integer b=13;b<25;b++) begin
            transfer(6,25'(1<<b),~controller_rom[0][7:0],1,1);
            transfer(6,25'((1<<b)|8191),~controller_rom[4095][15:8],1,1);
            intact();rejected+=2;
        end
        transfer(6,25'h1ffffff,~controller_rom[4095][15:8],1,1);intact();rejected++;
        transfer(5,0,~controller_rom[0][7:0],1,1);intact();rejected++;
        transfer(6,0,~controller_rom[0][7:0],0,1);intact();rejected++;
        transfer(6,8191,~controller_rom[4095][15:8],1,0);intact();rejected++;
        no_power(7,1,1,1,1);
        for(integer b=1;b<25;b++) no_power(7,25'(1<<b),1,1,1);
        for(integer d=0;d<256;d++) if(d!=1) no_power(7,0,8'(d),1,1);
        no_power(7,0,1,0,1);no_power(7,0,1,1,0);no_power(8,0,1,1,1);
        // Negative witnesses use legal traffic, not forced DUT state.
        if($test$plusargs("NEGATIVE_VALID_WRITE")) begin
            transfer(6,0,~controller_rom[0][7:0],1,1);intact();
            $fatal(1,"valid write negative did not trip oracle");
        end
        if($test$plusargs("NEGATIVE_VALID_POWER")) no_power(7,0,1,1,1);
        transfer(7,0,1,1,1);
        assert(dut.subCPU.experimental_rtc.oscillator.phase==0)
            else $fatal(1,"valid storage-loss token not accepted");
        @(negedge clk);reset=0;
        repeat(32) tick();
        transfer(6,0,~controller_rom[0][7:0],1,1);intact();rejected++;
        transfer(6,8191,~controller_rom[4095][15:8],1,1);intact();rejected++;
        no_power(7,0,1,1,1);
        $display("PASS: RTC public transport %0d rejected transactions, full image intact, explicit power token and active rejection; no DMA/partial-image/native acceptance",rejected);
        $finish;
    end
endmodule
