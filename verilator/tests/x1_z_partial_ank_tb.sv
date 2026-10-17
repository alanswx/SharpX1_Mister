// SPDX-License-Identifier: GPL-2.0-only
// Exact-slot base ANK policy: known masks, tags, request permission and revocation.
`timescale 1ns/1ps
module x1_z_partial_ank_tb;
    bit clk_vid=0,video_reset=1,prefetch_start=0,consume_capture=0,allow_partial_ank=0;
    initial forever begin #11640ps;clk_vid=~clk_vid;end
    logic [10:0] beam_cell=0,cache_response_cell=0;
    logic [3:0] beam_row=0;
    logic [4:0] cache_response_offset=0;
    logic [12:0] cache_response_glyph=0;
    logic [31:0] cache_response_descriptor=0;
    logic [7:0] cache_response_data=0;
    bit cache_response_valid=0,cache_response_hit=0;
    wire cache_request,packet_valid,packet_partial;
    wire [10:0] cache_cell;
    wire [4:0] cache_offset;
    wire [7:0] text_data,attr_data,kan_data,glyph_data;
    integer cases=0;
    x1_z_kanji_video #(.ALLOW_PARTIAL_ANK(1)) dut(.*);
    task automatic tick;@(posedge clk_vid);#2;endtask
    task automatic blank;
        assert(!packet_valid && !packet_partial && {text_data,attr_data,kan_data,glyph_data}==0)
            else $fatal(1,"PARTIAL_ANK_BLANK");
    endtask
    task automatic start(input bit permission);
        @(negedge clk_vid);prefetch_start=1;consume_capture=0;allow_partial_ank=permission;
        beam_cell=11'h7ff;beam_row=4'hd;cache_response_valid=0;
        #1;assert(cache_request && cache_cell==11'h7ff && cache_offset=={4'hd,1'b0})
            else $fatal(1,"PARTIAL_ANK_REQUEST");
        tick();blank();
        @(negedge clk_vid);prefetch_start=0;beam_cell=0;beam_row=0;tick();blank();
        @(negedge clk_vid);
    endtask
    task automatic reply(input logic [31:0] descriptor);
        cache_response_valid=1;cache_response_hit=1;cache_response_cell=11'h7ff;
        cache_response_descriptor=descriptor;cache_response_offset={4'hd,descriptor[22]};
        cache_response_glyph={descriptor[20:16],descriptor[7:0]};cache_response_data=8'ha5;
    endtask
    task automatic expect_packet(input logic [31:0] descriptor,input bit partial);
        assert(descriptor[31:24]==(partial ? 8'h03 : 8'h07) && packet_valid && packet_partial==partial && {kan_data,attr_data,text_data}==descriptor[23:0] &&
            glyph_data==(partial ? 8'd0 : 8'ha5)) else $fatal(1,"PARTIAL_ANK_PACKET");
    endtask
    initial begin
        tick();blank();@(negedge clk_vid);video_reset=0;
        for(integer mask=0;mask<256;mask++) begin
            start(1);reply({8'(mask),8'd0,8'h1f,8'h41});tick();
            if(mask==3 || mask==7) expect_packet({8'(mask),8'd0,8'h1f,8'h41},mask==3);
            else blank();cases++;
        end
        // A zero mask for the unknown byte is part of the partial contract.
        for(integer kan=1;kan<256;kan++) begin
            start(1);reply({8'h03,8'(kan),8'h0f,8'h42});tick();blank();cases++;
            start(1);reply({8'h07,8'(kan),8'h0f,8'h42});tick();
            expect_packet({8'h07,8'(kan),8'h0f,8'h42},0);cases++;
        end
        // Request and reply must both permit the partial interpretation.
        start(0);allow_partial_ank=1;reply(32'h03000f41);tick();blank();cases++;
        start(1);allow_partial_ank=0;reply(32'h03000f41);tick();blank();cases++;
        start(0);reply(32'h07000f41);tick();expect_packet(32'h07000f41,0);cases++;
        // A later mode change revokes a held packet, including at capture.
        for(integer capture=0;capture<2;capture++) begin
            start(1);reply(32'h03000f41);tick();expect_packet(32'h03000f41,1);
            @(negedge clk_vid);consume_capture=1'(capture);allow_partial_ank=0;tick();blank();
            @(negedge clk_vid);consume_capture=0;allow_partial_ank=1;tick();blank();cases++;
        end
        for(integer fault=0;fault<6;fault++) begin
            start(1);reply(32'h03000f41);
            case(fault)
                0:cache_response_valid=0;
                1:cache_response_hit=0;
                2:cache_response_cell=0;
                3:cache_response_offset[4:1]=0;
                4:cache_response_offset[0]=1;
                5:cache_response_glyph^=13'h1000;
            endcase
            tick();blank();cases++;
        end
        start(1);reply(32'h03000f41);tick();expect_packet(32'h03000f41,1);
        @(negedge clk_vid);video_reset=1;#2;blank();tick();blank();
        @(negedge clk_vid);video_reset=0;tick();blank();cases++;
        assert(cases==778) else $fatal(1,"PARTIAL_ANK_LEDGER");
        $display("PASS PARTIAL_ANK cases=%0d",cases);$finish;
    end
    initial begin #10ms;$fatal(1,"PARTIAL_ANK_TIMEOUT");end
endmodule
