// SPDX-License-Identifier: GPL-2.0-only
// Original standalone committed-cache packet adapter for x1_vid.
// Outside machine.qip. Prefetch at actual phase 0, capture at actual phase 10;
// hold metadata and glyph through phase-14 LOAD. Only video-local reset here.
// The cache has two sampling edges to its registered response; this consumer
// samples that reply on the third edge (two edges AFTER prefetch admission).
// A reply outside that exact slot, or at/after capture, cannot replace bytes.
// A new prefetch clears old output and supersedes any unfinished request.
// Descriptor contract is the writer's {5'b0,known[kan,attr,text],kan,attr,text}.
// Default: all metadata must be known. The machine may separately opt into
// base ANK packets with committed text/attributes and an UNKNOWN Kanji byte.
// That path requires caller permission at request/reply and throughout hold;
// it never returns a Kanji glyph or changes the descriptor's known bits.
// Returned cell/row/half/tag must agree. Missing/inconsistent packets are zero.
// No ANK/PCG lookup, raster eligibility, ASIC timing or reset lifecycle here.
`timescale 1ns/1ps
module x1_z_kanji_video #(parameter integer CELL_BITS=11, parameter bit ALLOW_PARTIAL_ANK=0) (
    input wire clk_vid, video_reset,
    input wire prefetch_start, consume_capture,
    input wire allow_partial_ank,
    input wire [CELL_BITS-1:0] beam_cell,
    input wire [3:0] beam_row,
    output wire cache_request,
    output wire [CELL_BITS-1:0] cache_cell,
    output wire [4:0] cache_offset,
    input wire cache_response_valid, cache_response_hit,
    input wire [CELL_BITS-1:0] cache_response_cell,
    input wire [4:0] cache_response_offset,
    input wire [12:0] cache_response_glyph,
    input wire [31:0] cache_response_descriptor,
    input wire [7:0] cache_response_data,
    output reg packet_valid,
    output reg packet_partial,
    output wire [7:0] text_data, attr_data, kan_data,
    output reg [7:0] glyph_data
);
    reg due_1, due_2, window_open;
    reg [CELL_BITS-1:0] held_cell;
    reg [3:0] held_row;
    reg [23:0] packet_metadata;
    reg held_partial_allowed;
    wire aligned=cache_response_cell==held_cell &&
        cache_response_offset=={held_row,cache_response_descriptor[22]} &&
        cache_response_glyph=={cache_response_descriptor[20:16],cache_response_descriptor[7:0]};
    wire known=cache_response_descriptor[31:24]==8'h07;
    wire partial_known=ALLOW_PARTIAL_ANK && held_partial_allowed && allow_partial_ank &&
        cache_response_descriptor[31:24]==8'h03 && cache_response_descriptor[23:16]==8'd0;
    initial begin
        assert(CELL_BITS>=1 && CELL_BITS<=11) else $fatal(1,"Z_VIDEO_PARAMETERS");
        due_1=0;due_2=0;window_open=0;held_cell=0;held_row=0;
        packet_metadata=0;packet_valid=0;glyph_data=0;
        packet_partial=0;held_partial_allowed=0;
    end
    assign cache_request=prefetch_start && !consume_capture && !video_reset;
    assign cache_cell=beam_cell;
    assign cache_offset={beam_row,1'b0}; // half comes from the cache descriptor
    assign {kan_data,attr_data,text_data}=packet_metadata;
    always @(posedge clk_vid or posedge video_reset) begin
        if(video_reset) begin
            due_1<=0;due_2<=0;window_open<=0;held_cell<=0;held_row<=0;
            packet_partial<=0;held_partial_allowed<=0;
            packet_metadata<=0;packet_valid<=0;glyph_data<=0;
        end else begin
            // A mode transition revokes this packet until the next request.
            // The renderer also checks permission at its later glyph LOAD.
            if(packet_partial && !allow_partial_ank) begin
                packet_metadata<=0;packet_valid<=0;glyph_data<=0;packet_partial<=0;
            end
            due_1<=cache_request;due_2<=due_1;
            if(prefetch_start) begin
                held_cell<=beam_cell;held_row<=beam_row;
                held_partial_allowed<=ALLOW_PARTIAL_ANK && allow_partial_ank;
                due_2<=0;window_open<=!consume_capture;
                packet_metadata<=0;packet_valid<=0;glyph_data<=0;
                packet_partial<=0;
            end else if(consume_capture) window_open<=0;
            else if(due_2 && window_open) begin
                window_open<=0;
                if(cache_response_valid && cache_response_hit && aligned && (known || partial_known)) begin
                    packet_metadata<=cache_response_descriptor[23:0];
                    glyph_data<=known ? cache_response_data : 8'd0;packet_valid<=1;
                    packet_partial<=!known;
                end
            end
        end
    end
endmodule
