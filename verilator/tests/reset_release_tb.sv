`timescale 1ns/1ps
// SPDX-License-Identifier: GPL-2.0-or-later
// Original reset phase/stopped-clock fixture, not metastability simulation.
module reset_release_tb;
    logic clk=0, async_reset=0, clock_running=1;
    wire reset;
    integer half_period=7;
    initial void'($value$plusargs("VIDEO_HALF=%d",half_period));
    always #(half_period) if(clock_running) clk=!clk;
    x1_reset_release dut(.*);
    task check_release;
        @(posedge clk); #0.001;
        assert(reset) else $fatal(1,"released on first destination edge");
        @(posedge clk); #0.001;
        assert(!reset) else $fatal(1,"not released on second destination edge");
    endtask
    initial begin
        // Vary release phase, including a pulse wholly between clock edges.
        for(integer phase=1;phase<half_period;phase++) begin
            @(negedge clk); #0.01; async_reset=1; #0.001;
            assert(reset) else $fatal(1,"assertion waited for clock");
            #(phase); async_reset=0;
            check_release();
        end
        @(negedge clk); clock_running=0;
        #1; async_reset=1; #0.001;
        assert(reset) else $fatal(1,"stopped-clock assertion");
        #1; async_reset=0;
        #(6*half_period);
        assert(reset) else $fatal(1,"release without destination edges");
        clock_running=1;
        check_release();
        $display("PASS: asynchronous assertion, two-edge release, short pulses and stopped destination half=%0d",half_period);
        $finish;
    end
endmodule
