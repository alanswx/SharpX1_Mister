// SPDX-License-Identifier: GPL-2.0-only
// Original default-off external-font machine service. Transport and publication
// clocks keep running through consumer reset. An accepted write drains before
// invalidation; a retained descriptor journal rebuilds the cache before release.
// The journal changes on the SAME edge as the three retained VRAM commit ports.
// No native ASIC write latency or power-on RAM contents are implied.
`timescale 1ns/1ps
module x1_z_kanji_machine (
    input wire clk_sys, clk_vid, reset_request,
    output wire machine_reset, cpu_run,
    input wire video_reset,
    input wire ioctl_download, ioctl_wr,
    input wire [7:0] ioctl_index, ioctl_data,
    input wire [24:0] ioctl_address,
    output wire ioctl_wait,
    input wire write_valid,
    input wire [2:0] write_select,
    input wire [10:0] cpu_cell,
    input wire [7:0] write_data,
    output wire write_wait_n,
    output wire [10:0] ram_address,
    output wire [7:0] ram_data,
    output wire [2:0] ram_write,
    input wire [7:0] ram_text, ram_attr, ram_kan,
    input wire cpu_font_read,
    input wire [17:0] cpu_font_address,
    output wire cpu_font_valid,
    output wire [7:0] cpu_font_data,
    output wire loaded, load_error,
    input wire prefetch_start, consume_capture,
    // VID-local permission for a base ANK packet; never an inferred RAM value.
    input wire allow_partial_ank,
    input wire [10:0] beam_cell,
    input wire [3:0] beam_row,
    output wire packet_valid,
    output wire packet_partial,
    output wire [7:0] text_data, attr_data, kan_data, glyph_data,
    output wire DDRAM_CLK,
    input wire DDRAM_BUSY,
    output wire [7:0] DDRAM_BURSTCNT,
    output wire [28:0] DDRAM_ADDR,
    input wire [63:0] DDRAM_DOUT,
    input wire DDRAM_DOUT_READY,
    output wire DDRAM_RD,
    output wire [63:0] DDRAM_DIN,
    output wire [7:0] DDRAM_BE,
    output wire DDRAM_WE
);
    localparam logic [3:0] RUN=0, DRAIN=1, INVALIDATE=2, ARBITER=3,
        PAUSED=4, REBUILD_LOAD=5, REBUILD_OFFER=6, REBUILD_WAIT=7;
    reg [3:0] state=DRAIN;
    reg retire_write=0;
    reg [10:0] rebuild_cell=0;
    reg [31:0] journal[0:2047];
    reg [31:0] journal_read;
    initial for(integer i=0;i<2048;i++) journal[i]=0;
    // No font yet: run, and the frontend answers blank glyphs (CSP and MAME
    // show blank Kanji). A rejected upload still holds the machine.
    wire pause_request=reset_request || ioctl_download || load_error;
    wire running=state==RUN && !pause_request;
    wire writer_idle, writer_wait;
    // Stop CPU enables immediately; retain its strobes until an owned write
    // commits. REPLY retirement is explicit, so stopping CPU cannot deadlock it.
    assign cpu_run=running;
    assign machine_reset=state!=RUN && (state!=DRAIN || writer_idle);
    assign write_wait_n=writer_wait;
    wire writer_valid=write_valid && !retire_write;
    wire writer_update, writer_ready, writer_done_ready;
    wire [10:0] writer_cell, done_cell;
    wire [12:0] writer_glyph, done_glyph;
    wire [31:0] writer_descriptor, done_descriptor;
    wire update_done, update_ready;
    wire rebuilding=state==REBUILD_LOAD || state==REBUILD_OFFER || state==REBUILD_WAIT;
    x1_z_kanji_vram_write writer (
        .clk(clk_sys), .admit_enable(running), .write_valid(writer_valid),
        .write_select(write_select), .write_cell(cpu_cell), .write_data(write_data),
        .wait_n(writer_wait), .idle(writer_idle), .write_accepted(),
        .ram_address(ram_address), .ram_data(ram_data), .ram_write(ram_write),
        .ram_text(ram_text), .ram_attr(ram_attr), .ram_kan(ram_kan),
        .update_valid(writer_update), .update_ready(writer_ready),
        .update_cell(writer_cell), .update_glyph(writer_glyph), .update_descriptor(writer_descriptor),
        .update_done(update_done && !rebuilding), .update_done_ready(writer_done_ready),
        .update_done_cell(done_cell), .update_done_glyph(done_glyph), .update_done_descriptor(done_descriptor)
    );
    assign writer_ready=update_ready && !rebuilding;
    wire invalidate_done;
    wire cache_read, cache_valid, cache_ack;
    wire [17:0] cache_address;
    wire [7:0] cache_data;
    wire vid_request, vid_valid, vid_hit;
    wire [10:0] vid_cell, response_cell;
    wire [4:0] vid_offset, response_offset;
    wire [12:0] response_glyph;
    wire [31:0] response_descriptor;
    wire [7:0] response_data;
    // Rebuild partial text/attribute publications too, retaining mask 03.
    // Video mode qualification belongs to the VID consumer, not this journal.
    wire rebuild_known=journal_read[31:24]==8'h07 ||
        (journal_read[31:24]==8'h03 && journal_read[23:16]==8'd0);
    x1_z_kanji_cache #(.VID_DESCRIPTOR_HALF_BIT(22)) cache (
        .clk_sys(clk_sys), .clk_vid(clk_vid), .invalidate(state==INVALIDATE), .invalidate_done(invalidate_done),
        .update_valid(rebuilding ? state==REBUILD_OFFER && rebuild_known && !pause_request : writer_update),
        .update_ready(update_ready), .update_cell(rebuilding ? rebuild_cell : writer_cell),
        .update_glyph(rebuilding ? {journal_read[20:16],journal_read[7:0]} : writer_glyph),
        .update_descriptor(rebuilding ? journal_read : writer_descriptor),
        .update_done(update_done), .update_done_ready(rebuilding ? state==REBUILD_WAIT : writer_done_ready),
        .update_done_cell(done_cell), .update_done_glyph(done_glyph), .update_done_descriptor(done_descriptor),
        .font_read(cache_read), .font_address(cache_address), .font_valid(cache_valid),
        .font_data(cache_data), .font_response_ack(cache_ack),
        .vid_request(vid_request), .vid_cell(vid_cell), .vid_offset(vid_offset),
        .vid_response_valid(vid_valid), .vid_response_hit(vid_hit), .vid_response_cell(response_cell),
        .vid_response_offset(response_offset), .vid_response_glyph(response_glyph),
        .vid_response_descriptor(response_descriptor), .vid_response_data(response_data)
    );
    wire arbiter_idle, font_read, font_valid, font_ack;
    wire [17:0] font_address;
    wire [7:0] font_data;
    wire pcg_read, pcg_ack, pcg_valid;
    wire [17:0] pcg_address;
    wire [7:0] pcg_data;
    x1_z_kanji_cpu_port cpu_port (
        .pcg_read(cpu_font_read), .pcg_address(cpu_font_address),
        .pcg_valid(cpu_font_valid), .pcg_data(cpu_font_data),
        .cpu_cancel(!running), .cpu_read(pcg_read), .cpu_address(pcg_address),
        .cpu_valid(pcg_valid), .cpu_data(pcg_data), .cpu_response_ack(pcg_ack)
    );
    x1_z_kanji_arbiter arbiter (
        .clk(clk_sys), .cpu_enabled(running),
        .cache_enabled(!load_error && state!=ARBITER && state!=PAUSED), .cpu_cancel(!running),
        .cpu_read(pcg_read), .cpu_address(pcg_address), .cpu_wait(), .cpu_valid(pcg_valid),
        .cpu_data(pcg_data), .cpu_response_ack(pcg_ack),
        .cache_read(cache_read), .cache_address(cache_address), .cache_valid(cache_valid),
        .cache_data(cache_data), .cache_response_ack(cache_ack), .idle(arbiter_idle),
        .font_read(font_read), .font_address(font_address), .font_valid(font_valid),
        .font_data(font_data), .font_response_ack(font_ack)
    );
    wire frontend_wait, upload_active;
    // 0x30000000..0x3003ffff: private experimental core backing region.
    // Framework scaler starts at 0x20000000; framebuffer feature is disabled.
    x1_z_kanji_frontend #(.BLANK_WHEN_UNLOADED(1)) frontend (
        .clk(clk_sys), .cold_reset(1'b0), .consumer_cancel(state==ARBITER && arbiter_idle),
        .cpu_read(font_read), .cpu_address(font_address), .cpu_wait(),
        .cpu_valid(font_valid), .cpu_data(font_data), .cpu_response_ack(font_ack),
        .ioctl_download(ioctl_download && ioctl_index==8'd5 && state==PAUSED),
        .ioctl_index(ioctl_index), .ioctl_address(ioctl_address), .ioctl_wr(ioctl_wr),
        .ioctl_data(ioctl_data), .ioctl_wait(frontend_wait), .upload_permitted(state==PAUSED),
        .loaded(loaded), .upload_error(load_error), .upload_active(upload_active),
        .DDRAM_CLK(DDRAM_CLK), .DDRAM_BUSY(DDRAM_BUSY), .DDRAM_BURSTCNT(DDRAM_BURSTCNT),
        .DDRAM_ADDR(DDRAM_ADDR), .DDRAM_DOUT(DDRAM_DOUT), .DDRAM_DOUT_READY(DDRAM_DOUT_READY),
        .DDRAM_RD(DDRAM_RD), .DDRAM_DIN(DDRAM_DIN), .DDRAM_BE(DDRAM_BE), .DDRAM_WE(DDRAM_WE)
    );
    assign ioctl_wait=ioctl_download && (state!=PAUSED || (ioctl_index==8'd5 && frontend_wait));
    x1_z_kanji_video #(.ALLOW_PARTIAL_ANK(1)) video_packet (
        .clk_vid(clk_vid), .video_reset(video_reset), .prefetch_start(prefetch_start),
        .consume_capture(consume_capture), .beam_cell(beam_cell), .beam_row(beam_row),
        .allow_partial_ank(allow_partial_ank),
        .cache_request(vid_request), .cache_cell(vid_cell), .cache_offset(vid_offset),
        .cache_response_valid(vid_valid), .cache_response_hit(vid_hit),
        .cache_response_cell(response_cell), .cache_response_offset(response_offset),
        .cache_response_glyph(response_glyph), .cache_response_descriptor(response_descriptor),
        .cache_response_data(response_data), .packet_valid(packet_valid),
        .packet_partial(packet_partial),
        .text_data(text_data), .attr_data(attr_data), .kan_data(kan_data), .glyph_data(glyph_data)
    );
    always @(posedge clk_sys) begin
        journal_read<=journal[rebuild_cell];
        if(|ram_write) journal[writer_cell]<=writer_descriptor;
        if(!write_valid) retire_write<=0;
        else if(state==DRAIN && writer_wait) retire_write<=1;
        case(state)
            RUN: if(pause_request) state<=DRAIN;
            DRAIN: if(writer_idle) state<=INVALIDATE;
            INVALIDATE: if(invalidate_done) state<=ARBITER;
            ARBITER: if(arbiter_idle) state<=PAUSED;
            PAUSED: if(!reset_request && !ioctl_download && !upload_active && !load_error) begin
                rebuild_cell<=0;state<=REBUILD_LOAD;
            end
            REBUILD_LOAD: state<=pause_request ? DRAIN : REBUILD_OFFER;
            REBUILD_OFFER: if(pause_request) state<=DRAIN;
                else if(!rebuild_known) begin
                    if(rebuild_cell==11'd2047) state<=RUN;
                    else begin rebuild_cell<=rebuild_cell+11'd1;state<=REBUILD_LOAD;end
                end else if(update_ready) state<=REBUILD_WAIT;
            REBUILD_WAIT: if(update_done) begin
                assert(done_cell==rebuild_cell && done_descriptor==journal_read &&
                    done_glyph=={journal_read[20:16],journal_read[7:0]})
                    else $fatal(1,"Z_MACHINE_REBUILD_OWNER");
                if(pause_request) state<=DRAIN;
                else if(rebuild_cell==11'd2047) state<=RUN;
                else begin rebuild_cell<=rebuild_cell+11'd1;state<=REBUILD_LOAD;end
            end
            default: state<=DRAIN;
        endcase
    end
endmodule
