// SPDX-License-Identifier: GPL-2.0-only
// Original CZ-880 sheet-46 digital ADC wiring adapter. MB40576 D1 is MSB;
// D1..D4 are connected, D5/D6 are NC. Inputs are settled six-bit ADC codes,
// NOT analog voltage or RGB12 palette values. No ADC clock/latency is modeled.
module x1_z_adc_pinmap (
    input wire source_connected, sample_valid,
    input wire [5:0] red_code, green_code, blue_code,
    output wire pixel_valid,
    output wire [11:0] rgb12
);
    assign pixel_valid = source_connected && sample_valid;
    // Zero when invalid is an interface convention, not a captured black dot.
    // A consumer must gate all writes/line-buffer advances on pixel_valid.
    assign rgb12 = pixel_valid ? {red_code[5:2],green_code[5:2],blue_code[5:2]} : 12'd0;
endmodule
