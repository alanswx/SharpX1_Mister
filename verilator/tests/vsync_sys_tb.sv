// Actual helper and mirrored existing SYS filter/config consumers.
// Does not instantiate full sys_top or simulate metastability.
module vsync_sys_tb;
    timeunit 1ps;
    timeprecision 1ps;
    integer half_ps=15625, source_half_ps=3366;
    bit clk=0, source_clk=0, running=1, raw_vs=0;
    wire clean_vs, synchronized_vs;
    bit raw_control=0, early_control=0;
    bit early_sample=0;
    initial begin
        raw_control=$test$plusargs("RAW_CONTROL");
        early_control=$test$plusargs("EARLY_CONTROL");
    end
    always @(posedge clk) early_sample<=raw_vs;
    assign clean_vs=raw_control ? raw_vs : early_control ? early_sample : synchronized_vs;
    bit cfg_ready=0, cfg_set=0, cfg_got=0;
    bit vs_d0=0, vs_d1=0, vs_d2=0, vsd=0, vsd2=0;
    integer observed_rises=0, expected_rises=0;
    bit [1:0] reference_samples=0;
    time last_sys_edge=0;
    initial begin
        void'($value$plusargs("HALF_PS=%d",half_ps));
        void'($value$plusargs("SOURCE_HALF_PS=%d",source_half_ps));
        forever begin #(half_ps); if(running) clk=~clk; else clk=0; end
    end
    initial begin
        #1;
        forever #(source_half_ps) source_clk=~source_clk;
    end
    x1_vsync_sys dut(clk,raw_vs,synchronized_vs);
    always @(posedge clk) begin
        last_sys_edge=$time;
        reference_samples={reference_samples[0],raw_vs};
        vs_d0<=clean_vs;
        if(vs_d0==clean_vs) vs_d1<=vs_d0;
        vs_d2<=vs_d1;
        if(!vs_d2 && vs_d1) observed_rises<=observed_rises+1;
        if(!cfg_ready || !cfg_set) cfg_got<=cfg_set;
        else begin
            vsd<=clean_vs;
            vsd2<=vsd;
            if(!vsd2 && vsd) cfg_got<=cfg_set;
        end
        #1;
        assert(clean_vs==reference_samples[1]) else $fatal(1,"VSYNC two-sample latency mismatch");
    end
    always @(clean_vs) if($time>0)
        assert($time==last_sys_edge) else $fatal(1,"VSYNC changed away from SYS edge");
    task automatic settle(input integer cycles);
        repeat(cycles) @(negedge clk);
        #2;
    endtask
    initial begin
        settle(6);
        // First edge after a near-edge source transition cannot release it.
        @(negedge clk); #(half_ps-1); raw_vs=1;
        @(posedge clk); #2;
        assert(!clean_vs) else $fatal(1,"first-stage leaked to consumer");
        @(posedge clk); #2;
        assert(clean_vs) else $fatal(1,"second-stage failed release");
        expected_rises++;
        settle(8); raw_vs=0; settle(8);
        // Wide source pulses; the helper intentionally does not queue short ones.
        for(integer phase=1;phase<=12;phase++) begin
            cfg_ready=1; cfg_set=1;
            @(negedge source_clk); #(phase*3); raw_vs=1;
            expected_rises++;
            settle(10);
            assert(cfg_got) else $fatal(1,"enabled config did not observe VSYNC");
            raw_vs=0; cfg_set=0; settle(10);
            assert(!cfg_got) else $fatal(1,"config disable failed clear");
            assert(observed_rises==expected_rises) else $fatal(1,"lost/duplicated frame wait event");
        end
        cfg_ready=0; cfg_set=1; settle(3);
        assert(cfg_got) else $fatal(1,"not-ready config bypass changed");
        cfg_set=0; settle(4);
        running=0; #(half_ps*4);
        raw_vs=1; #(half_ps*8);
        assert(!clean_vs) else $fatal(1,"stopped SYS clock changed VSYNC");
        running=1; settle(10); expected_rises++;
        assert(clean_vs && observed_rises==expected_rises) else $fatal(1,"stopped-clock restart lost level/event");
        $display("PASS: VSYNC two-stage SYS level, near edge, 12 source phases, frame filter/config gate and stopped-clock restart");
        $finish;
    end
    initial begin #100000000; $fatal(1,"VSYNC fixture timeout"); end
endmodule
