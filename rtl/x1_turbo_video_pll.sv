// Board-only candidate Turbo video oscillator. Quartus must report its actual
// generated frequency; the nominal request is not proof of a fitted PLL rate.
module x1_turbo_video_pll(input refclk, output video_clk, locked);
    altera_pll #(
        .fractional_vco_multiplier("false"),
        .reference_clock_frequency("50.0 MHz"), .operation_mode("direct"),
        .number_of_clocks(1), .output_clock_frequency0("42.954540 MHz"),
        .phase_shift0("0 ps"), .duty_cycle0(50),
        .pll_type("General"), .pll_subtype("General")
    ) oscillator (
        .rst(1'b0), .refclk(refclk), .outclk(video_clk), .locked(locked),
        .fboutclk(), .fbclk(1'b0)
    );
endmodule
