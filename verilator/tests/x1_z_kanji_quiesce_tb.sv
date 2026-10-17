// SPDX-License-Identifier: GPL-2.0-only
// Original connected component fixture; synthetic host/consumer hold and DDR.
`timescale 1ns/1ps
module x1_z_kanji_quiesce_tb #(parameter integer SYS_HALF_PS=15625);
    bit clk=0,clk_vid=0,run_vid=1;
    initial forever begin #(SYS_HALF_PS*1ps);clk=~clk;end
    initial forever begin #11640ps;if(run_vid) clk_vid=~clk_vid;end
    localparam logic [28:0] BASE=29'h06123400;
    logic pause_request=0,cold_reset_request=0,release_pause=0,consumers_quiescent=0;
    logic host_download=0,ioctl_wr=0;
    logic [24:0] ioctl_address=0;
    logic [7:0] ioctl_data=0;
    wire loaded,upload_active,upload_error,frontend_wait,frontend_cpu_wait;
    wire hold_consumers,cpu_enabled,cache_enabled,updates_enabled,cpu_cancel;
    wire cache_invalidate,cache_invalidate_done,arbiter_idle;
    wire frontend_cancel,frontend_cold_reset,pause_done,upload_permitted,release_ready;
    x1_z_kanji_quiesce control(.*);
    wire ioctl_wait=host_download && (!upload_permitted || frontend_wait);
    wire frontend_download=host_download && upload_permitted;
    logic cpu_read=0,cpu_response_ack=0;
    logic [17:0] cpu_address=18'h3fff7;
    wire cpu_wait,cpu_valid;
    wire [7:0] cpu_data;
    wire cache_read,cache_valid,cache_response_ack;
    wire [17:0] cache_address,font_address;
    wire [7:0] cache_data,font_data;
    wire font_read,font_valid,font_response_ack;
    x1_z_kanji_arbiter arbiter(.idle(arbiter_idle),.*);
    logic raw_update_valid=0,update_done_ready=0;
    wire update_valid=raw_update_valid && updates_enabled;
    wire update_ready,update_done;
    logic [2:0] update_cell=7;
    logic [12:0] update_glyph=0;
    logic [31:0] update_descriptor=0;
    wire [2:0] update_done_cell;
    wire [12:0] update_done_glyph;
    wire [31:0] update_done_descriptor;
    logic vid_request=0;
    logic [2:0] vid_cell=7;
    logic [4:0] vid_offset=0;
    wire vid_response_valid,vid_response_hit;
    wire [2:0] vid_response_cell;
    wire [4:0] vid_response_offset;
    wire [12:0] vid_response_glyph;
    wire [31:0] vid_response_descriptor;
    wire [7:0] vid_response_data;
    x1_z_kanji_cache #(.CELL_BITS(3)) cache(
        .clk_sys(clk),.clk_vid(clk_vid),.invalidate(cache_invalidate),.invalidate_done(cache_invalidate_done),
        .font_read(cache_read),.font_address(cache_address),.font_valid(cache_valid),
        .font_data(cache_data),.font_response_ack(cache_response_ack),.*);
    wire DDRAM_CLK,DDRAM_RD,DDRAM_WE;
    wire [7:0] DDRAM_BURSTCNT,DDRAM_BE;
    wire [28:0] DDRAM_ADDR;
    wire [63:0] DDRAM_DIN;
    logic DDRAM_BUSY=0,DDRAM_DOUT_READY=0;
    logic [63:0] DDRAM_DOUT=0;
    x1_z_kanji_frontend #(.BASE_WORD_ADDRESS(BASE)) frontend(
        .clk(clk),.cold_reset(frontend_cold_reset),.consumer_cancel(frontend_cancel),
        .cpu_read(font_read),.cpu_address(font_address),.cpu_wait(frontend_cpu_wait),
        .cpu_valid(font_valid),.cpu_data(font_data),.cpu_response_ack(font_response_ack),
        .ioctl_download(frontend_download),.ioctl_index(8'd5),.ioctl_address(ioctl_address),
        .ioctl_wr(ioctl_wr && upload_permitted),.ioctl_data(ioctl_data),.ioctl_wait(frontend_wait),
        .upload_permitted(upload_permitted),.loaded(loaded),.upload_error(upload_error),.upload_active(upload_active),
        .DDRAM_CLK(DDRAM_CLK),.DDRAM_BUSY(DDRAM_BUSY),.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
        .DDRAM_ADDR(DDRAM_ADDR),.DDRAM_DOUT(DDRAM_DOUT),.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
        .DDRAM_RD(DDRAM_RD),.DDRAM_DIN(DDRAM_DIN),.DDRAM_BE(DDRAM_BE),.DDRAM_WE(DDRAM_WE)
    );
    byte unsigned memory_image[0:262143];
    bit force_busy=0,hold_response=0,pending=0,previous_cache_read=0,previous_font_read=0;
    bit previous_cpu_read=0,cpu_pending=0,cache_pending=0,prefer_cache=0;
    integer expected_cache=0,expected_cpu=0,expected_font=0;
    integer active_glyph=0,cache_offset=0,font_epoch=0,write_offset=0,delay_left=0;
    logic [28:0] pending_word=BASE;
    integer reads=0,writes=0,requests=0,acks=0,updates=0,cancels=0,cold_cancels=0,cases=0;
    longint unsigned edges=0;
    function automatic [7:0] pattern(input integer a);
        return 8'((a*43)^(a>>7)^(a>>14)^8'ha7)^8'(font_epoch*8'hff);
    endfunction
    function automatic [63:0] word_at(input logic [28:0] a);
        integer first;
        first=(int'(a)-int'(BASE))*8;
        for(integer b=0;b<8;b++) word_at[b*8+:8]=memory_image[first+b];
    endfunction
    task automatic tick(input integer n=1);
        repeat(n) begin @(posedge clk);#3;end
    endtask
    task automatic drive();@(negedge clk);#3;endtask
    task automatic wait_pause();
        integer n=0;
        while(!pause_done && n<200) begin tick();n++;end
        assert(pause_done) else $fatal(1,"Z_QUIESCE_PAUSE_PROGRESS");
    endtask
    task automatic release_control();
        assert(release_ready) else $fatal(1,"Z_QUIESCE_RELEASE_READY");
        drive();release_pause=1;tick();drive();release_pause=0;consumers_quiescent=0;
        assert(cpu_enabled && updates_enabled && !hold_consumers) else $fatal(1,"Z_QUIESCE_RELEASE");
    endtask
    task automatic upload(input integer count,input bit stall_last=0);
        for(integer a=0;a<count;a++) begin
            while(ioctl_wait) tick();
            drive();if(stall_last && a==count-1) force_busy=1;
            ioctl_address=25'(a);ioctl_data=pattern(a);ioctl_wr=1;
            tick();drive();ioctl_wr=0;
        end
    endtask
    task automatic end_upload(input bit stall_last=0);
        drive();host_download=0;
        if(stall_last) begin
            release_pause=1;tick(8);
            assert(upload_active && pause_done && upload_permitted && hold_consumers &&
                !release_ready && write_offset==262143)
                else $fatal(1,"Z_QUIESCE_OWNED_UPLOAD_RELEASE");
            drive();release_pause=0;force_busy=0;
        end
        while(upload_active) tick();
        assert(loaded && !upload_error && write_offset==262144) else $fatal(1,"Z_QUIESCE_UPLOAD_COMMIT");
        tick(3);
    endtask
    task automatic start_update(input integer glyph,input logic [31:0] descriptor);
        drive();active_glyph=glyph;cache_offset=0;
        update_glyph=13'(glyph);update_descriptor=descriptor;raw_update_valid=1;
        assert(update_ready && updates_enabled) else $fatal(1,"Z_QUIESCE_UPDATE_ADMISSION");
        tick();drive();raw_update_valid=0;updates++;
    endtask
    task automatic wait_update();
        integer n=0;
        while(!update_done && n<3000) begin tick();n++;end
        assert(update_done && update_done_cell==7 && update_done_glyph==update_glyph &&
            update_done_descriptor==update_descriptor && cache_offset==32)
            else $fatal(1,"Z_QUIESCE_UPDATE_COMPLETION");
    endtask
    task automatic check_video(input bit hit,input integer glyph,input logic [31:0] descriptor);
        for(integer o=0;o<32;o++) begin
            @(negedge clk_vid);vid_request=1;vid_offset=5'(o);
            @(posedge clk_vid);#3;
            @(negedge clk_vid);vid_request=0;
            @(posedge clk_vid);#3;
            assert(vid_response_valid && vid_response_cell==7 && vid_response_offset==5'(o) &&
                vid_response_hit==hit && vid_response_glyph==(hit ? 13'(glyph) : 13'd0) &&
                vid_response_descriptor==(hit ? descriptor : 32'd0) &&
                vid_response_data==(hit ? pattern(glyph*32+o) : 8'd0))
                else $fatal(1,"Z_QUIESCE_VIDEO_PAYLOAD");
        end
    endtask
    initial forever begin
        @(negedge clk);#1;
        DDRAM_BUSY=force_busy || edges%11==0;
        DDRAM_DOUT=word_at(pending ? pending_word : DDRAM_ADDR);
        DDRAM_DOUT_READY=pending && delay_left==0 && !hold_response;
    end
    initial forever begin
        @(posedge clk);edges++;
        assert(cpu_wait==(cpu_read&&!cpu_valid) && frontend_cpu_wait==(font_read&&!font_valid) && !(DDRAM_RD&&DDRAM_WE) &&
            DDRAM_CLK==clk && DDRAM_BURSTCNT==1) else $fatal(1,"Z_QUIESCE_INTERFACE");
        assert(!cpu_valid && cpu_data==0) else $fatal(1,"Z_QUIESCE_CANCELLED_CPU");
        if(frontend_cancel || frontend_cold_reset || upload_permitted) begin
            assert(arbiter_idle && !cache_read && !font_read && consumers_quiescent &&
                !cache_enabled && !cpu_enabled && !updates_enabled)
                else $fatal(1,"Z_QUIESCE_UNDRAINED_PERMISSION");
        end
        if(frontend_cancel) cancels++;
        if(frontend_cold_reset) cold_cancels++;
        if(cpu_read && !previous_cpu_read) begin cpu_pending=1;expected_cpu=int'(cpu_address);end
        if(cache_read && !previous_cache_read) begin
            assert(cache_offset<32 && !cache_pending) else $fatal(1,"Z_QUIESCE_CACHE_INTENT");
            expected_cache=active_glyph*32+cache_offset;cache_offset++;cache_pending=1;
            assert(cache_address==18'(expected_cache)) else $fatal(1,"Z_QUIESCE_CACHE_ADDRESS");
        end
        if(cache_valid) assert(cache_data==pattern(expected_cache)) else $fatal(1,"Z_QUIESCE_CACHE_DATA");
        if(font_read && !previous_font_read) begin
            if(cache_pending && (!cpu_pending || prefer_cache)) begin
                expected_font=expected_cache;cache_pending=0;prefer_cache=0;
            end else begin
                assert(cpu_pending) else $fatal(1,"Z_QUIESCE_UNOWNED_REQUEST");
                expected_font=expected_cpu;cpu_pending=0;prefer_cache=1;
            end
            assert(font_address==18'(expected_font)) else $fatal(1,"Z_QUIESCE_FONT_INTENT");
            requests++;
        end
        if(font_response_ack) begin
            assert(font_valid) else $fatal(1,"Z_QUIESCE_FONT_ACK");acks++;
        end
        previous_cpu_read=cpu_read;previous_cache_read=cache_read;previous_font_read=font_read;
        if(pending) begin
            if(DDRAM_DOUT_READY) pending=0;else if(delay_left>0) delay_left--;
        end
        if((DDRAM_RD||DDRAM_WE)&&!DDRAM_BUSY) begin
            if(DDRAM_WE) begin
                assert(write_offset<262144 && DDRAM_ADDR==BASE+29'(write_offset/8) &&
                    DDRAM_BE==(8'd1<<(write_offset%8)) && DDRAM_DIN=={8{pattern(write_offset)}})
                    else $fatal(1,"Z_QUIESCE_UPLOAD_INTENT");
                for(integer b=0;b<8;b++) if(DDRAM_BE[b])
                    memory_image[(int'(DDRAM_ADDR)-int'(BASE))*8+b]=DDRAM_DIN[b*8+:8];
                writes++;write_offset++;
            end else begin
                assert(requests==reads+1 && DDRAM_ADDR==BASE+29'(expected_font/8) &&
                    DDRAM_BE==8'hff && !pending) else $fatal(1,"Z_QUIESCE_DDR_INTENT");
                reads++;pending=1;pending_word=DDRAM_ADDR;delay_left=4;
            end
        end
    end
    initial begin
        tick(4);drive();pause_request=1;host_download=1;ioctl_wr=1;ioctl_data=pattern(0);
        tick(30);
        assert(!upload_permitted && !frontend_download && ioctl_wait && !loaded && writes==0)
            else $fatal(1,"Z_QUIESCE_START_BEFORE_HOLD");
        drive();ioctl_wr=0;consumers_quiescent=1;wait_pause();
        drive();release_pause=1;host_download=0;tick(8);
        assert(pause_done && !release_ready && cancels==1 && hold_consumers)
            else $fatal(1,"Z_QUIESCE_HELD_PAUSE");
        drive();release_pause=0;pause_request=0;host_download=1;
        upload(262144);end_upload();release_control();cases++;
        start_update(8191,32'h7b3f19a5);wait_update();check_video(1,8191,32'h7b3f19a5);
        drive();update_done_ready=1;tick();drive();update_done_ready=0;

        // Host START must wait while an admitted cache read drains and VID stops.
        drive();force_busy=1;start_update(5461,32'h13579bdf);
        while(!font_read) tick();tick(5);
        @(negedge clk_vid);run_vid=0;
        drive();pause_request=1;host_download=1;
        tick();drive();pause_request=0;tick(16);
        assert(loaded && !upload_permitted && !frontend_cancel && cache_enabled && ioctl_wait)
            else $fatal(1,"Z_QUIESCE_CACHE_DRAIN_SERVICE");
        drive();force_busy=0;tick(80);
        assert(loaded && !upload_permitted && !frontend_cancel && !pending && cache_offset==1)
            else $fatal(1,"Z_QUIESCE_STOPPED_VID");
        run_vid=1;tick(60);
        assert(loaded && !upload_permitted && !frontend_cancel && arbiter_idle)
            else $fatal(1,"Z_QUIESCE_CONSUMER_ACK");
        drive();consumers_quiescent=1;wait_pause();
        check_video(0,0,0);
        drive();font_epoch=1;write_offset=0;
        upload(262144,1);end_upload(1);release_control();cases++;
        start_update(8191,32'h2468ace0);wait_update();check_video(1,8191,32'h2468ace0);

        // Cache has offered a read but CPU still owns DDR. Consumer hold may
        // arrive immediately; it must not disable admission of that cache read.
        drive();update_done_ready=1;tick();drive();update_done_ready=0;
        hold_response=1;cpu_read=1;
        while(!pending) tick();
        start_update(4096,32'ha55a3cc3);
        while(!cache_read) tick();
        drive();pause_request=1;consumers_quiescent=1;
        tick();drive();pause_request=0;tick(16);
        assert(loaded && !pause_done && !frontend_cancel && pending && cache_offset==1)
            else $fatal(1,"Z_QUIESCE_QUEUED_CACHE_DRAIN");
        drive();hold_response=0;wait_pause();check_video(0,0,0);
        drive();cpu_read=0;tick();release_control();cases++;

        // A cold request while CPU owns a delayed DDR reply may not cancel it.
        drive();hold_response=1;cpu_read=1;
        while(!pending) tick();
        drive();cold_reset_request=1;tick();drive();cold_reset_request=0;tick(20);
        assert(loaded && !frontend_cancel && !frontend_cold_reset && !pause_done && pending)
            else $fatal(1,"Z_QUIESCE_CPU_DRAIN");
        drive();hold_response=0;consumers_quiescent=1;wait_pause();
        assert(!loaded && cold_cancels==1) else $fatal(1,"Z_QUIESCE_COLD_LOSS");
        check_video(0,0,0);drive();cpu_read=0;cases++;

        // Cold loss during a partial upload ends its gated download and drains
        // the already-admitted write; explicit retry is a fresh complete image.
        drive();host_download=1;write_offset=0;upload(3,1);
        drive();cold_reset_request=1;release_pause=1;tick();drive();cold_reset_request=0;
        tick(20);
        assert(!upload_permitted && !frontend_download) else $fatal(1,"Z_QUIESCE_ABORT_RESTARTED");
        assert(!loaded && upload_error && !release_ready && hold_consumers && !cpu_enabled &&
            upload_active && write_offset==2)
            else $fatal(1,"Z_QUIESCE_PARTIAL_COLD");
        drive();force_busy=0;tick(20);
        assert(!upload_active && upload_error && !upload_permitted && !frontend_download && write_offset==3)
            else $fatal(1,"Z_QUIESCE_ABORT_RESTARTED");
        drive();host_download=0;release_pause=0;
        while(upload_active) tick();wait_pause();
        drive();host_download=1;write_offset=0;upload(262144);end_upload();release_control();cases++;
        tick(8);
        assert(reads==68 && requests==68 && acks==68 && writes==786435 &&
            updates==4 && cancels==5 && cold_cancels==2 && cases==5 && !pending && loaded && !upload_error)
            else $fatal(1,"Z_QUIESCE_FINAL_LEDGER");
        $display("PASS Z_QUIESCE cases=%0d reads=%0d requests=%0d acks=%0d writes=%0d updates=%0d cancels=%0d cold_cancels=%0d sys_half=%0d edges=%0d",
            cases,reads,requests,acks,writes,updates,cancels,cold_cancels,SYS_HALF_PS,edges);
        $finish;
    end
    initial begin #300ms;$fatal(1,"Z_QUIESCE_TEST_TIMEOUT");end
endmodule
