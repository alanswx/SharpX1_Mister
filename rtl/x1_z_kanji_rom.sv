// SPDX-License-Identifier: GPL-2.0-only
// Original full 256-KiB Z SIMULATION REFERENCE store: IC65 then IC66,
// each 128 KiB; byte address {level,bank,character,row,half}. No font bytes.
// NOT an FPGA storage solution: external backing/cache/arbitration is still
// required. Do not advertise this memory as fitting 164 spare M10Ks.
// No board/manifest enables it. Exact ordered upload requires BOTH resets.
// Warm reset retains bytes/readiness and cancels reader validity.
`timescale 1ps/1ps
module x1_z_kanji_rom (
    input wire cpu_clk, video_clk, cpu_reset, video_reset,
    input wire upload, load,
    input wire [24:0] load_address,
    input wire [7:0] load_data,
    input wire cpu_read,
    input wire [17:0] cpu_address,
    output wire [7:0] cpu_data,
    output wire cpu_valid,
    input wire display_select,
    input wire [17:0] display_address,
    output wire [7:0] display_data,
    output wire display_valid,
    output reg loaded,
    output reg load_error
);
    reg was_upload;
    reg [18:0] expected_address;
    wire starting=upload && !was_upload;
    wire [18:0] next_address=starting ? 19'd0 : expected_address;
    wire bad=starting ? 1'b0 : load_error;
    wire valid_byte=upload && cpu_reset && video_reset && !bad &&
        load_address<25'd262144 && load_address=={6'd0,next_address};
    wire write_entry=load && valid_byte;
    reg [7:0] memory [0:262143];
    reg [7:0] cpu_q,video_q;
    wire [17:0] cpu_port_address=write_entry ? load_address[17:0] : cpu_address;
    always @(posedge cpu_clk) begin
        if(write_entry) begin
            memory[cpu_port_address]<=load_data;
            cpu_q<=load_data;
        end else cpu_q<=memory[cpu_port_address];
    end
    always @(posedge video_clk) video_q<=memory[display_address];
    reg cpu_selected,display_selected;
    (* async_reg = "true" *) reg loaded_meta,loaded_video;
    initial begin
        loaded=0; load_error=0; was_upload=0; expected_address=0;
        cpu_selected=0; display_selected=0; loaded_meta=0; loaded_video=0;
    end
    assign cpu_valid=cpu_selected && loaded && !upload && !cpu_reset;
    assign cpu_data=cpu_valid ? cpu_q : 8'd0;
    assign display_valid=display_selected && loaded_video && !video_reset;
    assign display_data=display_valid ? video_q : 8'd0;
    always @(posedge cpu_clk or posedge cpu_reset)
        if(cpu_reset) cpu_selected<=0;
        else cpu_selected<=cpu_read && loaded && !upload;
    always @(posedge cpu_clk) begin
        was_upload<=upload;
        if(starting) begin
            loaded<=0; expected_address<=0;
            load_error<=!cpu_reset || !video_reset;
        end
        if(upload && (!cpu_reset || !video_reset)) begin
            loaded<=0; load_error<=1;
        end
        if(load) begin
            if(valid_byte) expected_address<=next_address+19'd1;
            else begin loaded<=0; load_error<=1; end
        end
        if(!upload && was_upload) begin
            loaded<=expected_address==19'd262144 && !load_error && !load &&
                    cpu_reset && video_reset;
            if(expected_address!=19'd262144 || load || !cpu_reset || !video_reset)
                load_error<=1;
        end
    end
    // Availability publishes after reset-held commit. Rejected live-upload
    // revocation crosses this synchronizer, not an async data-valid shortcut.
    always @(posedge video_clk or posedge video_reset) begin
        if(video_reset) begin
            loaded_meta<=0; loaded_video<=0; display_selected<=0;
        end else begin
            loaded_meta<=loaded;
            loaded_video<=loaded_meta;
            display_selected<=loaded_video && display_select;
        end
    end
endmodule
