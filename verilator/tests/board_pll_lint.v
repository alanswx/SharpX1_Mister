// Interface-only stand-in for linting emu without Intel primitive libraries.
// This does not simulate PLL frequency, lock behavior or board timing.
module pll(input refclk, rst, output outclk_0, outclk_1);
    assign outclk_0 = refclk;
    assign outclk_1 = refclk;
endmodule

module x1_turbo_video_pll(input refclk, output video_clk, locked);
    assign video_clk = refclk;
    assign locked = 1'b1;
endmodule
