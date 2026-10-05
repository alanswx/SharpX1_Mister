// SPDX-License-Identifier: GPL-2.0-or-later
// Original digital Turbo text-raster policy; see TURBO_TEXT_RASTER_STATUS.md.
// The ASIC bit encodings/precise gap phase remain provisional, not pin timing.
module x1_text_raster (
    input logic high_scan, text_y2, underline_mode, underline_cell,
    input logic [4:0] raster,
    output logic [3:0] font_row,
    output logic glyph_visible,
    output logic [2:0] reserved_color
);
    logic [4:0] row;
    always_comb begin
        row = text_y2 ? {1'b0,raster[4:1]} : raster;
        font_row = high_scan ? row[3:0] : {1'b0,row[2:0]};
        // Only underline mode reserves the gap; compatible non-underline
        // wrapping is deliberately retained pending broader CRTC acceptance.
        glyph_visible = !underline_mode || row < (high_scan ? 5'd16 : 5'd8);
        // Underline uses digital graphics palette entry 1, background entry 0.
        // High scan has two underline rasters followed by two blank rasters;
        // low scan one underline raster followed by one blank raster. Global
        // text expansion repeats each of these source rasters.
        reserved_color = underline_mode && underline_cell &&
            (high_scan ? (row == 5'd16 || row == 5'd17) : row == 5'd8)
            ? 3'd1 : 3'd0;
    end
endmodule
