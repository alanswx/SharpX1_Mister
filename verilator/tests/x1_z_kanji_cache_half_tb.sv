// SPDX-License-Identifier: GPL-2.0-only
// Original committed-half cache fixture with real frontend/backend/mock DDR.
`timescale 1ns/1ps
module x1_z_kanji_cache_half_tb #(
    parameter integer CELL_BITS=3, DESCRIPTOR_WIDTH=32, HALF_BIT=22,
    parameter integer SYS_HALF_PS=15625, VID_HALF_PS=11640
);
    localparam integer CELLS=1<<CELL_BITS;
    localparam logic [28:0] BASE=29'h06123400;
    bit clk_sys=0,clk_vid=0,run_vid=1;
    initial forever begin #(SYS_HALF_PS*1ps);clk_sys=~clk_sys;end
    initial forever begin #(VID_HALF_PS*1ps);if(run_vid) clk_vid=~clk_vid;end
    logic invalidate=0,update_valid=0,update_done_ready=0;
    wire invalidate_done,update_ready,update_done;
    logic [CELL_BITS-1:0] update_cell=0;
    logic [12:0] update_glyph=0;
    logic [DESCRIPTOR_WIDTH-1:0] update_descriptor=0;
    wire [CELL_BITS-1:0] update_done_cell;
    wire [12:0] update_done_glyph;
    wire [DESCRIPTOR_WIDTH-1:0] update_done_descriptor;
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
    wire [DESCRIPTOR_WIDTH-1:0] vid_response_descriptor;
    wire [7:0] vid_response_data;
    x1_z_kanji_cache #(.CELL_BITS(CELL_BITS),.DESCRIPTOR_WIDTH(DESCRIPTOR_WIDTH),
        .VID_DESCRIPTOR_HALF_BIT(HALF_BIT)) dut(.*);
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
    byte unsigned memory_image[0:262143];
    bit pending=0,previous_font_read=0,expected_ddr_read=0;
    integer delay_left=0,writes=0,reads=0,font_offers=0,font_acks=0,updates=0,invalidations=0;
    logic [28:0] pending_word=BASE;
    logic [17:0] expected_font_address=0;
    longint unsigned sys_edges=0,vid_edges=0,replies=0,half_poison_witnesses=0;
    bit model_valid[0:CELLS-1],new_seen[0:CELLS-1];
    logic [12:0] model_glyph[0:CELLS-1];
    logic [DESCRIPTOR_WIDTH-1:0] model_descriptor[0:CELLS-1];
    bit proposed=0,flushing=0,scan_all=0,sparse=0;
    integer proposed_cell=0,scan=0;
    logic [12:0] proposed_glyph=0;
    logic [DESCRIPTOR_WIDTH-1:0] proposed_descriptor=0;
    logic [15:0] seen_rows=0;
    bit previous_request=0;
    logic [CELL_BITS-1:0] previous_cell=0;
    logic [4:0] previous_offset=0;
    function automatic [7:0] font(input integer address_value);
        return 8'((address_value*43)^(address_value>>7)^(address_value>>14)^8'ha7);
    endfunction
    function automatic [DESCRIPTOR_WIDTH-1:0] metadata(input integer cell_number,input integer version_number,input bit half_number);
        logic [DESCRIPTOR_WIDTH-1:0] result;
        for(integer b=0;b<DESCRIPTOR_WIDTH;b++) result[b]=1'((cell_number*13+version_number*7+b*11)>>(b%5));
        result[HALF_BIT]=half_number;
        return result;
    endfunction
    function automatic [63:0] word_at(input logic [28:0] address_value);
        integer first;
        first=(int'(address_value)-int'(BASE))*8;
        for(integer b=0;b<8;b++) word_at[b*8+:8]=memory_image[first+b];
    endfunction
    initial forever begin
        @(negedge clk_sys);#1;
        DDRAM_BUSY=sys_edges%11==0;
        DDRAM_DOUT=word_at(pending ? pending_word : DDRAM_ADDR);
        DDRAM_DOUT_READY=pending && delay_left==0;
    end
    initial forever begin
        @(posedge clk_sys);sys_edges++;
        assert(DDRAM_CLK==clk_sys && DDRAM_BURSTCNT==1 && !(DDRAM_RD&&DDRAM_WE) &&
            cpu_wait==(font_read&&!font_valid)) else $fatal(1,"Z_HALF_INTERFACE");
        if(font_read && !previous_font_read) begin
            assert(proposed && !flushing && font_offers<32 && !expected_ddr_read)
                else $fatal(1,"Z_HALF_FONT_OWNER");
            expected_font_address={proposed_glyph,5'(font_offers)};font_offers++;expected_ddr_read=1;
        end
        if(font_read) assert(font_address==expected_font_address) else $fatal(1,"Z_HALF_FONT_ADDRESS");
        previous_font_read=font_read;
        if(font_valid && font_response_ack) font_acks++;
        if(pending) begin if(DDRAM_DOUT_READY) pending=0;else if(delay_left>0) delay_left--;end
        if((DDRAM_RD||DDRAM_WE)&&!DDRAM_BUSY) begin
            if(DDRAM_WE) begin
                assert(writes<262144 && DDRAM_ADDR==BASE+29'(writes/8) &&
                    DDRAM_BE==(8'd1<<(writes%8)) && DDRAM_DIN=={8{font(writes)}})
                    else $fatal(1,"Z_HALF_UPLOAD_INTENT");
                for(integer b=0;b<8;b++) if(DDRAM_BE[b])
                    memory_image[(int'(DDRAM_ADDR)-int'(BASE))*8+b]=DDRAM_DIN[8*b+:8];
                writes++;
            end else begin
                assert(expected_ddr_read && DDRAM_ADDR==BASE+29'(expected_font_address/8) &&
                    DDRAM_BE==8'hff && !pending) else $fatal(1,"Z_HALF_DDR_INTENT");
                expected_ddr_read=0;reads++;pending=1;pending_word=DDRAM_ADDR;delay_left=3+reads%5;
            end
        end
    end
    initial forever begin
        @(negedge clk_vid);scan++;
        vid_request=!sparse || scan%8==3;
        vid_cell=scan_all ? CELL_BITS'(scan/32) : CELL_BITS'(proposed_cell);
        // Both values of the ignored caller half are exercised at every row.
        vid_offset=5'(sparse ? scan/8 : scan);
    end
    initial forever begin : video_oracle
        bit half_number;
        logic [12:0] glyph_number;
        logic [DESCRIPTOR_WIDTH-1:0] descriptor_value;
        @(posedge clk_vid);#3;vid_edges++;
        assert(vid_response_valid==previous_request) else $fatal(1,"Z_HALF_REPLY_LATENCY");
        if(previous_request) begin
            replies++;
            assert(vid_response_cell==previous_cell && vid_response_offset[4:1]==previous_offset[4:1])
                else $fatal(1,"Z_HALF_REPLY_TAG");
            if(vid_response_hit) begin
                if(proposed && int'(previous_cell)==proposed_cell &&
                    vid_response_glyph==proposed_glyph && vid_response_descriptor==proposed_descriptor) begin
                    assert(font_acks==32) else $fatal(1,"Z_HALF_EARLY_PUBLICATION");
                    glyph_number=proposed_glyph;descriptor_value=proposed_descriptor;
                    new_seen[previous_cell]=1;seen_rows[previous_offset[4:1]]=1;
                end else begin
                    assert(model_valid[previous_cell] && !new_seen[previous_cell] &&
                        vid_response_glyph==model_glyph[previous_cell] &&
                        vid_response_descriptor==model_descriptor[previous_cell])
                        else $fatal(1,"Z_HALF_DESCRIPTOR_OWNER");
                    glyph_number=model_glyph[previous_cell];descriptor_value=model_descriptor[previous_cell];
                end
                half_number=descriptor_value[HALF_BIT];
                assert(vid_response_offset[0]==half_number) else $fatal(1,"Z_HALF_COMMITTED_OFFSET");
                assert(vid_response_data==font(int'({glyph_number,previous_offset[4:1],half_number})))
                    else $fatal(1,"Z_HALF_COMMITTED_DATA");
                if(previous_offset[0]!=half_number) half_poison_witnesses++;
            end else begin
                assert(!model_valid[previous_cell] || flushing) else $fatal(1,"Z_HALF_VISIBLE_MISS");
                assert(vid_response_offset[0]==0) else $fatal(1,"Z_HALF_INVALID_HALF");
                assert(vid_response_data==0 && vid_response_glyph==0 && vid_response_descriptor==0)
                    else $fatal(1,"Z_HALF_INVALID_DATA");
            end
        end else begin
            assert(!vid_response_hit && vid_response_offset==0 && vid_response_cell==0 &&
                vid_response_data==0 && vid_response_glyph==0 && vid_response_descriptor==0)
                else $fatal(1,"Z_HALF_IDLE_REPLY");
        end
        previous_request=vid_request;previous_cell=vid_cell;previous_offset=vid_offset;
    end
    task automatic tick(input integer n=1);repeat(n) begin @(posedge clk_sys);#2;end endtask
    task automatic begin_update(input integer cell_number,input integer glyph_number,input integer version_number,input bit half_number);
        assert(update_ready && loaded && !proposed && glyph_number>=0 && glyph_number<8192)
            else $fatal(1,"Z_HALF_ADMISSION");
        @(negedge clk_sys);proposed=1;proposed_cell=cell_number;proposed_glyph=13'(glyph_number);
        proposed_descriptor=metadata(cell_number,version_number,half_number);
        new_seen[cell_number]=0;seen_rows=0;font_offers=0;font_acks=0;
        update_valid=1;update_cell=CELL_BITS'(cell_number);update_glyph=proposed_glyph;
        update_descriptor=proposed_descriptor;
        tick();@(negedge clk_sys);update_valid=0;update_cell=~update_cell;
        update_glyph=~update_glyph;update_descriptor=~update_descriptor;
    endtask
    task automatic finish_update();
        integer n=0;
        while(!update_done && n<5000) begin tick();n++;end
        assert(update_done && font_offers==32 && font_acks==32 &&
            update_done_cell==CELL_BITS'(proposed_cell) && update_done_glyph==proposed_glyph &&
            update_done_descriptor==proposed_descriptor) else $fatal(1,"Z_HALF_UPDATE_COMPLETION");
        n=0;
        while(seen_rows!=16'hffff && n<300) begin @(negedge clk_vid);n++;end
        assert(seen_rows==16'hffff && update_done && !update_ready) else $fatal(1,"Z_HALF_ROW_COVERAGE");
        model_valid[proposed_cell]=1;model_glyph[proposed_cell]=proposed_glyph;
        model_descriptor[proposed_cell]=proposed_descriptor;new_seen[proposed_cell]=0;proposed=0;
        @(negedge clk_sys);update_done_ready=1;tick();@(negedge clk_sys);update_done_ready=0;updates++;
    endtask
    initial begin
        for(integer c=0;c<CELLS;c++) begin model_valid[c]=0;model_glyph[c]=0;model_descriptor[c]=0;new_seen[c]=0;end
        tick(32);@(negedge clk_sys);ioctl_download=1;
        for(integer a=0;a<262144;a++) begin
            while(ioctl_wait) tick();
            @(negedge clk_sys);ioctl_address=25'(a);ioctl_data=font(a);ioctl_wr=1;
            tick();@(negedge clk_sys);ioctl_wr=0;
        end
        @(negedge clk_sys);ioctl_download=0;
        while(upload_active) tick();
        assert(loaded && !upload_error && writes==262144) else $fatal(1,"Z_HALF_UPLOAD_COMMIT");
        for(integer a=0;a<262144;a++) assert(memory_image[a]==font(a)) else $fatal(1,"Z_HALF_WHOLE_FONT");
        for(integer version_number=0;version_number<3;version_number++) begin
            for(integer c=0;c<CELLS;c++) begin
                begin_update(c,(c*1031+8191+(version_number==2 ? 4096 : 0))%8192,version_number,1'(version_number%2));
                finish_update();
            end
        end
        // A fourth-edge request/descriptor RAM collision must forward the
        // new half along with its new bank, glyph tag and entire descriptor.
        @(negedge clk_vid);run_vid=0;
        begin_update(CELLS-1,4095,3,1);
        while(font_acks!=32) tick();tick(12);
        assert(!update_done && !update_ready) else $fatal(1,"Z_HALF_STOPPED_PUBLICATION");
        run_vid=1;repeat(4) @(posedge clk_vid);#4;
        assert(vid_response_valid && vid_response_hit && vid_response_cell==CELL_BITS'(CELLS-1) &&
            vid_response_glyph==proposed_glyph && vid_response_descriptor==proposed_descriptor && vid_response_offset[0])
            else $fatal(1,"Z_HALF_COMMIT_FORWARD");
        finish_update();
        @(negedge clk_vid);run_vid=0;
        @(negedge clk_sys);invalidate=1;flushing=1;tick(12);
        assert(!invalidate_done) else $fatal(1,"Z_HALF_STOPPED_INVALIDATE");
        run_vid=1;
        while(!invalidate_done) tick();
        assert(!vid_response_hit) else $fatal(1,"Z_HALF_INVALIDATE_RETIRE");
        for(integer c=0;c<CELLS;c++) begin model_valid[c]=0;new_seen[c]=0;end
        @(negedge clk_sys);invalidate=0;flushing=0;tick();invalidations++;
        scan_all=1;sparse=1;repeat(CELLS*32*8+4) @(posedge clk_vid);
        assert(updates==CELLS*3+1 && reads==32*updates && writes==262144 && invalidations==1 &&
            !font_read && !pending && !expected_ddr_read && half_poison_witnesses>CELLS*16)
            else $fatal(1,"Z_HALF_FINAL_LEDGER");
        $display("PASS Z_HALF cells=%0d updates=%0d reads=%0d writes=%0d invalidations=%0d poison=%0d replies=%0d width=%0d half_bit=%0d sys_half=%0d vid_half=%0d sys_edges=%0d vid_edges=%0d",
            CELLS,updates,reads,writes,invalidations,half_poison_witnesses,replies,DESCRIPTOR_WIDTH,HALF_BIT,SYS_HALF_PS,VID_HALF_PS,sys_edges,vid_edges);
        $finish;
    end
    initial begin #500ms;$fatal(1,"Z_HALF_TEST_TIMEOUT");end
endmodule
