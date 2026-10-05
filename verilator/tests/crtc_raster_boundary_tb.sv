`timescale 1ns/1ps
// SPDX-License-Identifier: GPL-2.0-or-later
// Original output-only frame-period check; no forced internal counters.
module crtc_raster_boundary_tb;
    logic clk=0, reset_n=0, ce=0;
    logic [4:0] last_raster=7, adjustment=0;
    wire [4:0] raster;
    wire [13:0] address;
    wire hs, vs, de;
    integer divider=1, phase=0;
    always #5 clk=!clk;
    always @(negedge clk) begin
        ce=phase==0;
        phase=(phase+1)%divider;
    end
    crtc_gen #(.ENABLE_MODE(1)) dut(
        .I_CLK(clk), .I_CE(ce), .I_RSTn(reset_n),
        .I_Nht(8'd3), .I_Nhd(8'd2), .I_Nhsp(8'd2), .I_Nhsw(4'd1),
        .I_Nvt(7'd4), .I_Nvd(7'd3), .I_Nvsp(7'd3), .I_Nvsw(4'd2),
        .I_Nr(last_raster), .I_Nadj(adjustment), .I_Msa(14'd0),
        .O_RA(raster), .O_MA(address), .O_H_SYNC(hs), .O_V_SYNC(vs), .O_DISPTMG(de)
    );
    initial begin
        for(int d=0;d<3;d++) begin
            divider=d==0?1:d==1?4:7;
            for(int r=0;r<3;r++) for(int a=0;a<4;a++) begin
                integer ticks, previous, rises, active_ticks, expected;
                logic old_vs;
                @(negedge clk); reset_n=0;
                last_raster=r==0?5'd7:r==1?5'd15:5'd31;
                adjustment=a==0?5'd0:a==1?5'd1:a==2?5'd2:5'd7;
                repeat(2) @(negedge clk);
                reset_n=1;
                ticks=0; previous=0; rises=0; active_ticks=0; old_vs=0;
                expected=4*(5*(int'(last_raster)+1)+int'(adjustment));
                while(rises<4 && ticks<5*expected) begin
                    @(posedge clk); #1;
                    if(ce) begin
                        ticks++;
                        if(de) active_ticks++;
                        if(vs && !old_vs) begin
                            if(rises>0) begin
                                assert(ticks-previous==expected) else
                                    $fatal(1,"frame CE%0d R9=%0d R5=%0d expected%0d actual%0d",
                                           divider,last_raster,adjustment,expected,ticks-previous);
                                assert(active_ticks==6*(int'(last_raster)+1)) else
                                    $fatal(1,"active raster count expected%0d actual%0d",
                                           6*(int'(last_raster)+1),active_ticks);
                            end
                            previous=ticks; rises++; active_ticks=0;
                        end
                        old_vs=vs;
                    end
                end
                assert(rises==4) else $fatal(1,"VSYNC watchdog");
            end
        end
        $display("PASS: 36 CRTC frame/active-raster cases, R9=7/15/31 R5=0/1/2/7 CE=1/4/7");
        $finish;
    end
endmodule
