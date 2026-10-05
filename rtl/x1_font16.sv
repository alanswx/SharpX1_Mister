// SPDX-License-Identifier: GPL-2.0-only
// Original externally loaded, character-major 256 x 16 ANK ROM storage.
// No firmware bytes are embedded. Incomplete/out-of-order loads stay blank.
`timescale 1ns/1ps
module x1_font16 (
    input cpu_clk, video_clk,
    input load, input [24:0] load_address, input [7:0] load_data,
    input [11:0] display_address,
    output reg [7:0] display_data,
    output reg loaded = 0
);
    reg [7:0] rom [0:4095];
    reg [12:0] expected_address = 0;
    reg bad_load = 0;
    (* async_reg = "true" *) reg loaded_meta = 0, loaded_video = 0;
    always @(posedge cpu_clk) begin
        if (load) begin
            if (load_address == 0) begin
                loaded <= 0; bad_load <= 0; expected_address <= 1;
                rom[0] <= load_data;
            end else if (load_address < 4096 && !bad_load &&
                         load_address == {12'd0,expected_address}) begin
                rom[load_address[11:0]] <= load_data;
                expected_address <= expected_address + 1'b1;
                if (load_address == 4095) loaded <= 1;
            end else begin loaded <= 0; bad_load <= 1; end
        end
    end
    // Storage/readiness survive warm reset. Firmware upload holds the machine
    // in reset; loaded-video becomes true only after a complete sequential load.
    always @(posedge video_clk) begin
        loaded_meta <= loaded; loaded_video <= loaded_meta;
        display_data <= loaded_video ? rom[display_address] : 8'd0;
    end
endmodule
