// SPDX-License-Identifier: GPL-2.0-or-later
// Native primitive controller diagnostic; no actual HDMI datapath/PHY claim.
module hdmi_handoff_vendor_tb;
    timeunit 1ps; timeprecision 1ps;
    bit control=0, video=0, hdmi=0, reset_request=0;
    bit run_video=1, run_hdmi=1;
    int video_half=11640, hdmi_half=3366, stop_level=0;
    bit [2:0] requested=0;
    wire outclock, blank, busy;
    wire [2:0] active;
    time last_edge=0, video_rise=0, hdmi_rise=0;
    bit had_edge=0;
    int visible_video=0, visible_hdmi=0, switches=0;
    int unsigned qualification_complete=0;
    reg [7:0] video_word=0, hdmi_word=0;
    reg [10:0] pipe0=0, pipe1=0, pipe2=0;
`ifdef HDMI_RAW_MODE_NEGATIVE
    wire [2:0] data_mode=requested;
`else
    wire [2:0] data_mode=active;
`endif
    always @(posedge video) video_word <= video_word+1'b1;
    always @(posedge hdmi) hdmi_word <= hdmi_word+1'b1;
    // Real source-clocked tokens through a three-edge output pipeline.
    // This is a diagnostic datapath, not an extracted OSD or HDMI PHY.
    always @(posedge outclock) begin
        pipe0 <= {data_mode,data_mode[0] ? video_word : hdmi_word};
        pipe1 <= pipe0;
        pipe2 <= pipe1;
    end
    x1_hdmi_clock_handoff dut(.clk_control(control),.clk_video(video),.clk_hdmi(hdmi),
        .reset_request(reset_request),.requested_mode(requested),.video_policy_ready(1'b1),
        .clk_output(outclock),.active_mode(active),.output_blank(blank),.busy(busy),.video_policy_epoch());
    always #15625 control=~control;
    initial begin #1; forever #(video_half) if(run_video) video=~video; end
    initial begin #2; forever #(hdmi_half) if(run_hdmi) hdmi=~hdmi; end
    always @(posedge video) video_rise=$time;
    always @(posedge hdmi) hdmi_rise=$time;
    always @(outclock) begin
        if(had_edge) assert($time-last_edge >= (video_half < hdmi_half ? video_half : hdmi_half))
            else $fatal(1,"handoff short output interval");
        last_edge=$time; had_edge=1;
    end
    always @(posedge outclock) begin
        time edge_time;
        edge_time=$time;
        #0;
        assert(edge_time == (active[0] ? video_rise : hdmi_rise))
            else $fatal(1,"output edge disagrees with acknowledged mode");
        if(!blank) begin
            assert(pipe2[10:8]==active) else $fatal(1,"visible data used unacknowledged mode");
            if(active[0]) visible_video++; else visible_hdmi++;
        end
    end
    always @(active) if($time) begin
        assert(!outclock && blank && !dut.gate_open)
            else $fatal(1,"active mode changed before blanked native gate closure");
        switches++;
    end
    task automatic request(input bit [2:0] mode);
        @(negedge control); requested=mode;
        wait(!busy && active==mode && !blank);
        repeat(10) @(posedge outclock);
    endtask
    initial begin
        void'($value$plusargs("VIDEO_HALF=%d",video_half));
        void'($value$plusargs("HDMI_HALF=%d",hdmi_half));
        void'($value$plusargs("STOP_LEVEL=%d",stop_level));
        assert(stop_level==0 || stop_level==1) else $fatal(1,"invalid stopped level");
        wait(!busy && !blank);
        request(3'b011); request(3'b110); request(3'b001); request(3'b000);
        // Change all qualifiers with the same source, then queue a reversal.
        @(negedge control); requested=3'b111;
        wait(busy); repeat(3) @(negedge control); requested=3'b010;
        wait(!busy && active==3'b010 && !blank);
        repeat(10) @(posedge outclock);
        // Stop incoming video low; handoff must stay blank until it resumes.
        if(stop_level) @(posedge video); else @(negedge video);
        run_video=0;
        @(negedge control); requested=3'b001;
        #1500000;
        assert(busy || blank) else $fatal(1,"stopped incoming source unblanked");
        run_video=1;
        wait(!busy && active==3'b001 && !blank);
        repeat(10) @(posedge outclock);
        // Stop outgoing video: there can be no fake blank/gate acknowledgement.
        if(stop_level) @(posedge video); else @(negedge video);
        run_video=0;
        @(negedge control); requested=3'b000;
        #1500000;
        assert(busy && active==3'b001) else $fatal(1,"stopped outgoing source fabricated handoff");
        run_video=1;
        wait(!busy && active==0 && !blank);
        request(3'b111);
        @(negedge control); reset_request=1;
        wait(active==0 && blank);
        repeat(20) @(posedge control);
        assert(blank) else $fatal(1,"reset request unblanked output");
        @(negedge control); reset_request=0; requested=0;
        wait(!busy && !blank);
        repeat(10) @(posedge outclock);
        assert(visible_video>=30 && visible_hdmi>=30 && switches>=8)
            else $fatal(1,"insufficient handoff coverage");
        $display("PASS: native acknowledged handoff video_half=%0d hdmi_half=%0d stop_level=%0d switches=%0d visible=%0d/%0d",video_half,hdmi_half,stop_level,switches,visible_video,visible_hdmi);
        qualification_complete=1;
        $finish;
    end
    initial begin #50000000; $fatal(1,"handoff timeout"); end
endmodule
