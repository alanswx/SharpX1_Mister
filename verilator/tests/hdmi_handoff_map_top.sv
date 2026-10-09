// SPDX-License-Identifier: GPL-2.0-or-later
// Isolated mapping probe: real PLL-driven atom inputs, not a MiSTer core.
module hdmi_handoff_map_top(
    input wire refclk,reset_request,video_policy_ready,
    input wire [2:0] requested_mode,
    output wire clk_output,output_blank,busy,video_policy_epoch,
    output wire [2:0] active_mode,
    output wire [1:0] pll_locked
);
    wire video_clock,hdmi_clock;
    altera_pll #(.fractional_vco_multiplier("false"),
        .reference_clock_frequency("50.0 MHz"),.operation_mode("direct"),
        .number_of_clocks(1),.output_clock_frequency0("42.954540 MHz"),
        .phase_shift0("0 ps"),.duty_cycle0(50),
        .pll_type("General"),.pll_subtype("General")) video_pll(
        .rst(1'b0),.refclk(refclk),.outclk(video_clock),.locked(pll_locked[0]),
        .fboutclk(),.fbclk(1'b0));
    altera_pll #(.fractional_vco_multiplier("false"),
        .reference_clock_frequency("50.0 MHz"),.operation_mode("direct"),
        .number_of_clocks(1),.output_clock_frequency0("74.25 MHz"),
        .phase_shift0("0 ps"),.duty_cycle0(50),
        .pll_type("General"),.pll_subtype("General")) hdmi_pll(
        .rst(1'b0),.refclk(refclk),.outclk(hdmi_clock),.locked(pll_locked[1]),
        .fboutclk(),.fbclk(1'b0));
    x1_hdmi_clock_handoff handoff(.clk_control(refclk),.clk_video(video_clock),.clk_hdmi(hdmi_clock),
        .reset_request(reset_request),.requested_mode(requested_mode),.video_policy_ready(video_policy_ready),
        .clk_output(clk_output),.active_mode(active_mode),.output_blank(output_blank),.busy(busy),
        .video_policy_epoch(video_policy_epoch));
endmodule
