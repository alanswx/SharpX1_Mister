`timescale 1ns/1ps
// Original asynchronous level/latency fixture, no forced machine state.
module video_status_tb;
    reg clk=0, video_clk=0, run_clock=1, reset=1;
    reg vdisp=1, vsync=1;
    wire sys_disp, sys_sync, base_disp, base_sync;
    reg [1:0] expected_meta=0, expected_sys=0;
    integer video_half=7, checks=0;
    always #5 if(run_clock) clk=!clk;
    initial begin
        if($value$plusargs("VIDEO_HALF=%d",video_half)) begin end
        forever #(video_half) video_clk=!video_clk;
    end
    x1_video_status #(.SYNCHRONIZE(1)) synced(clk,reset,vdisp,vsync,sys_disp,sys_sync);
    x1_video_status #(.SYNCHRONIZE(0)) compatible(clk,reset,vdisp,vsync,base_disp,base_sync);
    always @(posedge clk or posedge reset) begin
        if(reset) begin expected_meta=0; expected_sys=0; end
        else begin expected_sys=expected_meta; expected_meta={vdisp,vsync}; end
        #1;
        assert({sys_disp,sys_sync}==expected_sys) else $fatal(1,"two-stage latency/reset mismatch");
        assert({base_disp,base_sync}=={vdisp,vsync}) else $fatal(1,"base status path changed");
        checks++;
    end
    task stable_level(input [1:0] level);
        @(negedge video_clk); #2; {vdisp,vsync}=level;
        repeat(4) @(negedge clk);
        assert({sys_disp,sys_sync}==level) else $fatal(1,"persistent level lost");
    endtask
    initial begin
        #2; assert({sys_disp,sys_sync}==0 && {base_disp,base_sync}==3) else $fatal;
        #11; reset=0;
        for(int i=0;i<32;i++) stable_level(2'(i));
        // Reset asserts while destination clock is stopped, with high inputs.
        @(negedge clk); run_clock=0; {vdisp,vsync}=3;
        #2; reset=1; #2;
        assert({sys_disp,sys_sync}==0 && {base_disp,base_sync}==3) else $fatal(1,"stopped-clock reset failed");
        #17; reset=0; #19;
        assert({sys_disp,sys_sync}==0) else $fatal(1,"stopped clock advanced status");
        run_clock=1;
        repeat(4) @(negedge clk);
        assert({sys_disp,sys_sync}==3) else $fatal(1,"resumed clock lost level");
        for(int i=0;i<32;i++) stable_level(2'(i>>1));
        $display("PASS: independent PPI status levels, two-stage latency, compatible bypass, stopped clock/reset, %0d checks video half=%0d",checks,video_half);
        $finish;
    end
    initial begin #100000; $fatal(1,"status crossing timeout"); end
endmodule
