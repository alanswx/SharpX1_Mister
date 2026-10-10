// SPDX-License-Identifier: GPL-2.0-only
// Original full-store/public-port diagnostic. All bytes generated, not fonts.
`timescale 1ps/1ps
module z_kanji_rom_tb;
    logic cpu_clk,video_clk,cpu_reset=1,video_reset=1;
    initial begin cpu_clk=0; video_clk=0; end
    logic cpu_run=1,video_run=1;
    integer video_half_ps=17500,writes;
    initial writes=0;
    always #15625 if(cpu_run) cpu_clk=!cpu_clk;
    always #(video_half_ps) if(video_run) video_clk=!video_clk;
    logic upload=0,load=0,cpu_read=0,display_select=0;
    logic [24:0] load_address=0;
    logic [7:0] load_data=0;
    logic [17:0] cpu_address=0,display_address=0;
    wire [7:0] cpu_data,display_data;
    wire cpu_valid,display_valid,loaded,load_error;
    x1_z_kanji_rom dut(.*);
    always @(posedge cpu_clk) if(dut.write_entry) writes<=writes+1;
    function automatic logic [7:0] pattern(input integer a,input integer seed);
        return 8'((a*37) ^ ((a/256)*13) ^ ((a/65536)*211) ^ seed);
    endfunction
    task automatic ctick;@(posedge cpu_clk);#1;endtask
    task automatic vtick;@(posedge video_clk);#1;endtask
    task automatic begin_upload;
        @(negedge cpu_clk);cpu_reset=1;video_reset=1;cpu_read=1;display_select=1;
        upload=1;load=0;ctick();
        assert(!loaded && !cpu_valid && !display_valid && cpu_data==0 && display_data==0)
            else $fatal(1,"upload leaked availability");
    endtask
    task automatic put(input integer a,input integer seed);
        assert(a>=0 && a<=33554431) else $fatal(1,"fixture upload address bound");
        @(negedge cpu_clk);load=1;load_address=25'(a);load_data=pattern(a,seed);
        ctick();
        assert(!loaded && !cpu_valid && !display_valid) else $fatal(1,"partial upload published");
    endtask
    task automatic end_upload(input bit good,input bit orphan=0,input bit release_reset=0);
        @(negedge cpu_clk);upload=0;load=orphan;
        if(release_reset) begin cpu_reset=0;video_reset=0;end
        ctick();
        assert(loaded==good && load_error==!good) else $fatal(1,"commit contract");
        @(negedge cpu_clk);load=0;cpu_reset=0;video_reset=0;
        repeat(5) vtick();ctick();
        assert(cpu_valid==good && display_valid==good) else $fatal(1,"readiness propagation");
        if(!good) assert(cpu_data==0 && display_data==0) else $fatal(1,"bad image leaked");
    endtask
    task automatic full_upload(input integer seed,input bit trailing=0,input bit orphan=0,
                               input bit release_reset=0,input bit coincident=0);
        integer before_writes;
        before_writes=writes;
        if(coincident) begin
            @(negedge cpu_clk);cpu_reset=1;video_reset=1;cpu_read=1;display_select=1;
            upload=1;load=1;load_address=0;load_data=pattern(0,seed);ctick();
        end else begin_upload();
        for(integer a=coincident ? 1 : 0;a<262144;a++) put(a,seed);
        if(trailing) put(262144,seed);
        end_upload(!trailing && !orphan && !release_reset,orphan,release_reset);
        assert(writes-before_writes==262144) else $fatal(1,"trailing alias/write count");
    endtask
    task automatic read_all(input integer seed);
        for(integer a=0;a<262144;a++) begin
            @(negedge cpu_clk);cpu_address=18'(a);display_address=18'(262143-a);
            ctick();vtick();
            assert(cpu_valid && display_valid && cpu_data==pattern(a,seed) &&
                   display_data==pattern(262143-a,seed))
                else $fatal(1,"Z ROM byte mismatch %0d",a);
        end
    endtask
    initial begin
        if($value$plusargs("VIDEO_HALF_PS=%d",video_half_ps)) begin end
        repeat(4) ctick();repeat(4) vtick();
        assert(!loaded && !cpu_valid && !display_valid) else $fatal(1,"cold valid");
        begin_upload();end_upload(0);
        begin_upload();put(0,1);put(1,1);end_upload(0);
        begin_upload();put(1,1);put(0,1);end_upload(0);
        begin_upload();put(0,1);put(2,1);put(1,1);end_upload(0);
        begin_upload();put(0,1);put(0,1);end_upload(0);
        begin_upload();put(0,1);put(33554431,1);end_upload(0);
        // Losing either reset within an upload poisons it permanently.
        begin_upload();put(0,1);@(negedge cpu_clk);cpu_reset=0;ctick();
        cpu_reset=1;put(1,1);end_upload(0);
        begin_upload();put(0,1);@(negedge cpu_clk);video_reset=0;ctick();
        video_reset=1;put(1,1);end_upload(0);
        full_upload(0,1);full_upload(0,0,1);full_upload(0,0,0,1);
        full_upload(19,0,0,0,1);read_all(19);
        @(negedge cpu_clk);cpu_read=0;display_select=0;ctick();vtick();
        assert(!cpu_valid && !display_valid && cpu_data==0 && display_data==0)
            else $fatal(1,"inactive read drove data");
        @(negedge cpu_clk);cpu_read=1;display_select=1;ctick();vtick();
        assert(cpu_valid && display_valid) else $fatal(1,"fresh read not registered");
        @(negedge cpu_clk);cpu_reset=1;video_reset=1;#1;
        assert(loaded && !cpu_valid && !display_valid) else $fatal(1,"warm mask/retention");
        repeat(5) ctick();repeat(5) vtick();cpu_reset=0;video_reset=0;
        repeat(5) vtick();ctick();read_all(19);
        // Pulse reset entirely between edges: old valid must not return.
        @(negedge cpu_clk);#100;cpu_reset=1;video_reset=1;#100;
        assert(loaded && !cpu_valid && !display_valid) else $fatal(1,"short reset mask");
        #100;cpu_reset=0;video_reset=0;#100;
        assert(!cpu_valid && !display_valid) else $fatal(1,"stale valid after short reset");
        ctick();repeat(5) vtick();
        assert(cpu_valid && display_valid && cpu_data==pattern(262143,19) &&
               display_data==pattern(0,19)) else $fatal(1,"short reset fresh read");
        @(negedge video_clk);video_run=0;video_reset=1;#1;
        assert(!display_valid && cpu_valid && loaded) else $fatal(1,"stopped video mask");
        for(integer a=0;a<64;a++) begin
            @(negedge cpu_clk);cpu_address=18'(a*4096);ctick();
            assert(cpu_valid && cpu_data==pattern(a*4096,19)) else $fatal(1,"CPU needs VID");
        end
        video_reset=0;#1;assert(!display_valid) else $fatal(1,"VID stale valid");
        video_run=1;repeat(5) vtick();
        @(negedge cpu_clk);cpu_run=0;cpu_reset=1;#1;
        assert(!cpu_valid && display_valid && loaded) else $fatal(1,"stopped CPU mask");
        for(integer a=0;a<64;a++) begin
            @(negedge video_clk);display_address=18'(a*4096);vtick();
            assert(display_valid && display_data==pattern(a*4096,19)) else $fatal(1,"VID needs CPU");
        end
        cpu_reset=0;#1;assert(!cpu_valid) else $fatal(1,"CPU stale valid");
        cpu_run=1;ctick();
        @(negedge cpu_clk);upload=1;load=1;load_address=0;load_data=8'hee;ctick();
        assert(!loaded && load_error && !dut.write_entry) else $fatal(1,"live upload accepted");
        cpu_reset=1;video_reset=1;put(1,99);end_upload(0);
        full_upload(83);read_all(83);
        @(negedge cpu_clk);load=1;load_address=0;load_data=255;ctick();
        assert(!loaded && load_error && !dut.write_entry) else $fatal(1,"orphan write accepted");
        @(negedge cpu_clk);load=0;repeat(5) vtick();
        assert(!cpu_valid && !display_valid && cpu_data==0 && display_data==0)
            else $fatal(1,"orphan availability retained");
        $display("PASS Z ROM: 262144 bytes BOTH ports x3 scans; half-period=%0d; exact loader/poison/bounds/trailing/orphan/live/reset/clock-stop cancellation",video_half_ps);
        $finish;
    end
endmodule
