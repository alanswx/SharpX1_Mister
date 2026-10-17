// SPDX-License-Identifier: GPL-2.0-only
// Original standalone full-glyph cache/publication experiment.
// Not in machine.qip. No native CPU-write visibility or reset policy implied.
// SYS owns refill and the level-read/ACK font port. VID owns descriptors.
// Two 32-byte slots per cell: only the unpublished slot may be refilled.
// A held packet publishes descriptor/glyph/bank atomically; SYS cannot reuse
// either slot until the VID acknowledgement has crossed back. The packet
// and glyph data require physical bundled-data/dual-clock RAM qualification.
// invalidate is a SYS request, not a raw reset. It drains an admitted font
// read and any offered publication, then invalidates in VID. Hold it through
// invalidate_done, or pulse it and observe the eventual done. Held invalidate
// is acknowledged once. Stopped VID deliberately blocks completion/admission.
// Initial values are launch-only. No reset may clear CDC toggles mid-lease.
// VID_DESCRIPTOR_HALF_BIT=-1 preserves caller-selected row/half. With a valid
// descriptor bit selected, only vid_offset[4:1] selects the row; its low bit
// is ignored. RAM and returned offset use the SAME committed/forwarded half.
// A miss returns the requested row with half zero, plus zero data/metadata.
`timescale 1ns/1ps
module x1_z_kanji_cache #(
    parameter integer CELL_BITS=11,
    parameter integer DESCRIPTOR_WIDTH=32,
    parameter integer VID_DESCRIPTOR_HALF_BIT=-1
) (
    input wire clk_sys, clk_vid,
    input wire invalidate,
    output wire invalidate_done,
    input wire update_valid,
    output wire update_ready,
    input wire [CELL_BITS-1:0] update_cell,
    input wire [12:0] update_glyph,
    input wire [DESCRIPTOR_WIDTH-1:0] update_descriptor,
    output wire update_done,
    input wire update_done_ready,
    output wire [CELL_BITS-1:0] update_done_cell,
    output wire [12:0] update_done_glyph,
    output wire [DESCRIPTOR_WIDTH-1:0] update_done_descriptor,
    // Connect to the qualified frontend's CPU level-read/response interface.
    output wire font_read,
    output wire [17:0] font_address,
    input wire font_valid,
    input wire [7:0] font_data,
    output wire font_response_ack,
    // One request per VID edge; two sampling edges to the registered reply.
    // A miss still produces response_valid, with hit=0 and zero data/metadata.
    input wire vid_request,
    input wire [CELL_BITS-1:0] vid_cell,
    input wire [4:0] vid_offset,
    output reg vid_response_valid, vid_response_hit,
    output reg [CELL_BITS-1:0] vid_response_cell,
    output reg [4:0] vid_response_offset,
    output reg [12:0] vid_response_glyph,
    output reg [DESCRIPTOR_WIDTH-1:0] vid_response_descriptor,
    output wire [7:0] vid_response_data
);
    localparam integer CELLS=1<<CELL_BITS;
    localparam integer ENTRY_WIDTH=DESCRIPTOR_WIDTH+14;
    localparam logic [2:0] IDLE=0, READ=1, ACK=2, GAP=3,
                           PUBLISH=4, DONE=5, INVALIDATED=6;
    reg [2:0] state;
    reg flush_pending, held_flush, target_bank;
    reg [CELL_BITS-1:0] held_cell;
    reg [12:0] held_glyph;
    reg [DESCRIPTOR_WIDTH-1:0] held_descriptor;
    reg [4:0] fill_offset;
    reg [CELLS-1:0] active_bank;
    reg request_toggle, acknowledgement, request_seen, ack_pending;
    (* async_reg="true" *) reg req_meta, req_sync;
    (* async_reg="true" *) reg ack_meta, ack_sync;
    // Payload RAM is intentionally neither initialized nor reset. Validity
    // prevents unwritten data from reaching a response. Warm invalidation
    // clears explicit validity, avoiding generation-wrap resurrection.
    reg [7:0] glyph_bank0[0:CELLS*32-1];
    reg [7:0] glyph_bank1[0:CELLS*32-1];
    reg [ENTRY_WIDTH-1:0] descriptors[0:CELLS-1];
    reg [CELLS-1:0] visible;
    reg stage_request, stage_hit;
    reg [CELL_BITS-1:0] stage_cell;
    reg [4:0] stage_offset;
    reg [ENTRY_WIDTH-1:0] descriptor_read;
    reg stage_forward;
    reg [ENTRY_WIDTH-1:0] stage_forward_entry;
    wire [ENTRY_WIDTH-1:0] stage_entry=stage_forward ? stage_forward_entry : descriptor_read;
    reg [7:0] glyph_read0, glyph_read1;
    reg response_bank;
    wire [4:0] read_offset;
    generate if(VID_DESCRIPTOR_HALF_BIT>=0 && VID_DESCRIPTOR_HALF_BIT<DESCRIPTOR_WIDTH) begin : descriptor_half
        wire unused_caller_half=stage_offset[0];
        assign read_offset={stage_offset[4:1],stage_hit && stage_entry[VID_DESCRIPTOR_HALF_BIT]};
    end else begin : caller_half
        assign read_offset=stage_offset;
    end endgenerate
    wire commit_packet=req_sync!=request_seen && !ack_pending;
    initial begin
        state=IDLE;flush_pending=0;held_flush=0;target_bank=0;
        held_cell=0;held_glyph=0;held_descriptor=0;fill_offset=0;active_bank=0;
        request_toggle=0;acknowledgement=0;request_seen=0;ack_pending=0;
        req_meta=0;req_sync=0;ack_meta=0;ack_sync=0;visible=0;
        stage_request=0;stage_hit=0;stage_cell=0;stage_offset=0;
        stage_forward=0;stage_forward_entry=0;
        vid_response_valid=0;vid_response_hit=0;vid_response_cell=0;
        vid_response_offset=0;vid_response_glyph=0;vid_response_descriptor=0;response_bank=0;
        assert(CELL_BITS>=1 && CELL_BITS<=11 && DESCRIPTOR_WIDTH>=1 &&
               VID_DESCRIPTOR_HALF_BIT>=-1 && VID_DESCRIPTOR_HALF_BIT<DESCRIPTOR_WIDTH)
            else $fatal(1,"Z_CACHE_PARAMETERS");
    end
    assign update_ready=state==IDLE && !invalidate && !flush_pending;
    assign update_done=state==DONE && !invalidate && !flush_pending;
    assign invalidate_done=state==INVALIDATED;
    assign update_done_cell=held_cell;
    assign update_done_glyph=held_glyph;
    assign update_done_descriptor=held_descriptor;
    assign font_read=state==READ;
    assign font_address={held_glyph,fill_offset};
    assign font_response_ack=state==ACK;
    assign vid_response_data=vid_response_hit ? (response_bank ? glyph_read1 : glyph_read0) : 8'd0;

    // Keep payload RAM read registers unconditional too. Selecting the half
    // from descriptor RAM inside a conditional output assignment defeats
    // Quartus 17 RAM inference. These registers sample on the same edge as
    // response metadata; the bank/validity mux follows them without a cycle.
    // Uninitialized or colliding inactive-slot data is never made visible.
    always @(posedge clk_vid) begin
        glyph_read0<=glyph_bank0[{stage_cell,read_offset}];
        glyph_read1<=glyph_bank1[{stage_cell,read_offset}];
    end

    always @(posedge clk_sys) begin
        ack_meta<=acknowledgement;
        ack_sync<=ack_meta;
        if(invalidate && state!=INVALIDATED) flush_pending<=1;
        case(state)
            IDLE: begin
                if(invalidate || flush_pending) begin
                    held_flush<=1;request_toggle<=!request_toggle;state<=PUBLISH;
                end else if(update_valid && update_ready) begin
                    held_cell<=update_cell;held_glyph<=update_glyph;
                    held_descriptor<=update_descriptor;
                    target_bank<=!active_bank[update_cell];
                    fill_offset<=0;state<=READ;
                end
            end
            READ: if(font_valid) begin
                if(!invalidate && !flush_pending) begin
                    if(target_bank) glyph_bank1[{held_cell,fill_offset}]<=font_data;
                    else glyph_bank0[{held_cell,fill_offset}]<=font_data;
                end
                state<=ACK;
            end
            ACK: state<=GAP;
            GAP: begin
                if(invalidate || flush_pending) begin
                    held_flush<=1;request_toggle<=!request_toggle;state<=PUBLISH;
                end else if(fill_offset==31) begin
                    held_flush<=0;request_toggle<=!request_toggle;state<=PUBLISH;
                end else begin fill_offset<=fill_offset+5'd1;state<=READ;end
            end
            PUBLISH: if(ack_sync==request_toggle) begin
                if(held_flush) begin flush_pending<=0;state<=INVALIDATED;end
                else begin
                    active_bank[held_cell]<=target_bank;
                    if(invalidate || flush_pending) begin
                        held_flush<=1;request_toggle<=!request_toggle;
                    end else state<=DONE;
                end
            end
            DONE: begin
                if(invalidate || flush_pending) begin
                    held_flush<=1;request_toggle<=!request_toggle;state<=PUBLISH;
                end else if(update_done_ready) state<=IDLE;
            end
            INVALIDATED: begin
                flush_pending<=0;
                if(!invalidate) state<=IDLE;
            end
            default: state<=IDLE;
        endcase
    end

    always @(posedge clk_vid) begin
        req_meta<=request_toggle;
        req_sync<=req_meta;
        // Keep the RAM read register unconditional and separate from the
        // forwarding/validity mux, so Quartus can infer synchronous storage.
        // Its undefined cold/collision data is masked by stage_hit/forward.
        descriptor_read<=descriptors[vid_cell];
        // The extra edge retires the pre-invalidation reply before SYS can
        // observe invalidate_done, including when VID then stops indefinitely.
        if(ack_pending) begin acknowledgement<=request_seen;ack_pending<=0;end
        if(commit_packet) begin
            request_seen<=req_sync;ack_pending<=1;
            if(held_flush) visible<=0;
            else begin
                descriptors[held_cell]<={target_bank,held_glyph,held_descriptor};
                visible[held_cell]<=1;
            end
        end

        stage_request<=vid_request;
        stage_cell<=vid_cell;stage_offset<=vid_offset;
        stage_hit<=0;stage_forward<=0;
        if(vid_request) begin
            // Explicit collision forwarding avoids relying on an inferred
            // descriptor RAM's read-during-write mode.
            if(commit_packet && !held_flush && held_cell==vid_cell) begin
                stage_hit<=1;stage_forward<=1;
                stage_forward_entry<={target_bank,held_glyph,held_descriptor};
            end else if(!(commit_packet && held_flush) && visible[vid_cell]) begin
                stage_hit<=1;
            end
        end

        vid_response_valid<=stage_request;
        vid_response_hit<=stage_request && stage_hit;
        vid_response_cell<=stage_request ? stage_cell : {CELL_BITS{1'b0}};
        vid_response_offset<=stage_request ? read_offset : 5'd0;
        response_bank<=stage_entry[ENTRY_WIDTH-1];
        vid_response_glyph<=0;vid_response_descriptor<=0;
        if(stage_request && stage_hit) begin
            vid_response_glyph<=stage_entry[DESCRIPTOR_WIDTH+:13];
            vid_response_descriptor<=stage_entry[DESCRIPTOR_WIDTH-1:0];
        end
    end
endmodule
