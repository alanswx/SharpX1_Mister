// SPDX-License-Identifier: GPL-2.0-only
// Original full-colour fetch/shifter integration. Source bit significance is
// from Techknow figs. 4-8..4-14; no emulator implementation is copied.
// Only the full 320x200/4096 layout is enabled here. Native address wrap,
// reduced modes, text/priority and palette ownership are upstream/downstream.
`timescale 1ps/1ps
module x1_z_graphics (
    input wire clk, reset, enabled,
    input wire character_start, character_load, pixel_step,
    input wire [13:0] base_address,
    output wire read_enable,
    output wire [14:0] read_address,
    input wire [7:0] blue_q, red_q, green_q,
    output wire [11:0] palette_index,
    output wire index_valid
);
    wire ready, fetched, rejected;
    wire [31:0] fetch_blue, fetch_red, fetch_green;
    reg have_data=0, character_valid=0;
    reg [31:0] blue=0, red=0, green=0;
    x1_z_gram_fetch fetch(
        .clk(clk),.reset(reset || !enabled),
        .request(enabled && character_start),.ready(ready),
        .base_address(base_address),.mode(3'd0),.screen(1'b0),.raster_odd(1'b0),
        .read_enable(read_enable),.read_address(read_address),
        .blue_q(blue_q),.red_q(red_q),.green_q(green_q),
        .valid(fetched),.rejected(rejected),
        .blue(fetch_blue),.red(fetch_red),.green(fetch_green)
    );
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            have_data<=0;character_valid<=0;blue<=0;red<=0;green<=0;
        end else if(!enabled) begin
            have_data<=0;character_valid<=0;blue<=0;red<=0;green<=0;
        end else begin
            if(character_start) begin
                have_data<=0;
                assert(ready) else $error("Z GRAM character fetch overrun");
            end
            if(fetched) have_data<=1;
            if(pixel_step) begin
                for(integer lane=0;lane<4;lane=lane+1) begin
                    blue[lane*8+:8]<=blue[lane*8+:8]<<1;
                    red[lane*8+:8]<=red[lane*8+:8]<<1;
                    green[lane*8+:8]<=green[lane*8+:8]<<1;
                end
            end
            // The same phase-14 load as the enabled digital renderer. Load
            // wins over shift. A partial startup/mode switch is invalid, never
            // a reused previous character. Completed fetch data is held stable.
            if(character_load) begin
                character_valid<=have_data;
                blue<=have_data ? fetch_blue : 32'd0;
                red<=have_data ? fetch_red : 32'd0;
                green<=have_data ? fetch_green : 32'd0;
                have_data<=0;
            end
        end
    end
    assign index_valid=enabled && character_valid && !reset;
    assign palette_index={green[31],green[23],green[15],green[7],
                          red[31],red[23],red[15],red[7],
                          blue[31],blue[23],blue[15],blue[7]};
endmodule
