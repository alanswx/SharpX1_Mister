// SPDX-License-Identifier: GPL-2.0-only
// Original keyboard-selected cold/retained boot fixture. Real PS/2, Z80
// mailbox traffic, retained VRAM and DDR. No internal state is driven.
// Hierarchy is observation only. Generated assets, no native/private ROMs.
`timescale 1ps/1ps
module z_font_warm_reset_tb;
    bit ps2_clk=1,ps2_data=1,old_command=0;
    integer phase=0,key_f=0,key_r=0,upload_bytes=0;
    logic [15:0] last_key=0;
    bit expect_fail=0;
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
        .ps2_clk_in(ps2_clk),.ps2_data_in(ps2_data),.joya_n(8'hff),.joyb_n(8'hff),
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
        if(download && wr && !upload_wait) upload_bytes<=upload_bytes+1;
        if(phase!=0) assert(!download && !wr && upload_bytes==294912)
            else $fatal(1,"Z_WARM_ASSET_REUPLOAD");
        if(dut.subCPU.wram_cs && dut.subCPU.mem_we && dut.subCPU.sub_addr==16'h10b8 &&
           dut.subCPU.wdata!=last_key) begin
            last_key<=dut.subCPU.wdata;
            if((dut.subCPU.wdata[15:8]&8'hdf)==8'h46) key_f<=key_f+1;
            if((dut.subCPU.wdata[15:8]&8'hdf)==8'h52) key_r<=key_r+1;
        end
        if(dut.core_reset) begin old_command<=0;last_key<=0;end
        else begin
            old_command<=dut.io_write;
            if(!old_command && dut.io_write && dut.a[15:8]==8'h19)
                $fdisplay(trace_fd,"%0d,command,%0d,%0d,%0d",cycles,dut.a,boots,dut.data_out);
        end
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
        if(|dut.font_ram_write) begin
            commits<=commits+1;
            $fdisplay(trace_fd,"%0d,commit,%0d,%0d,%0d",cycles,dut.font_ram_address,dut.font_ram_write,dut.font_ram_data);
        end
        if(dut.core_reset) begin old_halt<=1;read_seen<=0;end
        else begin
            if(dut.io_read && (dut.a[15:8]==8'h14 || dut.a[15:8]==8'h15 || dut.a[15:12]==4'h2 || dut.a[15:12]==4'h3 || dut.a[15:8]==8'h19)) begin
                if(!read_seen) begin read_seen<=1;read_sampled<=0;read_port<=dut.a;end
                if(dut.cpu_ce && dut.machine_wait_n) begin read_value<=dut.di;read_sampled<=1;end
            end else if(read_seen) begin
                assert(read_sampled) else $fatal(1,"Z_EXTERNAL_CPU_UNREADY");
                if(read_port[15:8]==8'h19)
                    $fdisplay(trace_fd,"%0d,key,%0d,%0d,%0d",cycles,read_port,boots,read_value);
                else begin
                    $fdisplay(trace_fd,"%0d,read,%0d,%0d,%0d",cycles,read_port,boots,read_value);
                    read_count<=read_count+1;
                end
                read_seen<=0;
            end
            if(old_halt && !dut.halt_n) begin
                assert(boots<2) else $fatal(1,"Z_WARM_EXTRA_BOOT");
                assert(dut.RAM.mem[16'hf000]==(boots==0 ? 8'h5a : (expect_fail ? 8'hee : 8'h57)) &&
                    dut.attr_ram.mem[0]==(boots==0 || expect_fail ? 8'h07 : 8'h03))
                    else $fatal(1,"Z_WARM_CPU_ORACLE boots=%0d status=%0h",boots,dut.RAM.mem[16'hf000]);
                boots<=boots+1;
            end
            old_halt<=dut.halt_n;
        end
    end
    always @(posedge vclk) begin
        bit pixel_edge;
        pixel_edge=ce_pix;
        #2;
        if(dut.video_reset) begin
            assert(!capture) else $fatal(1,"Z_EXTERNAL_PARTIAL_FRAME_RESET");
            old_hs=0;old_vs=0;x=0;y=0;
        end else if(pixel_edge) begin
            if(hs && !old_hs && x!=0) begin x=0;y++;end
            if(vs && !old_vs) begin
                if(capture) begin $fclose(frame_fd);frame_fd=0;frames++;end
                capture=!dut.halt_n && frames<frame_limit;
                x=0;y=0;
                if(capture) begin
                    frame_fd=$fopen($sformatf("%s/frame-%0d.csv",output_path,frames),"w");
                    assert(frame_fd!=0) else $fatal(1,"Z_EXTERNAL_FRAME_OPEN");
                    $fdisplay(frame_fd,"y,x,rgb12");
                end
            end
            if(capture && !hb && !vb) begin
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
    task automatic ps2_byte(input [7:0] value);
        reg [10:0] packet;
        packet={1'b1,~^value,value,1'b0};
        $fdisplay(trace_fd,"%0d,ps2,%0d,%0d,0",cycles,value,boots);
        for(integer i=0;i<11;i++) begin
            ps2_data=packet[i];#50000000;ps2_clk=0;#50000000;ps2_clk=1;
        end
        ps2_data=1;
    endtask
    task automatic retained_cache;
        assert(dut.kanji_loaded && !dut.kanji_load_error &&
            dut.external_font.service.cache.visible=='1)
            else $fatal(1,"Z_WARM_CACHE_REBUILD");
        for(integer c=0;c<2048;c++)
            assert(dut.external_font.service.journal[c][23:0]==
                {dut.kan_ram.mem[c],dut.attr_ram.mem[c],dut.text_ram.mem[c]})
                else $fatal(1,"Z_WARM_JOURNAL");
    endtask
    initial begin #(64'd1500000000000);$fatal(1,"Z_WARM_TIMEOUT");end
    initial begin
        integer bad,r_before;
        assert($value$plusargs("FONT=%s",font_path) && $value$plusargs("IPL=%s",ipl_path) &&
            $value$plusargs("OUTPUT=%s",output_path) && $value$plusargs("BAD=%d",bad))
            else $fatal(1,"Z_WARM_PATHS");
        expect_fail=bad!=0;
        if($value$plusargs("COLUMNS=%d",columns)) begin end
        assert(columns==40 || columns==80) else $fatal(1,"Z_WARM_COLUMNS");
        $readmemh(font_path,font);$readmemh(ipl_path,ipl);
        trace_fd=$fopen({output_path,"/events.csv"},"w");
        assert(trace_fd!=0) else $fatal(1,"Z_WARM_TRACE_OPEN");
        $fdisplay(trace_fd,"cycle,event,address,select,data");
        repeat(32) tick();
        for(integer a=0;a<32768;a++) put_byte(0,a,ipl[a]);
        finish_upload();
        for(integer a=0;a<262144;a++) put_byte(5,a,font[a]);
        finish_upload();
        assert(upload_bytes==294912 && ddr_writes==262144 && dut.kanji_loaded)
            else $fatal(1,"Z_WARM_INITIAL_UPLOAD");
        @(negedge clk);reset=0;
        wait(dut.cpu_ce);repeat(800000) tick();ps2_byte(8'h2b); // F; C belongs to inherited joystick emulation.
        repeat(320000) tick();
        assert(key_f>0) else $fatal(1,"Z_WARM_INITIAL_F_NOT_DECODED");
        wait(boots==1);wait(frames==1 && !capture);
        assert(key_f>0 && read_count==46 && commits==6154)
            else $fatal(1,"Z_WARM_COLD_COUNTS");
        // Counterfactual first: real R reaches MR16, but DI/HALT cannot reboot.
        phase=1;ps2_byte(8'hf0);ps2_byte(8'h2b);
        repeat(800000) tick();r_before=key_r;ps2_byte(8'h2d);
        repeat(800000) tick();ps2_byte(8'hf0);ps2_byte(8'h2d);repeat(320000) tick();
        assert(key_r>r_before && boots==1 && !dut.halt_n && commits==6154 && read_count==46)
            else $fatal(1,"Z_WARM_NO_RESET_CONTROL");
        frame_limit=2;wait(frames==2 && !capture);
        // Actual warm reset; no IPL/font/media upload or VRAM host write.
        phase=2;@(negedge clk);reset=1;
        $fdisplay(trace_fd,"%0d,reset,0,0,0",cycles);
        wait(dut.core_reset);repeat(64) tick();
        @(negedge clk);reset=0;
        $fdisplay(trace_fd,"%0d,release,0,0,0",cycles);
        wait(dut.external_font.service.state==0);#3;retained_cache();
        assert(commits==6154 && read_count==46) else $fatal(1,"Z_WARM_REBUILD_CPU_WRITE");
        repeat(800000) tick();r_before=key_r;ps2_byte(8'h2d);
        wait(boots==2);repeat(16) tick();
        assert(key_r>r_before) else $fatal(1,"Z_WARM_NEW_KEY_MISSING");
        frame_limit=3;wait(frames==3 && !capture);
        assert(read_count==6190 && commits==(expect_fail ? 6154 : 6155) &&
            ddr_writes==262144 && upload_bytes==294912)
            else $fatal(1,"Z_WARM_COUNTS reads=%0d commits=%0d uploads=%0d",read_count,commits,upload_bytes);
        for(integer a=0;a<262144;a++)
            assert(backing[a>>3][(a%8)*8+:8]==font[a]) else $fatal(1,"Z_WARM_BACKING_CHANGED");
        $fclose(trace_fd);
        $display("PASS Z_WARM_RESET columns=%0d bad=%0d boots=%0d reads=%0d commits=%0d frames=%0d uploads=%0d cycles=%0d",
            columns,expect_fail,boots,read_count,commits,frames,upload_bytes,cycles);
        $finish;
    end
endmodule
