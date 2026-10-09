// SPDX-License-Identifier: GPL-2.0-only
// Original opt-in CPU 1FC0 register experiment. Stored upper/unused bits,
// inactive-AEN behavior and reset-to-zero are provisional, not native pins.
// Layer ordering/opacity/CDC belong downstream; no rendering is enabled here.
module x1_z_priority_register (
    input wire clk, reset, enabled, io_read, io_write, clear_read,
    input wire [15:0] address,
    input wire [7:0] data,
    output wire selected,
    output wire [7:0] read_data,
    output wire read_hold,
    output wire [7:0] held_data,
    output reg [7:0] control=0
);
    reg write_seen=1,completed_read=0;
    reg [7:0] response=0;
    assign selected=!reset && enabled && address==16'h1fc0 && (io_read ^ io_write);
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            control<=0;write_seen<=1;completed_read<=0;response<=0;
        end else begin
            if(!io_write) write_seen<=0;
            else if(!write_seen) begin
                write_seen<=1;
                if(selected) control<=data;
            end
            if(clear_read) completed_read<=0;
            else if(selected && io_read) begin
                completed_read<=1;response<=control;
            end
        end
    end
    assign read_data=selected && io_read ? control : 8'hff;
    assign read_hold=!reset && completed_read;
    assign held_data=read_hold ? response : 8'hff;
endmodule
