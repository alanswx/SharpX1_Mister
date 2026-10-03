`timescale 1ns/1ps
module clock_enables_tb;
    reg clk = 0, reset = 1;
    wire cpu_ce, psg_ce;
    x1_clock_enables dut(clk, reset, cpu_ce, psg_ce);
    always #5 clk = !clk;
    integer cpu_count, psg_count, last_cpu, last_psg;
    integer saved_cpu, saved_psg;
    task run_phase;
        cpu_count = 0; psg_count = 0; last_cpu = 0; last_psg = 0;
        @(posedge clk); #1; reset = 0;
        for (integer i = 1; i <= 100000; i++) begin
            @(posedge clk);
            if (cpu_ce) begin
                if (last_cpu != 0) assert(i-last_cpu == 7 || i-last_cpu == 8) else $fatal;
                last_cpu = i; cpu_count++;
            end
            if (psg_ce) begin
                if (last_psg != 0) assert(i-last_psg == 14 || i-last_psg == 15) else $fatal;
                last_psg = i; psg_count++;
            end
            // Count error is bounded to one tick throughout, not only at the end.
            assert(64'(cpu_count) == (64'(i)*4000000)/28636364 ||
                   64'(cpu_count) == (64'(i)*4000000)/28636364+1) else $fatal;
            assert(64'(psg_count) == (64'(i)*2000000)/28636364 ||
                   64'(psg_count) == (64'(i)*2000000)/28636364+1) else $fatal;
        end
    endtask
    initial begin
        run_phase();
        saved_cpu = cpu_count; saved_psg = psg_count;
        #1; reset = 1; #1;
        assert(dut.cpu_phase == 0 && dut.psg_phase == 0) else $fatal;
        run_phase();
        assert(cpu_count == saved_cpu && psg_count == saved_psg) else $fatal;
        $display("PASS: fractional enables, bounded rate error, 7/8 and 14/15 spacing, reset repeatability");
        $finish;
    end
endmodule
