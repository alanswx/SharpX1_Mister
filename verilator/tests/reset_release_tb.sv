`timescale 1ns/1ps
// SPDX-License-Identifier: GPL-2.0-or-later
// Original reset phase/stopped-clock fixture, not metastability simulation.
module reset_release_tb;
    logic clk=0, async_reset=0, clock_running=1;
    wire reset;
    integer half_period=7;
    integer half_ps=0;
    initial void'($value$plusargs("VIDEO_HALF=%d",half_period));
    initial if($value$plusargs("VIDEO_HALF_PS=%d",half_ps))
        assert(half_ps>0 && half_ps<100000) else $fatal(1,"bad reset test clock");
    always #(half_ps != 0 ? half_ps*0.001 : half_period) if(clock_running) clk=!clk;
    x1_reset_release dut(.*);
    task check_release;
        @(posedge clk); #0.001;
        assert(reset) else $fatal(1,"released on first destination edge");
        @(posedge clk); #0.001;
        assert(!reset) else $fatal(1,"not released on second destination edge");
    endtask
    initial begin
        // Vary release phase, including a pulse wholly between clock edges.
        for(integer phase=1000;phase<(half_ps != 0 ? half_ps : half_period*1000);phase+=1000) begin
            @(negedge clk); #0.01; async_reset=1; #0.001;
            assert(reset) else $fatal(1,"assertion waited for clock");
            #(phase*0.001); async_reset=0;
            check_release();
        end
        // Reassert between the first and second release edges. The pending
        // release must be cancelled and a fresh pair of edges required.
        repeat(4) begin
            @(negedge clk); async_reset=1; #0.001; async_reset=0;
            @(posedge clk); #0.001;
            assert(reset) else $fatal(1,"pending release lost first edge");
            @(negedge clk); #0.001; async_reset=1; #0.001; async_reset=0;
            check_release();
        end
        // Digital release 1 ps before a rising edge, without an on-edge race.
        @(negedge clk); async_reset=1;
        #((half_ps != 0 ? half_ps*0.001 : half_period)-0.001); async_reset=0;
        check_release();
        @(negedge clk); clock_running=0;
        #1; async_reset=1; #0.001;
        assert(reset) else $fatal(1,"stopped-clock assertion");
        #1; async_reset=0;
        #(6*(half_ps != 0 ? half_ps*0.001 : half_period));
        assert(reset) else $fatal(1,"release without destination edges");
        clock_running=1;
        check_release();
        $display("PASS: async assertion, two-edge release, reassertion, edge phase and stopped clock half_ps=%0d",half_ps != 0 ? half_ps : half_period*1000);
        $finish;
    end
endmodule
