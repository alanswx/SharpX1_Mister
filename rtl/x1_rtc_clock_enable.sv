// SPDX-License-Identifier: GPL-2.0-only
// Original synchronous nominal 32.768-kHz event producer. This is an enable,
// not a generated clock. It follows elapsed SYS edges, never CPU/MR16 activity.
// power_reset is configuration loss; ordinary warm reset must not be wired here.
// No crystal tolerance, stopped-FPGA battery time or asynchronous pin CDC model.
module x1_rtc_clock_enable #(
    parameter integer CLOCK_HZ = 32000000,
    parameter integer PHASE_WIDTH = $clog2(CLOCK_HZ)
) (
    input wire clk, power_reset,
    output wire oscillator_ce,
    output logic [PHASE_WIDTH-1:0] phase
);
    localparam integer SUM_WIDTH = PHASE_WIDTH+1;
    wire [SUM_WIDTH-1:0] next_sum = {1'b0,phase} + SUM_WIDTH'(32768);
    assign oscillator_ce = !power_reset && next_sum >= SUM_WIDTH'(CLOCK_HZ);
    always_ff @(posedge clk) begin
        if (power_reset) phase <= '0;
        else if (oscillator_ce) phase <= PHASE_WIDTH'(next_sum - SUM_WIDTH'(CLOCK_HZ));
        else phase <= PHASE_WIDTH'(next_sum);
    end
    initial begin
        assert(CLOCK_HZ >= 32768 && PHASE_WIDTH >= $clog2(CLOCK_HZ))
            else $fatal(1,"RTC enable requires SYS >= crystal and sufficient phase width");
    end
endmodule
