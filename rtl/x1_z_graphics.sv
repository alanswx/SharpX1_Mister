// SPDX-License-Identifier: GPL-2.0-only
// Original full-colour fetch/shifter integration. Source bit significance is
// from Techknow figs. 4-8..4-14; no emulator implementation is copied.
// Layout IDs match x1_z_gram_fetch. Mode 4 still requires an internal palette
// downstream; reduced external expansion is an explicit experimental policy.
`timescale 1ps/1ps
module x1_z_graphics (
    input wire clk, reset, enabled,
    input wire character_start, character_load, pixel_step,
    input wire [13:0] base_address,
    input wire [2:0] mode,
    input wire screen, raster_odd,
    output wire read_enable,
    output wire [14:0] read_address,
    input wire [7:0] blue_q, red_q, green_q,
    output wire [11:0] palette_index,
    output wire index_valid,
    output wire internal_palette,
    // Mode 5 keeps the two screens separate; priority and palette-bank
    // selection are downstream work, not an OR of the component bits.
    output wire paired_screens,
    output wire [11:0] second_palette_index
);
    wire ready, fetched, rejected;
    wire [31:0] fetch_blue, fetch_red, fetch_green;
    reg have_data=0, character_valid=0;
    reg [2:0] requested_mode=0, pixel_mode=0;
    reg [31:0] blue=0, red=0, green=0;
    x1_z_gram_fetch fetch(
        .clk(clk),.reset(reset || !enabled),
        .request(enabled && character_start),.ready(ready),
        .base_address(base_address),.mode(mode),.screen(screen),.raster_odd(raster_odd),
        .read_enable(read_enable),.read_address(read_address),
        .blue_q(blue_q),.red_q(red_q),.green_q(green_q),
        .valid(fetched),.rejected(rejected),
        .blue(fetch_blue),.red(fetch_red),.green(fetch_green)
    );
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            have_data<=0;character_valid<=0;blue<=0;red<=0;green<=0;requested_mode<=0;pixel_mode<=0;
        end else if(!enabled) begin
            have_data<=0;character_valid<=0;blue<=0;red<=0;green<=0;requested_mode<=0;pixel_mode<=0;
        end else begin
            if(character_start) begin
                have_data<=0;
                requested_mode<=mode;
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
                pixel_mode<=requested_mode;
                blue<=have_data ? fetch_blue : 32'd0;
                red<=have_data ? fetch_red : 32'd0;
                green<=have_data ? fetch_green : 32'd0;
                have_data<=0;
            end
        end
    end
    assign index_valid=enabled && character_valid && !reset;
    assign internal_palette=index_valid && pixel_mode==4;
    assign paired_screens=index_valid && pixel_mode==5;
    assign second_palette_index=paired_screens ?
        {green[23],green[31],green[23],green[31],
         red[23],red[31],red[23],red[31],blue[23],blue[31],blue[23],blue[31]} : 12'd0;
    // Techknow table 4-22 (printed 156): physical PA[3:0] is
    // QHA[3:0] for display, but DB[4:7] for CPU. Likewise PA[7:4]
    // uses AB[0:3], and PA[11:8] uses AB[4:7]. Storage is indexed
    // by logical CPU {AB[7:0],DB[7:4]}, NOT the physical PA pins.
    // Consequently each display nibble must reverse before the RAM lookup:
    // first fetched source QH?0 corresponds to logical component bit 3.
    wire [11:0] full_index={green[7],green[15],green[23],green[31],
                          red[7],red[15],red[23],red[31],
                          blue[7],blue[15],blue[23],blue[31]};
    // Printed 161: unused external-address bits expand effective channels.
    // This replicated effective-pair policy is not the emulator's CCC/333
    // bank-only table. CPU reduced-mode programming/bank controls remain open.
    assign palette_index=pixel_mode==0 ? full_index : pixel_mode==4 ? full_index :
        {green[7],green[15],green[7],green[15],
         red[7],red[15],red[7],red[15],blue[7],blue[15],blue[7],blue[15]};
endmodule
