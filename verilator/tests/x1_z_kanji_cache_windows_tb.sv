// SPDX-License-Identifier: GPL-2.0-only
// Observe actual cache publication/commit/ACK events; no forced DUT state.
`timescale 1ps/1ps
module x1_z_kanji_cache_windows_tb #(
    parameter integer SYS_HALF_PS=15625, VID_HALF_PS=11640
);
    bit clk_sys=0, clk_vid=0, run_sys=1, run_vid=1;
    initial forever begin #(SYS_HALF_PS); if(run_sys) clk_sys=~clk_sys; end
    initial forever begin #(VID_HALF_PS); if(run_vid) clk_vid=~clk_vid; end
    bit invalidate=0, update_valid=0, update_done_ready=0;
    bit [2:0] update_cell=0, vid_cell=0;
    bit [12:0] update_glyph=0;
    bit [31:0] update_descriptor=0;
    wire invalidate_done, update_ready, update_done;
    wire [2:0] update_done_cell;
    wire [12:0] update_done_glyph;
    wire [31:0] update_done_descriptor;
    wire font_read, font_ack;
    wire [17:0] font_address;
    bit font_valid, host_pending;
    bit [7:0] font_data;
    bit [17:0] host_address;
    integer host_delay;
    initial begin font_valid=0;host_pending=0;font_data=0;host_address=0;host_delay=0;end
    wire response_valid, response_hit;
    wire [2:0] response_cell;
    wire [4:0] response_offset;
    wire [12:0] response_glyph;
    wire [31:0] response_descriptor;
    wire [7:0] response_data;
    x1_z_kanji_cache #(.CELL_BITS(3)) dut(
        .clk_sys(clk_sys),.clk_vid(clk_vid),.invalidate(invalidate),.invalidate_done(invalidate_done),
        .update_valid(update_valid),.update_ready(update_ready),.update_cell(update_cell),
        .update_glyph(update_glyph),.update_descriptor(update_descriptor),.update_done(update_done),
        .update_done_ready(update_done_ready),.update_done_cell(update_done_cell),
        .update_done_glyph(update_done_glyph),.update_done_descriptor(update_done_descriptor),
        .font_read(font_read),.font_address(font_address),.font_valid(font_valid),.font_data(font_data),
        .font_response_ack(font_ack),.vid_request(1'b1),.vid_cell(vid_cell),.vid_offset(5'd0),
        .vid_response_valid(response_valid),.vid_response_hit(response_hit),
        .vid_response_cell(response_cell),.vid_response_offset(response_offset),
        .vid_response_glyph(response_glyph),.vid_response_descriptor(response_descriptor),
        .vid_response_data(response_data)
    );
    function automatic [7:0] pattern(input [17:0] address);
        return address[7:0]^address[15:8]^{6'd0,address[17:16]}^8'h59;
    endfunction
    // Synthetic level-response host. The cache must acknowledge every reply.
    always @(posedge clk_sys) begin
        if(!host_pending && font_read) begin
            host_pending<=1;host_address<=font_address;host_delay<=3;
        end else if(host_pending && host_delay!=0) host_delay<=host_delay-1;
        else if(host_pending && !font_valid) begin
            font_valid<=1;font_data<=pattern(host_address);
        end
        if(font_valid && font_ack) begin font_valid<=0;host_pending<=0;end
    end
    wire [49:0] bundle={dut.held_flush,dut.held_cell,dut.held_glyph,dut.held_descriptor,dut.target_bank};
    bit leased=0, previous_toggle=0, previous_ack=0, previous_done=0;
    bit published_toggle=0;
    bit [49:0] frozen_bundle=0;
    time publication_time=0, commit_time=0, ack_time=0;
    integer publications=0, commits=0, acknowledgements=0, releases=0, completions=0;
    initial forever begin
        @(posedge clk_sys);
        if(leased && dut.ack_sync==published_toggle) begin
            assert(acknowledgements>0 && $time-ack_time>=4*SYS_HALF_PS)
                else $fatal(1,"Z_CACHE_ACK_WINDOW");
            leased=0;releases++;
        end
        #1;
        if(dut.request_toggle!=previous_toggle) begin
            assert(!leased) else $fatal(1,"Z_CACHE_LEASE_REUSE");
            publication_time=$time-1;published_toggle=dut.request_toggle;
            frozen_bundle=bundle;leased=1;publications++;
        end else if(leased) begin
            assert(bundle==frozen_bundle) else $fatal(1,"Z_CACHE_HELD_BUNDLE");
        end
        if((update_done || invalidate_done) && !previous_done) begin
            assert(acknowledgements>0 && $time-1-ack_time>=4*SYS_HALF_PS)
                else $fatal(1,"Z_CACHE_ACK_WINDOW");
            completions++;
        end
        previous_toggle=dut.request_toggle;previous_done=update_done || invalidate_done;
    end
    initial forever begin
        @(posedge clk_vid);
        if(dut.commit_packet) begin
            assert(leased && publications==commits+1) else $fatal(1,"Z_CACHE_PUBLICATION_OWNER");
            assert($time-publication_time>=4*VID_HALF_PS)
                else $fatal(1,"Z_CACHE_PUBLICATION_WINDOW");
            assert(dut.req_sync==published_toggle) else $fatal(1,"Z_CACHE_PUBLICATION_OWNER");
            assert(bundle==frozen_bundle) else $fatal(1,"Z_CACHE_HELD_BUNDLE");
            commit_time=$time;commits++;
        end
        #1;
        if(dut.acknowledgement!=previous_ack) begin
            assert(commits==acknowledgements+1 && $time-1-commit_time>=2*VID_HALF_PS)
                else $fatal(1,"Z_CACHE_ACK_RETIRE_EDGE");
            ack_time=$time-1;acknowledgements++;
        end
        previous_ack=dut.acknowledgement;
    end
    task automatic tick;
        @(posedge clk_sys);#2;
    endtask
    task automatic begin_update(input integer number);
        assert(update_ready) else $fatal(1,"Z_CACHE_WINDOW_ADMISSION");
        @(negedge clk_sys);
        update_cell=3'(number);update_glyph=13'(number*503+17);
        update_descriptor=32'h81030000^32'(number*391);update_valid=1;
        tick();
        @(negedge clk_sys);update_valid=0;
        update_cell=~update_cell;update_glyph=~update_glyph;update_descriptor=~update_descriptor;
    endtask
    task automatic finish_update(input integer number);
        integer count=0;
        while(!update_done) begin tick();count++;assert(count<1000) else $fatal(1,"Z_CACHE_WINDOW_DEADLINE");end
        assert(update_done_cell==3'(number) && update_done_glyph==13'(number*503+17) &&
               update_done_descriptor==(32'h81030000^32'(number*391))) else $fatal(1,"Z_CACHE_WINDOW_DONE");
        @(negedge clk_vid);vid_cell=3'(number);
        repeat(4) @(negedge clk_vid);
        assert(response_valid && response_hit && response_cell==3'(number) && response_offset==0 &&
               response_glyph==13'(number*503+17) && response_descriptor==(32'h81030000^32'(number*391)) &&
               response_data==pattern({13'(number*503+17),5'd0})) else $fatal(1,"Z_CACHE_WINDOW_PAYLOAD");
        repeat(3) tick();
        @(negedge clk_sys);update_done_ready=1;tick();
        @(negedge clk_sys);update_done_ready=0;tick();
        assert(update_ready) else $fatal(1,"Z_CACHE_WINDOW_RETIRE");
    endtask
    task automatic flush;
        integer count=0;
        @(negedge clk_sys);invalidate=1;
        while(!invalidate_done) begin tick();count++;assert(count<1000) else $fatal(1,"Z_CACHE_WINDOW_FLUSH_DEADLINE");end
        repeat(4) tick();
        assert(!update_ready && !update_done && !font_read) else $fatal(1,"Z_CACHE_WINDOW_FLUSH_HELD");
        @(negedge clk_sys);invalidate=0;tick();
        repeat(4) @(negedge clk_vid);
        assert(update_ready && response_valid && !response_hit && response_data==0)
            else $fatal(1,"Z_CACHE_WINDOW_FLUSH_REPLY");
    endtask
    initial begin
        repeat(4) tick();
        for(integer i=0;i<16;i++) begin begin_update(i);finish_update(i);end
        @(negedge clk_vid);run_vid=0;
        begin_update(19);repeat(350) tick();
        assert(leased && !update_done && !update_ready) else $fatal(1,"Z_CACHE_WINDOW_STOPPED_VID");
        @(negedge clk_sys);run_sys=0;run_vid=1;
        repeat(8) @(negedge clk_vid);
        assert(!update_done && !update_ready && commits==17 && acknowledgements==17)
            else $fatal(1,"Z_CACHE_WINDOW_STOPPED_SYS");
        run_sys=1;finish_update(19);
        flush();
        begin_update(21);repeat(5) tick();flush();
        assert(publications==19 && commits==19 && acknowledgements==19 && releases==19 && completions==19 && !leased)
            else $fatal(1,"Z_CACHE_WINDOW_COUNTS");
        $display("PASS Z_CACHE_WINDOWS publications=%0d commits=%0d acks=%0d releases=%0d completions=%0d sys_half=%0d vid_half=%0d",
            publications,commits,acknowledgements,releases,completions,SYS_HALF_PS,VID_HALF_PS);
        $finish;
    end
    initial begin #5000000000;$fatal(1,"Z_CACHE_WINDOW_TIMEOUT");end
endmodule
