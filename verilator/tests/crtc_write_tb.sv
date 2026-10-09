// Actual transaction helper, actual reset release and actual inherited MPU.
// No metastability model or native scanline-write timing claim.
module crtc_write_tb;
    timeunit 1ps;
    timeprecision 1ps;
    integer video_half=11640;
    bit cpu_clk=0, cpu_running=1, video_clk=0, running=1, reset=1;
    bit select=0, rs=0, raw_control=0;
    bit [7:0] data=0;
    wire video_reset, wait_n, video_write, video_rs;
    wire [7:0] video_data;
    wire [4:0] nadj, nr;
    integer writes=0;
    time video_edge=0;
    initial forever begin #15625; if(cpu_running) cpu_clk=~cpu_clk; end
    initial begin
        void'($value$plusargs("VIDEO_HALF=%d",video_half));
        raw_control=$test$plusargs("RAW_CONTROL");
        forever begin #(video_half); if(running) video_clk=~video_clk; else video_clk=0; end
    end
    x1_reset_release release_video(video_clk,reset,video_reset);
    x1_crtc_write dut(cpu_clk,reset,video_clk,video_reset,select,rs,data,
                      wait_n,video_write,video_rs,video_data);
    mpu_if target(.I_E(raw_control ? ~cpu_clk : ~video_clk),
        .I_DI(raw_control ? data : video_data),.I_RS(raw_control ? rs : video_rs),
        .I_RWn(raw_control ? !select : !video_write),
        .I_CSn(raw_control ? !select : !video_write),
        .O_Nadj(nadj),.O_Nr(nr),.O_Nht(),.O_Nhd(),.O_Nhsp(),.O_Nhsw(),
        .O_Nvt(),.O_Nvd(),.O_Nvsp(),.O_Nvsw(),.O_Msa(),.O_DScue(),
        .O_CScue(),.O_VMode(),.O_IntSync());
    always @(posedge video_clk) begin
        video_edge=$time;
        if(video_write && !video_reset) writes++;
    end
    always @(nadj or nr) if($time>1000000)
        assert($time==video_edge) else $fatal(1,"CRTC register changed away from destination edge");
    task automatic transaction(input bit address_bit, input byte value, input bit perturb=0);
        integer before_writes;
        before_writes=writes;
        @(negedge cpu_clk); rs=address_bit; data=value; select=1;
        #2; assert(!wait_n) else $fatal(1,"CRTC write did not immediately stop bus");
        repeat(2) @(negedge cpu_clk);
        if(perturb) begin rs=~address_bit; data=~value; end
        wait(wait_n); #2;
        assert(writes==before_writes+1) else $fatal(1,"CRTC WAIT released before exact target consumption");
        repeat(12) @(negedge cpu_clk);
        assert(writes==before_writes+1) else $fatal(1,"held bus duplicated CRTC write");
        select=0; repeat(3) @(negedge cpu_clk);
    endtask
    task automatic register_write(input byte index, input byte value);
        transaction(0,index,1);
        transaction(1,value,1);
    endtask
    initial begin
        repeat(5) @(negedge cpu_clk); reset=0;
        repeat(10) @(negedge video_clk);
        register_write(5,0); register_write(9,0);
        for(integer k=0;k<24;k++) begin
            register_write(5,byte'(k*11));
            assert(nadj==5'(k*11)) else $fatal(1,"CRTC Nadj packet corruption");
            register_write(9,byte'(k*7+3));
            assert(nr==5'(k*7+3)) else $fatal(1,"CRTC Nr packet corruption");
        end
        // A pending packet must not escape while video is stopped. Reset both
        // ends, release CPU first, then restart the held new request.
        @(negedge video_clk); running=0;
        @(negedge cpu_clk); rs=0;data=9;select=1;
        repeat(8) @(negedge cpu_clk);
        assert(!wait_n && !video_write) else $fatal(1,"stopped video accepted a write");
        reset=1; #3; select=0; reset=0;
        repeat(5) @(negedge cpu_clk);
        assert(video_reset && !video_write) else $fatal(1,"video reset released without edges");
        @(negedge cpu_clk); rs=0;data=5;select=1;
        repeat(5) @(negedge cpu_clk); running=1;
        wait(wait_n); select=0; repeat(4) @(negedge cpu_clk);
        transaction(1,8'h16,1);
        assert(nadj==5'h16) else $fatal(1,"reset/restart changed register ordering");
        assert(nr==5'(23*7+3)) else $fatal(1,"transport reset cleared retained target registers");
        // Reset after destination capture but BEFORE target consumption.
        transaction(0,5);
        begin
            integer before_writes=writes;
            @(negedge cpu_clk);rs=1;data=8'h1b;select=1;
            wait(video_write);#1;reset=1;#3;select=0;reset=0;
            repeat(8) @(negedge video_clk);repeat(4) @(negedge cpu_clk);
            assert(writes==before_writes && nadj==5'h16)
                else $fatal(1,"reset failed to cancel unconsumed CRTC write");
        end
        // Reset after target consumption but BEFORE the source sees ACK.
        transaction(0,9);
        begin
            integer before_writes=writes;
            @(negedge cpu_clk);rs=1;data=8'h1f;select=1;
            wait(writes==before_writes+1);#1;
            assert(!wait_n && nr==5'h1f) else $fatal(1,"CRTC ACK escaped target edge");
            reset=1;#3;select=0;reset=0;
            repeat(8) @(negedge video_clk);repeat(4) @(negedge cpu_clk);
            assert(writes==before_writes+1 && nr==5'h1f)
                else $fatal(1,"reset lost/duplicated consumed CRTC write");
        end
        // Destination can finish while SYS is stopped, but source WAIT/data
        // must remain held until acknowledgement synchronization resumes.
        transaction(0,5);
        begin
            integer before_writes=writes;
            @(negedge cpu_clk);rs=1;data=8'h11;select=1;
            wait(dut.busy);cpu_running=0;
            wait(writes==before_writes+1);#1;
            repeat(8) @(negedge video_clk);
            assert(!wait_n && nadj==5'h11 && dut.held_packet==9'h111)
                else $fatal(1,"stopped SYS lost CRTC packet/WAIT");
            cpu_running=1;wait(wait_n);select=0;
            repeat(4) @(negedge cpu_clk);
            assert(writes==before_writes+1) else $fatal(1,"SYS restart duplicated CRTC write");
        end
        $display("PASS: actual CRTC MPU coherent RS/data, exact writes, held WAIT, perturbation, stopped SYS/VID and pre/post-consumption reset/restart");
        $finish;
    end
    initial begin #1000000000; $fatal(1,"CRTC transport timeout"); end
endmodule
