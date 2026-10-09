// SPDX-License-Identifier: GPL-2.0-or-later
// Diagnostic for the installed Intel primitive through a licensed simulator.
// Vendor bytes are not bundled. This is not FPGA pin/placement acceptance.
module hdmi_vendor_clock_tb;
    timeunit 1ps; timeprecision 1ps;
    bit clk_vid=0,clk_hdmi=0,select_video=0,transition=0;
    wire outclk;
    time vid_rise=0,hdmi_rise=0,last_edge=0;
    bit had_edge=0;
    int synthetic_rises=0,short_intervals=0,checked=0;
    cyclonev_clkselect dut(.inclk({clk_vid,clk_hdmi,2'b00}),
                          .clkselect({1'b1,select_video}),.outclk(outclk));
    always #11640 clk_vid=~clk_vid;
    initial begin #2; forever #3366 clk_hdmi=~clk_hdmi; end
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
            $display("OBSERVE: vendor output rise off selected-source rising edge t=%0t select=%0d",event_time,select_video);
        end
    end
    always @(outclk) begin
        if(transition && had_edge && $time-last_edge < 3366) begin
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
        #100000;
        check_stable(0);
        // Deliberately asynchronous requests, not a claimed safe protocol.
        transition=1;
        wait(!clk_hdmi && clk_vid); #3; select_video=1;
        #100000; transition=0;
        check_stable(1);
        transition=1;
        wait(!clk_vid && clk_hdmi); #3; select_video=0;
        #100000; transition=0;
        check_stable(0);
        assert(checked==48) else $fatal(1,"vendor clock diagnostic incomplete");
        $display("PASS: vendor primitive steady source selection checks=%0d",checked);
        $display("OBSERVATION ONLY: asynchronous switches off-source rises=%0d short intervals=%0d; no physical safe-switch claim",synthetic_rises,short_intervals);
        $finish;
    end
    initial begin #10000000; $fatal(1,"vendor clock diagnostic timeout"); end
endmodule
