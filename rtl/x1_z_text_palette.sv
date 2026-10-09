// SPDX-License-Identifier: GPL-2.0-only
// Original CPU text-palette experiment, Techknow printed 161-163.
// Eight words x six bits; word zero is fixed black and inaccessible to CPU.
// Reset flushes strobes/responses, not palette contents. Inactive AEN gate
// and upper read bits are provisional; no RGB bit significance is inferred.
`timescale 1ps/1ps
module x1_z_text_palette (
    input wire cpu_clk, video_clk, reset, video_reset,
    input wire enabled, io_read, io_write, clear_read,
    input wire [15:0] address,
    input wire [7:0] data,
    output wire selected,
    output wire [7:0] read_data,
    output wire read_hold,
    output wire [7:0] held_data,
    input wire [2:0] video_index,
    output wire [5:0] video_bits,
    output wire video_valid
);
    reg [47:0] palette=0;
    initial begin
        for(integer c=0;c<8;c=c+1)
            palette[c*6+:6]={{2{c[2]}},{2{c[1]}},{2{c[0]}}};
    end
    wire port_selected=address[15:3]==13'h3f7 && address[2:0]!=0;
    assign selected=!reset && enabled && port_selected && (io_read ^ io_write);
    reg write_seen=1, completed_read=0;
    reg [5:0] response=0;
    // Memory has no reset-time assignment or asynchronous reset sensitivity.
    // Only the transaction flags below reset; accepted writes are clocked.
    always @(posedge cpu_clk)
        if(selected && io_write && !write_seen) palette[address[2:0]*6+:6]<=data[5:0];
    always @(posedge cpu_clk or posedge reset) begin
        if(reset) begin write_seen<=1;completed_read<=0;response<=0;end
        else begin
            if(!io_write) write_seen<=0;
            else if(!write_seen) begin
                write_seen<=1;
            end
            if(clear_read) completed_read<=0;
            else if(selected && io_read) begin
                completed_read<=1;response<=palette[address[2:0]*6+:6];
            end
        end
    end
    assign read_data=selected && io_read ? {2'b00,palette[address[2:0]*6+:6]} : 8'hff;
    assign read_hold=!reset && completed_read;
    assign held_data=read_hold ? {2'b00,response} : 8'hff;
    wire [47:0] video_palette;
    wire snapshot_valid;
    x1_cdc_snapshot #(.WIDTH(48)) transfer(
        .source_clk(cpu_clk),.destination_clk(video_clk),.source_data(palette),
        .destination_data(video_palette),.destination_valid(snapshot_valid));
    assign video_valid=snapshot_valid && !video_reset;
    assign video_bits=video_valid ? video_palette[video_index*6+:6] : 6'd0;
endmodule
