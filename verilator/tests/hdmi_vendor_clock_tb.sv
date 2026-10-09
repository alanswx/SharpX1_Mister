// SPDX-License-Identifier: GPL-2.0-or-later
// Diagnostic for the installed Intel primitive through a licensed simulator.
// Vendor bytes are not bundled. This is not FPGA pin/placement acceptance.
module hdmi_vendor_clock_tb;
    timeunit 1ps; timeprecision 1ps;
    bit clk_vid=0,clk_hdmi=0,select_video=0,transition=0;
    bit run_vid=1,run_hdmi=1;
    int video_half=11640,hdmi_half=3366,stop_profile=0;
    wire outclk;
    time vid_rise=0,hdmi_rise=0,last_edge=0;
    bit had_edge=0;
    int synthetic_rises=0,short_intervals=0,checked=0;
`ifdef HDMI_ALTCLKCTRL
    // Locally generated vendor IP; never embedded or selected by a board.
    x1_hdmi_clockctrl dut(.inclk({clk_vid,clk_hdmi}),
                         .clkselect(select_video),.outclk(outclk));
`else
    cyclonev_clkselect dut(.inclk({clk_vid,clk_hdmi,2'b00}),
                          .clkselect({1'b1,select_video}),.outclk(outclk));
`endif
    initial begin #1; forever #(video_half) if(run_vid) clk_vid=~clk_vid; end
    initial begin #2; forever #(hdmi_half) if(run_hdmi) clk_hdmi=~clk_hdmi; end
    always @(posedge clk_vid) vid_rise=$time;
    always @(posedge clk_hdmi) hdmi_rise=$time;
    always @(posedge outclk) begin
        time event_time;
        event_time=$time;
        // Let all same-time native edge observers finish before comparison.
        // A same-delta scheduling race is not an off-source primitive edge.
        #0;
        if(transition && event_time != (select_video ? vid_rise : hdmi_rise)) begin
            synthetic_rises++;
            $display("OBSERVE: vendor output rise off requested-source rising edge t=%0t request=%0d",event_time,select_video);
        end
    end
    always @(outclk) begin
        if(transition && had_edge && $time-last_edge < (video_half < hdmi_half ? video_half : hdmi_half)) begin
            short_intervals++;
            $display("OBSERVE: vendor output edge interval %0t ps during switch",$time-last_edge);
        end
        had_edge=1; last_edge=$time;
    end
    task automatic check_stable(input bit video);
        repeat(8) begin
            if(video) @(posedge clk_vid); else @(posedge clk_hdmi);
            #1;
            assert(outclk===1'b1) else $fatal(1,"vendor steady selected clock high mismatch");
            if(video) @(negedge clk_vid); else @(negedge clk_hdmi);
            #1;
            assert(outclk===1'b0) else $fatal(1,"vendor steady selected clock low mismatch");
            checked+=2;
        end
    endtask
    initial begin
        void'($value$plusargs("VIDEO_HALF=%d",video_half));
        void'($value$plusargs("HDMI_HALF=%d",hdmi_half));
        void'($value$plusargs("STOP_PROFILE=%d",stop_profile));
        assert(video_half>0 && hdmi_half>0 && stop_profile>=0 && stop_profile<=2) else $fatal(1,"invalid vendor switch profile");
`ifndef HDMI_ALTCLKCTRL
        assert(stop_profile==0) else $fatal(1,"stopped-source contract belongs to ALTCLKCTRL candidate");
`endif
        #100000;
        check_stable(0);
        // Deliberately asynchronous requests, not a claimed safe protocol.
        transition=1;
        if(stop_profile==0) begin
            wait(!clk_hdmi && clk_vid); #3; select_video=1;
        end else begin
            if(stop_profile==1) begin @(negedge clk_vid); run_vid=0; end
            else begin @(negedge clk_hdmi); run_hdmi=0; end
            #3; select_video=1;
            #200000;
            assert(outclk===1'b0) else $fatal(1,"stopped-source candidate did not stay quiescent");
            $display("PASS: stopped source profile=%0d remains quiescent before recovery",stop_profile);
            run_vid=1; run_hdmi=1;
        end
        #100000; transition=0;
        check_stable(1);
        transition=1;
        wait(!clk_vid && clk_hdmi); #3; select_video=0;
        #100000; transition=0;
        check_stable(0);
        assert(checked==48) else $fatal(1,"vendor clock diagnostic incomplete");
`ifdef HDMI_ALTCLKCTRL
        assert(short_intervals==0) else $fatal(1,"glitch-free candidate shortened an output interval");
        $display("PASS: ALTCLKCTRL candidate no short intervals in two switches; stop_profile=%0d",stop_profile);
`endif
        $display("PASS: vendor primitive steady source selection checks=%0d video_half=%0d hdmi_half=%0d stop_profile=%0d",checked,video_half,hdmi_half,stop_profile);
        $display("OBSERVATION ONLY: asynchronous switches off-source rises=%0d short intervals=%0d; no physical safe-switch claim",synthetic_rises,short_intervals);
        $finish;
    end
    initial begin #10000000; $fatal(1,"vendor clock diagnostic timeout"); end
endmodule
