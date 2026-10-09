// Original GPL-2.0-or-later diagnostic of extracted inherited static policy.
// Ideal mux only: no claims about Intel primitive switching or pin CDC.
module hdmi_policy_tb;
    timeunit 1ps; timeprecision 1ps;
    bit clk_vid=0,clk_hdmi=0;
    int mode=0,hdmi_half=3366,profile=0,edges=0,checked=0;
    bit selected,stop_inactive=0;
    logic [23:0] dv_data=24'h110000,hdmi_data_osd=24'h220000;
    wire dv_hs=dv_data[0],dv_vs=dv_data[1],dv_de=dv_data[2];
    wire hdmi_hs_osd=hdmi_data_osd[0],hdmi_vs_osd=hdmi_data_osd[1],hdmi_de_osd=hdmi_data_osd[2];
    wire hdmi_cs_osd=~hdmi_data_osd[0];
    wire hs,vs,de,fixture_clk;
    wire [23:0] data_out;
    wire direct_video=mode[0],vga_fb=mode[1],csync_en=mode[2];
    hdmi_policy_fixture dut(.*,.HDMI_TX_HS(hs),.HDMI_TX_VS(vs),.HDMI_TX_DE(de),.HDMI_TX_D(data_out));
    logic [26:0] history[0:2];
    initial begin
        void'($value$plusargs("MODE=%d",mode));
        void'($value$plusargs("HDMI_HALF=%d",hdmi_half));
        void'($value$plusargs("PROFILE=%d",profile));
        assert(mode>=0 && mode<8 && hdmi_half>0 && profile>=0 && profile<3) else $fatal(1,"invalid policy fixture inputs");
        // Truth-table oracle, independently specified rather than copied mux.
        selected=(mode==1 || mode==5);
        for(int i=0;i<3;i++) history[i]=0;
        #100000000; $fatal(1,"HDMI policy did not finish");
    end
    initial forever begin
        #11640;
        if(!(stop_inactive && !selected)) clk_vid=~clk_vid;
    end
    initial begin
        #2;
        forever begin
            #(hdmi_half);
            if(!(stop_inactive && selected)) clk_hdmi=~clk_hdmi;
        end
    end
    always @(negedge clk_vid)
        if(!(profile==1 && !selected)) dv_data<=dv_data+24'd1;
    always @(negedge clk_hdmi)
        if(!(profile==1 && selected)) hdmi_data_osd<=hdmi_data_osd+24'd1;
    initial forever begin
        #1201;
        if(profile==1) begin
            if(selected) hdmi_data_osd=hdmi_data_osd+24'd7;
            else dv_data=dv_data+24'd7;
        end
    end
    always @(posedge fixture_clk) begin
        logic [26:0] sample,expected;
        assert(selected ? clk_vid : clk_hdmi) else $fatal(1,"HDMI clock/data mode association failed");
        // Direct: three edges; scaled and framebuffer/csync: two edges.
        if(selected) sample={dv_hs,dv_vs,dv_de,dv_data};
        else sample={(mode==7 ? hdmi_cs_osd : hdmi_hs_osd),hdmi_vs_osd,hdmi_de_osd,hdmi_data_osd};
        history[2]=history[1]; history[1]=history[0]; history[0]=sample;
        expected=history[selected ? 2 : 1];
        edges++;
        #1;
        if(edges>4) begin
            assert({hs,vs,de,data_out}===expected) else $fatal(1,"HDMI extracted policy latency/source mismatch mode=%0d edge=%0d got=%h expected=%h",mode,edges,{hs,vs,de,data_out},expected);
            checked++;
        end
        // Stop only the unused source while low, never truncate active edges.
        if(profile==2 && edges>40 && (selected ? !clk_hdmi : !clk_vid)) stop_inactive=1;
        if(edges==300) begin
            assert(checked==296 && (profile!=2 || stop_inactive)) else $fatal(1,"HDMI incomplete inactive-clock qualification");
            $display("PASS: extracted HDMI static policy mode=%0d half=%0d profile=%0d checks=%0d",mode,hdmi_half,profile,checked);
            $finish;
        end
    end
endmodule
