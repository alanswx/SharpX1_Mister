// SPDX-License-Identifier: GPL-2.0-only
// Original exact-slot/packet unit gate; synthetic response bus only.
`timescale 1ns/1ps
module x1_z_kanji_video_tb;
    bit clk_vid=0,video_reset=1;
    initial forever begin #11640ps;clk_vid=~clk_vid;end
    bit prefetch_start=0,consume_capture=0;
    bit allow_partial_ank=0;
    logic [10:0] beam_cell=0;
    logic [3:0] beam_row=0;
    wire cache_request;
    wire [10:0] cache_cell;
    wire [4:0] cache_offset;
    bit cache_response_valid=0,cache_response_hit=0;
    logic [10:0] cache_response_cell=0;
    logic [4:0] cache_response_offset=0;
    logic [12:0] cache_response_glyph=0;
    logic [31:0] cache_response_descriptor=0;
    logic [7:0] cache_response_data=0;
    wire packet_valid,packet_partial;
    wire [7:0] text_data,attr_data,kan_data,glyph_data;
    integer cases=0;
    x1_z_kanji_video dut(.*);
    task automatic tick();@(posedge clk_vid);#2;endtask
    task automatic blank();
        assert(!packet_valid && !packet_partial && {text_data,attr_data,kan_data,glyph_data}==0) else $fatal(1,"Z_VIDEO_ZERO_PACKET");
    endtask
    task automatic expected(input logic [31:0] descriptor,input logic [7:0] data_value);
        assert(descriptor[31:24]==7 && packet_valid && !packet_partial && {kan_data,attr_data,text_data}==descriptor[23:0] && glyph_data==data_value)
            else $fatal(1,"Z_VIDEO_EXACT_PACKET");
    endtask
    task automatic start(input logic [10:0] cell_value,input logic [3:0] row_value);
        @(negedge clk_vid);prefetch_start=1;consume_capture=0;beam_cell=cell_value;beam_row=row_value;
        #1;assert(cache_request && cache_cell==cell_value && cache_offset=={row_value,1'b0}) else $fatal(1,"Z_VIDEO_REQUEST");
        tick();blank();
        @(negedge clk_vid);prefetch_start=0;beam_cell=~cell_value;beam_row=~row_value;
    endtask
    task automatic reply(input logic [10:0] cell_value,input logic [3:0] row_value,input logic [31:0] descriptor,input logic [7:0] value);
        cache_response_valid=1;cache_response_hit=1;cache_response_cell=cell_value;
        cache_response_offset={row_value,descriptor[22]};cache_response_descriptor=descriptor;
        cache_response_glyph={descriptor[20:16],descriptor[7:0]};cache_response_data=value;
    endtask
    initial begin : matrix
        logic [31:0] descriptor;
        logic [7:0] value;
        tick();blank();@(negedge clk_vid);video_reset=0;
        for(integer c=0;c<2048;c++) for(integer r=0;r<16;r++) for(integer h=0;h<2;h++) begin
            descriptor={8'h07,8'(32'h80|(c%32)|(h<<6)),8'(c*13+7),8'(c*31+3)};value=8'(c*43+r*17+h*91);
            start(11'(c),4'(r));reply(11'(c),4'(r),descriptor^32'h12345,~value);
            tick();blank(); // an aligned early packet must not be consumed
            @(negedge clk_vid);reply(11'(c),4'(r),descriptor,value);tick();expected(descriptor,value);
            @(negedge clk_vid);reply(11'(c),4'(r),descriptor,~value);tick();expected(descriptor,value);
            @(negedge clk_vid);consume_capture=1;tick();expected(descriptor,value);
            @(negedge clk_vid);consume_capture=0;cache_response_valid=0;tick();expected(descriptor,value);cases++;
        end
        for(integer kind=0;kind<9;kind++) begin
            descriptor=32'h07d71b93;start(11'h7ff,4'hf);cache_response_valid=0;tick();
            @(negedge clk_vid);reply(11'h7ff,4'hf,descriptor,8'ha7);
            case(kind)
                0:cache_response_valid=0;
                1:cache_response_hit=0;
                2:cache_response_cell=11'h7fe;
                3:cache_response_offset[4:1]=0;
                4:cache_response_offset[0]=~cache_response_offset[0];
                5:cache_response_glyph^=13'h1000;
                6:cache_response_descriptor[24]=0;
                7:cache_response_descriptor[26]=0;
                8:cache_response_descriptor[31]=1;
            endcase
            tick();blank();@(negedge clk_vid);reply(11'h7ff,4'hf,descriptor,8'ha7);tick();blank();cases++;
        end
        // A capture before the fixed reply slot permanently closes that request.
        start(11'h7ff,4'hf);cache_response_valid=0;consume_capture=1;tick();blank();
        @(negedge clk_vid);consume_capture=0;reply(11'h7ff,4'hf,32'h07d71b93,8'ha7);tick();blank();cases++;
        // New same-address requests supersede pending older packets, even when
        // the older response is indistinguishable by address/tag alone.
        @(negedge clk_vid);prefetch_start=1;consume_capture=0;beam_cell=11'h7ff;beam_row=4'hf;tick();blank();
        tick();blank();@(negedge clk_vid);prefetch_start=0;reply(11'h7ff,4'hf,32'h07d71b93,8'ha7);tick();blank();
        @(negedge clk_vid);reply(11'h7ff,4'hf,32'h07d71b93,8'h59);tick();expected(32'h07d71b93,8'h59);cases++;
        // Reset clears a held packet and pending ownership. A stale reply on
        // recovery cannot populate outputs before a new request's exact slot.
        @(negedge clk_vid);video_reset=1;#2;blank();tick();blank();
        @(negedge clk_vid);video_reset=0;tick();blank();
        start(11'h7ff,4'hf);reply(11'h7ff,4'hf,32'h07d71b93,8'ha7);tick();blank();
        @(negedge clk_vid);reply(11'h7ff,4'hf,32'h07d71b93,8'h59);tick();expected(32'h07d71b93,8'h59);cases++;
        assert(cases==65548) else $fatal(1,"Z_VIDEO_CASE_LEDGER");
        $display("PASS Z_VIDEO_UNIT cases=%0d",cases);$finish;
    end
    initial begin #100ms;$fatal(1,"Z_VIDEO_UNIT_TIMEOUT");end
endmodule
