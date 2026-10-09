// SPDX-License-Identifier: GPL-2.0-only
// Original normal external-palette transaction test. No firmware/font assets.
`timescale 1ps/1ps
module z_palette_access_tb;
    logic clk=0,video_clk=0;
    integer ce_period=1,video_half_ps=17500;
    always #15625 clk=!clk;
    always #(video_half_ps) video_clk=!video_clk;
    logic reset=1,external_enabled=1,read_mode=0,permit=1;
    logic io_read=0,io_write=0;
    logic [15:0] address=0;
    logic [7:0] data=0;
    wire selected,wait_n,read_valid,ram_access,ram_write,ram_valid;
    wire [3:0] read_nibble,ram_nibble,ram_data;
    wire [11:0] ram_address;
    wire [1:0] ram_component;
    logic allow_response=1;
    wire backend_valid;
    wire [3:0] backend_data;
    logic saved_valid=0;
    logic [3:0] saved_data=0;
    logic [11:0] display_address=0;
    logic display_read=0;
    wire [11:0] display_rgb12;
    wire display_valid;
    integer requests=0,writes=0;
    x1_z_palette_access dut(.*);
    // Fixture-only latency injection retains the real RAM response while
    // delivery is withheld; the adapter must not invent an early completion.
    assign ram_valid=allow_response && (backend_valid || saved_valid);
    assign ram_data=backend_valid ? backend_data : saved_data;
    always @(posedge clk) begin
        if(reset) saved_valid<=0;
        else if(backend_valid && !allow_response) begin saved_valid<=1;saved_data<=backend_data;end
        else if(allow_response) saved_valid<=0;
    end
    x1_z_palette_ram store(
        .cpu_clk(clk),.video_clk(video_clk),.cpu_reset(reset),.video_reset(reset),
        .cpu_access(ram_access),.cpu_write(ram_write),.cpu_address(ram_address),
        .cpu_component(ram_component),.cpu_nibble(ram_nibble),
        .cpu_data(backend_data),.cpu_valid(backend_valid),
        .display_read(display_read),.display_address(display_address),
        .display_rgb12(display_rgb12),.display_valid(display_valid)
    );
    always @(posedge clk) if(ram_access) begin requests++;if(ram_write) writes++;end
    task automatic tick;@(posedge clk);#1;endtask
    task automatic idle;
        @(negedge clk);io_read=0;io_write=0;tick();
        assert(wait_n && !read_valid && !ram_access) else $fatal(1,"idle response");
    endtask
    function automatic integer pattern(input integer index,component,seed);
        return (index*3+(index/16)*5+(index/256)*7+seed+component)%16;
    endfunction
    task automatic out(input integer port,input integer value,input bit reading);
        integer before_requests,before_writes;
        before_requests=requests;before_writes=writes;
        @(negedge clk);address=16'(port);data=8'(value);read_mode=reading;io_write=1;
        repeat(5*ce_period) tick();
        assert(wait_n && !read_valid && requests==before_requests+(reading ? 0 : 1)
               && writes==before_writes+(reading ? 0 : 1)) else $fatal(1,"held OUT dedup/selector");
        idle();
    endtask
    task automatic read(input integer port,input integer expected);
        integer before_requests,before_writes;
        before_requests=requests;before_writes=writes;
        @(negedge clk);address=16'(port);read_mode=1;io_read=1;
        repeat(5*ce_period) tick();
        assert(wait_n && read_valid && read_nibble==4'(expected)
               && requests==before_requests+1 && writes==before_writes)
            else $fatal(1,"read port=%h expected=%h got=%h",port,expected,read_nibble);
        repeat(4*ce_period) tick();
        assert(read_valid && read_nibble==4'(expected) && requests==before_requests+1)
            else $fatal(1,"read response must persist without another RAM request");
        idle();
    endtask
    initial begin
        if($value$plusargs("CE_PERIOD=%d",ce_period)) begin end
        if($value$plusargs("VIDEO_HALF_PS=%d",video_half_ps)) begin end
        repeat(3) tick();@(negedge clk);reset=0;idle();
        // Cold image read via real selector operations before any RAM write.
        for(integer index=0;index<4096;index++) begin
            for(integer component=0;component<3;component++) begin
                out(('h1000+component*256)+(index/16), (index%16)*16+15, 1);
                read(('h1000+component*256)+(index/16),
                     component==0 ? index%16 : component==1 ? (index/16)%16 : index/256);
            end
        end
        assert(writes==0) else $fatal(1,"dummy selector wrote RAM");
        for(integer seed=0;seed<16;seed++) begin
            for(integer index=0;index<4096;index++) begin
                for(integer component=0;component<3;component++) begin
                    out('h1000+component*256+index/16,(index%16)*16+pattern(index,component,seed),0);
                    out('h1000+component*256+index/16,(index%16)*16+15,1);
                    read('h1000+component*256+index/16,pattern(index,component,seed));
                end
            end
            // Verify all adapter-written entries through the independent
            // display port, not just immediate CPU write/read pairs.
            for(integer index=0;index<4096;index++) begin
                @(negedge video_clk);display_read=1;display_address=12'(index);
                @(posedge video_clk);#1;
                assert(display_valid && display_rgb12=={4'(pattern(index,1,seed)),
                    4'(pattern(index,2,seed)),4'(pattern(index,0,seed))})
                    else $fatal(1,"independent display index=%h seed=%0d",index,seed);
            end
            @(negedge video_clk);display_read=0;
        end
        assert(writes==196608) else $fatal(1,"exhaustive write count");
        // Denied ownership must freeze the request, not capture changed live
        // fields or write until permission is really granted.
        @(negedge clk);permit=0;read_mode=0;address=16'h11ab;data=8'hc7;io_write=1;
        repeat(3) tick();
        assert(!wait_n && !ram_access && writes==196608) else $fatal(1,"denied access escaped");
        @(negedge clk);address=16'h1200;data=8'h00;read_mode=1;
        repeat(12) tick();
        assert(ram_address==12'habc && ram_component==1 && ram_nibble==7 && ram_write)
            else $fatal(1,"queued metadata followed live bus");
        @(negedge clk);permit=1;repeat(8) tick();
        assert(wait_n && writes==196609) else $fatal(1,"permitted write not exactly once");
        idle();out('h11ab,'hcf,1);read('h11ab,7);
        // Withhold a real read response over many stopped-CPU-equivalent
        // edges, then deliver it once. WAIT and completion must track valid.
        @(negedge clk);allow_response=0;address=16'h11ab;io_read=1;
        repeat(3) tick();
        @(negedge clk);external_enabled=0;read_mode=0;address=16'h13ff;
        repeat(12*ce_period) tick();
        assert(!wait_n && !read_valid && saved_valid) else $fatal(1,"read completed without backend valid");
        @(negedge clk);allow_response=1;tick();
        assert(wait_n && read_valid && read_nibble==7) else $fatal(1,"delayed real response lost");
        idle();external_enabled=1;read_mode=1;
        // Reset while a bus is held flushes response/selector, not palette.
        @(negedge clk);io_write=1;read_mode=0;address=16'h11ab;data=8'hc0;permit=0;
        repeat(3) tick();@(negedge clk);#100;reset=1;#100;reset=0;permit=1;
        repeat(12) tick();assert(writes==196609 && !ram_access && !read_valid)
            else $fatal(1,"old held request replayed after short reset");
        idle();out('h11ab,'hcf,1);read('h11ab,7);
        // Disabled/unmapped/illegal strobes never affect RAM or selector.
        @(negedge clk);external_enabled=0;io_write=1;address=16'h11ab;data=8'h00;
        repeat(8) tick();assert(!selected && writes==196609) else $fatal(1,"disabled write");
        idle();external_enabled=1;out('h11ab,'hcf,1);read('h11ab,7);
        @(negedge clk);address=16'h13ab;io_write=1;read_mode=0;
        repeat(8) tick();assert(!selected && writes==196609) else $fatal(1,"unmapped component alias");
        idle();@(negedge clk);address=16'h10ab;io_read=1;io_write=1;
        repeat(8) tick();assert(!selected && writes==196609) else $fatal(1,"illegal simultaneous strobes");
        idle();
        $display("PASS external palette adapter: cold/selectors, all indices/components/nibbles, held CE=%0d, frozen permission/reset/no replay video_half=%0d",ce_period,video_half_ps);
        $finish;
    end
    initial begin #20000000000000;$fatal(1,"palette access timeout");end
endmodule
