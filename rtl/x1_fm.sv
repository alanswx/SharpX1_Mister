// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ps/1ps
// Original functional YM2151 adapter. JT51 is GPL-3.0-or-later; preserve its
// notices. This standalone increment is not X1 decode/IRQ integration.
module x1_fm #(parameter integer MASTER_HZ = 32000000) (
    input logic clk, reset, enable,
    input logic cpu_cs, cpu_rd_n, cpu_wr_n, cpu_a0,
    input logic [7:0] cpu_data_in,
    output logic [7:0] cpu_data_out,
    output logic wait_n, irq_n, ct1, ct2,
    output logic sample,
    output logic signed [15:0] left, right,
    output logic cen_chip, cen_half,
    output logic protocol_error
);
    initial assert (MASTER_HZ >= 4000000)
        else $fatal(1, "FM master must be at least the 4 MHz chip input");
    // Fractional enables, never a generated/gated clock. The documented
    // provisional X1 Z input is 4 MHz; JT51's internal P1 rate is half that.
    logic [31:0] phase;
    logic half_phase;
    wire [32:0] phase_sum = {1'b0, phase} + 33'd4000000;
    assign cen_chip = !reset && enable && phase_sum >= 33'(MASTER_HZ);
    assign cen_half = cen_chip && half_phase;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin phase <= 0; half_phase <= 0; end
        else if (enable) begin
            if (cen_chip) begin
                phase <= 32'(phase_sum - 33'(MASTER_HZ));
                half_phase <= !half_phase;
            end else phase <= phase_sum[31:0];
        end
    end

    logic pending, write_seen, saved_a0;
    logic [7:0] saved_data;
    wire write_event = cpu_cs && !cpu_wr_n && !write_seen;
    wire dispatch = pending && cen_half;
    wire [7:0] status;
    wire chip_sample;
    // WAIT is only this adapter's bounded transaction latency, not Yamaha's
    // busy interval or a proven X1 wait-ASIC waveform. Caller must poll busy.
    assign wait_n = reset || !(pending || write_event);
    assign cpu_data_out = cpu_cs && !cpu_rd_n ? status : 8'hff;
    assign sample = chip_sample && !reset;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pending <= 0; write_seen <= 0; saved_a0 <= 0; saved_data <= 0;
            protocol_error <= 0;
        end else begin
            if (!cpu_cs || cpu_wr_n) write_seen <= 0;
            if (dispatch) pending <= 0;
            if (write_event) begin
                write_seen <= 1;
                if (!pending || dispatch) begin
                    saved_a0 <= cpu_a0; saved_data <= cpu_data_in;
                    pending <= 1;
                end else protocol_error <= 1;
            end
        end
    end
    jt51 chip (
        .rst(reset), .clk(clk), .cen(cen_chip), .cen_p1(cen_half),
        .cs_n(!dispatch), .wr_n(!dispatch), .a0(saved_a0), .din(saved_data),
        .dout(status), .ct1(ct1), .ct2(ct2), .irq_n(irq_n),
        .sample(chip_sample), .left(left), .right(right), .xleft(), .xright()
    );
endmodule
