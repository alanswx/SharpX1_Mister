// SPDX-License-Identifier: GPL-2.0-only
// Original standalone lifecycle coordinator, outside machine.qip.
// pause_request may pulse or remain high through pause_done. The pause persists
// until an explicit release handshake. cold_reset_request also initiates pause
// and revokes frontend readiness only AFTER cache/arbiter/consumers drain.
// consumers_quiescent is a caller-owned SYS acknowledgement that actual CPU
// and VID consumers are held; it must remain high through upload commit.
// Gate frontend font-download START and WR with upload_permitted, including
// START itself, and expose WAIT while permission is absent. On cold loss during
// upload permission drops: end the download and preserve frontend drain service.
// host_download denotes the upstream font transaction, not the gated signal.
// No raw reset may clear this coordinator or any owned transport/CDC state.
`timescale 1ns/1ps
module x1_z_kanji_quiesce (
    input wire clk,
    input wire pause_request, cold_reset_request, release_pause,
    input wire consumers_quiescent,
    input wire loaded, upload_active, host_download,
    input wire cache_invalidate_done, arbiter_idle,
    output wire hold_consumers, cpu_enabled, cache_enabled, updates_enabled,
    output wire cpu_cancel, cache_invalidate,
    output wire frontend_cancel, frontend_cold_reset,
    output wire pause_done, upload_permitted, release_ready
);
    localparam logic [2:0] RUN=0, CACHE=1, ARBITER=2, CONSUMERS=3,
                           CANCEL=4, PAUSED=5;
    reg [2:0] state;
    reg cold_pending, cold_seen, upload_blocked;
    wire cold_start=cold_reset_request && !cold_seen;
    initial begin state=RUN;cold_pending=0;cold_seen=0;upload_blocked=0;end
    assign hold_consumers=state!=RUN || pause_request || cold_reset_request || !loaded;
    assign cpu_enabled=!hold_consumers;
    assign updates_enabled=!hold_consumers;
    assign cpu_cancel=hold_consumers;
    // Cache cancellation itself drains its admitted font read. Keep serving
    // it until its VID invalidation and last reply have been acknowledged.
    assign cache_enabled=loaded && (state==RUN || state==CACHE);
    assign cache_invalidate=state==CACHE;
    assign frontend_cancel=state==CANCEL;
    assign frontend_cold_reset=state==CANCEL && cold_pending;
    assign pause_done=state==PAUSED && !cold_pending && !cold_start && consumers_quiescent;
    assign upload_permitted=pause_done && !cold_reset_request && !upload_blocked;
    assign release_ready=pause_done && !upload_active && !host_download &&
                         !pause_request && !cold_reset_request;
    always @(posedge clk) begin
        cold_seen<=cold_reset_request;
        if(!host_download) upload_blocked<=0;
        // Restoring permission must never turn the SAME upstream transaction
        // into a fresh frontend START after cold loss aborted it.
        if(cold_start && host_download) upload_blocked<=1;
        case(state)
            RUN: if(pause_request || cold_start) state<=CACHE;
            CACHE: if(cache_invalidate_done) state<=ARBITER;
            ARBITER: if(arbiter_idle) state<=CONSUMERS;
            CONSUMERS: if(consumers_quiescent) state<=CANCEL;
            CANCEL: begin cold_pending<=0;state<=PAUSED;end
            PAUSED: if(cold_pending || cold_start) state<=CANCEL;
                else if(release_pause && release_ready) state<=RUN;
            default: state<=CACHE;
        endcase
        // New cold events win over retirement of an earlier event.
        if(cold_start) cold_pending<=1;
    end
endmodule
