// SPDX-License-Identifier: GPL-2.0-only
// Original independent-domain reset/reacquisition fixture. No metastability
// or native ASIC/palette-memory timing claim follows from digital simulation.
`timescale 1ps/1ps
module z_palette_owner_reset_tb #(parameter LOCAL_RESET_RELEASE = 1);
    reg cpu_clk=0, video_clk=0, reset=1;
    reg run_cpu=1, run_video=1, cpu_request=0, video_blank=1;
    integer half=11640;
    always #15625 if(run_cpu) cpu_clk=~cpu_clk;
    always #(half) if(run_video) video_clk=~video_clk;
    wire cpu_permit, display_allowed;
    x1_z_palette_owner #(.LOCAL_RESET_RELEASE(LOCAL_RESET_RELEASE)) owner(.*);
    always @(posedge cpu_clk) begin
        #1;
        assert(!(cpu_permit && display_allowed)) else $fatal(1,"CPU/display overlap");
    end
    always @(posedge video_clk) begin
        #1;
        assert(!(cpu_permit && display_allowed)) else $fatal(1,"video/display overlap");
    end
    task automatic cpu_tick;
        @(posedge cpu_clk); #1;
    endtask
    task automatic acquire;
        integer ticks;
        ticks=0;
        while(!cpu_permit) begin
            cpu_tick(); ticks++;
            assert(ticks<64) else $fatal(1,"fresh lease timeout");
        end
        assert(!display_allowed) else $fatal(1,"grant without display exclusion");
    endtask
    initial begin
        if($value$plusargs("video_half=%d",half)) begin end
        repeat(4) cpu_tick();
        @(negedge cpu_clk); reset=0;
        repeat(8) cpu_tick();
        assert(display_allowed && !cpu_permit) else $fatal(1,"initial idle");
        cpu_request=1; acquire();
        // Reset a real owned lease while both destination clocks are stopped.
        @(negedge video_clk); run_video=0;
        @(negedge cpu_clk); run_cpu=0;
        #137; reset=1; #1;
        assert(!cpu_permit && !display_allowed) else $fatal(1,"asynchronous ownership mask");
        #137; cpu_request=0; reset=0;
        #1000000;
        assert(!display_allowed) else $fatal(1,"display released without video edges");
        assert(!cpu_permit) else $fatal(1,"old grant survived stopped-clock reset");
        // CPU may restart and request, but cannot invent a grant while VID is
        // still stopped and its local reset has not released.
        run_cpu=1; cpu_request=1;
        repeat(20) begin
            cpu_tick();
            assert(!cpu_permit && !display_allowed) else $fatal(1,"stopped-video grant/reset leak");
        end
        run_video=1;
        @(posedge video_clk); #1;
        assert(!display_allowed) else $fatal(1,"video reset released on first edge");
        @(posedge video_clk); #1;
        assert(display_allowed && !cpu_permit) else $fatal(1,"video reset second-edge release");
        acquire();
        // Hold an actual grant, then reset with CPU stopped but VID running.
        @(negedge cpu_clk); run_cpu=0;
        #137; reset=1; #1;
        assert(!cpu_permit && !display_allowed) else $fatal(1,"stopped-CPU assertion");
        #137; cpu_request=0; reset=0;
        repeat(8) begin @(posedge video_clk); #1; end
        assert(display_allowed && !cpu_permit) else $fatal(1,"independent video restart");
        assert(owner.cpu_reset) else $fatal(1,"CPU reset released without CPU edges");
        run_cpu=1;
        cpu_tick();
        assert(owner.cpu_reset && !cpu_permit) else $fatal(1,"CPU first-edge reset release");
        cpu_tick();
        assert(!owner.cpu_reset && !cpu_permit) else $fatal(1,"CPU second-edge reset release");
        cpu_request=1; acquire();
        cpu_request=0;
        repeat(20) cpu_tick();
        assert(display_allowed && !cpu_permit) else $fatal(1,"final lease drain");
        $display("PASS palette local reset: immediate assertion, both stopped clocks, independent two-edge release, fresh grants and drain; half=%0d",half);
        $finish;
    end
    initial begin #100000000; $fatal(1,"palette reset watchdog"); end
endmodule
