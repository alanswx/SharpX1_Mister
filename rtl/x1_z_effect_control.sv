// SPDX-License-Identifier: GPL-2.0-only
// Original decoder of X1-Techknow Appendix A, printed pages 280-281.
// No input-video timing, CPU register storage, GRAM writes or composition.
// enabled is caller-qualified; capture_64color_mode must mean an actual
// 64-color format, not merely 1FB0 bit 4 (the 320x200 two-screen selector).
module x1_z_effect_control (
    input wire enabled, high_scan, capture_64color_mode,
    input wire [7:0] mode_control, position_control, mosaic_control,
                     chroma_control, scroll_control,
    output wire capture_enabled, capture_inverted,
    output wire position_enabled,
    output wire [7:0] position_dots,
    output wire [2:0] capture_component_bits,
    output wire mosaic_defined,
    output wire [6:0] mosaic_x_dots,
    output wire [5:0] mosaic_y_lines,
    output wire chroma_enabled, chroma_inverted,
    output wire [2:0] chroma_grb,
    output wire scroll_enabled, scroll_out, scroll_repeat, crt_disabled
);
    wire [1:0] quantization = {mosaic_control[7] | capture_64color_mode,
                              mosaic_control[6]};
    assign capture_enabled = enabled && mode_control[7] && mode_control[3];
    assign capture_inverted = capture_enabled && mode_control[2];
    assign position_enabled = enabled && !high_scan;
    // Raw correction count only: direction/origin is not specified here.
    assign position_dots = position_enabled ? position_control : 8'd0;
    assign capture_component_bits = enabled ? 3'd4 - {1'b0,quantization} : 3'd0;
    // Dash entries in the primary table are undefined, not clamped/wrapped.
    assign mosaic_defined = enabled && mosaic_control[2:0] <= 3'd6 &&
                                      mosaic_control[5:3] <= 3'd5;
    assign mosaic_x_dots = mosaic_defined ? 7'd1 << mosaic_control[2:0] : 7'd0;
    assign mosaic_y_lines = mosaic_defined ? 6'd1 << mosaic_control[5:3] : 6'd0;
    assign chroma_enabled = enabled && chroma_control[7];
    assign chroma_inverted = chroma_enabled && chroma_control[6];
    // Table's digital key code: G/R/B use bits 5/3/1, not contiguous RGB12.
    assign chroma_grb = enabled ? {chroma_control[5],chroma_control[3],
                                  chroma_control[1]} : 3'd0;
    assign scroll_enabled = enabled && scroll_control[3];
    assign scroll_out = scroll_enabled && scroll_control[0];
    assign scroll_repeat = scroll_enabled && scroll_control[1];
    assign crt_disabled = scroll_enabled && scroll_control[2];
endmodule
