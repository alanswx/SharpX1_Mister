// SPDX-License-Identifier: GPL-2.0-only
// Original live-input HDMI measurement isolation/period fixture. No force,
// native pulse-width, metastability, placement or hardware timing claim.
`timescale 1ps/1ps
module hps_hdmi_measure_case #(parameter COHERENT=1, HALF=11640, EXPECT_SYNC=COHERENT)(output bit done=0);
    bit clk_100=0, clk_sys=0, clk_vid=0, running=1, hdmi_vs=0;
    always #5000 if(running) clk_100=~clk_100;
    always #15625 clk_sys=~clk_sys;
    always #(HALF) clk_vid=~clk_vid;
    wire [15:0] dout;
    bit [3:0] selector=12;
    video_calc #(.COHERENT_SNAPSHOTS(COHERENT)) dut(
        .clk_100(clk_100),.clk_sys(clk_sys),.clk_vid(clk_vid),
        .ce_pix(1'b0),.de(1'b0),.hs(1'b0),.vs(1'b0),.vs_hdmi(hdmi_vs),
        .f1(1'b0),.new_vmode(1'b0),.video_rotated(1'b0),.par_num(selector),.dout(dout));
    bit first=0,second=0,old=0,older=0;
    integer period_count=0,events=0;
    integer expected_period=0;
    bit checked=0;
    always @(posedge clk_100) begin
        // Independent clock-count oracle follows the unchanged measurement
        // algorithm using an independently delayed raw input, not DUT state.
        if(!older && old) begin
            if(events>1) begin
                expected_period=period_count;
                checked=1;
            end
            period_count=0;events++;
        end else period_count++;
        older=old;
        old=EXPECT_SYNC ? second : hdmi_vs;
        second=first;first=hdmi_vs;
        #2;
        // Check every clock, not just after expected updates: a detector
        // bypass can produce correct intervals at the wrong update edge.
        if(checked) assert(dut.vid_vtime_hdmi==expected_period)
            else $fatal(1,"HDMI measurement consumer bypassed stage two or changed period coherent=%0d got=%0d expected=%0d",COHERENT,dut.vid_vtime_hdmi,expected_period);
        assert(dut.measured_hdmi_vs==(EXPECT_SYNC ? second : hdmi_vs))
            else $fatal(1,"HDMI input bypassed two-stage synchronizer");
    end
    initial begin
        // The source clock is unrelated to the 100 MHz measurement clock.
        for(integer pulse=0;pulse<8;pulse++) begin
            // Vary intervals so an early update cannot hide behind the same
            // counter value on successive frames.
            repeat(64+3*pulse) @(negedge clk_vid);
            #137;hdmi_vs=1;
            repeat(12) @(negedge clk_vid);
            #137;hdmi_vs=0;
        end
        assert(checked && events>=6) else $fatal(1,"no actual HDMI period measurements");
        // Drain the just-fallen source level before stopping its sampler;
        // retaining the previous high while stopped would be correct behavior.
        repeat(4) @(negedge clk_100);
        assert(!dut.measured_hdmi_vs) else $fatal(1,"pre-stop low not settled");
        @(negedge clk_100);running=0;
        #1000;hdmi_vs=1;#1000;
        if(COHERENT) assert(!dut.measured_hdmi_vs) else $fatal(1,"stopped measurement clock propagated raw HDMI VS");
        #70000;running=1;
        repeat(4) @(negedge clk_100);
        assert(dut.measured_hdmi_vs) else $fatal(1,"HDMI sync did not recover");
        hdmi_vs=0;
        repeat(4) @(negedge clk_100);
        assert(!dut.measured_hdmi_vs) else $fatal(1,"HDMI low did not recover");
        // A live interval spanning both counter halves exercises the actual
        // held snapshot and HPS reads, without forced measurement registers.
        repeat(70000) @(negedge clk_100);
        hdmi_vs=1;
        repeat(5) @(negedge clk_100);
        assert(expected_period>65535) else $fatal(1,"live high counter half missing");
        repeat(64) @(negedge clk_sys);
        selector=12;
        repeat(2) @(negedge clk_sys);
        assert(dout==16'(expected_period)) else $fatal(1,"live HPS HDMI low half mismatch");
        selector=13;
        repeat(2) @(negedge clk_sys);
        assert(dout==16'(expected_period>>16)) else $fatal(1,"live HPS HDMI high half mismatch");
        done=1;
    end
endmodule

module hps_hdmi_measure_negative_tb;
    wire done;
    // Actual legacy bypass must fail the unchanged two-stage oracle, not a
    // timeout or missing signal. No RTL state is forced for this control.
    hps_hdmi_measure_case #(0,11640,1) bypass(done);
    initial begin wait(done);$fatal(1,"unexpected raw HDMI acceptance");end
    initial begin #2000000000;$fatal(1,"negative HDMI watchdog");end
endmodule

module hps_hdmi_measure_tb;
    wire [3:0] done;
    hps_hdmi_measure_case #(1,11640) x3(done[0]);
    hps_hdmi_measure_case #(1,17500) base(done[1]);
    hps_hdmi_measure_case #(1,25000) slow(done[2]);
    hps_hdmi_measure_case #(0,11640) legacy(done[3]);
    initial begin wait(&done);$display("PASS live HDMI measurement: three unrelated clock ratios, exact update edges/periods, live HPS halves, stopped clock recovery and unchanged legacy route");$finish;end
    initial begin #2000000000;$fatal(1,"HDMI measurement watchdog");end
endmodule
