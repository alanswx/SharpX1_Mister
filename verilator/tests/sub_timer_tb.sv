`timescale 1ns/1ps
module sub_timer_tb #(parameter CLOCK_HZ = 28636364);
    reg clk = 0, reset = 1, gate = 1, address = 0, cs = 0, wr = 0, ack = 0;
    reg [15:0] data = 0;
    wire irq;
    timer #(.TIMER_WIDTH(16), .CLOCK_HZ(CLOCK_HZ)) dut(
        .I_RESET(reset), .I_CLK(clk), .I_GATE(gate), .I_A(address), .I_CS(cs),
        .I_WR(wr), .I_D(data), .O_D(), .O_INT(irq), .I_IACK(ack));
    always #5 clk = !clk;
    longint cycles = 0;
    integer count = 0, interval = 0, control = 0, interrupts = 0;
    integer ticks, next_count;
    reg expected_irq = 0, overflow;
    // Independent golden model: elapsed virtual ticks from absolute rational
    // time, then modular timer expiry. No DUT accumulator or reload logic used.
    always @(posedge clk) begin
        if (reset) begin
            cycles = 0; count = 0; interval = 0; control = 0; expected_irq = 0;
        end else begin
            ticks = int'(((cycles+1)*32000000)/CLOCK_HZ - (cycles*32000000)/CLOCK_HZ);
            cycles++;
            next_count = count - ((control & 2) != 0 && gate ? ticks : 0);
            overflow = next_count < 0;
            if (overflow) interrupts++;
            if (cs && wr && address && data[3]) count = interval;
            else if (overflow) count = (next_count + interval + 1) % (interval + 1);
            else count = next_count;
            if (ack) expected_irq = 0;
            else if (overflow) expected_irq = (control & 4) != 0;
            if (cs && wr && !address) interval = int'(data);
            if (cs && wr && address) begin
                control = int'(data[2:0]); expected_irq = data[0];
            end
        end
        #1;
        assert(dut.timer_cnt == 16'(count)) else $fatal(1, "counter clock=%0d cycle=%0d expected=%0d actual=%0d", CLOCK_HZ, cycles, count, dut.timer_cnt);
        assert(irq == expected_irq) else $fatal(1, "IRQ mismatch");
    end
    task write_reg(input bit select, input [15:0] value);
        @(negedge clk); address = select; data = value; cs = 1; wr = 1;
        @(negedge clk); cs = 0; wr = 0;
    endtask
    initial begin
        repeat (3) @(negedge clk);
        reset = 0;
        foreach_period(256);
        foreach_period(17);
        foreach_period(1);
        foreach_period(0);
        foreach_period(1023);
        assert(interrupts > 200) else $fatal;
        $display("PASS: MR16 32-MHz virtual timer at %0d Hz: reload/overshoot/gate/IRQ/ack/stop", CLOCK_HZ);
        $finish;
    end
    task foreach_period(input [15:0] value);
        write_reg(1, 0); // stop before changing interval
        write_reg(0, value);
        write_reg(1, 14); // run, IRQ enabled, force reload
        repeat (4000) @(negedge clk);
        gate = 0;
        repeat (30) @(negedge clk);
        gate = 1; ack = 1;
        repeat (10) @(negedge clk);
        ack = 0;
        repeat (100) @(negedge clk);
        write_reg(1, 0);
        repeat (30) @(negedge clk);
    endtask
endmodule
