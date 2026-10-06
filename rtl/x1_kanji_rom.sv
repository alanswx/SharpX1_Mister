// SPDX-License-Identifier: GPL-2.0-only
// Original first-level ROM storage for the audited model-20/30 address bus.
// Physical bytes: IC106, IC105, IC104, IC103, each 32768 bytes. No font data.
// Upload owns the CPU port and requires BOTH reset domains asserted. Publish
// readiness only after an exact, ordered 131072-byte upload ends. This avoids
// exposing a nominally complete image before trailing invalid bytes arrive.
// Warm reset preserves ROM/readiness but masks readers and flushes read-valid.
// CPU/video byte reads each have one local clock edge of latency. No JIS/CPU
// register protocol, native dump filename order, renderer or Z ROM is implied.
`timescale 1ps/1ps
module x1_kanji_rom (
    input wire cpu_clk, video_clk, cpu_reset, video_reset,
    input wire upload, load,
    input wire [24:0] load_address,
    input wire [7:0] load_data,
    input wire cpu_read,
    input wire [16:0] cpu_address,
    output wire [7:0] cpu_data,
    output wire cpu_valid,
    input wire display_select,
    input wire [16:0] display_address,
    output wire [7:0] display_data,
    output wire display_valid,
    output reg loaded=0,
    output reg load_error=0
);
    reg was_upload=0;
    reg [17:0] expected_address=0;
    wire starting=upload && !was_upload;
    wire [17:0] next_address=starting ? 18'd0 : expected_address;
    wire bad=starting ? 1'b0 : load_error;
    wire valid_byte=upload && cpu_reset && video_reset && !bad &&
                    load_address<25'd131072 && load_address=={7'd0,next_address};
    wire write_entry=load && valid_byte;
    reg [7:0] memory [0:131071];
    reg [7:0] cpu_q,video_q;
    wire [16:0] cpu_port_address=write_entry ? load_address[16:0] : cpu_address;
    // One physical address per port; CPU writes forward new data to its
    // masked output. No old-data read during writes is required. Otherwise
    // Quartus duplicates the whole ROM to satisfy the extra read semantics.
    // Never use same-address cross-clock read/write collision values.
    always @(posedge cpu_clk) begin
        if(write_entry) begin
            memory[cpu_port_address]<=load_data;
            cpu_q<=load_data;
        end else cpu_q<=memory[cpu_port_address];
    end
    always @(posedge video_clk) video_q<=memory[display_address];
    reg cpu_selected=0;
    (* async_reg = "true" *) reg loaded_meta=0,loaded_video=0;
    reg display_selected=0;
    assign cpu_valid=cpu_selected && loaded && !upload && !cpu_reset;
    assign cpu_data=cpu_valid ? cpu_q : 8'd0;
    assign display_valid=display_selected && !video_reset;
    assign display_data=display_valid ? video_q : 8'd0;
    always @(posedge cpu_clk or posedge cpu_reset)
        if(cpu_reset) cpu_selected<=0;
        else cpu_selected<=cpu_read && loaded && !upload;
    always @(posedge cpu_clk) begin
        was_upload<=upload;
        if(starting) begin
            loaded<=0;
            expected_address<=0;
            load_error<=!cpu_reset || !video_reset;
        end
        if(upload && (!cpu_reset || !video_reset)) begin
            loaded<=0;load_error<=1;
        end
        if(load) begin
            if(valid_byte) expected_address<=next_address+18'd1;
            else begin loaded<=0;load_error<=1;end
        end
        if(!upload && was_upload) begin
            // A byte strobe on the falling upload edge is an orphan, not a
            // commit. Include current inputs; the earlier error assignment
            // in this clocked block has not reached load_error yet.
            loaded<=expected_address==18'd131072 && !load_error && !load &&
                    cpu_reset && video_reset;
            if(expected_address!=18'd131072 || load || !cpu_reset || !video_reset)
                load_error<=1;
        end
    end
    // Metadata crosses only while the uploader holds video reset. Reset
    // flushes the availability pipeline, not the loaded ROM or host parser.
    always @(posedge video_clk or posedge video_reset) begin
        if(video_reset) begin
            loaded_meta<=0;loaded_video<=0;display_selected<=0;
        end else begin
            loaded_meta<=loaded;
            loaded_video<=loaded_meta;
            display_selected<=loaded_video && display_select;
        end
    end
endmodule
