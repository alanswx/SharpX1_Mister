// SPDX-License-Identifier: GPL-2.0-only
// Original real-CPU partial-ANK/reset/mode pixel gate. Public uploads only.
// Hierarchy is observation only; generated IPL and synthetic font.
`timescale 1ps/1ps
module z_partial_ank_machine_tb #(parameter integer KIND=0, COLUMNS=80, OMIT_RESET=0);
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
    integer frame_limit=2;
    logic [7:0] expected_ank[0:2047];
    string ank_path;
    integer fetch_boots=0,read_fd=0;
    bit boot_sampled=0;
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
        if(|dut.font_ram_write) commits<=commits+1;
        if(dut.core_reset) begin old_halt<=1;read_seen<=0;boot_sampled<=0;end
        else begin
            if(dut.mem_read && !dut.m1 && dut.a==0) begin
                if(dut.cpu_ce && dut.machine_wait_n) begin
                    assert(dut.di==8'hf3) else $fatal(1,"PARTIAL_MACHINE_IPL_OPCODE");
                    boot_sampled<=1;
                end
            end else if(boot_sampled) begin
                fetch_boots<=fetch_boots+1;boot_sampled<=0;
                $fdisplay(trace_fd,"%0d,boot,0,243",cycles);
            end
            if(dut.io_read && (dut.a[15:12]==4'h2 || dut.a[15:12]==4'h3)) begin
                if(!read_seen) begin read_seen<=1;read_sampled<=0;read_port<=dut.a;end
                if(dut.cpu_ce && dut.machine_wait_n) begin read_value<=dut.di;read_sampled<=1;end
            end else if(read_seen) begin
                assert(read_sampled) else $fatal(1,"PARTIAL_MACHINE_READ_READY");
                $fdisplay(read_fd,"%0d,%04x,%02x",cycles,read_port,read_value);
                read_count<=read_count+1;read_seen<=0;
            end
            if(old_halt && !dut.halt_n) begin
                assert(dut.RAM.mem[16'hf000]==8'h90 && dut.RAM.mem[16'hf041]==8'(boots+1))
                    else $fatal(1,"PARTIAL_MACHINE_CPU");
                boots<=boots+1;
                $fdisplay(trace_fd,"%0d,halt,0,%0d",cycles,boots+1);
            end
            old_halt<=dut.halt_n;
        end
    end
    always @(posedge vclk) begin
        bit pixel_edge;
        bit ink;
        logic [11:0] expected;
        pixel_edge=ce_pix;
        #2;
        if(dut.video_reset) begin
            assert(!capture) else $fatal(1,"PARTIAL_MACHINE_PARTIAL_RESET");
            old_hs=0;old_vs=0;x=0;y=0;
        end else if(pixel_edge) begin
            if(hs && !old_hs && x!=0) begin x=0;y++;end
            if(vs && !old_vs) begin
                if(capture) begin
                    $fclose(frame_fd);frame_fd=0;
                    assert(x==0 && y==200) else $fatal(1,"PARTIAL_MACHINE_GEOMETRY");
                    frames++;
                end
                capture=!dut.halt_n && boots==frames+1 && frames<2;
                x=0;y=0;
                if(capture) begin
                    frame_fd=$fopen($sformatf("%s/frame-%0d.csv",output_path,frames),"w");
                    assert(frame_fd!=0) else $fatal(1,"PARTIAL_MACHINE_FRAME_OPEN");
                    $fdisplay(frame_fd,"y,x,rgb12");
                end
            end
            if(capture && !hb && !vb) begin
                assert(x<COLUMNS*8 && y<200) else $fatal(1,"PARTIAL_MACHINE_PIXEL_COORD");
                ink=(expected_ank[65*8+y%8] & (8'h80>>(x%8)))!=0;
                expected=KIND==0 && !ink ? 12'hfff : 12'd0;
                assert(rgb==expected) else $fatal(1,"PARTIAL_MACHINE_PIXELS frame=%0d x=%0d y=%0d actual=%03x expected=%03x",frames,x,y,rgb,expected);
                $fdisplay(frame_fd,"%0d,%0d,%03x",y,x,rgb);x++;
            end
            old_hs=hs;old_vs=vs;
        end
    end
    task automatic tick;@(posedge clk);#3;endtask
    task automatic put_byte(input integer kind,input integer a,input [7:0] value);
        @(negedge clk);index=8'(kind);address=25'(a);data=value;wr=1;download=1;
        // Check WAIT at the admission edge, not after the accepted edge has
        // already changed the frontend state and raised backpressure.
        do begin @(posedge clk); end while(upload_wait);
        #3;@(negedge clk);wr=0;tick();
    endtask
    task automatic finish_upload;
        @(negedge clk);wr=0;download=0;repeat(16) tick();
    endtask
    initial begin #(64'd2000000000000);$fatal(1,"PARTIAL_MACHINE_TIMEOUT");end
    initial begin
        integer cold_commits;
        assert($value$plusargs("FONT=%s",font_path) && $value$plusargs("IPL=%s",ipl_path) &&
            $value$plusargs("ANK=%s",ank_path) && $value$plusargs("OUTPUT=%s",output_path))
            else $fatal(1,"PARTIAL_MACHINE_PATHS");
        assert((COLUMNS==40 || COLUMNS==80) && KIND>=0 && KIND<=4)
            else $fatal(1,"PARTIAL_MACHINE_PROFILE");
        $readmemh(font_path,font);$readmemh(ipl_path,ipl);$readmemh(ank_path,expected_ank);
        trace_fd=$fopen({output_path,"/events.csv"},"w");
        read_fd=$fopen({output_path,"/reads.csv"},"w");
        assert(trace_fd!=0 && read_fd!=0) else $fatal(1,"PARTIAL_MACHINE_TRACE_OPEN");
        $fdisplay(trace_fd,"cycle,event,address,data");$fdisplay(read_fd,"cycle,address,data");
        repeat(32) tick();
        // Public debug RAM upload establishes only the generated fixture's
        // cold marker; native/physical power-on contents are not inferred.
        put_byte(2,32'h0000f040,8'd0);finish_upload();
        for(integer a=0;a<32768;a++) put_byte(0,a,ipl[a]);finish_upload();
        for(integer a=0;a<262144;a++) put_byte(5,a,font[a]);finish_upload();
        assert(dut.kanji_loaded && !dut.kanji_load_error && ddr_writes==262144)
            else $fatal(1,"PARTIAL_MACHINE_FULL_FONT");
        for(integer a=0;a<262144;a++)
            assert(backing[a>>3][(a%8)*8+:8]==font[a]) else $fatal(1,"PARTIAL_MACHINE_FONT_BYTES");
        @(negedge clk);reset=0;
        wait(boots==1 && frames==1);@(negedge clk);cold_commits=commits;
        assert(cold_commits==(KIND==1 ? 2048 : 4096)) else $fatal(1,"PARTIAL_MACHINE_COMMITS");
        for(integer c=0;c<2048;c++)
            assert(dut.external_font.service.journal[c]==(KIND==1 ? 32'h02000f00 : 32'h03000f41))
                else $fatal(1,"PARTIAL_MACHINE_COLD_MASK");
        if(OMIT_RESET==0) begin
            reset=1;repeat(64) tick();@(negedge clk);reset=0;
        end
        repeat(8000000) tick();
        assert(boots==2 && fetch_boots==2 && dut.RAM.mem[16'hf041]==2)
            else $fatal(1,"PARTIAL_MACHINE_REBOOT");
        wait(frames==2);repeat(32) tick();
        assert(commits==cold_commits && !download) else $fatal(1,"PARTIAL_MACHINE_RETAINED_WRITES");
        for(integer c=0;c<2048;c++)
            assert(dut.external_font.service.journal[c]==(KIND==1 ? 32'h02000f00 : 32'h03000f41))
                else $fatal(1,"PARTIAL_MACHINE_WARM_MASK");
        $fclose(trace_fd);$fclose(read_fd);
        $display("PASS PARTIAL_MACHINE kind=%0d columns=%0d boots=%0d fetch_boots=%0d commits=%0d reads=%0d frames=%0d",KIND,COLUMNS,boots,fetch_boots,commits,read_count,frames);
        $finish;
    end
endmodule
