// SPDX-License-Identifier: GPL-2.0-or-later
// Native helper phase/reset fixture, not actual DV/DDR or machine reset proof.
module hdmi_handoff_reset_tb;
    timeunit 1ps; timeprecision 1ps;
    bit control=0,video=0,hdmi=0,reset_request=0,policy_ready=1;
    bit [2:0] requested=0;
    int phase=0,stop_ready=0,video_half=11640,hdmi_half=3366;
    int unsigned qualification_complete=0;
    wire outclock,blank,busy;
    wire [2:0] active;
    time video_rise=0,hdmi_rise=0,last_edge=0;
    bit had_edge=0,reset_completed=0;
    x1_hdmi_clock_handoff dut(.clk_control(control),.clk_video(video),.clk_hdmi(hdmi),
        .reset_request(reset_request),.requested_mode(requested),.video_policy_ready(policy_ready),
        .clk_output(outclock),.active_mode(active),.output_blank(blank),.busy(busy),.video_policy_epoch());
    always #15625 control=~control;
    initial begin #1; forever #(video_half) video=~video; end
    initial begin #2; forever #(hdmi_half) hdmi=~hdmi; end
    always @(posedge video) video_rise=$time;
    always @(posedge hdmi) hdmi_rise=$time;
    always @(outclock) begin
        if(had_edge) assert($time-last_edge >= (video_half < hdmi_half ? video_half : hdmi_half))
            else $fatal(1,"phase reset shortened output interval");
        last_edge=$time; had_edge=1;
    end
    always @(posedge outclock) begin
        time edge_time;
        edge_time=$time;
        #0;
        assert(edge_time==(active[0] ? video_rise : hdmi_rise)) else $fatal(1,"phase reset mismatched clock/mode");
        #1;
        if(reset_completed && reset_request)
            assert(blank && active==0) else $fatal(1,"completed reset lost blank/baseline mode");
    end
    always @(active) if($time)
        assert(blank && !outclock && !dut.gate_open) else $fatal(1,"phase reset changed mode before gate closure");
    initial begin
        void'($value$plusargs("PHASE=%d",phase));
        void'($value$plusargs("STOP_READY=%d",stop_ready));
        void'($value$plusargs("VIDEO_HALF=%d",video_half));
        void'($value$plusargs("HDMI_HALF=%d",hdmi_half));
        assert(phase>=0 && phase<8 && stop_ready>=0 && stop_ready<=1) else $fatal(1,"invalid reset phase");
        if(phase>=3) begin
            wait(!busy && !blank);
            @(negedge control); requested=3'b111;
        end
        wait(dut.state==phase);
        @(negedge control);
        assert(dut.state==phase) else $fatal(1,"reset fixture missed chosen state");
        reset_request=1;
        policy_ready=!stop_ready;
        // Acknowledge the actual reset transaction, not the initial blank.
        wait(active==0 && blank && dut.state==1 && dut.gate_sample && dut.ack_sample &&
             dut.completed_sample==dut.generation);
        reset_completed=1;
        repeat(100) @(posedge control);
        @(negedge control); requested=0; reset_request=0; policy_ready=1;
        wait(!busy && active==0 && !blank);
        repeat(20) @(posedge outclock);
        @(negedge control); requested=3'b111;
        wait(!busy && active==3'b111 && !blank);
        repeat(20) @(posedge outclock);
        @(negedge control); requested=0;
        wait(!busy && active==0 && !blank);
        qualification_complete=1;
        $display("PASS: native handoff reset phase=%0d stopped_ready=%0d video_half=%0d hdmi_half=%0d",phase,stop_ready,video_half,hdmi_half);
        $finish;
    end
    initial begin #20000000; $fatal(1,"phase reset failed to recover"); end
endmodule
