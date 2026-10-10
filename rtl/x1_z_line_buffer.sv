// SPDX-License-Identifier: GPL-2.0-only
// Original digital uPD41101 storage-cycle model from NEC 1986 Memory Data
// Book, printed 3-1/3-2/3-9/3-10. Not native analog/access/retention timing.
// Caller must establish both cursors with their synchronous address resets.
// Unwritten, same-address collision and expired data are not qualified.
// Standalone: no machine manifest, guessed ASIC clocks or GRAM wiring.
`timescale 1ps/1ps
module x1_z_line_buffer (
    input logic write_clock, read_clock,
    input logic write_reset_n, read_reset_n,
    input logic write_enable_n, read_enable_n,
    input logic [7:0] data_in,
    output logic [7:0] data_out,
    // FPGA boundary equivalent of driven/high-Z ownership, NOT data validity.
    output logic output_owned = 0
);
    logic [7:0] memory [0:909];
    logic [9:0] write_next = 0, read_next = 0, pending_address = 0;
    logic write_known = 0, read_known = 0, pending_write = 0;
    wire [9:0] write_address = !write_reset_n ? 10'd0 : write_next;
    wire [9:0] read_address = !read_reset_n ? 10'd0 : read_next;
    function automatic logic [9:0] increment(input logic [9:0] address);
        return address==10'd909 ? 10'd0 : address+10'd1;
    endfunction

    always @(posedge write_clock) begin
        // Close the preceding accepted cycle using CURRENT DIN, even if
        // the newly sampled reset/WE changes. Stopped WCK retains this pair.
        if(pending_write) memory[pending_address] <= data_in;
        pending_write <= !write_enable_n && (write_known || !write_reset_n);
        if(!write_enable_n && (write_known || !write_reset_n)) begin
            pending_address <= write_address;
            write_next <= increment(write_address);
        end else if(!write_reset_n) write_next <= 0;
        if(!write_reset_n) write_known <= 1;
    end

    always @(posedge read_clock) begin
        // RCK starts a read; unlike DIN there is no ending-edge pipeline.
        // Retain the byte when disabled, but withdraw output ownership.
        output_owned <= !read_enable_n;
        if(!read_enable_n && (read_known || !read_reset_n)) begin
            data_out <= memory[read_address];
            read_next <= increment(read_address);
        end else if(!read_reset_n) read_next <= 0;
        if(!read_reset_n) read_known <= 1;
    end
endmodule
