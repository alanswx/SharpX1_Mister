// SPDX-License-Identifier: GPL-2.0-only
// Original complete-machine public-upload/DDR/reset/CPU/pixel diagnostic.
// Hierarchy is observation only. Generated assets, no native/private ROMs.
`timescale 1ps/1ps
// SINGLE_X3 drives both machine clocks from one free-running X3 master;
// its video-stop phases therefore leave the clock running.
module z_external_font_machine_tb #(parameter bit CORRUPT_READ=0, parameter bit SINGLE_X3=0);
    bit sclk=0,vclk=0,video_run=1,ddr_run=1,reset=1,download=0,wr=0;
    always #15625 sclk=~sclk;
    always #11640 if(video_run || SINGLE_X3) vclk=~vclk;
    wire clk=SINGLE_X3 ? vclk : sclk;
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
    sharpx1 #(.SINGLE_CLOCK(SINGLE_X3),.MASTER_HZ(SINGLE_X3 ? 42954540 : 28636364),
        .TURBO(1),.TURBO_VIDEO_MASTER(1),.TURBO_KANJI(1),
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
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),.disk_raw(1'b0),.disk_raw_b(1'b0),
        .sd_drive(),.sd_lba(),.sd_rd(),.sd_wr(),.sd_ack(1'b0),
        .sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_din(),.sd_buff_wr(1'b0),
        .ce_pix(ce_pix),.HSync(hs),.VSync(vs),.HBlank(hb),.VBlank(vb),
        .video(),.rgb(),.rgb12(rgb),.audio(),.audio_left(),.audio_right(),.audio_mono(),.audio_sample());

    always @(posedge clk) begin
        cycles<=cycles+1;ddr_ready<=0;
        if(pending && ddr_run) begin
            if(delay_left==0) begin
                ddr_data<=backing[pending_word] ^ (CORRUPT_READ ? 64'h0101010101010101 : 64'd0);
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
            if(dut.io_read && (dut.a[15:8]==8'h14 || dut.a[15:8]==8'h15 || dut.a[15:12]==4'h2 || dut.a[15:12]==4'h3)) begin
                if(!read_seen) begin read_seen<=1;read_sampled<=0;read_port<=dut.a;end
                if(dut.cpu_ce && dut.machine_wait_n) begin read_value<=dut.di;read_sampled<=1;end
            end else if(read_seen) begin
                assert(read_sampled) else $fatal(1,"Z_EXTERNAL_CPU_UNREADY");
                $fdisplay(trace_fd,"%0d,read,%0d,0,%0d",cycles,read_port,read_value);
                read_count<=read_count+1;read_seen<=0;
            end
            if(old_halt && !dut.halt_n) begin
                assert(dut.RAM.mem[16'hf000]!=8'hee) else $fatal(1,"Z_EXTERNAL_CPU_ORACLE");
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
                capture=dut.RAM.mem[16'hf010]==8'h90 && !dut.halt_n && frames<frame_limit;
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
    function automatic [7:0] replacement_byte(input integer a);
        // Keep the CPU's two font-test glyphs fixed; change every other glyph
        // so a retained stale cache cannot pass the third frame's RGB oracle.
        return font[a] ^ ((a>=8160 && a<8192) || a>=262112 ? 8'd0 : 8'h5a);
    endfunction
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
    task automatic check_retained;
        wait(dut.external_font.service.state==0);#3;
        assert(dut.external_font.service.cache.visible=='1)
            else $fatal(1,"Z_EXTERNAL_REBUILD_VALIDITY");
        for(integer c=0;c<2048;c++) begin
            assert(dut.external_font.service.journal[c][23:0]==
                {dut.kan_ram.mem[c],dut.attr_ram.mem[c],dut.text_ram.mem[c]})
                else $fatal(1,"Z_EXTERNAL_JOURNAL_RETENTION");
        end
    endtask
    initial begin #(64'd2000000000000);$fatal(1,"Z_EXTERNAL_TIMEOUT");end
    initial begin
        integer before_commits;
        assert($value$plusargs("FONT=%s",font_path) && $value$plusargs("IPL=%s",ipl_path) &&
            $value$plusargs("OUTPUT=%s",output_path)) else $fatal(1,"Z_EXTERNAL_PATHS");
        if($value$plusargs("COLUMNS=%d",columns)) begin end
        assert(columns==40 || columns==80) else $fatal(1,"Z_EXTERNAL_COLUMNS");
        $readmemh(font_path,font);$readmemh(ipl_path,ipl);
        trace_fd=$fopen({output_path,"/events.csv"},"w");
        assert(trace_fd!=0) else $fatal(1,"Z_EXTERNAL_TRACE_OPEN");
        $fdisplay(trace_fd,"cycle,event,address,select,data");
        repeat(32) tick();
        // Missing font is a deliberate held-reset boot policy, not random DDR.
        @(negedge clk);reset=0;repeat(256) tick();
        assert(dut.core_reset && !dut.cpu_ce && ddr_reads==0 && ddr_writes==0)
            else $fatal(1,"Z_EXTERNAL_MISSING_FONT");
        @(negedge clk);reset=1;
        for(integer a=0;a<32768;a++) put_byte(0,a,ipl[a]);
        finish_upload();
        for(integer a=0;a<262144;a++) put_byte(5,a,font[a]);
        finish_upload();
        assert(dut.kanji_loaded && !dut.kanji_load_error && ddr_writes==262144)
            else $fatal(1,"Z_EXTERNAL_FULL_UPLOAD");
        for(integer a=0;a<262144;a++)
            assert(backing[a>>3][(a%8)*8+:8]==font[a]) else $fatal(1,"Z_EXTERNAL_BACKING_BYTES");
        @(negedge clk);reset=0;
        // Interrupt the first truly owned write while both service domains
        // are stopped. Neither CPU reset nor upload may bypass that ownership.
        wait(dut.external_font.service.writer.state==3 && pending);
        @(negedge clk);video_run=0;ddr_run=0;reset=1;download=1;index=0;wr=0;
        before_commits=commits;
        repeat(64) tick();
        assert(!dut.core_reset && !dut.cpu_ce && upload_wait && commits==before_commits)
            else $fatal(1,"Z_EXTERNAL_EARLY_RESET_UPLOAD");
        @(negedge clk);ddr_run=1;repeat(64) tick();
        // Stopped-VID-only terms: one X3 clock cannot stop video alone.
        assert(!dut.core_reset && (SINGLE_X3 || upload_wait) && commits==before_commits)
            else $fatal(1,"Z_EXTERNAL_STOPPED_VIDEO_DRAIN");
        @(negedge clk);video_run=1;
        wait(dut.core_reset && !upload_wait);repeat(8) tick();
        assert(commits==before_commits+1) else $fatal(1,"Z_EXTERNAL_OWNED_COMMIT_ONCE");
        @(negedge clk);download=0;reset=0;
        // Separately cancel an actually owned CPU font read. The backend must
        // consume its delayed response while consumer reset remains asserted.
        wait(dut.kanji_cpu_read && !dut.external_font.service.arbiter.owner_cache &&
            dut.external_font.service.arbiter.state==1 && pending);
        // One X3 clock acknowledges a font START at once, so an empty font
        // upload would really begin; single mode cancels under an IPL START.
        @(negedge clk);reset=1;ddr_run=0;video_run=0;download=1;index=SINGLE_X3 ? 8'd0 : 8'd5;wr=0;
        repeat(64) tick();
        assert(dut.core_reset && !dut.cpu_ce && !dut.kanji_cpu_valid && upload_wait && pending)
            else $fatal(1,"Z_EXTERNAL_CPU_CANCEL_OWNER");
        @(negedge clk);ddr_run=1;repeat(64) tick();
        assert(!pending && !dut.kanji_cpu_valid && (SINGLE_X3 || upload_wait) && ddr_writes==262144)
            else $fatal(1,"Z_EXTERNAL_CPU_CANCEL_DRAIN");
        // Withdraw the blocked font START before VID can acknowledge drain.
        @(negedge clk);download=0;reset=0;video_run=1;
        wait(!dut.halt_n);repeat(16) tick();
        assert({dut.RAM.mem[16'hf000],dut.RAM.mem[16'hf001],dut.RAM.mem[16'hf002],dut.RAM.mem[16'hf003]}==32'h5a504958)
            else $fatal(1,"Z_EXTERNAL_BOOT_MARKER");
        wait(frames==1 && !capture);
        // No asset reupload: rebuild all retained cells before the second boot.
        @(negedge clk);reset=1;video_run=0;
        repeat(64) tick();assert(dut.core_reset) else $fatal(1,"Z_EXTERNAL_WARM_HOLD");
        @(negedge clk);reset=0;repeat(64) tick();
        assert(SINGLE_X3 || !dut.cpu_ce) else $fatal(1,"Z_EXTERNAL_STOPPED_VIDEO_RELEASE");
        @(negedge clk);video_run=1;
        check_retained();frame_limit=2;wait(!dut.halt_n);repeat(16) tick();
        wait(frames==2 && !capture);
        // A short replacement revokes readiness and must hold the consumers.
        // Retrying the complete font rebuilds retained cells without IPL/VRAM upload.
        for(integer a=0;a<16;a++) put_byte(5,a,font[a]);
        finish_upload();repeat(128) tick();
        assert(!dut.kanji_loaded && dut.kanji_load_error && dut.core_reset && !dut.cpu_ce)
            else $fatal(1,"Z_EXTERNAL_SHORT_REPLACEMENT");
        for(integer a=0;a<262144;a++) put_byte(5,a,replacement_byte(a));
        finish_upload();
        for(integer a=0;a<262144;a++)
            assert(backing[a>>3][(a%8)*8+:8]==replacement_byte(a))
                else $fatal(1,"Z_EXTERNAL_REPLACEMENT_BYTES");
        check_retained();frame_limit=3;
        wait(!dut.halt_n);repeat(16) tick();wait(frames==3 && !capture);
        assert(boots==3 && read_count==140 && ddr_writes==524304 && !dut.kanji_load_error)
            else $fatal(1,"Z_EXTERNAL_FINAL_COUNTS boots=%0d reads=%0d writes=%0d",boots,read_count,ddr_writes);
        $fclose(trace_fd);
        $display("PASS Z_EXTERNAL_MACHINE boots=%0d cpu_reads=%0d commits=%0d ddr_reads=%0d ddr_writes=%0d frames=%0d cycles=%0d",boots,read_count,commits,ddr_reads,ddr_writes,frames,cycles);
        $finish;
    end
endmodule
