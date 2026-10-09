// SPDX-License-Identifier: GPL-2.0-only
// Original normal explicit external-palette bus adapter. The documented
// selector/write/read sequence is in Techknow printed 157-159; no listing copied.
// Upstream must establish external_enabled/read_mode and safe RAM ownership.
// This is not native ASIC mode decode or beam arbitration. CPU read upper bits
// are deliberately not invented: this interface returns the component nibble.
`timescale 1ps/1ps
module x1_z_palette_access (
    input wire clk, reset,
    input wire external_enabled, read_mode, permit,
    input wire io_read, io_write,
    input wire [15:0] address,
    input wire [7:0] data,
    output wire selected, wait_n, read_valid,
    output wire [3:0] read_nibble,
    // Retained completed response for the upstream CPU's inactive I/O tail.
    // Upstream must exclude memory/IACK/new transactions before using it.
    output wire read_hold,
    output wire [3:0] read_hold_nibble,
    output wire ram_access, ram_write,
    output wire [11:0] ram_address,
    output wire [1:0] ram_component,
    output wire [3:0] ram_nibble,
    input wire ram_valid,
    input wire [3:0] ram_data
);
    typedef enum logic [2:0] {DISARMED, IDLE, REQUEST, RESPONSE, DONE} state_t;
    state_t state=DISARMED;
    reg [3:0] selector=0, response=0;
    reg [11:0] held_address=0;
    reg [1:0] held_component=0;
    reg [3:0] held_nibble=0;
    reg held_write=0, held_read=0;
    reg completed_read=0;
    wire bus_active=io_read || io_write;
    wire component_port=address[15:8]>=8'h10 && address[15:8]<=8'h12;
    // Reject illegal simultaneous read/write. IACK/DAM/decode exclusion is
    // upstream: these inputs are ordinary I/O strobes, not raw IORQ alone.
    wire decoded=external_enabled && component_port && (io_read ^ io_write)
                 && (io_write || read_mode);
    // Once acquired, neither a live mode/address change nor loss of grant
    // may release WAIT or redirect the response of the outstanding request.
    wire owned=bus_active && (state==REQUEST || state==RESPONSE ||
                             (state==DONE && held_read));
    assign selected=decoded || owned;
    assign wait_n=reset || !selected || state==DONE;
    assign read_valid=!reset && bus_active && state==DONE && held_read;
    assign read_nibble=read_valid ? response : 4'd0;
    assign read_hold=!reset && completed_read;
    assign read_hold_nibble=read_hold ? response : 4'd0;
    assign ram_access=!reset && state==REQUEST && permit && bus_active;
    assign ram_write=held_write;
    assign ram_address=held_address;
    assign ram_component=held_component;
    assign ram_nibble=held_nibble;
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            state<=DISARMED;selector<=0;response<=0;
            held_address<=0;held_component<=0;held_nibble<=0;
            held_write<=0;held_read<=0;completed_read<=0;
        end else if(!bus_active) begin
            state<=IDLE;held_read<=0;
        end else case(state)
            DISARMED: begin end // old held strobe after reset cannot replay
            IDLE: begin
                completed_read<=0;
                if(selected) begin
                    held_address<={address[7:0],io_write ? data[7:4] : selector};
                    held_component<=2'(address[15:8]-8'h10);
                    held_nibble<=data[3:0];
                    held_write<=io_write && !read_mode;
                    held_read<=io_read;
                    if(io_write) selector<=data[7:4];
                    // A dummy OUT in read mode selects an address but must
                    // never write the RAM, irrespective of its low nibble.
                    state<=io_write && read_mode ? DONE : REQUEST;
                end else state<=DONE; // ignored held bus cannot become a new access
            end
            REQUEST: if(permit) begin
                state<=held_write ? DONE : RESPONSE;
            end
            RESPONSE: if(ram_valid) begin response<=ram_data;completed_read<=1;state<=DONE;end
            DONE: begin end
            default: state<=DISARMED;
        endcase
    end
endmodule
