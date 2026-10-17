// SPDX-License-Identifier: GPL-2.0-only
// Original actual-Z80/PCG/font-service fixture. Generated code/font and mock
// DDR only. No machine profile, native firmware, forced state or board claim.
`timescale 1ns/1ps
module x1_z_kanji_cpu_service_tb #(parameter integer CE_PERIOD=8, VID_HALF_PS=11640);
    bit clk=0,clk_vid=0,cpu_reset=1;
    initial forever begin #15625ps;clk=~clk;end
    initial forever begin #(VID_HALF_PS*1ps);clk_vid=~clk_vid;end
    localparam logic [28:0] BASE=29'h06123400;
    logic pause_request=0,release_pause=0,host_download=0,ioctl_wr=0;
    logic [24:0] ioctl_address=0;
    logic [7:0] ioctl_data=0;
    wire loaded,upload_active,upload_error,host_wait,frontend_cpu_wait;
    wire hold_consumers,cpu_enabled,cache_enabled,updates_enabled,cpu_cancel;
    wire cache_invalidate,cache_invalidate_done,arbiter_idle;
    wire frontend_cancel,frontend_cold_reset,pause_done,upload_permitted,release_ready;
    wire video_reset;
    x1_reset_release reset_release(clk_vid,cpu_reset,video_reset);
    reg held_meta,held_sync;
    initial begin held_meta=0;held_sync=0;end
    always @(posedge clk) begin held_meta<=video_reset;held_sync<=held_meta;end
    wire consumers_quiescent=cpu_reset && held_sync;
    wire lifecycle_cancel;
    bit cancel_pulse=0;
    assign cpu_cancel=lifecycle_cancel || cancel_pulse;
    x1_z_kanji_quiesce control(.cold_reset_request(1'b0),.cpu_cancel(lifecycle_cancel),.*);
    wire ioctl_wait=host_download && (!upload_permitted || host_wait);
    wire frontend_download=host_download && upload_permitted;
    wire cpu_read,cpu_valid,cpu_response_ack,cpu_wait;
    wire [17:0] cpu_address;
    wire [7:0] cpu_data;
    wire pcg_read,pcg_valid;
    wire [17:0] pcg_address;
    wire [7:0] pcg_data;
    x1_z_kanji_cpu_port bridge(.*);
    wire cache_read,cache_valid,cache_response_ack;
    wire [17:0] cache_address,font_address;
    wire [7:0] cache_data,font_data;
    wire font_read,font_valid,font_response_ack;
    x1_z_kanji_arbiter arbiter(.idle(arbiter_idle),.*);
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
        .ioctl_wr(ioctl_wr && upload_permitted),.ioctl_data(ioctl_data),.ioctl_wait(host_wait),
        .upload_permitted(upload_permitted),.loaded(loaded),.upload_error(upload_error),.upload_active(upload_active),
        .DDRAM_CLK(DDRAM_CLK),.DDRAM_BUSY(DDRAM_BUSY),.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
        .DDRAM_ADDR(DDRAM_ADDR),.DDRAM_DOUT(DDRAM_DOUT),.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
        .DDRAM_RD(DDRAM_RD),.DDRAM_DIN(DDRAM_DIN),.DDRAM_BE(DDRAM_BE),.DDRAM_WE(DDRAM_WE)
    );
    reg [4:0] divider;
    always @(negedge clk or posedge cpu_reset)
        if(cpu_reset) divider<=0;
        else divider<=divider==5'(CE_PERIOD-1) ? 5'd0 : divider+5'd1;
    wire cpu_ce=!cpu_reset && divider==0;
    wire [15:0] a;
    wire [7:0] data_out,cg_q;
    wire mreq,iorq,rd,wr,m1,halt_n,busak_n,wait_n,read_hold,unused_rfsh_n;
    logic [7:0] memory[0:65535];
    reg [7:0] memory_data,io_data;
    reg io_active;
    wire io_write=!cpu_reset && !iorq && !wr && m1;
    wire io_read=!cpu_reset && !iorq && !rd && m1;
    wire cg_select=(io_read || io_write) && a[15:10]==6'b000101;
    wire [7:0] cpu_di=cg_select && !rd ? cg_q : io_active && mreq ? io_data : memory_data;
    cpu processor(.clock(clk),.cep(cpu_ce),.cen(1'b0),.reset_n(!cpu_reset),.int_n(1'b1),
        .wait_n(wait_n),.busrq_n(1'b1),.busak_n(busak_n),.di(cpu_di),.a(a),.data_out(data_out),
        .mreq(mreq),.iorq(iorq),.rd(rd),.wr(wr),.m1(m1),.halt_n(halt_n),.rfsh_n(unused_rfsh_n),
        .dir(16'd0),.dirset(1'b0));
    wire [10:0] selected_addr;
    wire [11:0] selected_font_addr;
    wire selected_font16,selected_unsupported,selected_kanji;
    wire [17:0] selected_kanji_addr;
    x1_z_pcg_selector selector(.clk(clk),
        .text_write(io_write && a[15:12]==4'h3 && !a[11]),
        .attr_write(io_write && a[15:12]==4'h2),.kan_write(io_write && a[15:11]==5'b00111),
        .address(a[10:0]),.data(data_out),.nibble(a[3:0]),.plane(a[9:8]),.font16_mode(1'b1),
        .byte_address(selected_addr),.font_address(selected_font_addr),.font16_select(selected_font16),
        .unsupported(selected_unsupported),.kanji_select(selected_kanji),.kanji_address(selected_kanji_addr));
    integer video_ticks=0;
    initial forever begin @(posedge clk_vid);if(video_reset) video_ticks=0;else video_ticks++;end
    wire video_window=video_ticks%128>=96 && video_ticks%128<100;
    wire [2:0] access_write;
    wire [10:0] unused_access_addr;
    wire [7:0] unused_access_data;
    wire [11:0] unused_font_addr;
    x1_pcg_access #(.KANJI_SUPPORT(1),.KANJI_ADDRESS_BITS(18),.SEPARATE_VIDEO_RESET(1)) pcg(
        .reset(cpu_reset),.cpu_clk(clk),.video_clk(clk_vid),.video_reset(video_reset),
        .cpu_select(cg_select),.cpu_write(io_write),.cpu_plane(a[9:8]),.cpu_data(data_out),
        .wait_n(wait_n),.cpu_q(cg_q),.beam_addr(11'd0),.access_addr(unused_access_addr),
        .access_data(unused_access_data),.access_write(access_write),.rom_q(8'h32),
        .blue_q(8'h43),.red_q(8'h54),.green_q(8'h65),.high_speed(1'b1),
        .selected_addr(selected_addr),.selected_font16(selected_font16),.selected_unsupported(selected_unsupported),
        .selected_font_addr(selected_font_addr),.video_window(video_window),
        .font_cpu_addr(unused_font_addr),.font_cpu_q(8'ha6),.cpu_read_hold(read_hold),
        .selected_kanji(selected_kanji),.selected_kanji_addr(selected_kanji_addr),.kanji_available(loaded),
        .kanji_cpu_valid(pcg_valid),.kanji_cpu_q(pcg_data),.kanji_cpu_addr(pcg_address),.kanji_cpu_read(pcg_read));

    reg update_valid,update_done_ready;
    reg [12:0] update_glyph;
    reg [31:0] update_descriptor;
    wire update_ready,update_done;
    wire [2:0] update_done_cell;
    wire [12:0] update_done_glyph;
    wire [31:0] update_done_descriptor;
    integer update_id=0,active_glyph=0,cache_offset=0,updates=0,completed_updates=0;
    logic vid_request=1;
    logic [2:0] vid_cell=0;
    logic [4:0] vid_offset=0;
    wire vid_response_valid,vid_response_hit;
    wire [2:0] vid_response_cell;
    wire [4:0] vid_response_offset;
    wire [12:0] vid_response_glyph;
    wire [31:0] vid_response_descriptor;
    wire [7:0] vid_response_data;
    x1_z_kanji_cache #(.CELL_BITS(3)) cache(
        .clk_sys(clk),.clk_vid(clk_vid),.invalidate(cache_invalidate),.invalidate_done(cache_invalidate_done),
        .update_valid(update_valid && updates_enabled),.update_cell(3'd7),
        .font_read(cache_read),.font_address(cache_address),.font_valid(cache_valid),
        .font_data(cache_data),.font_response_ack(cache_response_ack),.*);
    function automatic [31:0] descriptor(input integer glyph);
        return 32'h59ac0000 ^ (32'(glyph)*32'h01010001);
    endfunction
    initial begin
        update_valid=0;update_done_ready=1;update_glyph=0;update_descriptor=0;
        forever begin
            @(negedge clk);#2;
            update_valid=updates_enabled && !cpu_reset;
            update_glyph=13'((update_id*1031+8191)%8192);
            update_descriptor=descriptor(int'(update_glyph));
        end
    end
    initial forever begin
        @(posedge clk);
        if(update_valid && updates_enabled && update_ready) begin
            active_glyph=int'(update_glyph);cache_offset=0;updates++;update_id++;
        end
        if(update_done) begin
            assert(update_done_cell==7 && update_done_glyph==13'(active_glyph) &&
                update_done_descriptor==descriptor(active_glyph) && cache_offset==32)
                else $fatal(1,"Z_CPU_SERVICE_CACHE_COMPLETION");
            completed_updates++;
        end
    end
    integer scan=0,replies=0;
    bit previous_vid_request=0;
    logic [2:0] previous_vid_cell=0;
    logic [4:0] previous_vid_offset=0;
    initial forever begin
        @(negedge clk_vid);scan++;vid_cell=3'(scan/32);vid_offset=5'(scan);
    end
    initial forever begin
        @(posedge clk_vid);#3;
        assert(vid_response_valid==previous_vid_request) else $fatal(1,"Z_CPU_SERVICE_VIDEO_LATENCY");
        if(previous_vid_request) begin
            replies++;
            assert(vid_response_cell==previous_vid_cell && vid_response_offset==previous_vid_offset)
                else $fatal(1,"Z_CPU_SERVICE_VIDEO_TAG");
            if(vid_response_hit) begin
                assert(previous_vid_cell==7 && vid_response_descriptor==descriptor(int'(vid_response_glyph)) &&
                    vid_response_data==pattern(int'({vid_response_glyph,previous_vid_offset})) && !pause_done)
                    else $fatal(1,"Z_CPU_SERVICE_VIDEO_PAYLOAD");
            end else assert(vid_response_data==0 && vid_response_glyph==0 && vid_response_descriptor==0)
                else $fatal(1,"Z_CPU_SERVICE_VIDEO_MISS");
        end
        previous_vid_request=vid_request;previous_vid_cell=vid_cell;previous_vid_offset=vid_offset;
    end

    byte unsigned font_memory[0:262143];
    integer external_intent[0:2047],intent_count=0;
    integer pc=0,boot=0,completed_boots=0,boot_external=0,cpu_offers=0,cache_offers=0;
    integer requests=0,reads=0,acks=0,writes=0,cpu_ddr_reads=0,cache_ddr_reads=0;
    integer wait_edges=0,held_reply_edges=0,cg_reads=0,long_reads=0;
    longint unsigned edges=0;
    bit previous_cpu_read=0,previous_cache_read=0,previous_font_read=0;
    bit cpu_pending=0,cache_pending=0,prefer_cache=0,font_owner_cache=0;
    bit scheduled=0,scheduled_cache=0;
    integer expected_cpu=0,expected_cache=0,expected_font=0,scheduled_address=0;
    bit pending=0,stall_next_cpu=0,response_held=0,stalled_cpu=0;
    integer delay_left=0;
    logic [28:0] pending_word=BASE;
    function automatic [7:0] pattern(input integer address_value);
        return 8'((address_value*43)^(address_value>>7)^(address_value>>14)^8'ha7);
    endfunction
    function automatic [63:0] word_at(input logic [28:0] address_value);
        integer first;
        first=(int'(address_value)-int'(BASE))*8;
        for(integer b=0;b<8;b++) word_at[b*8+:8]=font_memory[first+b];
    endfunction
    initial forever begin
        @(negedge clk);#1;
        DDRAM_BUSY=edges%11==0;
        DDRAM_DOUT=word_at(pending ? pending_word : DDRAM_ADDR);
        DDRAM_DOUT_READY=pending && delay_left==0 && !response_held;
    end
    initial forever begin
        @(posedge clk);edges++;
        if(cpu_reset) boot_external=0;
        assert(cpu_wait==(cpu_read&&!cpu_valid) && frontend_cpu_wait==(font_read&&!font_valid) &&
            DDRAM_CLK==clk && DDRAM_BURSTCNT==1 && !(DDRAM_RD&&DDRAM_WE))
            else $fatal(1,"Z_CPU_SERVICE_INTERFACE");
        if(frontend_cancel || frontend_cold_reset || upload_permitted) begin
            assert(arbiter_idle && !cache_read && !font_read && consumers_quiescent &&
                !cache_enabled && !cpu_enabled && !updates_enabled)
                else $fatal(1,"Z_CPU_SERVICE_UNDRAINED_PERMISSION");
        end
        if(cpu_valid && pcg_read) begin
            assert(!cpu_response_ack) else $fatal(1,"Z_CPU_SERVICE_EARLY_ACK");
            held_reply_edges++;
        end
        if(cpu_cancel) assert(!pcg_valid && pcg_data==0) else $fatal(1,"Z_CPU_SERVICE_CANCEL_DELIVERY");
        if(!pcg_valid) assert(pcg_data==0) else $fatal(1,"Z_CPU_SERVICE_IDLE_DATA");
        if(cpu_read && !previous_cpu_read) begin
            assert(!cpu_reset && boot_external<intent_count && !cpu_pending)
                else $fatal(1,"Z_CPU_SERVICE_CPU_REQUEST_COUNT");
            expected_cpu=external_intent[boot_external];boot_external++;cpu_offers++;cpu_pending=1;
            assert(cpu_address==18'(expected_cpu)) else $fatal(1,"Z_CPU_SERVICE_CPU_ADDRESS");
        end
        if(cache_read && !previous_cache_read) begin
            assert(cache_offset<32 && !cache_pending) else $fatal(1,"Z_CPU_SERVICE_CACHE_REQUEST_COUNT");
            expected_cache=active_glyph*32+cache_offset;cache_offset++;cache_offers++;cache_pending=1;
            assert(cache_address==18'(expected_cache)) else $fatal(1,"Z_CPU_SERVICE_CACHE_ADDRESS");
        end
        if(font_read && !previous_font_read) begin
            assert(scheduled) else $fatal(1,"Z_CPU_SERVICE_UNOWNED_READ");
            expected_font=scheduled_address;font_owner_cache=scheduled_cache;scheduled=0;
            assert(font_address==18'(expected_font)) else $fatal(1,"Z_CPU_SERVICE_ARBITRATION_ADDRESS");
            requests++;
        end
        // Predict selection from public pre-admission inputs/idle, before
        // newly offered clients on the following edge could affect ordering.
        if(arbiter_idle && ((cpu_pending && cpu_enabled && !cpu_cancel) || (cache_pending && cache_enabled))) begin
            assert(!scheduled) else $fatal(1,"Z_CPU_SERVICE_DUPLICATE_ADMISSION");
            scheduled_cache=cache_pending && cache_enabled &&
                (!(cpu_pending && cpu_enabled && !cpu_cancel) || prefer_cache);
            if(scheduled_cache) begin scheduled_address=expected_cache;cache_pending=0;prefer_cache=0;end
            else begin scheduled_address=expected_cpu;cpu_pending=0;prefer_cache=1;end
            scheduled=1;
        end
        if(font_read) assert(font_address==18'(expected_font)) else $fatal(1,"Z_CPU_SERVICE_ADDRESS_HELD");
        if(font_response_ack) begin
            assert(font_valid) else $fatal(1,"Z_CPU_SERVICE_FONT_ACK");acks++;
        end
        previous_cpu_read=cpu_read;previous_cache_read=cache_read;previous_font_read=font_read;
        if(pending) begin
            if(DDRAM_DOUT_READY) pending=0;else if(delay_left>0) delay_left--;
        end
        if((DDRAM_RD||DDRAM_WE)&&!DDRAM_BUSY) begin
            if(DDRAM_WE) begin
                assert(writes<262144 && DDRAM_ADDR==BASE+29'(writes/8) &&
                    DDRAM_BE==(8'd1<<(writes%8)) && DDRAM_DIN=={8{pattern(writes)}})
                    else $fatal(1,"Z_CPU_SERVICE_UPLOAD_INTENT");
                for(integer b=0;b<8;b++) if(DDRAM_BE[b])
                    font_memory[(int'(DDRAM_ADDR)-int'(BASE))*8+b]=DDRAM_DIN[b*8+:8];
                writes++;
            end else begin
                assert(requests==reads+1 && DDRAM_ADDR==BASE+29'(expected_font/8) &&
                    DDRAM_BE==8'hff && !pending) else $fatal(1,"Z_CPU_SERVICE_DDR_INTENT");
                reads++;pending=1;pending_word=DDRAM_ADDR;delay_left=3+reads%5;
                if(font_owner_cache) cache_ddr_reads++;
                else begin
                    cpu_ddr_reads++;
                    if(stall_next_cpu) begin response_held=1;stall_next_cpu=0;stalled_cpu=1;end
                    else if(boot_external==1) begin
                        // Force the first real CPU read beyond a complete
                        // synthetic VID window at either tested frequency.
                        // PCG must still wait for font validity after VID ACK.
                        delay_left=200;long_reads++;
                    end
                end
            end
        end
    end

    integer trace_fd,read_physical=0;
    bit read_seen=0,write_seen=0,read_sampled=0;
    logic [15:0] read_port=0;
    logic [7:0] last_sample=0,observed_text=0;
    logic [6:0] observed_kan=0;
    bit observed_attr_pcg=0;
    string trace_path,program_path;
    initial begin memory_data=0;io_data=0;io_active=0;end
    // Registered memory and retained I/O tail match the existing CPU fixture;
    // scoreboard bookkeeping below remains in a separate simulation process.
    always @(posedge clk) begin
        memory_data<=memory[a];
        if(cpu_reset) begin io_active<=0;io_data<=0;end
        else begin
            if(!mreq && !rd) io_active<=0;
            else if(io_read) begin io_active<=1;io_data<=cg_q;end
            if(!mreq && !wr) memory[a]<=data_out;
        end
    end
    initial forever begin
        @(posedge clk);
        if(cpu_reset) begin read_seen=0;write_seen=0;end
        else begin
            assert(busak_n) else $fatal(1,"Z_CPU_SERVICE_CPU_GRANT");
            assert(access_write==0) else $fatal(1,"Z_CPU_SERVICE_ROM_WRITE");
            if(cpu_ce && !wait_n) wait_edges++;
            if(!io_write) write_seen=0;
            if(io_write && !write_seen) begin
                write_seen=1;
                if(a==16'h37ff) observed_text=data_out;
                if(a==16'h3fff) observed_kan={data_out[7:6],data_out[4:0]};
                if(a==16'h27ff) observed_attr_pcg=data_out[5];
            end
            if(io_read && cg_select) begin
                if(!read_seen) begin
                    read_seen=1;read_sampled=0;read_port=a;
                    read_physical=observed_kan[6] && !observed_attr_pcg ?
                        int'({observed_kan[4],observed_kan[3:0],observed_text,a[3:0],observed_kan[5]}) : -1;
                end
                if(cpu_ce && wait_n) begin last_sample=cpu_di;read_sampled=1;end
            end else if(read_seen) begin
                assert(read_sampled) else $fatal(1,"Z_CPU_SERVICE_UNSAMPLED_READ");
                $fdisplay(trace_fd,"%0d,%0d,%0d,%0d",boot,read_port,read_physical,last_sample);
                $fflush(trace_fd);
                cg_reads++;read_seen=0;
            end
        end
    end
    task automatic tick(input integer n=1);repeat(n) begin @(posedge clk);#3;end endtask
    task automatic drive();@(negedge clk);#3;endtask
    task automatic emit(input logic [7:0] value);memory[pc]=value;pc++;endtask
    task automatic port(input logic [15:0] value);emit(8'h01);emit(value[7:0]);emit(value[15:8]);endtask
    task automatic out_byte(input logic [15:0] target,input logic [7:0] value);
        port(target);emit(8'h3e);emit(value);emit(8'hed);emit(8'h79);
    endtask
    task automatic equal_port(input logic [15:0] target,input logic [7:0] value,input integer physical=-1);
        port(target);emit(8'hed);emit(8'h78);emit(8'hfe);emit(value);
        emit(8'hc2);emit(8'h00);emit(8'hf1);
        if(physical>=0) begin external_intent[intent_count]=physical;intent_count++;end
    endtask
    task automatic wait_pause();
        integer n=0;
        while(!pause_done && n<600) begin tick();n++;end
        assert(pause_done && hold_consumers) else $fatal(1,"Z_CPU_SERVICE_PAUSE_PROGRESS");
    endtask
    task automatic start_boot();
        assert(release_ready && loaded && !upload_error) else $fatal(1,"Z_CPU_SERVICE_RELEASE_READY");
        drive();release_pause=1;tick();drive();release_pause=0;boot++;cpu_reset=0;
    endtask
    task automatic finish_boot();
        integer n=0;
        while(halt_n && n<3000000) begin tick();n++;end
        assert(!halt_n) else $fatal(1,"Z_CPU_SERVICE_CPU_DEADLINE");
        assert(memory[16'hf000]==8'ha5 && boot_external==intent_count)
            else $fatal(1,"Z_CPU_SERVICE_EXECUTED_ORACLE marker=%0d boot=%0d external=%0d",
                memory[16'hf000],boot,boot_external);
        completed_boots++;
        drive();pause_request=1;cpu_reset=1;tick();drive();pause_request=0;wait_pause();
        assert(loaded && !upload_error && !pcg_read && !read_hold && cg_q==8'hff)
            else $fatal(1,"Z_CPU_SERVICE_RETAINED_RESET");
    endtask
    initial begin : diagnostic
        integer physical;
        assert(CE_PERIOD>=4 && CE_PERIOD<=16) else $fatal(1,"Z_CPU_SERVICE_PARAMETERS");
        assert($value$plusargs("TRACE=%s",trace_path)) else $fatal(1,"Z_CPU_SERVICE_TRACE_ARGUMENT");
        assert($value$plusargs("PROGRAM=%s",program_path)) else $fatal(1,"Z_CPU_SERVICE_PROGRAM_ARGUMENT");
        trace_fd=$fopen(trace_path,"w");assert(trace_fd!=0) else $fatal(1,"Z_CPU_SERVICE_TRACE_OPEN");
        $fdisplay(trace_fd,"boot,port,physical,value");
        for(integer i=0;i<65536;i++) memory[i]=0;
        emit(8'hf3);emit(8'h31);emit(8'hff);emit(8'hff);
        emit(8'h3e);emit(0);emit(8'h32);emit(8'h00);emit(8'hf0);
        for(integer level=0;level<2;level++)
        for(integer bank=0;bank<16;bank++)
        for(integer glyph=0;glyph<4;glyph++)
        for(integer half=0;half<2;half++) begin
            integer character;
            character=glyph==0 ? 0 : glyph==1 ? 127 : glyph==2 ? 128 : 255;
            out_byte(16'h37ff,8'(character));out_byte(16'h27ff,7);
            out_byte(16'h3fff,8'(128+64*half+16*level+bank));
            // Neighbor writes must not replace the unique highest selector.
            out_byte(16'h37fc,8'h31);out_byte(16'h27fd,8'h27);out_byte(16'h3ffb,0);
            for(integer r=0;r<4;r++) begin
                integer row;
                row=r==0 ? 0 : r==1 ? 1 : r==2 ? 7 : 15;
                physical=level*131072+bank*8192+character*32+row*2+half;
                equal_port(16'(16'h1400+row),pattern(physical),physical);
            end
        end
        out_byte(16'h3fff,0);equal_port(16'h1403,8'ha6);
        out_byte(16'h27ff,8'h27);equal_port(16'h1400,8'hff);
        out_byte(16'h27ff,7);out_byte(16'h3fff,8'hdf);
        out_byte(16'h1400,8'h66); // ROM write ignored; INI checks that byte below.
        port(16'h1400);emit(8'h21);emit(8'h00);emit(8'hd0);
        for(integer row=0;row<16;row++) begin
            emit(8'hed);emit(8'ha2);emit(8'h04);emit(8'h0c);
            external_intent[intent_count]=262113+row*2;intent_count++;
        end
        for(integer row=0;row<16;row++) begin
            emit(8'h3a);emit(8'(row));emit(8'hd0);emit(8'hfe);emit(pattern(262113+row*2));
            emit(8'hc2);emit(8'h00);emit(8'hf1);
        end
        assert(pc<16'hd000 && intent_count==1040) else $fatal(1,"Z_CPU_SERVICE_PROGRAM_RANGE");
        emit(8'h3e);emit(8'ha5);emit(8'h32);emit(8'h00);emit(8'hf0);emit(8'h76);
        pc=32'hf100;emit(8'h3e);emit(8'hee);emit(8'h32);emit(8'h00);emit(8'hf0);emit(8'h76);
        $writememh(program_path,memory);
        tick(6);drive();pause_request=1;tick();drive();pause_request=0;wait_pause();
        drive();host_download=1;
        for(integer addr=0;addr<262144;addr++) begin
            while(ioctl_wait) tick();
            drive();ioctl_address=25'(addr);ioctl_data=pattern(addr);ioctl_wr=1;
            tick();drive();ioctl_wr=0;
        end
        drive();host_download=0;
        while(upload_active) tick();tick(4);
        start_boot();finish_boot();
        start_boot();finish_boot();
        // Pulse cancellation while the actual PCG request stays high. After
        // the real DDR reply drains, that old read must remain quarantined
        // until the later CPU/PCG reset; CPU execution cannot complete it.
        drive();stall_next_cpu=1;stalled_cpu=0;
        start_boot();
        while(!stalled_cpu || !cache_read) tick();
        drive();cancel_pulse=1;tick();drive();cancel_pulse=0;tick(6);
        drive();response_held=0;tick(120);
        assert(pcg_read && !pcg_valid && !wait_n && memory[16'hf000]==0 && boot_external==1)
            else $fatal(1,"Z_CPU_SERVICE_CANCEL_QUARANTINE");
        drive();pause_request=1;cpu_reset=1;tick();drive();pause_request=0;wait_pause();
        start_boot();finish_boot();
        drive();stall_next_cpu=1;stalled_cpu=0;
        start_boot();
        while(!stalled_cpu || !cache_read) tick();
        assert(memory[16'hf000]==0 && !wait_n && pending) else $fatal(1,"Z_CPU_SERVICE_OWNED_RESET_PHASE");
        drive();pause_request=1;cpu_reset=1;tick();drive();pause_request=0;tick(40);
        assert(!pause_done && !frontend_cancel && loaded && pending && !pcg_valid)
            else $fatal(1,"Z_CPU_SERVICE_OWNED_RESET_DRAIN");
        drive();response_held=0;wait_pause();
        assert(loaded && !upload_error && memory[16'hf000]==0) else $fatal(1,"Z_CPU_SERVICE_CANCELLED_BOOT");
        start_boot();finish_boot();tick(8);
        assert(completed_boots==4 && boot==6 && cpu_offers==4162 && cpu_ddr_reads==4162 && cg_reads==4168 &&
            writes==262144 && reads==requests && acks==requests && cache_offers==cache_ddr_reads &&
            requests==cpu_offers+cache_offers && !pending && !cpu_pending && !cache_pending &&
            completed_updates>0 && held_reply_edges>0 && wait_edges>0 && replies>0 && long_reads==4)
            else $fatal(1,"Z_CPU_SERVICE_FINAL_LEDGER");
        $fclose(trace_fd);
        $display("PASS Z_CPU_SERVICE boots=%0d attempts=%0d cpu_reads=%0d cg_reads=%0d cache_reads=%0d requests=%0d acks=%0d writes=%0d updates=%0d completed_updates=%0d wait_edges=%0d held_reply_edges=%0d replies=%0d ce_period=%0d vid_half=%0d edges=%0d long_reads=%0d",
            completed_boots,boot,cpu_ddr_reads,cg_reads,cache_ddr_reads,requests,acks,writes,updates,
            completed_updates,wait_edges,held_reply_edges,replies,CE_PERIOD,VID_HALF_PS,edges,long_reads);
        $finish;
    end
    initial begin #500ms;$fatal(1,"Z_CPU_SERVICE_TEST_TIMEOUT");end
endmodule
