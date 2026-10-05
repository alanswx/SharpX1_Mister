`timescale 1ns/1ps
// SPDX-License-Identifier: GPL-2.0-or-later
// Original exhaustive combinational policy check, not ASIC validation.
module text_raster_tb;
    logic high_scan, text_y2, underline_mode, underline_cell;
    logic [4:0] raster;
    wire [3:0] font_row;
    wire glyph_visible;
    wire [2:0] reserved_color;
    x1_text_raster dut(.*);
    initial begin
        for(int h=0;h<2;h++) for(int y=0;y<2;y++)
        for(int u=0;u<2;u++) for(int c=0;c<2;c++)
        for(int r=0;r<32;r++) begin
            high_scan=1'(h); text_y2=1'(y); underline_mode=1'(u);
            underline_cell=1'(c); raster=5'(r); #1;
            assert(font_row==4'((r/(y!=0?2:1))%(h!=0?16:8)))
                else $fatal(1,"font raster h%0d y%0d r%0d",h,y,r);
            assert(glyph_visible==(u==0 || r/(y!=0?2:1)<(h!=0?16:8)))
                else $fatal(1,"glyph reservation");
            assert(reserved_color==((u!=0 && c!=0 && r/(y!=0?2:1)>=(h!=0?16:8) &&
                   r/(y!=0?2:1)<(h!=0?18:9))?3'd1:3'd0)) else $fatal(1,"underline/gap");
        end
        $display("PASS: all 512 digital text raster policy combinations");
        $finish;
    end
endmodule
