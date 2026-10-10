// SPDX-License-Identifier: GPL-2.0-only
// Original connected Z CPU/RGB diagnostic. Public upload/reset only;
// hierarchy is observation, never force/write. No native font/software assets.
`timescale 1ps/1ps
module z_kanji_machine_tb #(parameter bit ENABLED=1);
    bit clk=0,vclk=0,video_run=1,reset=1,download=0,wr=0;
    always #15625 clk=~clk;
    initial begin : video_clock
        longint unsigned remainder_ps=0,delay_ps;
        forever begin
            remainder_ps+=64'd1000000000000;
            delay_ps=remainder_ps/64'd85909080;
            remainder_ps=remainder_ps%64'd85909080;
            #(delay_ps);
            if(video_run) vclk=~vclk;
        end
    end
    logic [7:0] index=0,data=0;
    logic [24:0] address=0;
    wire upload_wait,ce_pix,hs,vs,hb,vb;
    wire [11:0] rgb;
    logic [7:0] font[0:262143],ipl[0:32767],absent_ipl[0:32767];
    integer scenario=0,columns=80,load_kind=0,delay_kind=0;
    integer trace_fd,frame_fd=0,frames=0,x=0,y=0,reads=0,halts=0,unsupported_edges=0;
    string font_path,ipl_path,absent_path,output_path,frame_path;
    bit old_hs=0,old_vs=0,read_seen=0,write_seen=0,old_halt=1;
    bit capture=0,read_sampled=0;
    logic [7:0] selector_text=0,selector_kan=0,read_value=0;
    logic [17:0] read_address=0;
    sharpx1 #(.TURBO(1),.TURBO_VIDEO_MASTER(1),.TURBO_KANJI(ENABLED),
        .TURBO_KANJI_RENDER(ENABLED),.TURBO_Z_KANJI(ENABLED)) dut (
        .clk_sys(clk),.clk_28636(vclk),.reset(reset),.pal(1'b0),.scandouble(1'b0),
        .ioctl_download(download),.ioctl_index(index),.ioctl_wr(wr),
        .ioctl_addr(address),.ioctl_dout(data),.ioctl_wait(upload_wait),
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
    function automatic [7:0] expected(input integer a);
        return 8'((a>>17)*167+((a>>13)&15)*13+((a>>5)&255)*37+((a>>1)&15)*29+(a&1)*83);
    endfunction
    always @(posedge clk) begin : bus_observation
        if(reset) begin read_seen=0;write_seen=0;old_halt=1;end
        else begin
            if(!dut.io_write) write_seen=0;
            if(dut.io_write && !write_seen) begin
                write_seen=1;
                if(dut.a==16'h37ff) selector_text=dut.data_out;
                if(dut.a==16'h3fff) selector_kan=dut.data_out;
            end
            if(dut.io_read && dut.a[15:4]==12'h140) begin
                if(!read_seen) begin
                    read_seen=1;read_sampled=0;
                    read_address={selector_kan[4],selector_kan[3:0],selector_text,dut.a[3:0],selector_kan[6]};
                end
                // Actual CPU consuming CE, not an unready first raw bus sample.
                if(dut.cpu_ce && dut.machine_wait_n) begin read_value=dut.di;read_sampled=1;end
            end else if(read_seen) begin
                assert(read_sampled) else $fatal(1,"Z_CPU_READ_WITHOUT_RESPONSE");
                $fdisplay(trace_fd,"%0t,read,%0d,%0d",$time,read_address,read_value);
                reads++;read_seen=0;
            end
            if(old_halt && !dut.halt_n) begin
                halts++;
                assert(dut.RAM.mem[16'hf000]!=8'hee) else $fatal(1,"Z_CPU_EXECUTED_DATA_ORACLE");
                $fdisplay(trace_fd,"%0t,halt,%0d,%0d",$time,halts,reads);
            end
            old_halt=dut.halt_n;
        end
    end
    // Actual output pixels; no request-address-derived image. Capture complete
    // frames only after the CPU has published its initialized-raster marker.
    always @(posedge vclk) begin
        bit pixel_edge;
        pixel_edge=ce_pix; // pre-edge enable drives the actual shifter step
        #2;
        if(dut.video_reset) begin
            if(frame_fd!=0) $fclose(frame_fd);
            frame_fd=0;capture=0;old_hs=0;old_vs=0;x=0;y=0;frames=0;
        end else if(scenario==1 || scenario==2 || scenario>=6) begin
            if(dut.RAM.mem[16'hf010]==8'h90 && !dut.halt_n) begin
                assert(!dut.z_kanji_display_miss) else $fatal(1,"Z_SUPPORTED_DISPLAY_MISS");
                if(scenario<6) assert(!dut.z_kanji_display_unsupported) else $fatal(1,"Z_SUPPORTED_DISPLAY_UNSUPPORTED");
                if(dut.z_kanji_display_unsupported) unsupported_edges++;
            end
            if(pixel_edge) begin
                if(hs && !old_hs && x!=0) begin x=0;y++;end
                if(vs && !old_vs) begin
                    if(capture) begin
                        $fclose(frame_fd);frame_fd=0;frames++;
                        $fdisplay(trace_fd,"%0t,frame,%0d,%0d",$time,frames,y);
                    end
                    capture=dut.RAM.mem[16'hf010]==8'h90 && !dut.halt_n;
                    x=0;y=0;
                    if(capture) begin
                        frame_path=$sformatf("%s/frame-%0d.csv",output_path,frames);
                        frame_fd=$fopen(frame_path,"w");
                        assert(frame_fd!=0) else $fatal(1,"frame open");
                        $fdisplay(frame_fd,"y,x,rgb12");
                    end
                end
                if(capture && !hb && !vb) begin
                    $fdisplay(frame_fd,"%0d,%0d,%03x",y,x,rgb);x++;
                end
                old_hs=hs;old_vs=vs;
            end
        end
    end
    task automatic tick;@(posedge clk);#3;endtask
    task automatic byte_upload(input integer kind,input integer a,input [7:0] value);
        @(negedge clk);index=8'(kind);address=25'(a);data=value;wr=1;download=1;
        while(upload_wait) tick();
        tick();@(negedge clk);wr=0;
        if(delay_kind!=0 && (a%17)==0) repeat((a%5)+1) tick();
    endtask
    task automatic commit_upload;
        @(negedge clk);wr=0;download=0;repeat(8) tick();
    endtask
    task automatic valid_font;
        for(integer a=0;a<262144;a++) byte_upload(5,a,font[a]);
        commit_upload();
        assert(dut.kanji_loaded && !dut.kanji_load_error)
            else $fatal(1,"Z_ORDERED_UPLOAD_ADMISSION");
    endtask
    task automatic upload_program(input bit absent);
        for(integer a=0;a<32768;a++) byte_upload(0,a,absent ? absent_ipl[a] : ipl[a]);
        commit_upload();
    endtask
    task automatic bad_font;
        @(negedge clk);index=5;download=1;wr=0;tick();
        case(load_kind)
            0:begin end
            1:for(integer a=0;a<16;a++) byte_upload(5,a,font[a]);
            2:byte_upload(5,1,font[1]);
            3:begin byte_upload(5,0,font[0]);byte_upload(5,0,font[0]);end
            4:begin byte_upload(5,0,font[0]);byte_upload(5,2,font[2]);end
            5:begin byte_upload(5,0,font[0]);byte_upload(5,262144,0);end
            6:begin
                @(negedge clk);download=0;wr=1;address=0;tick();
            end
            7:begin @(negedge clk);reset=0;byte_upload(5,0,font[0]);@(negedge clk);reset=1;end
            default:$fatal(1,"invalid loader case");
        endcase
        commit_upload();
        assert(!dut.kanji_loaded && dut.kanji_load_error) else $fatal(1,"Z_MALFORMED_UPLOAD_ACCEPTED");
    endtask
    task automatic completed_cpu;
        wait(!dut.halt_n);repeat(8) tick();
        assert({dut.RAM.mem[16'hf000],dut.RAM.mem[16'hf001],dut.RAM.mem[16'hf002],dut.RAM.mem[16'hf003]}==32'h5a435055)
            else $fatal(1,"Z_CPU_EXECUTED_DATA_ORACLE");
    endtask
    initial begin #(64'd30000000000000);$fatal(1,"Z_MACHINE_TIMEOUT");end
    initial begin
        assert($value$plusargs("FONT=%s",font_path) && $value$plusargs("IPL=%s",ipl_path) &&
               $value$plusargs("ABSENT_IPL=%s",absent_path) && $value$plusargs("OUTPUT=%s",output_path))
            else $fatal(1,"required fixture paths");
        if($value$plusargs("SCENARIO=%d",scenario)) begin end
        if($value$plusargs("COLUMNS=%d",columns)) begin end
        if($value$plusargs("LOAD_KIND=%d",load_kind)) begin end
        if($value$plusargs("DELAY=%d",delay_kind)) begin end
        assert(scenario>=0 && scenario<=8 && (columns==40 || columns==80)) else $fatal(1,"fixture configuration");
        $readmemh(font_path,font);$readmemh(ipl_path,ipl);$readmemh(absent_path,absent_ipl);
        trace_fd=$fopen({output_path,"/events.csv"},"w");
        assert(trace_fd!=0) else $fatal(1,"trace open");$fdisplay(trace_fd,"time_ps,event,address,value");
        repeat(16) tick();
        valid_font();
        if(scenario==4) begin
            bad_font();upload_program(1);@(negedge clk);reset=0;completed_cpu();
            @(negedge clk);reset=1;repeat(16) tick();valid_font();
        end
        upload_program(0);@(negedge clk);reset=0;
        if(scenario==3) begin
            wait(dut.cg_bus.busy && dut.kanji_cpu_read && !dut.cg_wait_n);
            @(negedge clk);video_run=0;reset=1;#10;
            assert(!dut.cg_bus.busy && !dut.kanji_cpu_valid && dut.cg_wait_n)
                else $fatal(1,"Z_PENDING_RESET_CANCELLATION");
            repeat(32) tick();@(negedge clk);reset=0;repeat(32) tick();
            assert(dut.video_reset) else $fatal(1,"Z_STOPPED_VIDEO_RESET_RELEASE");
            video_run=1;
        end
        if(scenario==1 || scenario==2 || scenario>=6) begin
            wait(!dut.halt_n);repeat(8) tick();
            if(scenario==2) begin
                @(negedge clk);reset=1;repeat(32) tick();@(negedge clk);reset=0;
                wait(dut.halt_n);wait(!dut.halt_n);
            end
            wait(frames>=3);
            if(scenario>=6) assert(unsupported_edges>0) else $fatal(1,"Z_UNSUPPORTED_WITNESS_MISSING");
        end else completed_cpu();
        if(scenario==0) assert(reads==262144) else $fatal(1,"Z_EXHAUSTIVE_READ_COUNT actual=%0d",reads);
        assert(dut.kanji_loaded && !dut.kanji_load_error) else $fatal(1,"Z_RETAINED_UPLOAD");
        $fdisplay(trace_fd,"%0t,complete,%0d,%0d",$time,reads,frames);$fclose(trace_fd);
        $display("PASS Z_MACHINE scenario=%0d reads=%0d frames=%0d halts=%0d",scenario,reads,frames,halts);
        $finish;
    end
endmodule
