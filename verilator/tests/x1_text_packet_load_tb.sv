// SPDX-License-Identifier: GPL-2.0-only
// Public-port renderer LOAD/color gate, including a post-capture mode change.
`timescale 1ns/1ps
module x1_text_packet_load_tb;
    bit clk=0,reset=1;
    initial forever begin #11640ps;clk=~clk;end
    bit packet_valid=1,partial=1,high_scan=0,expanded=0,underline=0;
    bit crtc_wr=0,crtc_rs=0;
    logic [7:0] crtc_data=0;
    wire allowed=packet_valid && (!partial || (!high_scan && !expanded && !underline));
    wire [2:0] color;
    wire [4:0] phase;
    wire ce_pixel,graphics_load;
    integer cases=0;
    x1_vid #(.ENABLE_CRTC(1),.TURBO_SUPPORT(1),.TURBO_CLOCKS(1),.SEPARATE_VIDEO_RESET(1),
        .SEPARATE_CRTC_BUS(1),.Z_KANJI_RENDER(1),.EXTERNAL_TEXT_PACKET(1)) dut(
        .I_VIDEO_RESET(reset),.I_RESET(reset),.I_CCLK(clk),.I_VCLK(clk),
        .I_CRTC_BUS_CLK(clk),.I_CRTC_BUS_RS(crtc_rs),.I_CRTC_BUS_DATA(crtc_data),.I_CRTC_BUS_WRITE(crtc_wr),
        .I_TURBO_BLACK(7'd0),.I_TURBO_HIGH_SCAN(high_scan),.I_TURBO_TEXT_Y2(expanded),.I_TURBO_UNDERLINE(underline),
        .I_A(16'd0),.I_D(8'd0),.O_D(),.O_DE(),.I_WR(1'b0),.I_RD(1'b0),.O_VWAIT(),
        .I_CRTC_CS(1'b0),.I_CG_CS(1'b0),.I_PAL_CS(1'b0),.I_TXT_CS(1'b0),.I_ATT_CS(1'b0),.I_KAN_CS(1'b0),
        .I_GRB_CS(1'b0),.I_GRR_CS(1'b0),.I_GRG_CS(1'b0),.I_CLK1(1'b0),.I_W40(1'b0),
        .O_VQ(phase),.O_VA(),.O_GRAPHICS_RA(),.O_GRAPHICS_START(),.O_GRAPHICS_LOAD(graphics_load),.O_GRAPHICS_DISP(),
        .O_CG_TRANSPARENT(),.O_CG_COLOR(color),.O_TXT_WE(),.O_ATT_WE(),.O_KAN_WE(),
        .I_TXT_D(8'h41),.I_ATT_D(8'h0f),.I_KAN_D(8'd0),
        .O_GRB_WE(),.O_GRR_WE(),.O_GRG_WE(),.I_GRB_D(8'd0),.I_GRR_D(8'd0),.I_GRG_D(8'd0),
        .O_CGA(),.O_ANK16_ADDR(),.I_CG_D(8'd0),.I_PCGB_D(8'd0),.I_PCGR_D(8'd0),.I_PCGG_D(8'd0),
        .O_KANJI_ADDR(),.O_KANJI_SELECT(),.O_KANJI_LEVEL1(),
        .O_Z_KANJI_ADDR(),.O_Z_KANJI_SELECT(),.I_Z_KANJI_VALID(packet_valid),.I_TEXT_PACKET_VALID(allowed),
        .O_Z_KANJI_MISS(),.O_Z_KANJI_UNSUPPORTED(),.O_R(),.O_G(),.O_B(),.O_HSYNC(),.O_VSYNC(),
        .O_VDISP(),.O_HBLANK(),.O_VBLANK(),.O_CE_PIXEL(ce_pixel));
    task automatic tick;@(posedge clk);#2;endtask
    task automatic write_crtc(input bit rs,input logic [7:0] value);
        @(negedge clk);crtc_rs=rs;crtc_data=value;crtc_wr=1;tick();
        @(negedge clk);crtc_wr=0;tick();
    endtask
    task automatic next_load;
        do begin @(negedge clk);end while(!graphics_load);
        tick();
    endtask
    initial begin
        logic [7:0] regs[0:13];
        regs='{8'd111,8'd80,8'd92,8'h34,8'd31,8'd2,8'd25,8'd28,8'd0,8'd7,8'h60,8'd7,8'd0,8'd0};
        tick();@(negedge clk);reset=0;
        for(integer r=0;r<14;r++) begin write_crtc(0,8'(r));write_crtc(1,regs[r]);end
        for(integer flags=0;flags<32;flags++) begin
            @(negedge clk);{packet_valid,partial,high_scan,expanded,underline}=5'(flags);
            repeat(3) next_load();
            assert(color==(allowed ? 3'd7 : 3'd0)) else $fatal(1,"TEXT_PACKET_COLOR");cases++;
        end
        @(negedge clk);packet_valid=1;partial=1;high_scan=0;expanded=0;underline=0;
        repeat(3) next_load();assert(color==7) else $fatal(1,"TEXT_PACKET_COLOR");
        // O_VQ is the inherited inverted divider code. Use the actual LOAD
        // output, not a numeric O_VQ alias, for the final color observation.
        do begin @(negedge clk);end while(!(ce_pixel && phase==5'b01010));
        tick();@(negedge clk);underline=1;next_load();
        assert(color==0) else $fatal(1,"TEXT_PACKET_LATE_LOAD");cases++;
        @(negedge clk);partial=0;underline=0;repeat(3) next_load();
        do begin @(negedge clk);end while(!(ce_pixel && phase==5'b01010));
        tick();@(negedge clk);underline=1;next_load();
        assert(color==7) else $fatal(1,"TEXT_PACKET_FULL_MODE");cases++;
        assert(cases==34) else $fatal(1,"TEXT_PACKET_LEDGER");
        $display("PASS TEXT_PACKET_LOAD cases=%0d",cases);$finish;
    end
    initial begin #10ms;$fatal(1,"TEXT_PACKET_TIMEOUT");end
endmodule
