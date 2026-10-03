`timescale 1ns/1ps
module crtc_enable_tb;
    reg clk = 0, reset = 1, w40 = 0;
    reg ppres = 0;
    reg [3:0] phase = 0;
    reg cs_n = 1, rs = 0;
    reg [7:0] data = 0;
    wire [4:0] old_ra, new_ra;
    wire [13:0] old_ma, new_ma;
    wire old_hs, old_vs, old_de, new_hs, new_vs, new_de;
    always #5 clk = !clk;
    always @(posedge clk or posedge reset)
        if (reset) begin ppres <= 0; phase <= 0; end
        else begin ppres <= ~ppres & w40; if (!ppres) phase <= phase + 1'b1; end
    crtc6845s baseline(.I_E(~clk), .I_DI(data), .I_RS(rs), .I_RWn(1'b0), .I_CSn(cs_n),
        .I_CLK(phase[3]), .I_CE(1'b1), .I_RSTn(~reset),
        .O_RA(old_ra), .O_MA(old_ma), .O_H_SYNC(old_hs), .O_V_SYNC(old_vs), .O_DISPTMG(old_de));
    crtc6845s #(.ENABLE_MODE(1)) enabled(.I_E(~clk), .I_DI(data), .I_RS(rs), .I_RWn(1'b0), .I_CSn(cs_n),
        .I_CLK(clk), .I_CE(!ppres && phase == 15), .I_RSTn(~reset),
        .O_RA(new_ra), .O_MA(new_ma), .O_H_SYNC(new_hs), .O_V_SYNC(new_vs), .O_DISPTMG(new_de));
    task write_reg(input [7:0] address, value);
        @(negedge clk); cs_n = 0; rs = 0; data = address;
        @(negedge clk); rs = 1; data = value;
        @(negedge clk); cs_n = 1;
    endtask
    initial begin
        write_reg(0, 55); write_reg(1, 40); write_reg(2, 45); write_reg(3, 8'h24);
        write_reg(4, 31); write_reg(5, 0); write_reg(6, 25); write_reg(7, 28);
        write_reg(8, 0); write_reg(9, 7); write_reg(12, 0); write_reg(13, 0);
        for (integer mode = 0; mode < 2; mode++) begin
            @(negedge clk); reset = 1; w40 = 1'(mode);
            @(negedge clk); reset = 0;
            for (integer i = 0; i < 600000; i++) begin
                @(posedge clk); #1;
                assert({old_ra, old_ma, old_hs, old_vs, old_de} ==
                       {new_ra, new_ma, new_hs, new_vs, new_de}) else $fatal(1, "CRTC phase mismatch mode %0d cycle %0d", mode, i);
            end
        end
        $display("PASS: enabled CRTC equals divided-clock CRTC at every master edge in 40/80 modes");
        $finish;
    end
endmodule
