// SPDX-License-Identifier: GPL-2.0-only
// Original externally loaded, character-major 256 x 16 ANK ROM storage.
// No firmware bytes are embedded. Incomplete/out-of-order loads stay blank.
`timescale 1ns/1ps
module x1_font16 (
    input cpu_clk, video_clk,
    input load, input [24:0] load_address, input [7:0] load_data,
    input [11:0] display_address,
    output [7:0] display_data,
    output reg loaded = 0,
    input [11:0] cpu_address,
    output [7:0] cpu_data
);
    reg [12:0] expected_address = 0;
    reg bad_load = 0;
    (* async_reg = "true" *) reg loaded_meta = 0, loaded_video = 0;
    reg loaded_read = 0;
    reg loaded_cpu_read = 0;
    wire sequential = load_address < 4096 && !bad_load &&
                      load_address == {12'd0,expected_address};
    wire write_entry = load && (load_address == 0 || sequential);
    wire [7:0] rom_data, cpu_rom_data;
    // One unconditional memory read and one qualified write port permit BRAM
    // inference. Gating the read inside the RAM process mapped 32K font bits
    // into flip-flops in Quartus 17; gate availability after the RAM instead.
    x1_video_ram #(12) storage (
        .cpu_clk(cpu_clk), .cpu_addr(load ? load_address[11:0] : cpu_address),
        .cpu_data(load_data), .cpu_write(write_entry), .cpu_q(cpu_rom_data),
        .video_clk(video_clk), .video_addr(display_address), .video_q(rom_data)
    );
    assign display_data = loaded_read ? rom_data : 8'd0;
    // Upload owns this port and holds the machine reset in the loader flow.
    // CPU reads outside that flow require a complete load and one read edge.
    assign cpu_data = loaded_cpu_read && loaded && !load ? cpu_rom_data : 8'd0;
    always @(posedge cpu_clk) begin
        loaded_cpu_read <= loaded && !load;
        if (load) begin
            if (load_address == 0) begin
                loaded <= 0; bad_load <= 0; expected_address <= 1;
            end else if (sequential) begin
                expected_address <= expected_address + 1'b1;
                if (load_address == 4095) loaded <= 1;
            end else begin loaded <= 0; bad_load <= 1; end
        end
    end
    // Storage/readiness survive warm reset. Firmware upload holds the machine
    // in reset; loaded-video becomes true only after a complete sequential load.
    always @(posedge video_clk) begin
        loaded_meta <= loaded; loaded_video <= loaded_meta;
        loaded_read <= loaded_video;
    end
endmodule
