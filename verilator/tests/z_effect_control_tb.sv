// SPDX-License-Identifier: GPL-2.0-only
// Independent arithmetic/table oracle; this does not qualify native effects.
`timescale 1ps/1ps
module z_effect_control_tb;
    bit enabled=0, high_scan=0, capture_64color_mode=0;
    bit [7:0] mode_control=0, position_control=0, mosaic_control=0;
    bit [7:0] chroma_control=0, scroll_control=0;
    wire capture_enabled,capture_inverted,position_enabled,mosaic_defined;
    wire [7:0] position_dots;
    wire [2:0] capture_component_bits,chroma_grb;
    wire [6:0] mosaic_x_dots;
    wire [5:0] mosaic_y_lines;
    wire chroma_enabled,chroma_inverted,scroll_enabled,scroll_out,scroll_repeat,crt_disabled;
    bit negative_quant=0,negative_scroll=0;
    x1_z_effect_control dut(.*,
        .capture_64color_mode(negative_quant ? 1'b0 : capture_64color_mode),
        .scroll_control(negative_scroll ? scroll_control | 8'h08 : scroll_control));
    integer checks=0;
    initial begin
        negative_quant=$test$plusargs("NEGATIVE_QUANT");
        negative_scroll=$test$plusargs("NEGATIVE_SCROLL");
        for(integer active=0;active<2;active++)
        for(integer pair_mode=0;pair_mode<2;pair_mode++)
        for(integer mode=0;mode<256;mode++)
        for(integer mosaic=0;mosaic<256;mosaic++) begin
            integer levels[0:3];
            integer x_sizes[0:7],y_sizes[0:7];
            integer quant,x,y;
            bit cap,legal;
            enabled=1'(active);capture_64color_mode=1'(pair_mode);
            mode_control=8'(mode);mosaic_control=8'(mosaic);
            levels='{4,3,2,1};
            x_sizes='{1,2,4,8,16,32,64,0};
            y_sizes='{1,2,4,8,16,32,0,0};
            quant=mosaic/64;
            if(pair_mode!=0 && quant<2) quant=quant+2;
            x=mosaic%8;y=(mosaic/8)%8;
            cap=active!=0 && mode>=128 && (mode/8)%2!=0;
            legal=active!=0 && x_sizes[x]!=0 && y_sizes[y]!=0;
            #1;
            assert(capture_enabled==cap && capture_inverted==(cap && (mode/4)%2!=0))
                else $fatal(1,"capture enable/inversion mode=%h",mode);
            assert(capture_component_bits==3'(active!=0 ? levels[quant] : 0))
                else $fatal(1,"quantization mode=%0d control=%h active=%0d",pair_mode,mosaic,active);
            assert(mosaic_defined==legal &&
                   mosaic_x_dots==7'(legal ? x_sizes[x] : 0) &&
                   mosaic_y_lines==6'(legal ? y_sizes[y] : 0))
                else $fatal(1,"mosaic defined/dimensions control=%h",mosaic);
            checks++;
        end
        capture_64color_mode=0;
        for(integer active=0;active<2;active++)
        for(integer scan=0;scan<2;scan++)
        for(integer raw=0;raw<256;raw++) begin
            enabled=1'(active);high_scan=1'(scan);position_control=8'(raw);
            #1;
            assert(position_enabled==(active!=0 && scan==0) &&
                   position_dots==8'(active!=0 && scan==0 ? raw : 0))
                else $fatal(1,"position count/high-scan guard");
            checks++;
        end
        for(integer active=0;active<2;active++)
        for(integer raw=0;raw<256;raw++) begin
            integer code;
            bit key_on;
            enabled=1'(active);chroma_control=8'(raw);
            key_on=active!=0 && raw>=128;
            code=4*((raw/32)%2)+2*((raw/8)%2)+(raw/2)%2;
            #1;
            assert(chroma_enabled==key_on && chroma_inverted==(key_on && (raw/64)%2!=0) &&
                   chroma_grb==3'(active!=0 ? code : 0))
                else $fatal(1,"chroma key control/gating/code");
            checks++;
        end
        for(integer active=0;active<2;active++)
        for(integer raw=0;raw<256;raw++) begin
            bit scroll_on;
            enabled=1'(active);scroll_control=8'(raw);
            scroll_on=active!=0 && (raw/8)%2!=0;
            #1;
            assert(scroll_enabled==scroll_on && scroll_out==(scroll_on && raw%2!=0) &&
                   scroll_repeat==(scroll_on && (raw/2)%2!=0) &&
                   crt_disabled==(scroll_on && (raw/4)%2!=0))
                else $fatal(1,"scroll activation/control raw=%h active=%0d",raw,active);
            checks++;
        end
        assert(checks==264192) else $fatal(1,"missing control cases");
        $display("PASS: 264192 capture/mosaic/position/chroma/scroll decode cases; no native input/GRAM/composition claim");
        $finish;
    end
endmodule
