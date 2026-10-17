// SPDX-License-Identifier: GPL-2.0-only
// Original public-pin fixture with real qualified frontend/backend and mock DDR.
`timescale 1ns/1ps
module x1_z_kanji_cache_tb #(
    parameter integer CELL_BITS=3,
    parameter integer SYS_HALF_PS=15625,
    parameter integer VID_HALF_PS=11640
);
    localparam integer CELLS=1<<CELL_BITS;
    localparam logic [28:0] BASE=29'h06123400;
    bit clk_sys=0,clk_vid=0,run_sys=1,run_vid=1;
    initial forever begin #(SYS_HALF_PS*1ps);if(run_sys) clk_sys=~clk_sys;end
    initial forever begin #(VID_HALF_PS*1ps);if(run_vid) clk_vid=~clk_vid;end
    logic invalidate=0,update_valid=0,update_done_ready=0;
    wire invalidate_done,update_ready,update_done;
    logic [CELL_BITS-1:0] update_cell=0;
    logic [12:0] update_glyph=0;
    logic [31:0] update_descriptor=0;
    wire [CELL_BITS-1:0] update_done_cell;
    wire [12:0] update_done_glyph;
    wire [31:0] update_done_descriptor;
    wire font_read,font_valid,font_response_ack;
    wire [17:0] font_address;
    wire [7:0] font_data;
    logic vid_request=1;
    logic [CELL_BITS-1:0] vid_cell=0;
    logic [4:0] vid_offset=0;
    wire vid_response_valid,vid_response_hit;
    wire [CELL_BITS-1:0] vid_response_cell;
    wire [4:0] vid_response_offset;
    wire [12:0] vid_response_glyph;
    wire [31:0] vid_response_descriptor;
    wire [7:0] vid_response_data;
    x1_z_kanji_cache #(.CELL_BITS(CELL_BITS)) dut(.*);
    logic ioctl_download=0,ioctl_wr=0;
    logic [24:0] ioctl_address=0;
    logic [7:0] ioctl_data=0;
    wire ioctl_wait,loaded,upload_error,upload_active,cpu_wait;
    wire DDRAM_CLK,DDRAM_RD,DDRAM_WE;
    wire [7:0] DDRAM_BURSTCNT,DDRAM_BE;
    wire [28:0] DDRAM_ADDR;
    wire [63:0] DDRAM_DIN;
    logic DDRAM_BUSY=0,DDRAM_DOUT_READY=0;
    logic [63:0] DDRAM_DOUT=0;
    x1_z_kanji_frontend #(.BASE_WORD_ADDRESS(BASE)) frontend(
        .clk(clk_sys),.cold_reset(1'b0),.consumer_cancel(1'b0),
        .cpu_read(font_read),.cpu_address(font_address),.cpu_wait(cpu_wait),
        .cpu_valid(font_valid),.cpu_data(font_data),.cpu_response_ack(font_response_ack),
        .ioctl_download(ioctl_download),.ioctl_index(8'd5),.ioctl_address(ioctl_address),
        .ioctl_wr(ioctl_wr),.ioctl_data(ioctl_data),.ioctl_wait(ioctl_wait),
        .upload_permitted(1'b1),.loaded(loaded),.upload_error(upload_error),.upload_active(upload_active),
        .DDRAM_CLK(DDRAM_CLK),.DDRAM_BUSY(DDRAM_BUSY),.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
        .DDRAM_ADDR(DDRAM_ADDR),.DDRAM_DOUT(DDRAM_DOUT),.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
        .DDRAM_RD(DDRAM_RD),.DDRAM_DIN(DDRAM_DIN),.DDRAM_BE(DDRAM_BE),.DDRAM_WE(DDRAM_WE)
    );
    byte unsigned font_memory[0:262143];
    bit font_read_seen[0:262143],font_pixel_seen[0:262143];
    bit force_busy=0,read_pending=0;
    integer delay_left=0,font_epoch=0,write_index=0;
    logic [28:0] pending_address=BASE;
    longint unsigned sys_edges=0,vid_edges=0,ddr_reads=0,ddr_writes=0,replies=0;
    integer updates=0,invalidations=0,cases=0,font_offers=0,font_acks=0;
    bit previous_font_read=0,expected_ddr_read=0;
    logic [17:0] expected_font_address=0;
    bit model_valid[0:CELLS-1],new_seen[0:CELLS-1];
    logic [12:0] model_glyph[0:CELLS-1];
    logic [31:0] model_descriptor[0:CELLS-1];
    bit proposed=0,flushing=0,scan_fixed=1,sparse_scan=0;
    integer proposed_cell=0,scan_counter=0;
    logic [CELL_BITS-1:0] fixed_cell=0;
    logic [12:0] proposed_glyph=0;
    logic [31:0] proposed_descriptor=0;
    bit previous_request=0;
    logic [CELL_BITS-1:0] previous_cell=0;
    logic [4:0] previous_offset=0;
    function automatic [7:0] font(input integer a);
        return 8'((a*43)^(a>>7)^(a>>14)^8'ha7)^((font_epoch!=0)?8'hff:8'h00);
    endfunction
    function automatic [63:0] word_at(input logic [28:0] a);
        integer first;
        first=(int'(a)-int'(BASE))*8;
        for(integer i=0;i<8;i++) word_at[i*8+:8]=font_memory[first+i];
    endfunction
    initial forever begin
        @(negedge clk_sys);#1;
        DDRAM_BUSY=force_busy || sys_edges%11==0;
        DDRAM_DOUT=word_at(read_pending ? pending_address : DDRAM_ADDR);
        DDRAM_DOUT_READY=(read_pending && delay_left==0) ||
            (DDRAM_RD && !DDRAM_BUSY && ddr_reads%8==0);
    end
    initial forever begin
        @(posedge clk_sys);
        sys_edges++;
        assert(DDRAM_CLK==clk_sys && DDRAM_BURSTCNT==1 && !(DDRAM_RD&&DDRAM_WE))
            else $fatal(1,"Z_CACHE_DDR_SHAPE");
        assert(cpu_wait==(font_read && !font_valid)) else $fatal(1,"Z_CACHE_FONT_WAIT");
        if(font_read && !previous_font_read) begin
            assert(!flushing) else $fatal(1,"Z_CACHE_CANCEL_REFILL");
            assert(proposed && font_offers<32 && loaded) else $fatal(1,"Z_CACHE_FONT_OWNER");
            expected_font_address={proposed_glyph,5'(font_offers)};
            if(font_epoch==0) font_read_seen[expected_font_address]=1;
            assert(font_address==expected_font_address) else $fatal(1,"Z_CACHE_FONT_ADDRESS");
            assert(!expected_ddr_read) else $fatal(1,"Z_CACHE_FONT_REPLAY");
            expected_ddr_read=1;font_offers++;
        end
        if(font_read) assert(font_address==expected_font_address)
            else $fatal(1,"Z_CACHE_FONT_ADDRESS_HELD");
        previous_font_read=font_read;
        if(font_valid && font_response_ack) font_acks++;
        if(read_pending) begin
            if(delay_left==0) read_pending=0;else delay_left--;
        end
        if((DDRAM_RD || DDRAM_WE) && !DDRAM_BUSY) begin
            if(DDRAM_WE) begin
                assert(write_index<262144 && DDRAM_ADDR==BASE+29'(write_index/8) &&
                    DDRAM_BE==(8'd1<<(write_index%8)) && DDRAM_DIN=={8{font(write_index)}})
                    else $fatal(1,"Z_CACHE_UPLOAD_METADATA");
                for(integer b=0;b<8;b++) if(DDRAM_BE[b])
                    font_memory[(int'(DDRAM_ADDR)-int'(BASE))*8+b]=DDRAM_DIN[8*b+:8];
                write_index++;ddr_writes++;
            end else begin
                assert(expected_ddr_read && DDRAM_ADDR==BASE+29'(expected_font_address/8) &&
                    DDRAM_BE==8'hff && !read_pending) else $fatal(1,"Z_CACHE_DDR_READ_OWNER");
                expected_ddr_read=0;ddr_reads++;
                if(!DDRAM_DOUT_READY) begin
                    read_pending=1;pending_address=DDRAM_ADDR;delay_left=3+int'(ddr_reads%5);
                end
            end
        end
    end
    initial forever begin
        @(negedge clk_vid);
        scan_counter++;
        vid_request=!sparse_scan || scan_counter%16==10;
        vid_cell=scan_fixed ? fixed_cell : CELL_BITS'(scan_counter/(sparse_scan ? 512 : 32));
        vid_offset=5'(scan_counter/(sparse_scan ? 16 : 1));
    end
    initial forever begin
        @(posedge clk_vid);#3;
        vid_edges++;
        assert(vid_response_valid==previous_request) else $fatal(1,"Z_CACHE_REPLY_LATENCY");
        if(previous_request) begin
            replies++;
            assert(vid_response_cell==previous_cell && vid_response_offset==previous_offset)
                else $fatal(1,"Z_CACHE_REPLY_TAG");
            if(vid_response_hit) begin
                if(proposed && int'(previous_cell)==proposed_cell &&
                   vid_response_glyph==proposed_glyph && vid_response_descriptor==proposed_descriptor) begin
                    assert(font_acks==32) else $fatal(1,"Z_CACHE_EARLY_PUBLICATION");
                    assert(vid_response_data==font(int'({proposed_glyph,previous_offset})))
                        else $fatal(1,"Z_CACHE_ATOMIC_DATA");
                    if(font_epoch==0) font_pixel_seen[{proposed_glyph,previous_offset}]=1;
                    new_seen[proposed_cell]=1;
                end else begin
                    assert(model_valid[previous_cell] &&
                        vid_response_glyph==model_glyph[previous_cell] &&
                        vid_response_descriptor==model_descriptor[previous_cell])
                        else $fatal(1,"Z_CACHE_DESCRIPTOR_OWNER");
                    assert(!new_seen[previous_cell]) else $fatal(1,"Z_CACHE_VERSION_REGRESSION");
                    assert(vid_response_data==font(int'({model_glyph[previous_cell],previous_offset})))
                        else $fatal(1,"Z_CACHE_ATOMIC_DATA");
                    if(font_epoch==0) font_pixel_seen[{model_glyph[previous_cell],previous_offset}]=1;
                end
            end else begin
                assert(!model_valid[previous_cell] || flushing) else $fatal(1,"Z_CACHE_VISIBLE_MISS");
                assert(!new_seen[previous_cell] || flushing) else $fatal(1,"Z_CACHE_VERSION_REGRESSION");
                assert(vid_response_data==0 && vid_response_glyph==0 && vid_response_descriptor==0)
                    else $fatal(1,"Z_CACHE_INVALID_INK");
            end
        end else begin
            assert(!vid_response_hit && vid_response_cell==0 && vid_response_offset==0 &&
                vid_response_data==0 && vid_response_glyph==0 && vid_response_descriptor==0)
                else $fatal(1,"Z_CACHE_IDLE_REPLY");
        end
        previous_request=vid_request;previous_cell=vid_cell;previous_offset=vid_offset;
    end
    task automatic tick;
        @(posedge clk_sys);#2;
    endtask
    task automatic wait_done;
        integer n;
        n=0;
        while(!update_done) begin tick();n++;assert(n<5000) else $fatal(1,"Z_CACHE_UPDATE_DEADLINE");end
        assert(update_done_cell==CELL_BITS'(proposed_cell) && update_done_glyph==proposed_glyph &&
            update_done_descriptor==proposed_descriptor && font_offers==32 && font_acks==32)
            else $fatal(1,"Z_CACHE_DONE_OWNER");
    endtask
    task automatic begin_update(input integer cell_number,input integer glyph_number);
        assert(!proposed && update_ready && loaded) else $fatal(1,"Z_CACHE_STIMULUS_ADMISSION");
        @(negedge clk_sys);
        proposed=1;proposed_cell=cell_number;proposed_glyph=13'(glyph_number);
        proposed_descriptor=32'h91000000^(32'(updates+invalidations+1)*32'h00010231)^32'(glyph_number);
        new_seen[cell_number]=0;font_offers=0;font_acks=0;
        fixed_cell=CELL_BITS'(cell_number);scan_fixed=1;
        update_valid=1;update_cell=CELL_BITS'(cell_number);
        update_glyph=proposed_glyph;update_descriptor=proposed_descriptor;
        tick();
        assert(!update_ready) else $fatal(1,"Z_CACHE_SECOND_ADMISSION");
        @(negedge clk_sys);update_valid=0;update_cell=~update_cell;
        update_glyph=~update_glyph;update_descriptor=~update_descriptor;
    endtask
    task automatic finish_update;
        integer n;
        wait_done();
        repeat(8) begin tick();assert(update_done && !update_ready)
            else $fatal(1,"Z_CACHE_DONE_NOT_HELD");end
        repeat(3) @(posedge clk_vid);
        @(negedge clk_vid);
        n=0;
        while(!vid_response_valid) begin
            @(negedge clk_vid);n++;assert(n<32) else $fatal(1,"Z_CACHE_SPARSE_REPLY");
        end
        assert(vid_response_valid && vid_response_hit && vid_response_cell==CELL_BITS'(proposed_cell) &&
            vid_response_descriptor==proposed_descriptor && vid_response_glyph==proposed_glyph)
            else $fatal(1,"Z_CACHE_PUBLISHED_RESULT");
        model_valid[proposed_cell]=1;model_glyph[proposed_cell]=proposed_glyph;
        model_descriptor[proposed_cell]=proposed_descriptor;new_seen[proposed_cell]=0;proposed=0;
        @(negedge clk_sys);update_done_ready=1;
        tick();
        @(negedge clk_sys);update_done_ready=0;
        assert(update_ready && !update_done) else $fatal(1,"Z_CACHE_DONE_RETIRE");
        updates++;
    endtask
    task automatic finish_invalidate(input bit held_request=1);
        integer n;
        n=0;
        while(!invalidate_done) begin tick();n++;assert(n<5000)
            else $fatal(1,"Z_CACHE_INVALIDATE_DEADLINE");end
        assert(!update_done && !update_ready && !font_read && !read_pending && !expected_ddr_read)
            else $fatal(1,"Z_CACHE_INVALIDATE_DRAIN");
        assert(!vid_response_valid || !vid_response_hit) else $fatal(1,"Z_CACHE_INVALIDATE_RETIRE");
        for(integer c=0;c<CELLS;c++) begin model_valid[c]=0;new_seen[c]=0;end
        proposed=0;
        if(held_request) repeat(8) begin tick();assert(invalidate_done && !update_ready)
            else $fatal(1,"Z_CACHE_INVALIDATE_NOT_HELD");end
        @(negedge clk_sys);invalidate=0;flushing=0;
        tick();assert(update_ready) else $fatal(1,"Z_CACHE_INVALIDATE_RELEASE");
        invalidations++;
    endtask
    task automatic start_invalidate;
        @(negedge clk_sys);invalidate=1;flushing=1;
    endtask
    task automatic upload;
        integer n;
        write_index=0;
        assert(!proposed && !font_read && !read_pending) else $fatal(1,"Z_CACHE_UPLOAD_DRAIN");
        @(negedge clk_sys);ioctl_download=1;
        tick();
        for(integer a=0;a<262144;a++) begin
            @(negedge clk_sys);ioctl_address=25'(a);ioctl_data=font(a);ioctl_wr=1;
            n=0;
            while(ioctl_wait) begin tick();n++;assert(n<100) else $fatal(1,"Z_CACHE_UPLOAD_WAIT");end
            tick();
            @(negedge clk_sys);ioctl_wr=0;
            tick();
        end
        @(negedge clk_sys);ioctl_download=0;
        n=0;
        while(upload_active) begin tick();n++;assert(n<100) else $fatal(1,"Z_CACHE_UPLOAD_COMMIT");end
        assert(loaded && !upload_error && write_index==262144) else $fatal(1,"Z_CACHE_UPLOAD");
        for(integer a=0;a<262144;a++) assert(font_memory[a]==font(a)) else $fatal(1,"Z_CACHE_WHOLE_FONT");
    endtask
    initial begin
        for(integer a=0;a<262144;a++) begin font_read_seen[a]=0;font_pixel_seen[a]=0;end
        for(integer c=0;c<CELLS;c++) begin
            model_valid[c]=0;new_seen[c]=0;model_glyph[c]=0;model_descriptor[c]=0;
        end
        repeat(32) tick();
        assert(ddr_reads==0 && ddr_writes==0) else $fatal(1,"Z_CACHE_UNLOADED");
        upload();
        begin_update(0,0);finish_update();
        begin_update(0,8191);finish_update();cases++;
        @(negedge clk_sys);force_busy=1;
        begin_update(1,4096);
        while(!(DDRAM_RD && DDRAM_BUSY)) tick();
        start_invalidate();tick();
        @(negedge clk_sys);invalidate=0; // one-edge request must remain pending
        repeat(8) tick();
        assert(!invalidate_done && font_read && font_offers==1) else $fatal(1,"Z_CACHE_BUSY_DRAIN");
        @(negedge clk_sys);force_busy=0;
        finish_invalidate(0);cases++;
        for(integer stop_at=16;stop_at<=32;stop_at+=16) begin
            begin_update(0,128+stop_at);
            while(!(font_response_ack && font_offers==stop_at)) tick();
            start_invalidate();finish_invalidate();cases++;
        end
        @(negedge clk_vid);run_vid=0;
        begin_update(CELLS-1,8190);
        while(font_acks!=32) tick();
        repeat(12) tick();
        assert(!update_done && !update_ready && !font_read) else $fatal(1,"Z_CACHE_STOPPED_VID_OWNER");
        @(negedge clk_sys);run_sys=0;
        run_vid=1;
        repeat(4) @(posedge clk_vid);
        #4;
        assert(vid_response_valid && vid_response_hit &&
            vid_response_cell==CELL_BITS'(proposed_cell) &&
            vid_response_glyph==proposed_glyph && vid_response_descriptor==proposed_descriptor)
            else $fatal(1,"Z_CACHE_COMMIT_FORWARD");
        repeat(26) @(posedge clk_vid);
        @(negedge clk_vid);run_sys=1;
        finish_update();cases++;
        @(negedge clk_vid);run_vid=0;
        start_invalidate();repeat(12) tick();
        assert(!invalidate_done) else $fatal(1,"Z_CACHE_STOPPED_INVALIDATE");
        run_vid=1;
        repeat(3) @(posedge clk_vid);
        @(negedge clk_vid);run_vid=0;
        repeat(12) tick();
        assert(!invalidate_done) else $fatal(1,"Z_CACHE_INVALIDATE_RETIRE");
        run_vid=1;
        finish_invalidate();cases++;
        for(integer k=0;k<3;k++) begin
            begin_update(k%CELLS,1000+k);finish_update();
            start_invalidate();finish_invalidate();
            scan_fixed=0;repeat(CELLS*32+4) @(posedge clk_vid);
        end
        cases++;
        for(integer pass=0;pass<4;pass++) begin
            for(integer c=0;c<CELLS;c++) begin
                begin_update(c,pass*CELLS+c);finish_update();
            end
        end
        scan_fixed=0;repeat(CELLS*32+4) @(posedge clk_vid);
        if(CELL_BITS==11) begin
            for(integer a=0;a<262144;a++) assert(font_read_seen[a] && font_pixel_seen[a])
                else $fatal(1,"Z_CACHE_PHYSICAL_COVERAGE");
        end
        cases++;
        start_invalidate();finish_invalidate();
        font_epoch=1;upload();sparse_scan=1;
        for(integer c=0;c<CELLS;c++) begin
            begin_update(c,8191-c);finish_update();
        end
        scan_fixed=0;repeat(CELLS*32*16+4) @(posedge clk_vid);
        cases++;
        assert(ddr_writes==524288 && !font_read && !read_pending && !expected_ddr_read &&
            updates==CELLS*5+6 && invalidations==8 && cases==9)
            else $fatal(1,"Z_CACHE_TERMINAL_COUNTS");
        $display("PASS Z_CACHE cells=%0d updates=%0d invalidations=%0d cases=%0d writes=%0d reads=%0d replies=%0d physical_bytes=%0d sys_half=%0d vid_half=%0d sys_edges=%0d vid_edges=%0d",
            CELLS,updates,invalidations,cases,ddr_writes,ddr_reads,replies,(CELL_BITS==11)?262144:0,SYS_HALF_PS,VID_HALF_PS,sys_edges,vid_edges);
        $finish;
    end
    initial begin #(60000000.0*SYS_HALF_PS*1ps);$fatal(1,"Z_CACHE_TEST_TIMEOUT");end
endmodule
