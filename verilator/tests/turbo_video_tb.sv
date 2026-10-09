`timescale 1ns/1ps
// Original pipeline comparison: unrelated legacy macro not enabled.
module turbo_video_tb;
    reg clk=0,reset=1;
    reg [6:0] black=0;
    reg high_scan=0;
    wire [2:0] color;
    wire [10:0] pcg_address;
    wire [11:0] ank_address;
    always #5 clk=!clk;
    x1_vid #(.TURBO_SUPPORT(1),.ENABLE_CRTC(1)) dut(
        .I_CRTC_BUS_CLK(1'b0),.I_CRTC_BUS_RS(1'b0),
        .I_CRTC_BUS_DATA(8'd0),.I_CRTC_BUS_WRITE(1'b0),
        .I_RESET(reset), .I_VIDEO_RESET(reset), .I_TURBO_BLACK(black), .I_TURBO_HIGH_SCAN(high_scan),
        .I_TURBO_TEXT_Y2(1'b0), .I_TURBO_UNDERLINE(1'b0),
        .I_CCLK(clk), .I_VCLK(clk), .O_GRAPHICS_RA(),
        .O_GRAPHICS_START(),.O_GRAPHICS_LOAD(),.O_CG_TRANSPARENT(),.O_GRAPHICS_DISP(),
        .O_ANK16_ADDR(ank_address), .O_CGA(pcg_address),
        .O_KANJI_ADDR(), .O_KANJI_SELECT(), .O_KANJI_LEVEL1(),
        .I_A(16'd0), .I_D(8'd0), .I_WR(1'b0), .I_RD(1'b0),
        .I_CRTC_CS(1'b0), .I_CG_CS(1'b0), .I_PAL_CS(1'b0),
        .I_TXT_CS(1'b0), .I_ATT_CS(1'b0), .I_KAN_CS(1'b0),
        .I_GRB_CS(1'b0), .I_GRR_CS(1'b0), .I_GRG_CS(1'b0),
        .I_CLK1(1'b0), .I_W40(1'b0), .I_TXT_D(8'd0), .I_ATT_D(8'd0),
        .I_KAN_D(8'd0), .I_GRB_D(8'd0), .I_GRR_D(8'd0), .I_GRG_D(8'd0),
        .I_CG_D(8'd0), .I_PCGB_D(8'd0), .I_PCGR_D(8'd0), .I_PCGG_D(8'd0),
        .O_R(color[1]), .O_G(color[2]), .O_B(color[0]));
    // Test the registered mixer in isolation, not an invented full raster.
    initial begin
        repeat(3) @(negedge clk); reset=0;
        force dut.disp_d=1;
        force dut.att_blink=0; force dut.att_rev=0;
        force dut.att_pcg=0; force dut.att_b=1; force dut.att_r=1; force dut.att_g=1;
        force dut.PAL_B=8'h55; force dut.PAL_R=8'hcc; force dut.PAL_G=8'hf0;
        force dut.PRIO_R=8'hff;
        force dut.cgg_d=8'hff;
        for(int mask=0;mask<128;mask++) begin
            black=7'(mask);
            for(int raw=0;raw<8;raw++) begin
                force dut.grb_d=8'((raw&1)*128);
                force dut.grr_d=8'(((raw>>1)&1)*128);
                force dut.grg_d=8'(((raw>>2)&1)*128);
                @(posedge clk); #1;
                assert(color==((raw==0 && (mask&16)) || (raw==1 && (mask&32)) ? 0 : 3'(raw^1)))
                    else $fatal(1,"graphics raw=%d mask=%d color=%d",raw,mask,color);
            end
        end
        force dut.PRIO_R=0;
        force dut.grb_d=0; force dut.grr_d=0; force dut.grg_d=0;
        for(int textcolor=1;textcolor<8;textcolor++) begin
            force dut.att_b=1'(textcolor); force dut.att_r=1'(textcolor>>1); force dut.att_g=1'(textcolor>>2);
            for(int mask=0;mask<128;mask++) begin
                black=7'(mask);
                @(posedge clk); #1;
                assert(color==((mask&8) && (mask&7)==textcolor ? 0 : 3'(textcolor)))
                    else $fatal(1,"text=%d mask=%d color=%d",textcolor,mask,color);
            end
        end
        for(int hi=0;hi<2;hi++) begin
            high_scan=1'(hi);
            for(int paired=0;paired<2;paired++) begin
                force dut.pcg_paired=1'(paired);
                for(int character=0;character<256;character++) begin
                    force dut.txt_d=8'(character);
                    for(int row=0;row<16;row++) begin
                        force dut.cg_line=4'(row); #1;
                        assert(ank_address==12'(character*16+row)) else $fatal(1,"ANK row alias");
                        assert(pcg_address==11'((hi && paired ? (character/2)*2+row/8 : character)*8 +
                                                (hi && !paired ? row/2 : row%8)))
                            else $fatal(1,"PCG ordinary/paired/base glyph address");
                    end
                end
            end
        end
        $display("PASS: Turbo blackclip and all ANK/PCG glyph rows/pairs/base isolation");
        $finish;
    end
endmodule
