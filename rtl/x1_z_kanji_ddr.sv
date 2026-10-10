// SPDX-License-Identifier: GPL-2.0-only
// Original full-font MiSTer DDR command backend, not a cache or renderer.
// Address is the physical IC65/IC66 flattened 18-bit BYTE address.
// Requests transfer on valid && ready. The response (write flag and byte)
// remains held until response_ready; no second request is accepted meanwhile.
// Caller must retire/advance valid after ready accepts a request, and cancel
// its outstanding valid on reset. An old valid held through reset/drain is
// a NEW request at the next ready edge; no external-generation quarantine.
// A write response only acknowledges Avalon command acceptance, NOT physical
// persistence: this interface has no write-response/fence signal.
// Synchronous reset cancels delivery but drains a queued/issued DDR command.
// Keep clk running during reset. No CDC is implemented; all inputs are SYS.
`timescale 1ns/1ps
module x1_z_kanji_ddr #(
    parameter logic [28:0] BASE_WORD_ADDRESS = 29'h06000000
) (
    input wire clk, reset,
    input wire request_valid, request_write,
    input wire [17:0] request_address,
    input wire [7:0] request_data,
    output wire request_ready,
    output wire response_valid, response_write,
    output wire [7:0] response_data,
    input wire response_ready,
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
    localparam logic [1:0] IDLE=0, COMMAND=1, READ_WAIT=2, RESPONSE=3;
    reg [1:0] state;
    reg write_latched, cancelled;
    reg [17:0] address_latched;
    reg [7:0] data_latched, result_latched;
    initial begin
        state=IDLE;write_latched=0;cancelled=0;
        address_latched=0;data_latched=0;result_latched=0;
        assert(BASE_WORD_ADDRESS <= 29'h1fff8000)
            else $fatal(1,"Z_DDR_BASE_OVERFLOW");
    end
    assign request_ready = state==IDLE && !reset;
    assign response_valid = state==RESPONSE && !reset;
    assign response_write = write_latched;
    assign response_data = result_latched;
    assign DDRAM_CLK = clk;
    assign DDRAM_BURSTCNT = 8'd1;
    assign DDRAM_ADDR = BASE_WORD_ADDRESS + {14'd0,address_latched[17:3]};
    assign DDRAM_DIN = {8{data_latched}};
    assign DDRAM_BE = write_latched ? (8'd1 << address_latched[2:0]) : 8'hff;
    // Never withdraw even an unaccepted COMMAND under machine reset.
    assign DDRAM_RD = state==COMMAND && !write_latched;
    assign DDRAM_WE = state==COMMAND && write_latched;
    wire [7:0] read_byte = DDRAM_DOUT[{address_latched[2:0],3'b000} +: 8];
    always @(posedge clk) begin
        case(state)
            IDLE: begin
                cancelled<=0;
                if(request_valid && request_ready) begin
                    write_latched<=request_write;
                    address_latched<=request_address;
                    data_latched<=request_data;
                    state<=COMMAND;
                end
            end
            COMMAND: begin
                if(reset) cancelled<=1;
                if(!DDRAM_BUSY) begin
                    if(write_latched) begin
                        result_latched<=data_latched;
                        state <= (reset || cancelled) ? IDLE : RESPONSE;
                    end else if(DDRAM_DOUT_READY) begin
                        // Zero extra response latency is legal at acceptance.
                        result_latched<=read_byte;
                        state <= (reset || cancelled) ? IDLE : RESPONSE;
                    end else state<=READ_WAIT;
                end
            end
            READ_WAIT: begin
                if(reset) cancelled<=1;
                if(DDRAM_DOUT_READY) begin
                    result_latched<=read_byte;
                    state <= (reset || cancelled) ? IDLE : RESPONSE;
                end
            end
            RESPONSE: begin
                if(reset || response_ready) state<=IDLE;
            end
            default: state<=IDLE;
        endcase
    end
endmodule
