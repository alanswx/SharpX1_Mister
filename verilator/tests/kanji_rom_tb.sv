// SPDX-License-Identifier: GPL-2.0-only
// Original asynchronous clock/read/loader fixture. All ROM bytes synthetic.
`timescale 1ps/1ps
module kanji_rom_tb;
    logic cpu_clk=0,video_clk=0,cpu_reset=1,video_reset=1;
    logic cpu_run=1,video_run=1;
    integer video_half_ps=17500,writes=0;
    always #15625 if(cpu_run) cpu_clk=!cpu_clk;
    always #(video_half_ps) if(video_run) video_clk=!video_clk;
    logic upload=0,load=0,cpu_read=0,display_select=0;
    logic [24:0] load_address=0;
    logic [7:0] load_data=0;
    logic [16:0] cpu_address=0;
    wire [16:0] display_address;
    logic [7:0] display_dkan=0,display_dcha=0;
    logic [3:0] display_row=0;
    wire [7:0] cpu_data,display_data;
    wire cpu_valid,display_valid,loaded,load_error;
    x1_kanji_rom dut(.*);
    x1_kanji_address address_decoder (
        .level1_enable(display_select),.dkan(display_dkan),.dcha(display_dcha),
        .raster(display_row),.rom_address(),.rom_oe_n(),.byte_address(display_address)
    );
    always @(posedge cpu_clk) if(dut.write_entry) writes++;
    function automatic logic [7:0] pattern(input integer address,input integer seed);
        return 8'(address*37+(address>>8)*13+(address>>16)*211+seed);
    endfunction
    task automatic ctick;@(posedge cpu_clk);#1;endtask
    task automatic vtick;@(posedge video_clk);#1;endtask
    task automatic begin_upload;
        @(negedge cpu_clk);cpu_reset=1;video_reset=1;cpu_read=1;display_select=1;
        upload=1;load=0;ctick();
        assert(!loaded && !cpu_valid && !display_valid && cpu_data==0 && display_data==0)
            else $fatal(1,"upload did not hide ROM");
    endtask
    task automatic put(input integer address,input integer seed);
        @(negedge cpu_clk);load=1;load_address=25'(address);load_data=pattern(address,seed);
        ctick();
        assert(!loaded && !cpu_valid && !display_valid)
            else $fatal(1,"partial/trailing upload published ROM");
    endtask
    task automatic end_upload(input bit good,input bit orphan_at_end=0,input bit release_at_end=0);
        @(negedge cpu_clk);load=orphan_at_end;upload=0;
        if(release_at_end) begin cpu_reset=0;video_reset=0;end
        ctick();
        assert(loaded==good && load_error==!good) else $fatal(1,"upload commit status");
        @(negedge cpu_clk);load=0;cpu_reset=0;video_reset=0;
        repeat(5) vtick();ctick();
        assert(cpu_valid==good && display_valid==good) else $fatal(1,"readiness propagation");
        if(!good) assert(cpu_data==0 && display_data==0) else $fatal(1,"invalid image leaked bytes");
    endtask
    task automatic full_upload(input integer seed,input bit append_bad,input bit orphan_at_end=0,
                               input bit release_at_end=0,input bit first_at_start=0);
        integer before_writes;
        before_writes=writes;
        if(first_at_start) begin
            @(negedge cpu_clk);cpu_reset=1;video_reset=1;cpu_read=1;display_select=1;
            upload=1;load=1;load_address=0;load_data=pattern(0,seed);ctick();
            assert(!loaded && !cpu_valid && !display_valid)
                else $fatal(1,"coincident begin published ROM");
        end else begin_upload();
        for(integer address=first_at_start ? 1 : 0;address<131072;address++) put(address,seed);
        if(append_bad) put(131072,seed);
        end_upload(!append_bad && !orphan_at_end && !release_at_end,orphan_at_end,release_at_end);
        assert(writes-before_writes==131072) else $fatal(1,"upload write count/trailing alias");
    endtask
    task automatic read_all(input integer seed);
        integer physical;
        // Complementary addresses, both ports active on unrelated clocks.
        for(integer address=0;address<131072;address++) begin
            @(negedge cpu_clk);cpu_address=17'(address);physical=131071-address;
            display_dkan=8'((physical/65536)*64+(physical%65536)/4096);
            display_dcha=8'((physical%4096)/16);display_row=4'(physical%16);
            ctick();vtick();
            assert(cpu_valid && display_valid && cpu_data==pattern(address,seed) &&
                   display_data==pattern(131071-address,seed))
                else $fatal(1,"ROM byte mismatch at %0d",address);
        end
    endtask
    initial begin
        if($value$plusargs("VIDEO_HALF_PS=%d",video_half_ps)) begin end
        repeat(4) ctick();repeat(4) vtick();
        assert(!loaded && !cpu_valid && !display_valid) else $fatal(1,"cold ROM availability");
        // Short, missing-zero, gap and duplicate streams all fail closed.
        begin_upload();end_upload(0);
        begin_upload();put(0,1);put(1,1);end_upload(0);
        begin_upload();put(1,1);put(0,1);end_upload(0);
        begin_upload();put(0,1);put(2,1);put(1,1);end_upload(0);
        begin_upload();put(0,1);put(0,1);put(1,1);end_upload(0);
        begin_upload();put(0,1);put(33554431,1);end_upload(0);
        full_upload(0,1); // valid last byte does not commit before upload end
        full_upload(0,0,1); // falling upload with a byte strobe is not a commit
        full_upload(0,0,0,1); // resets must remain asserted on commit edge
        full_upload(19,0,0,0,1);read_all(19); // first byte may coincide with begin
        // Each valid bit follows the local memory/read-select edge. No reads
        // are acknowledged solely because ROM loading completed earlier.
        @(negedge cpu_clk);cpu_read=0;display_select=0;ctick();vtick();
        assert(!cpu_valid && !display_valid && cpu_data==0 && display_data==0)
            else $fatal(1,"inactive read drove ROM");
        @(negedge cpu_clk);cpu_read=1;display_select=1;ctick();vtick();
        assert(cpu_valid && display_valid) else $fatal(1,"fresh read not enabled");
        // Warm reset masks outputs immediately and retains all valid bytes.
        @(negedge cpu_clk);cpu_reset=1;video_reset=1;#1;
        assert(loaded && !cpu_valid && !display_valid) else $fatal(1,"warm reset availability");
        repeat(5) ctick();repeat(5) vtick();cpu_reset=0;video_reset=0;
        repeat(5) vtick();ctick();read_all(19);
        // Even a reset entirely between CPU/video edges must flush stale
        // read-valid. Retained ROM may be read again only on fresh edges.
        @(negedge cpu_clk);#100;cpu_reset=1;video_reset=1;#100;
        assert(loaded && !cpu_valid && !display_valid) else $fatal(1,"short reset mask");
        #100;cpu_reset=0;video_reset=0;#100;
        assert(!cpu_valid && !display_valid) else $fatal(1,"short reset retained stale read-valid");
        ctick();repeat(5) vtick();
        assert(cpu_valid && display_valid && cpu_data==pattern(131071,19) &&
               display_data==pattern(0,19)) else $fatal(1,"short reset fresh read/retention");
        // Independent reset/clock domains: the other reader keeps working,
        // and stopped clocks cannot prevent an asynchronous validity flush.
        @(negedge video_clk);video_run=0;video_reset=1;#1;
        assert(!display_valid && cpu_valid && loaded) else $fatal(1,"video-only reset");
        for(integer address=0;address<64;address++) begin
            @(negedge cpu_clk);cpu_address=17'(address*2048);ctick();
            assert(cpu_valid && cpu_data==pattern(address*2048,19))
                else $fatal(1,"CPU reader required running video clock");
        end
        video_reset=0;#1;
        assert(!display_valid) else $fatal(1,"stopped video reset release restored stale valid");
        video_run=1;repeat(5) vtick();
        @(negedge cpu_clk);cpu_run=0;cpu_reset=1;#1;
        assert(!cpu_valid && display_valid && loaded) else $fatal(1,"CPU-only reset");
        for(integer address=0;address<64;address++) begin
            @(negedge video_clk);display_dkan=8'(address);display_dcha=8'(address*3);
            display_row=4'(address);vtick();
            assert(display_valid && display_data==pattern(int'(display_address),19))
                else $fatal(1,"video reader required running CPU clock");
        end
        cpu_reset=0;#1;
        assert(!cpu_valid) else $fatal(1,"stopped CPU reset release restored stale valid");
        cpu_run=1;ctick();
        assert(cpu_valid && cpu_data==pattern(63*2048,19)) else $fatal(1,"CPU restart read");
        // Unauthorized live upload cannot alter memory, even after resets
        // are later asserted within that same malformed transaction.
        @(negedge cpu_clk);upload=1;load=1;load_address=0;load_data=8'hee;
        ctick();assert(!loaded && load_error && !dut.write_entry)
            else $fatal(1,"live upload accepted");
        cpu_reset=1;video_reset=1;put(1,99);end_upload(0);
        // Fresh reload replaces every byte, never exposing stale chip halves.
        full_upload(83,0);read_all(83);
        // Orphan writes are rejected outside an upload and invalidate ready.
        @(negedge cpu_clk);load=1;load_address=0;load_data=8'hff;ctick();
        assert(!loaded && load_error && !dut.write_entry) else $fatal(1,"orphan write accepted");
        @(negedge cpu_clk);load=0;repeat(5) vtick();
        assert(!cpu_valid && !display_valid && cpu_data==0 && display_data==0)
            else $fatal(1,"orphan upload retained availability");
        $display("PASS Kanji first-level storage half-period=%0d ps: exact uploads, all 131072 bytes on both ports, warm retention/reload, short/gap/duplicate/bounds/trailing/live/orphan rejection",video_half_ps);
        $finish;
    end
endmodule
