// SPDX-License-Identifier: GPL-2.0-or-later
// Native clocks and actual extracted output registers, not the upstream OSD/PHY.
module hdmi_handoff_policy_tb;
    timeunit 1ps; timeprecision 1ps;
    bit clk_control=0,clk_vid=0,clk_hdmi=0,reset_request=0;
    int hdmi_half=3366,video_half=11640,mode=0,checked=0;
    int unsigned qualification_complete=0;
    bit direct_video=0,vga_fb=0,csync_en=0;
    bit ce_pix=1;
    logic [23:0] dv_data=24'ha50000,hdmi_data_osd=24'h5a0000;
    wire dv_hs=dv_data[0],dv_vs=dv_data[1],dv_de=dv_data[2];
    wire hdmi_hs_osd=hdmi_data_osd[0],hdmi_vs_osd=hdmi_data_osd[1],hdmi_de_osd=hdmi_data_osd[2];
    wire hdmi_cs_osd=~hdmi_data_osd[0];
    wire fixture_clk,fixture_blank,fixture_busy;
    wire [2:0] fixture_mode;
    wire hs,vs,de;
    wire [23:0] data_out;
    logic [26:0] history[0:2];
    hdmi_policy_fixture dut(.*,.HDMI_TX_HS(hs),.HDMI_TX_VS(vs),.HDMI_TX_DE(de),.HDMI_TX_D(data_out));
    always #15625 clk_control=~clk_control;
    initial begin #1; forever #(video_half) clk_vid=~clk_vid; end
    initial begin #2; forever #(hdmi_half) clk_hdmi=~clk_hdmi; end
    always @(negedge clk_vid) dv_data<=dv_data+1'b1;
    always @(negedge clk_hdmi) hdmi_data_osd<=hdmi_data_osd+1'b1;
    always @(posedge fixture_clk) begin
        logic [26:0] sample,expected;
        if(fixture_mode[0]) sample={dv_hs,dv_vs,dv_de,dv_data};
        else sample={(fixture_mode[2] && fixture_mode[1] ? hdmi_cs_osd : hdmi_hs_osd),hdmi_vs_osd,hdmi_de_osd,hdmi_data_osd};
        history[2]=history[1]; history[1]=history[0]; history[0]=sample;
        expected=history[fixture_mode[0] ? 2 : 1];
        #1;
        if(fixture_blank) begin
            assert(de===0 && data_out===0) else $fatal(1,"actual HDMI output not blanked");
        end else begin
            assert({hs,vs,de,data_out}===expected) else $fatal(1,"actual HDMI handoff pipeline mismatch");
            checked++;
        end
    end
    initial begin
        void'($value$plusargs("HDMI_HALF=%d",hdmi_half));
        void'($value$plusargs("VIDEO_HALF=%d",video_half));
        foreach(history[i]) history[i]=0;
        wait(!fixture_busy && !fixture_blank);
        // A stopped pixel enable must NOT fabricate upstream-policy readiness.
        @(negedge clk_control); ce_pix=0; direct_video=1;
        #2000000;
        assert(fixture_busy && fixture_blank) else $fatal(1,"missing native DV CE acknowledgement");
        // Abort that incomplete video epoch, then retry while CE stays stopped.
        @(negedge clk_control); reset_request=1;
        wait(fixture_mode==0 && fixture_blank);
        repeat(10) @(posedge clk_control);
        @(negedge clk_control); reset_request=0;
        #2000000;
        assert(fixture_busy && fixture_blank) else $fatal(1,"aborted DV epoch reused stale readiness");
        ce_pix=1;
        wait(!fixture_busy && !fixture_blank && fixture_mode==3'b011);
        repeat(3) begin
            for(int test_mode=0;test_mode<8;test_mode++) begin
                bit [2:0] expected_mode;
                @(negedge clk_control);
                mode=test_mode;
                direct_video=mode[0]; vga_fb=mode[1]; csync_en=mode[2];
                expected_mode={mode[2],mode[0],(mode==1 || mode==5)};
                wait(!fixture_busy && !fixture_blank && fixture_mode==expected_mode);
                repeat(20) @(posedge fixture_clk);
            end
            @(negedge clk_control); reset_request=1;
            wait(fixture_mode==0 && fixture_blank);
            repeat(10) @(posedge clk_control);
            @(negedge clk_control); reset_request=0;
            wait(!fixture_busy && !fixture_blank);
        end
        assert(checked>=480) else $fatal(1,"missing actual-policy coverage");
        qualification_complete=1;
        $display("PASS: actual HDMI handoff policy video_half=%0d hdmi_half=%0d checks=%0d",video_half,hdmi_half,checked);
        $finish;
    end
    initial begin #100000000; $fatal(1,"actual-policy timeout"); end
endmodule
