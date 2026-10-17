// SPDX-License-Identifier: GPL-2.0-only
// Original standalone CPU/ordered-upload frontend. No display cache or CDC.
// All signals are SYS synchronous; memory clock MUST continue during resets.
// CPU level requests and ioctl_wr must retire after acceptance; both require
// a SYS-observed low before another capture. Held wr while wait is legal.
// Response ACK likewise requires a SYS-observed low after use/cancellation;
// a stale high ACK cannot retire the next response owner.
// upload_permitted is a CALLER guarantee that CPU and VID are held reset.
// Permission and index 5 must remain asserted THROUGH commit (upload_active
// falling); download may end while the final backend command drains.
// Download rising under cold_reset, or index changing to 5 mid-download,
// is rejected with upload_error; download must go low before a fresh retry.
// Backend write responses mean command acceptance, NOT physical persistence.
`timescale 1ns/1ps
module x1_z_kanji_frontend #(
    parameter logic [28:0] BASE_WORD_ADDRESS=29'h06000000
) (
    input wire clk, cold_reset, consumer_cancel,
    input wire cpu_read,
    input wire [17:0] cpu_address,
    output wire cpu_wait, cpu_valid,
    output wire [7:0] cpu_data,
    input wire cpu_response_ack,
    input wire ioctl_download,
    input wire [7:0] ioctl_index,
    input wire [24:0] ioctl_address,
    input wire ioctl_wr,
    input wire [7:0] ioctl_data,
    output wire ioctl_wait,
    input wire upload_permitted,
    output reg loaded, upload_error, upload_active,
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
    localparam logic [1:0] IDLE=0, SEND=1, RETURN=2, CPU_HELD=3;
    reg [1:0] state;
    reg cpu_armed, ack_armed, wr_armed, download_seen;
    reg owner_write, discard;
    reg [17:0] address_latched;
    reg [7:0] data_latched, cpu_result;
    reg [18:0] upload_count;
    initial begin
        loaded=0;upload_error=0;upload_active=0;state=IDLE;
        cpu_armed=1;ack_armed=1;wr_armed=1;download_seen=0;owner_write=0;discard=0;
        address_latched=0;data_latched=0;cpu_result=0;upload_count=0;
    end
    wire start_upload=ioctl_download && ioctl_index==8'd5 &&
                      !download_seen && !upload_active;
    wire abort_upload=upload_active &&
        (!upload_permitted || ioctl_index!=8'd5 ||
         (!ioctl_download && upload_count!=19'd262144));
    wire cancel_cpu=cold_reset || consumer_cancel || start_upload;
    wire request_ready, response_valid, response_write;
    wire [7:0] response_data;
    wire request_valid=state==SEND;
    wire response_ready=state==RETURN;
    // Never tie this reset to core_reset. Frontend keeps ownership and drains
    // every staged command, discarding cancelled results itself.
    x1_z_kanji_ddr #(.BASE_WORD_ADDRESS(BASE_WORD_ADDRESS)) backend (
        .clk(clk), .reset(1'b0), .request_valid(request_valid),
        .request_write(owner_write), .request_address(address_latched),
        .request_data(data_latched), .request_ready(request_ready),
        .response_valid(response_valid), .response_write(response_write),
        .response_data(response_data), .response_ready(response_ready),
        .DDRAM_CLK(DDRAM_CLK), .DDRAM_BUSY(DDRAM_BUSY),
        .DDRAM_BURSTCNT(DDRAM_BURSTCNT), .DDRAM_ADDR(DDRAM_ADDR),
        .DDRAM_DOUT(DDRAM_DOUT), .DDRAM_DOUT_READY(DDRAM_DOUT_READY),
        .DDRAM_RD(DDRAM_RD), .DDRAM_DIN(DDRAM_DIN),
        .DDRAM_BE(DDRAM_BE), .DDRAM_WE(DDRAM_WE)
    );
    assign cpu_valid=state==CPU_HELD && !cancel_cpu && !upload_active;
    assign cpu_data=cpu_result;
    assign cpu_wait=cpu_read && !cpu_valid;
    assign ioctl_wait=ioctl_download && ioctl_index==8'd5 &&
        (!upload_active || state!=IDLE || !wr_armed ||
         !upload_permitted || cold_reset);
    // Main waits for the last SPI ACK to fall before sending FILE_TX=0.
    // WAIT must therefore release after the final backend command drains.
    // Error is a write-admission guard, not transport backpressure: Main must
    // retire rejected bytes and send FILE_TX=0 before a complete retry. Keep
    // draining any previously accepted backend owner before releasing ACK.
    // Reject an extra WR separately; never wrap its address into font byte 0.
    wire take_upload=ioctl_download && ioctl_index==8'd5 && ioctl_wr && !ioctl_wait &&
                     !upload_error && upload_count<19'd262144;
    always @(posedge clk) begin
        download_seen<=ioctl_download;
        if(!cpu_read) cpu_armed<=1;
        if(!cpu_response_ack) ack_armed<=1;
        if(cancel_cpu) ack_armed<=0;
        if(!ioctl_wr) wr_armed<=1;
        if(cancel_cpu && cpu_read) cpu_armed<=0;
        if(cancel_cpu && !owner_write && (state==SEND || state==RETURN)) discard<=1;
        if(cold_reset) begin
            loaded<=0;
            if(upload_active) upload_error<=1;
        end
        if(ioctl_download && ioctl_index==8'd5 && !upload_active &&
           (cold_reset || !start_upload)) begin
            loaded<=0; upload_error<=1;
        end
        if(start_upload && !cold_reset) begin
            loaded<=0; upload_active<=1; upload_count<=0;
            upload_error<=!upload_permitted;
        end
        if(abort_upload) upload_error<=1;
        if(upload_active && upload_count==19'd262144 && ioctl_download &&
           ioctl_index==8'd5 && ioctl_wr && wr_armed) upload_error<=1;
        case(state)
            IDLE: begin
                if(take_upload) begin
                    wr_armed<=0;
                    if(ioctl_address!={6'd0,upload_count}) upload_error<=1;
                    else begin
                        owner_write<=1; discard<=0;
                        address_latched<=ioctl_address[17:0]; data_latched<=ioctl_data;
                        upload_count<=upload_count+19'd1; state<=SEND;
                    end
                end else if(cpu_read && cpu_armed && loaded && !upload_active && !cancel_cpu) begin
                    cpu_armed<=0; owner_write<=0; discard<=0;
                    address_latched<=cpu_address; data_latched<=0; state<=SEND;
                end
                if(upload_active && !ioctl_download) begin
                    upload_active<=0;
                    if(!upload_error && !abort_upload && !cold_reset) loaded<=1;
                end
            end
            SEND: if(request_ready) state<=RETURN;
            RETURN: if(response_valid) begin
                assert(response_write==owner_write)
                    else $fatal(1,"Z_FRONTEND_BACKEND_OWNER");
                if(owner_write || discard || cancel_cpu) state<=IDLE;
                else begin cpu_result<=response_data; state<=CPU_HELD; end
            end
            CPU_HELD: if(cancel_cpu || (cpu_response_ack && ack_armed)) begin
                state<=IDLE;
                ack_armed<=0;
            end
            default: state<=IDLE;
        endcase
    end
endmodule
