// SPDX-License-Identifier: GPL-2.0-only
// Original standalone SYS font-port arbiter. Outside machine.qip.
// Each client uses a level request with an observed-low rearm and a held
// response with an independently observed-low ACK rearm. Address is captured
// at admission. Clients must not infer admission from read or WAIT alone.
// Round robin bounds contention by completed transactions, not clock cycles:
// DDR stalls and a client's held response may stall both clients indefinitely.
// Admission controls never cancel an owner. cpu_cancel suppresses CPU delivery
// and drains that owner's real response/ACK; cache ownership is never cancelled.
// For font replacement: block CPU/update admission, invalidate the cache while
// keeping cache_enabled asserted, then disable cache admission after its done,
// wait for idle, and only then cancel/reset/upload through the frontend.
// No raw reset: ownership and ACK state must survive machine reset requests.
`timescale 1ns/1ps
module x1_z_kanji_arbiter (
    input wire clk,
    input wire cpu_enabled, cache_enabled, cpu_cancel,
    input wire cpu_read,
    input wire [17:0] cpu_address,
    output wire cpu_wait, cpu_valid,
    output wire [7:0] cpu_data,
    input wire cpu_response_ack,
    input wire cache_read,
    input wire [17:0] cache_address,
    output wire cache_valid,
    output wire [7:0] cache_data,
    input wire cache_response_ack,
    output wire idle,
    output wire font_read,
    output wire [17:0] font_address,
    input wire font_valid,
    input wire [7:0] font_data,
    output wire font_response_ack
);
    localparam logic [2:0] IDLE=0, READ=1, HELD=2, ACK=3, GAP=4;
    reg [2:0] state;
    reg owner_cache, prefer_cache, discard_cpu;
    reg cpu_armed, cache_armed, cpu_ack_armed, cache_ack_armed;
    reg [17:0] held_address;
    reg [7:0] held_data;
    wire cpu_eligible=cpu_enabled && cpu_read && cpu_armed && !cpu_cancel;
    wire cache_eligible=cache_enabled && cache_read && cache_armed;
    wire choose_cache=cache_eligible && (!cpu_eligible || prefer_cache);
    initial begin
        state=IDLE;owner_cache=0;prefer_cache=0;discard_cpu=0;
        cpu_armed=1;cache_armed=1;cpu_ack_armed=0;cache_ack_armed=0;
        held_address=0;held_data=0;
    end
    assign idle=state==IDLE;
    assign font_read=state==READ || state==HELD || state==ACK;
    assign font_address=held_address;
    assign font_response_ack=state==ACK;
    assign cpu_valid=state==HELD && !owner_cache && !cpu_cancel && !discard_cpu;
    assign cache_valid=state==HELD && owner_cache;
    assign cpu_data=cpu_valid ? held_data : 8'd0;
    assign cache_data=cache_valid ? held_data : 8'd0;
    assign cpu_wait=cpu_read && !cpu_valid;
    always @(posedge clk) begin
        if(!cpu_read) cpu_armed<=1;
        if(!cache_read) cache_armed<=1;
        if(!cpu_response_ack) cpu_ack_armed<=1;
        if(!cache_response_ack) cache_ack_armed<=1;
        if(cpu_cancel) begin
            if(cpu_read) cpu_armed<=0;
            cpu_ack_armed<=0;
            if(!owner_cache && state!=IDLE) discard_cpu<=1;
        end
        case(state)
            IDLE: if(cpu_eligible || cache_eligible) begin
                owner_cache<=choose_cache;prefer_cache<=!choose_cache;
                held_address<=choose_cache ? cache_address : cpu_address;
                discard_cpu<=0;
                if(choose_cache) cache_armed<=0;else cpu_armed<=0;
                state<=READ;
            end
            READ: if(font_valid) begin
                held_data<=font_data;
                if(!owner_cache && (discard_cpu || cpu_cancel)) state<=ACK;
                else state<=HELD;
            end
            HELD: if(owner_cache ? (cache_response_ack && cache_ack_armed) :
                (cpu_cancel || discard_cpu || (cpu_response_ack && cpu_ack_armed))) begin
                if(owner_cache) cache_ack_armed<=0;else cpu_ack_armed<=0;
                state<=ACK;
            end
            ACK: state<=GAP;
            GAP: state<=IDLE;
            default: state<=IDLE;
        endcase
    end
endmodule
