// SPDX-License-Identifier: GPL-2.0-only
// Native IPL startup observer for the existing external-font shared profile.
// Public ioctl uploads only; hierarchy records completed bus observations.
// No disk transport, native boot acceptance or physical timing claim.
`timescale 1ps/1ps
module native_ipl_startup_tb;
    bit clk=0,vclk=0,video_run=1,ddr_run=1,reset=1,download=0,wr=0;
    always #15625 clk=~clk;
    always #11640 if(video_run) vclk=~vclk;
    logic [7:0] index=0,data=0;
    logic [24:0] address=0;
    wire upload_wait,ce_pix,hs,vs,hb,vb;
    wire [11:0] rgb;
    logic [7:0] font[0:262143],ipl[0:32767];
    logic [63:0] backing[0:32767];
    wire ddr_read,ddr_write;
    wire [7:0] ddr_burst,ddr_be;
    wire [28:0] ddr_address;
    wire [63:0] ddr_write_data;
    logic [63:0] ddr_data=0;
    logic ddr_ready=0;
    wire ddr_busy=!ddr_run || pending || cycles%13<3;
    bit pending=0;
    logic [14:0] pending_word=0;
    integer delay_left=0,cycles=0,ddr_reads=0,ddr_writes=0,commits=0,boots=0;
    integer frame_fd=0,frames=0,x=0,y=0,read_count=0,trace_fd=0,columns=80;
    integer frame_limit=1;
    bit old_hs=0,old_vs=0,capture=0,old_halt=1,read_seen=0,read_sampled=0;
    logic [7:0] read_value=0;
    logic [15:0] read_port=0;
    string font_path,ipl_path,output_path;
    sharpx1 #(.TURBO(1),.TURBO_VIDEO_MASTER(1),.TURBO_KANJI(1),
        .TURBO_KANJI_RENDER(1),.TURBO_Z_KANJI(1),.TURBO_Z_EXTERNAL_FONT(1)) dut (
        .clk_sys(clk),.clk_28636(vclk),.reset(reset),.pal(1'b0),.scandouble(1'b0),
        .ioctl_download(download),.ioctl_index(index),.ioctl_wr(wr),
        .ioctl_addr(address),.ioctl_dout(data),.ioctl_wait(upload_wait),
        .DDRAM_CLK(), .DDRAM_BUSY(ddr_busy), .DDRAM_BURSTCNT(ddr_burst),
        .DDRAM_ADDR(ddr_address), .DDRAM_DOUT(ddr_data), .DDRAM_DOUT_READY(ddr_ready),
        .DDRAM_RD(ddr_read), .DDRAM_DIN(ddr_write_data), .DDRAM_BE(ddr_be), .DDRAM_WE(ddr_write),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),.sio_rxd(2'b11),
        .sio_cts_n(2'b11),.sio_dcd_n(2'b11),.sio_txd(),.sio_rts_n(),.sio_dtr_n(),
        .tape_mount(1'b0),.tape_present(1'b0),.tape_empty(1'b0),
        .tape_sample_valid(1'b0),.tape_sample_level(1'b0),.tape_sample_last(1'b0),
        .tape_sample_ready(),.tape_underflow(),.tape_mode(),.tape_sensor(),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_drive(),.sd_lba(),.sd_rd(),.sd_wr(),.sd_ack(1'b0),
        .sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_din(),.sd_buff_wr(1'b0),
        .ce_pix(ce_pix),.HSync(hs),.VSync(vs),.HBlank(hb),.VBlank(vb),
        .video(),.rgb(),.rgb12(rgb),.audio(),.audio_left(),.audio_right(),.audio_mono(),.audio_sample());

    always @(posedge clk) begin
        cycles<=cycles+1;ddr_ready<=0;
        if(pending && ddr_run) begin
            if(delay_left==0) begin
                ddr_data<=backing[pending_word];
                ddr_ready<=1;pending<=0;
            end else delay_left<=delay_left-1;
        end
        if((ddr_read || ddr_write) && !ddr_busy) begin
            assert(ddr_read!=ddr_write && ddr_burst==1 &&
                ddr_address>=29'h06000000 && ddr_address<29'h06008000)
                else $fatal(1,"Z_EXTERNAL_DDR_COMMAND");
            if(ddr_write) begin
                assert($onehot(ddr_be)) else $fatal(1,"Z_EXTERNAL_BYTE_ENABLE");
                for(integer lane=0;lane<8;lane++)
                    if(ddr_be[lane]) backing[ddr_address[14:0]][lane*8+:8]<=ddr_write_data[lane*8+:8];
                ddr_writes<=ddr_writes+1;
            end else begin
                assert(ddr_be==8'hff) else $fatal(1,"Z_EXTERNAL_READ_ENABLE");
                pending<=1;pending_word<=ddr_address[14:0];delay_left<=cycles%7+2;ddr_reads<=ddr_reads+1;
            end
        end
    end

    integer obs_cycles=0,limit_cycles=6400000,fetches=0,writes=0,reads=0;
    integer history[0:65535];
    integer history_fd=0,summary_fd=0,journal_fd=0;
    integer packets_valid=0,packets_missing=0;
    bit started=0,old_write=0,fetch_seen=0,fetch_sampled=0,io_seen=0,io_sampled=0;
    logic [15:0] fetch_address=0,io_address=0,last_fetch=0;
    logic [7:0] fetch_data=0,io_data=0;
    always @(posedge clk) begin
        if(!dut.core_reset && started) begin
            obs_cycles<=obs_cycles+1;
            if(dut.io_write && !old_write) begin
                $fdisplay(trace_fd,"%0d,out,%04x,%02x,1",obs_cycles,dut.a,dut.data_out);
                writes<=writes+1;
            end
            old_write<=dut.io_write;
            if(dut.mem_read && !dut.m1) begin
                if(!fetch_seen) begin fetch_seen<=1;fetch_sampled<=0;fetch_address<=dut.a;end
                if(dut.cpu_ce && dut.machine_wait_n) begin fetch_sampled<=1;fetch_data<=dut.di;end
            end else if(fetch_seen) begin
                if(fetch_sampled) begin
                    history[fetch_address]=history[fetch_address]+1;
                    last_fetch<=fetch_address;
                    if(fetches<4096) $fdisplay(trace_fd,"%0d,m1,%04x,%02x,1",obs_cycles,fetch_address,fetch_data);
                    fetches<=fetches+1;
                end
                fetch_seen<=0;
            end
            if(dut.io_read) begin
                if(!io_seen) begin io_seen<=1;io_sampled<=0;io_address<=dut.a;end
                if(dut.cpu_ce && dut.machine_wait_n) begin io_sampled<=1;io_data<=dut.di;end
            end else if(io_seen) begin
                $fdisplay(trace_fd,"%0d,in,%04x,%02x,%0d",obs_cycles,io_address,io_data,io_sampled);
                reads<=reads+1;io_seen<=0;
            end
            if(|dut.font_ram_write) commits<=commits+1;
        end else begin old_write<=0;fetch_seen<=0;io_seen<=0;end
    end
    always @(posedge vclk) begin
        if(started && !dut.video_reset && dut.ce_pix && dut.video_phase==5'b01110) begin
            if(dut.z_kanji_display_valid) packets_valid<=packets_valid+1;
            else packets_missing<=packets_missing+1;
        end
    end
    task automatic tick;@(posedge clk);#3;endtask
    task automatic put_byte(input integer kind,input integer a,input [7:0] value);
        @(negedge clk);index=8'(kind);address=25'(a);data=value;wr=1;download=1;
        do begin @(posedge clk);end while(upload_wait);
        #3;@(negedge clk);wr=0;tick();
    endtask
    task automatic finish_upload;
        @(negedge clk);wr=0;download=0;repeat(16) tick();
    endtask
    initial begin #(64'd2000000000000);$fatal(1,"NATIVE_STARTUP_TIMEOUT");end
    initial begin
        assert($value$plusargs("FONT=%s",font_path) && $value$plusargs("IPL=%s",ipl_path) &&
            $value$plusargs("OUTPUT=%s",output_path)) else $fatal(1,"NATIVE_STARTUP_PATHS");
        if($value$plusargs("CYCLES=%d",limit_cycles)) begin end
        assert(limit_cycles>0 && limit_cycles<=32000000) else $fatal(1,"NATIVE_STARTUP_LIMIT");
        $readmemh(font_path,font);$readmemh(ipl_path,ipl);
        for(integer a=0;a<65536;a++) history[a]=0;
        trace_fd=$fopen({output_path,"/events.csv"},"w");
        assert(trace_fd!=0) else $fatal(1,"NATIVE_STARTUP_OPEN");
        $fdisplay(trace_fd,"cycle,event,address,data,sampled");
        repeat(32) tick();
        for(integer a=0;a<32768;a++) put_byte(0,a,ipl[a]);
        finish_upload();
        for(integer a=0;a<262144;a++) put_byte(5,a,font[a]);
        finish_upload();
        assert(dut.kanji_loaded && !dut.kanji_load_error && ddr_writes==262144)
            else $fatal(1,"NATIVE_STARTUP_FULL_FONT");
        for(integer a=0;a<262144;a++)
            assert(backing[a>>3][(a%8)*8+:8]==font[a]) else $fatal(1,"NATIVE_STARTUP_FONT_BYTES");
        @(negedge clk);started=1;reset=0;
        wait(obs_cycles>=limit_cycles);@(negedge clk);
        history_fd=$fopen({output_path,"/fetches.csv"},"w");
        $fdisplay(history_fd,"address,count");
        for(integer a=0;a<65536;a++) if(history[a]!=0) $fdisplay(history_fd,"%04x,%0d",a,history[a]);
        $fclose(history_fd);
        journal_fd=$fopen({output_path,"/journal.csv"},"w");
        $fdisplay(journal_fd,"cell,descriptor,cache_visible");
        for(integer a=0;a<2048;a++)
            $fdisplay(journal_fd,"%0d,%08x,%0d",a,dut.external_font.service.journal[a],dut.external_font.service.cache.visible[a]);
        $fclose(journal_fd);
        summary_fd=$fopen({output_path,"/summary.csv"},"w");
        $fdisplay(summary_fd,"cycles,fetches,writes,reads,commits,last_fetch,wait_n,address,core_reset,writer_state,packets_valid,packets_missing");
        $fdisplay(summary_fd,"%0d,%0d,%0d,%0d,%0d,%04x,%0d,%04x,%0d,%0d,%0d,%0d",obs_cycles,fetches,writes,reads,commits,last_fetch,dut.machine_wait_n,dut.a,dut.core_reset,dut.external_font.service.writer.state,packets_valid,packets_missing);
        $fclose(summary_fd);$fclose(trace_fd);
        $display("OBSERVED NATIVE_STARTUP cycles=%0d fetches=%0d last=%04x wait=%0d",obs_cycles,fetches,last_fetch,dut.machine_wait_n);
        $finish;
    end
endmodule
