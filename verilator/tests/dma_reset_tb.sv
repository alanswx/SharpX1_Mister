`timescale 1ns/1ps
// SPDX-License-Identifier: GPL-2.0-or-later
// Original ownership/reset-controller test. Inputs model ownership, not a
// substitute for the actual-CPU or connected-FDC acceptance gates.
module dma_reset_tb;
    logic clk=0, clock_running=1, reset_request=0;
    logic dma_busak_n=1, dma_busrq_n=1;
    wire machine_reset, cpu_run, dma_reset, draining;
    always #5 if(clock_running) clk=!clk;
    x1_dma_reset dut(.clk(clk),.reset_request(reset_request),
        .dma_busak_n(dma_busak_n),.dma_busrq_n(dma_busrq_n),
        .machine_reset(machine_reset),.cpu_run(cpu_run),
        .dma_reset(dma_reset),.draining(draining));
    task release_reset;
        for(integer edge_count=1;edge_count<=4;edge_count++) begin
            @(posedge clk); #0.001;
            assert(machine_reset == (edge_count<4)) else
                $fatal(1,"reset hold duration edge%0d",edge_count);
        end
        assert(cpu_run && !dma_reset && !draining) else $fatal(1,"reset release");
    endtask
    initial begin
        #1; assert(cpu_run && !machine_reset && !dma_reset);
        // Idle, awaiting grant, and request-released/ACK-retained boundaries.
        for(integer boundary=0;boundary<3;boundary++) begin
            @(negedge clk);
            dma_busak_n=boundary!=2; dma_busrq_n=boundary!=1;
            #1; reset_request=1; #0.001;
            assert(machine_reset && !cpu_run && dma_reset && !draining)
                else $fatal(1,"unowned boundary reset");
            #1; reset_request=0;
            release_reset();
        end
        // Owned pair, short pulse; stalled DMA never revokes actual ownership.
        @(negedge clk); dma_busak_n=0; dma_busrq_n=0;
        #1; reset_request=1; #0.001;
        assert(!machine_reset && !cpu_run && dma_reset && draining);
        #1; reset_request=0;
        repeat(20) begin
            @(posedge clk); #0.001;
            assert(!machine_reset && !cpu_run && dma_reset && draining)
                else $fatal(1,"reset revoked stalled grant");
        end
        @(negedge clk); dma_busrq_n=1; #0.001;
        assert(machine_reset && !cpu_run) else $fatal(1,"reset after drain");
        release_reset();
        // Physical SYS clock stopped: pulse still retained, cannot time out.
        @(negedge clk); clock_running=0; dma_busak_n=0; dma_busrq_n=0;
        #1; reset_request=1; #1; reset_request=0; #100;
        assert(draining && !machine_reset && !cpu_run && dma_reset);
        dma_busrq_n=1; #1;
        assert(machine_reset && !cpu_run);
        clock_running=1;
        release_reset();
        // A held request does not consume the four-edge release interval.
        @(negedge clk); dma_busak_n=1; reset_request=1;
        repeat(12) begin @(posedge clk); #0.001; assert(machine_reset && !cpu_run); end
        @(negedge clk); reset_request=0;
        release_reset();
        $display("PASS: DMA reset ownership boundaries, retained short pulse, stopped clock, indefinite stalled grant and four-edge release");
        $finish;
    end
endmodule
