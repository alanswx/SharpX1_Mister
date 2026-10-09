// SPDX-License-Identifier: GPL-2.0-only
// Original sequential fetch buffer for the Techknow screen-chapter source
// matrix (see docs/TURBO_Z_PALETTE_CONTRACT.md). One existing synchronous
// video read port per component; CPU ports are untouched. This is not native
// CRTC address formation, reduced palette expansion or a beam/CPU arbiter.
`timescale 1ps/1ps
module x1_z_gram_fetch (
    input wire clk, reset,
    input wire request,
    output wire ready,
    input wire [13:0] base_address,
    // 0: 320x200/4096; 1: two-screen 320x200/64; 2: 640x200/64;
    // 3: 320x400/64; 4: 640x400/8. These are internal IDs, not ASIC bits.
    input wire [2:0] mode,
    input wire screen, raster_odd,
    output wire read_enable,
    output wire [14:0] read_address,
    input wire [7:0] blue_q, red_q, green_q,
    output reg valid = 0, rejected = 0,
    // Byte lane n supplies component bit n; unused lanes are zero.
    output reg [31:0] blue = 0, red = 0, green = 0
);
    reg busy = 0;
    reg [13:0] base = 0;
    reg [2:0] selected_mode = 0, count = 0, issued = 0;
    reg selected_page = 0;
    reg pending = 0;
    reg [1:0] pending_lane = 0;
    wire offset = selected_mode == 0 ? issued[0] :
                  (selected_mode == 1 || selected_mode == 3) && issued[0];
    wire bank = selected_mode == 0 ? issued[1] :
                selected_mode == 2 ? issued[0] : selected_page;
    // Offset wraps within a component's 16 KiB bank, never into the next bank.
    wire [13:0] byte_address = base + (offset ? 14'h0400 : 14'd0);
    assign ready = !reset && !busy;
    assign read_enable = !reset && busy && issued < count;
    assign read_address = {bank, byte_address};
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 0; pending <= 0; valid <= 0; rejected <= 0;
            base <= 0; selected_mode <= 0; selected_page <= 0;
            count <= 0; issued <= 0; pending_lane <= 0;
            blue <= 0; red <= 0; green <= 0;
        end else begin
            valid <= 0;
            rejected <= 0;
            pending <= read_enable;
            if (ready && request) begin
                if (mode > 4) rejected <= 1;
                else begin
                    busy <= 1;
                    base <= base_address;
                    selected_mode <= mode;
                    selected_page <= mode == 1 ? screen : raster_odd;
                    count <= mode == 0 ? 4 : mode == 4 ? 1 : 2;
                    issued <= 0;
                    blue <= 0; red <= 0; green <= 0;
                end
            end
            if (read_enable) begin
                pending_lane <= issued[1:0];
                issued <= issued + 1'b1;
            end
            // The RAM's registered q is the previous edge's issued address.
            if (pending) begin
                blue[pending_lane*8 +: 8] <= blue_q;
                red[pending_lane*8 +: 8] <= red_q;
                green[pending_lane*8 +: 8] <= green_q;
                if ({1'b0,pending_lane} == count - 3'd1) begin
                    busy <= 0;
                    valid <= 1;
                end
            end
        end
    end
endmodule
