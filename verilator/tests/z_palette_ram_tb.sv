// SPDX-License-Identifier: GPL-2.0-only
// Original palette SRAM/dual-clock fixture; every byte/nibble is synthetic.
`timescale 1ps/1ps
module z_palette_ram_tb;
    logic cpu_clk=0,video_clk=0,cpu_run=1,video_run=1;
    integer video_half_ps=17500,ce_period=1,edges=0,writes=0;
    always #15625 if(cpu_run) cpu_clk=!cpu_clk;
    always #(video_half_ps) if(video_run) video_clk=!video_clk;
    logic cpu_reset=1,video_reset=1,cpu_access=0,cpu_write=0,display_read=0;
    logic [11:0] cpu_address=0,display_address=0;
    logic [1:0] cpu_component=0;
    logic [3:0] cpu_nibble=0;
    wire [3:0] cpu_data;
    wire cpu_valid,display_valid;
    wire [11:0] display_rgb12;
    logic [3:0] expected [0:4095][0:2];
    x1_z_palette_ram dut(.*);
    always @(posedge cpu_clk) begin
        edges++;
        if(dut.accepted_write) writes++;
    end
    task automatic ctick;@(posedge cpu_clk);#1;endtask
    task automatic vtick;@(posedge video_clk);#1;endtask
    task automatic accepted_edge;
        @(negedge cpu_clk);
        while(edges%ce_period!=0) @(negedge cpu_clk);
    endtask
    function automatic logic [3:0] pattern(input integer address,component,seed);
        return 4'(address*7+(address>>4)*3+(address>>8)*11+component*5+seed);
    endfunction
    function automatic logic [11:0] rgb(input integer address);
        return {expected[address][1],expected[address][2],expected[address][0]};
    endfunction
    task automatic put(input integer address,component,input logic [3:0] value);
        accepted_edge();cpu_address=12'(address);cpu_component=2'(component);
        cpu_nibble=value;cpu_access=1;cpu_write=1;ctick();
        assert(cpu_valid && cpu_data==value) else $fatal(1,"CPU write forwarding");
        expected[address][component]=value;
        @(negedge cpu_clk);cpu_write=0;cpu_access=0;
    endtask
    task automatic read(input integer address,component);
        accepted_edge();cpu_address=12'(address);cpu_component=2'(component);
        cpu_access=1;cpu_write=0;ctick();
        assert(cpu_valid && cpu_data==expected[address][component])
            else $fatal(1,"CPU nibble address=%0h component=%0d",address,component);
        // A changed live component/address cannot select different data from
        // the completed edge until a fresh local read edge.
        cpu_component=2'((component+1)%3);cpu_address=12'(4095-address);#1;
        assert(cpu_data==expected[address][component]) else $fatal(1,"response metadata not latched");
        @(negedge cpu_clk);cpu_access=0;
    endtask
    task automatic read_video(input integer address);
        @(negedge video_clk);display_address=12'(address);display_read=1;vtick();
        assert(display_valid && display_rgb12==rgb(address))
            else $fatal(1,"video palette address=%0h expected=%0h got=%0h",address,rgb(address),display_rgb12);
    endtask
    task automatic read_all;
        for(integer address=0;address<4096;address++) begin
            for(integer component=0;component<3;component++) read(address,component);
            read_video(4095-address);
        end
    endtask
    initial begin
        if($value$plusargs("VIDEO_HALF_PS=%d",video_half_ps)) begin end
        if($value$plusargs("CE_PERIOD=%d",ce_period)) begin end
        repeat(3) ctick();repeat(3) vtick();
        assert(!cpu_valid && !display_valid && cpu_data==0 && display_rgb12==0)
            else $fatal(1,"reset response mask");
        @(negedge cpu_clk);cpu_reset=0;video_reset=0;
        // Program every physical entry before reading it; no test assumes
        // FPGA/simulator power-up palette contents are authentic hardware.
        for(integer seed=0;seed<16;seed++) begin
            for(integer address=0;address<4096;address++)
                for(integer component=0;component<3;component++)
                    put(address,component,pattern(address,component,seed));
            read_all();
        end
        assert(writes==4096*3*16) else $fatal(1,"accepted operation count");
        // Invalid fourth component and inactive write inputs must not alias
        // any bank. This is storage-port validation, not ASIC decode.
        accepted_edge();cpu_address=12'hfff;cpu_component=3;cpu_access=1;cpu_write=1;
        cpu_nibble=0;ctick();
        assert(!cpu_valid && cpu_data==0 && writes==196608) else $fatal(1,"invalid component alias");
        @(negedge cpu_clk);cpu_component=0;cpu_access=0;repeat(4) ctick();
        assert(!cpu_valid && writes==196608) else $fatal(1,"inactive write accepted");
        @(negedge cpu_clk);cpu_write=0;
        // Video reads a stable OTHER address while accepted CPU component
        // writes progress. Same-address cross-clock collision is excluded.
        display_address=12'hfff;display_read=1;
        for(integer address=0;address<4095;address++) begin
            for(integer component=0;component<3;component++) begin
                put(address,component,pattern(address,component,29));
                vtick();
                assert(display_valid && display_rgb12==rgb(4095))
                    else $fatal(1,"other-address concurrent write contaminated video");
            end
        end
        read_all();
        // Full, independent and entirely-between-edge resets flush response
        // validity without changing any programmed palette entry.
        @(negedge cpu_clk);cpu_reset=1;video_reset=1;#1;
        assert(!cpu_valid && !display_valid && cpu_data==0 && display_rgb12==0)
            else $fatal(1,"warm reset mask");
        cpu_access=1;cpu_write=1;cpu_component=0;cpu_nibble=0;
        repeat(5) ctick();repeat(5) vtick();
        assert(writes==196608+4095*3) else $fatal(1,"reset accepted write");
        @(negedge cpu_clk);cpu_access=0;cpu_write=0;cpu_reset=0;video_reset=0;
        read_all();
        @(negedge cpu_clk);#100;cpu_reset=1;video_reset=1;#100;
        assert(!cpu_valid && !display_valid) else $fatal(1,"short reset mask");
        cpu_reset=0;video_reset=0;#100;
        assert(!cpu_valid && !display_valid) else $fatal(1,"stale valid after short reset");
        read_all();
        @(negedge video_clk);video_run=0;video_reset=1;#1;
        assert(!display_valid) else $fatal(1,"stopped video reset");
        for(integer address=0;address<64;address++) read(address*61, address%3);
        video_reset=0;#1;assert(!display_valid) else $fatal(1,"stopped video stale valid");
        video_run=1;read_video(1234);
        @(negedge cpu_clk);cpu_run=0;cpu_reset=1;#1;
        assert(!cpu_valid) else $fatal(1,"stopped CPU reset");
        for(integer address=0;address<64;address++) read_video(address*61);
        cpu_reset=0;#1;assert(!cpu_valid) else $fatal(1,"stopped CPU stale valid");
        cpu_run=1;read(1234,1);
        $display("PASS palette RAM: all 4096 addresses/3 components/16 values, RGB12 isolation, accepted CE=%0d, video_half=%0d, concurrent reads and retained reset",ce_period,video_half_ps);
        $finish;
    end
    initial begin #2000000000000;$fatal(1,"palette RAM fixture timeout");end
endmodule
