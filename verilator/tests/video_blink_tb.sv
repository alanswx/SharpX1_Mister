// Actual helper and actual video reset release; no metastability model.
module video_blink_tb;
    timeunit 1ps;
    timeprecision 1ps;
    integer half_ps=11640;
    bit clk=0, running=1, core_reset=1, sub_blink=0;
    wire video_reset, synchronized_blink, compatible_blink;
    bit [1:0] reference_samples=0;
    bit early_control=0, raw_control=0;
    wire display_blink=raw_control ? sub_blink : early_control ? reference_samples[0] : synchronized_blink;
    time allowed_time=0;
    initial begin
        void'($value$plusargs("HALF_PS=%d",half_ps));
        early_control=$test$plusargs("EARLY_CONTROL");
        raw_control=$test$plusargs("RAW_CONTROL");
        forever begin #(half_ps); if(running) clk=~clk; else clk=0; end
    end
    x1_reset_release release_reset(clk,core_reset,video_reset);
    x1_video_blink #(.SYNCHRONIZE(1)) dut(clk,video_reset,sub_blink,synchronized_blink);
    x1_video_blink #(.SYNCHRONIZE(0)) compatible(clk,video_reset,sub_blink,compatible_blink);
    always @(posedge clk or posedge video_reset) begin
        allowed_time=$time;
        if(video_reset) reference_samples=0;
        else reference_samples={reference_samples[0],sub_blink};
        #1;
        assert(display_blink==reference_samples[1]) else $fatal(1,"blink two-sample latency mismatch");
    end
    always @(display_blink) if($time>0)
        assert($time==allowed_time) else $fatal(1,"blink changed away from video edge/reset");
    task automatic settle(input integer edges);
        repeat(edges) @(negedge clk);
        #2;
        assert(compatible_blink==sub_blink) else $fatal(1,"compatible blink path changed");
    endtask
    initial begin
        settle(4); core_reset=0; settle(6);
        for(integer phase=1;phase<=12;phase++) begin
            @(negedge clk); #(half_ps-phase); sub_blink=~sub_blink;
            @(posedge clk); #2;
            assert(display_blink!=sub_blink) else $fatal(1,"first blink stage leaked");
            @(posedge clk); #2;
            assert(display_blink==sub_blink) else $fatal(1,"second blink stage missed level");
            settle(3);
        end
        sub_blink=1; settle(4);
        running=0; #(half_ps*4); sub_blink=0; #(half_ps*4);
        assert(display_blink) else $fatal(1,"stopped video clock changed blink");
        core_reset=1; #3;
        assert(!display_blink && video_reset) else $fatal(1,"stopped-clock reset did not clear blink");
        sub_blink=1; core_reset=0; #(half_ps*8);
        assert(!display_blink && video_reset) else $fatal(1,"reset released without video edges");
        running=1; settle(8);
        assert(display_blink && !video_reset) else $fatal(1,"restart missed held blink level");
        core_reset=1; #3;
        assert(!display_blink) else $fatal(1,"blink reset reassertion failed");
        core_reset=0; settle(8);
        assert(display_blink) else $fatal(1,"blink reassertion restart failed");
        $display("PASS: X3 blink two stages, twelve near-edge phases, local reset, stopped-clock restart and compatible bypass");
        $finish;
    end
    initial begin #100000000; $fatal(1,"blink fixture timeout"); end
endmodule
