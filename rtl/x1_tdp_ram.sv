// SPDX-License-Identifier: GPL-2.0-or-later
// Explicit true dual-port block RAM (altsyncram BIDIR_DUAL_PORT), adapted
// from SharpMZ2500_MiSTer rtl/wd1793_mem.v with a second clock.
// Inferred "read/write port + separate read port" memories were built by
// Quartus as two duplicated copies; this maps each to one M10K set.
// Each port: registered address/data/write, registered output (one cycle),
// same-port read-during-write returns the new data. Cross-port collisions
// (same address, either clock) are undefined, as for the inferred RAMs.
// The VERILATOR branch is the behavioral model of the same contract.
module x1_tdp_ram #(
    parameter integer AW = 11,
    parameter integer DW = 8
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
    altsyncram altsyncram_component (
        .address_a(address_a), .address_b(address_b),
        .clock0(clock_a), .clock1(clock_b),
        .data_a(data_a), .data_b(data_b),
        .wren_a(wren_a), .wren_b(wren_b),
        .q_a(q_a), .q_b(q_b),
        .aclr0(1'b0), .aclr1(1'b0),
        .addressstall_a(1'b0), .addressstall_b(1'b0),
        .byteena_a(1'b1), .byteena_b(1'b1),
        .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
        .eccstatus(), .rden_a(1'b1), .rden_b(1'b1));
    defparam
        altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
        altsyncram_component.intended_device_family = "Cyclone V",
        altsyncram_component.lpm_type = "altsyncram",
        altsyncram_component.ram_block_type = "M10K",
        altsyncram_component.numwords_a = 1 << AW,
        altsyncram_component.numwords_b = 1 << AW,
        altsyncram_component.widthad_a = AW,
        altsyncram_component.widthad_b = AW,
        altsyncram_component.width_a = DW,
        altsyncram_component.width_b = DW,
        altsyncram_component.width_byteena_a = 1,
        altsyncram_component.width_byteena_b = 1,
        altsyncram_component.address_reg_b = "CLOCK1",
        altsyncram_component.indata_reg_b = "CLOCK1",
        altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1",
        altsyncram_component.clock_enable_input_a = "BYPASS",
        altsyncram_component.clock_enable_input_b = "BYPASS",
        altsyncram_component.clock_enable_output_a = "BYPASS",
        altsyncram_component.clock_enable_output_b = "BYPASS",
        altsyncram_component.outdata_reg_a = "UNREGISTERED",
        altsyncram_component.outdata_reg_b = "UNREGISTERED",
        altsyncram_component.outdata_aclr_a = "NONE",
        altsyncram_component.outdata_aclr_b = "NONE",
        altsyncram_component.power_up_uninitialized = "FALSE",
        altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
        altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
        altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ";
`endif
endmodule
