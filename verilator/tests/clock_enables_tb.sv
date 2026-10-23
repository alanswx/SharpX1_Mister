`timescale 1ns/1ps
module clock_enables_tb #(parameter MASTER_HZ = 28636364);
    // Enable spacing is floor/ceil of master/rate: 7/8 and 14/15 at 28.6 MHz.
    // Fast (tape) mode: CPU at 16 MHz, 2/3 at 42.95 MHz; PSG unchanged.
    localparam integer PSG_MIN = MASTER_HZ / 2000000;
    integer cpu_hz, CPU_MIN;
    reg clk = 0, reset = 1, fast = 0;
    wire cpu_ce, psg_ce;
    x1_clock_enables #(.MASTER_HZ(MASTER_HZ)) dut(.clk(clk), .reset(reset), .fast(fast), .cpu_ce(cpu_ce), .psg_ce(psg_ce));
    always #5 clk = !clk;
    integer cpu_count, psg_count, last_cpu, last_psg;
    integer saved_cpu, saved_psg;
    task run_phase;
        cpu_hz = fast ? 16000000 : 4000000; CPU_MIN = MASTER_HZ / cpu_hz;
        cpu_count = 0; psg_count = 0; last_cpu = 0; last_psg = 0;
        @(posedge clk); #1; reset = 0;
        for (integer i = 1; i <= 100000; i++) begin
            @(posedge clk);
            if (cpu_ce) begin
                if (last_cpu != 0) assert(i-last_cpu == CPU_MIN || i-last_cpu == CPU_MIN+1) else $fatal;
                last_cpu = i; cpu_count++;
            end
            if (psg_ce) begin
                if (last_psg != 0) assert(i-last_psg == PSG_MIN || i-last_psg == PSG_MIN+1) else $fatal;
                last_psg = i; psg_count++;
            end
            // Count error is bounded to one tick throughout, not only at the end.
            assert(64'(cpu_count) == (64'(i)*cpu_hz)/64'(MASTER_HZ) ||
                   64'(cpu_count) == (64'(i)*cpu_hz)/64'(MASTER_HZ)+1) else $fatal;
            assert(64'(psg_count) == (64'(i)*2000000)/64'(MASTER_HZ) ||
                   64'(psg_count) == (64'(i)*2000000)/64'(MASTER_HZ)+1) else $fatal;
        end
    endtask
    initial begin
        run_phase();
        saved_cpu = cpu_count; saved_psg = psg_count;
        #1; reset = 1; #1;
        assert(dut.cpu_phase == 0 && dut.psg_phase == 0) else $fatal;
        run_phase();
        assert(cpu_count == saved_cpu && psg_count == saved_psg) else $fatal;
        #1; reset = 1; fast = 1; #1;
        run_phase();
        assert(psg_count == saved_psg) else $fatal;
        $display("PASS: fast CPU enable %0d/%0d spacing, %0d enables", CPU_MIN, CPU_MIN+1, cpu_count);
        fast = 0;
        $display("PASS: fractional enables at %0d Hz, bounded rate error, %0d/%0d PSG spacing, reset repeatability", MASTER_HZ, PSG_MIN, PSG_MIN+1);
        $finish;
    end
endmodule
