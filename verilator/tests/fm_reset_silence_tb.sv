`timescale 1ps/1ps
// After reset, a channel that is given a pitch, an output connection and
// full operator level, but is never keyed on, must stay silent: every
// YM2151 operator starts in release at maximum attenuation. Checked after
// the power-on reset and again after a warm reset that follows a played
// (keyed, still sounding) note.
module fm_reset_silence_tb;
    localparam integer MASTER_HZ = 32000000;
    reg clk = 0, reset = 1, cs = 0, wr_n = 1, a0 = 0;
    reg [7:0] din = 0;
    always #15625 clk = !clk;
    wire [7:0] dout;
    wire wait_n, irq_n, ct1, ct2, sample, cen_chip, cen_half, fault;
    wire signed [15:0] left, right;
    x1_fm #(.MASTER_HZ(MASTER_HZ)) dut (
        .clk(clk), .reset(reset), .enable(1'b1),
        .cpu_cs(cs), .cpu_rd_n(1'b1), .cpu_wr_n(wr_n), .cpu_a0(a0), .cpu_data_in(din),
        .cpu_data_out(dout), .wait_n(wait_n), .irq_n(irq_n), .ct1(ct1), .ct2(ct2),
        .sample(sample), .left(left), .right(right),
        .cen_chip(cen_chip), .cen_half(cen_half), .protocol_error(fault));

    task automatic bus_write(input bit address, input [7:0] value);
        @(negedge clk); cs = 1; a0 = address; din = value; wr_n = 0;
        do @(negedge clk); while (!wait_n);
        cs = 0; wr_n = 1;
        repeat (4) @(negedge clk);
    endtask
    task automatic reg_write(input [7:0] r, input [7:0] value);
        bus_write(0, r); bus_write(1, value);
        repeat (400) @(negedge clk);        // past the YM busy interval
    endtask
    // Channel 0: both outputs, algorithm 7 (four carriers), a pitch, every
    // operator TL 0 and MUL 1. No key-on.
    task automatic program_channel;
        reg_write(8'h20, 8'hc7);
        reg_write(8'h28, 8'h4a);
        for (integer op = 0; op < 4; op++) begin
            reg_write(8'h40 + 8'(op * 8), 8'h01);   // DT1/MUL
            reg_write(8'h60 + 8'(op * 8), 8'h00);   // TL 0
            reg_write(8'h80 + 8'(op * 8), 8'h1f);   // AR
            reg_write(8'he0 + 8'(op * 8), 8'h0f);   // D1L/RR
        end
    endtask
    function automatic integer peak(input integer samples);
        return 0;
    endfunction
    integer loudest;
    task automatic measure(input integer samples);
        loudest = 0;
        for (integer n = 0; n < samples; ) begin
            @(posedge clk);
            if (sample) begin
                n++;
                if ((left < 0 ? -left : left) > loudest) loudest = left < 0 ? -left : left;
                if ((right < 0 ? -right : right) > loudest) loudest = right < 0 ? -right : right;
            end
        end
    endtask

    initial begin
        repeat (40) @(negedge clk); reset = 0;
        repeat (2000) @(negedge clk);
        program_channel();
        measure(4000);
        $display("power-on: peak |out| without key-on = %0d", loudest);
        assert(loudest == 0) else $fatal(1, "FM sounds after power-on reset without key-on");
        // Play a note, then warm-reset while it sounds.
        reg_write(8'h08, 8'h78);                  // key on all operators, ch 0
        measure(2000);
        assert(loudest > 0) else $fatal(1, "keyed note is silent (fixture)");
        @(negedge clk); reset = 1; repeat (40) @(negedge clk); reset = 0;
        repeat (2000) @(negedge clk);
        program_channel();
        measure(4000);
        $display("warm reset: peak |out| without key-on = %0d", loudest);
        assert(loudest == 0) else $fatal(1, "FM sounds after warm reset without key-on");
        $display("PASS FM reset: unkeyed operators silent after power-on and warm reset");
        $finish;
    end
endmodule
