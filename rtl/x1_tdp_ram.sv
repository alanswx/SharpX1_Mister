// SPDX-License-Identifier: GPL-2.0-or-later
// Explicit true dual-port block RAM (altsyncram BIDIR_DUAL_PORT), adapted
// from SharpMZ2500_MiSTer rtl/wd1793_mem.v with a second clock.
// Inferred "read/write port + separate read port" memories were built by
// Quartus as two duplicated copies; this maps each to one M10K set.
// Each port: registered address/data/write, registered output (one cycle),
// same-port read-during-write returns the new data. Cross-port collisions
// (same address, either clock) are undefined, as for the inferred RAMs,
// unless SAME_CLOCK=1: both ports then use clock_a, and a read colliding
// with the other port's write returns the old data (the VERILATOR model's
// behavior for one clock).
// The VERILATOR branch is the behavioral model of the same contract.
module x1_tdp_ram #(
    parameter integer AW = 11,
    parameter integer DW = 8,
    parameter integer SAME_CLOCK = 0
) (
    input  wire          clock_a,
    input  wire [AW-1:0] address_a,
    input  wire [DW-1:0] data_a,
    input  wire          wren_a,
    output wire [DW-1:0] q_a,

    input  wire          clock_b,
    input  wire [AW-1:0] address_b,
    input  wire [DW-1:0] data_b,
    input  wire          wren_b,
    output wire [DW-1:0] q_b
);
`ifdef VERILATOR
    reg [DW-1:0] mem [0:(1<<AW)-1];
    reg [DW-1:0] q_a_r, q_b_r;
    assign q_a = q_a_r;
    assign q_b = q_b_r;
    always @(posedge clock_a) begin
        if (wren_a) begin
            mem[address_a] <= data_a;
            q_a_r <= data_a;
        end else
            q_a_r <= mem[address_a];
    end
    always @(posedge clock_b) begin
        if (wren_b) begin
            mem[address_b] <= data_b;
            q_b_r <= data_b;
        end else
            q_b_r <= mem[address_b];
    end
`else
    localparam CLOCK_B = SAME_CLOCK ? "CLOCK0" : "CLOCK1";
    localparam MIXED = SAME_CLOCK ? "OLD_DATA" : "DONT_CARE";
    // altsyncram rejects a connected clock1 when port B uses CLOCK0.
    generate if (SAME_CLOCK) begin : same_clock
        wire unused_clock_b = clock_b;
        altsyncram #(
        .operation_mode("BIDIR_DUAL_PORT"),
        .intended_device_family("Cyclone V"),
        .lpm_type("altsyncram"),
        .ram_block_type("M10K"),
        .numwords_a(1 << AW), .numwords_b(1 << AW),
        .widthad_a(AW), .widthad_b(AW),
        .width_a(DW), .width_b(DW),
        .width_byteena_a(1), .width_byteena_b(1),
        .address_reg_b(CLOCK_B), .indata_reg_b(CLOCK_B),
        .wrcontrol_wraddress_reg_b(CLOCK_B),
        .clock_enable_input_a("BYPASS"), .clock_enable_input_b("BYPASS"),
        .clock_enable_output_a("BYPASS"), .clock_enable_output_b("BYPASS"),
        .outdata_reg_a("UNREGISTERED"), .outdata_reg_b("UNREGISTERED"),
        .outdata_aclr_a("NONE"), .outdata_aclr_b("NONE"),
        .power_up_uninitialized("FALSE"),
        .read_during_write_mode_mixed_ports(MIXED),
        .read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
        .read_during_write_mode_port_b("NEW_DATA_NO_NBE_READ")
        ) altsyncram_component (
        .clock0(clock_a),
        .address_a(address_a), .address_b(address_b),
        .data_a(data_a), .data_b(data_b),
        .wren_a(wren_a), .wren_b(wren_b),
        .q_a(q_a), .q_b(q_b),
        .aclr0(1'b0), .aclr1(1'b0),
        .addressstall_a(1'b0), .addressstall_b(1'b0),
        .byteena_a(1'b1), .byteena_b(1'b1),
        .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
        .eccstatus(), .rden_a(1'b1), .rden_b(1'b1));
    end else begin : two_clocks
        altsyncram #(
        .operation_mode("BIDIR_DUAL_PORT"),
        .intended_device_family("Cyclone V"),
        .lpm_type("altsyncram"),
        .ram_block_type("M10K"),
        .numwords_a(1 << AW), .numwords_b(1 << AW),
        .widthad_a(AW), .widthad_b(AW),
        .width_a(DW), .width_b(DW),
        .width_byteena_a(1), .width_byteena_b(1),
        .address_reg_b(CLOCK_B), .indata_reg_b(CLOCK_B),
        .wrcontrol_wraddress_reg_b(CLOCK_B),
        .clock_enable_input_a("BYPASS"), .clock_enable_input_b("BYPASS"),
        .clock_enable_output_a("BYPASS"), .clock_enable_output_b("BYPASS"),
        .outdata_reg_a("UNREGISTERED"), .outdata_reg_b("UNREGISTERED"),
        .outdata_aclr_a("NONE"), .outdata_aclr_b("NONE"),
        .power_up_uninitialized("FALSE"),
        .read_during_write_mode_mixed_ports(MIXED),
        .read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
        .read_during_write_mode_port_b("NEW_DATA_NO_NBE_READ")
        ) altsyncram_component (
        .clock0(clock_a), .clock1(clock_b),
        .address_a(address_a), .address_b(address_b),
        .data_a(data_a), .data_b(data_b),
        .wren_a(wren_a), .wren_b(wren_b),
        .q_a(q_a), .q_b(q_b),
        .aclr0(1'b0), .aclr1(1'b0),
        .addressstall_a(1'b0), .addressstall_b(1'b0),
        .byteena_a(1'b1), .byteena_b(1'b1),
        .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
        .eccstatus(), .rden_a(1'b1), .rden_b(1'b1));
    end endgenerate
`endif
endmodule
