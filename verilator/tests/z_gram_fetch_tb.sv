// SPDX-License-Identifier: GPL-2.0-only
// Original independent-clock fixture using the real machine RAM primitive.
`timescale 1ps/1ps
module z_gram_fetch_tb;
    reg clk=0, cpu_clk=0, reset=1, request=0;
    integer video_half=17500;
    always #(video_half) clk=~clk;
    always #15625 cpu_clk=~cpu_clk;
    reg [13:0] base_address=0;
    reg [2:0] mode=0;
    reg screen=0, raster_odd=0;
    wire ready, read_enable, valid, rejected;
    wire [14:0] read_address;
    wire [7:0] bq,rq,gq;
    wire [31:0] blue,red,green;
    reg cpu_write=0;
    reg [14:0] cpu_address=0;
    reg [7:0] bd=0,rd=0,gd=0;
    wire [7:0] bc,rc,gc;
    reg timing_reset=1,high_scan=0,width40=0;
    wire step;
    wire [4:0] phase;
    x1_video_timing timing(clk,timing_reset,high_scan,width40,step,phase);
    x1_video_ram #(15) b(cpu_clk,cpu_address,bd,cpu_write,bc,clk,read_address,bq);
    x1_video_ram #(15) r(cpu_clk,cpu_address,rd,cpu_write,rc,clk,read_address,rq);
    x1_video_ram #(15) g(cpu_clk,cpu_address,gd,cpu_write,gc,clk,read_address,gq);
    x1_z_gram_fetch dut(.*,.blue_q(bq),.red_q(rq),.green_q(gq));
    function automatic [7:0] pattern(input integer address, component);
        // Bank, +400h, byte/row and component all influence the byte.
        pattern=8'((address*37 + address/256*19 + address/1024*53 +
                    address/16384*101 + component*73) ^ (address/16));
    endfunction
    integer accepted=0;
    always @(posedge clk) if(read_enable) accepted<=accepted+1;
    task automatic tick;
        @(posedge clk); #1;
    endtask
    task automatic check_fetch(input integer q,m,s,p);
        integer lanes, start_reads, edges, bank, offset, address;
        reg [31:0] expected_b,expected_r,expected_g;
        lanes=m==0 ? 4 : m==4 ? 1 : 2;
        expected_b=0;expected_r=0;expected_g=0;
        for(integer n=0;n<lanes;n=n+1) begin
            // Arithmetic oracle distinct from the RTL's bit-mux expressions.
            case(m)
                0: begin bank=n/2;offset=(n%2)*1024;end
                1: begin bank=s;offset=n*1024;end
                2: begin bank=n;offset=0;end
                3: begin bank=p;offset=n*1024;end
                default: begin bank=p;offset=0;end
            endcase
            address=bank*16384+(q+offset)%16384;
            expected_b[n*8+:8]=pattern(address,0);
            expected_r[n*8+:8]=pattern(address,1);
            expected_g[n*8+:8]=pattern(address,2);
        end
        @(negedge clk);
        assert(ready) else $fatal(1,"not ready");
        base_address=14'(q);mode=3'(m);screen=1'(s);raster_odd=1'(p);
        request=1;start_reads=accepted;
        tick();
        assert(!ready && !valid) else $fatal(1,"acceptance/early validity");
        @(negedge clk);
        // A competing request/live input change must not redirect this one.
        base_address=14'h3fff;mode=7;screen=~screen;raster_odd=~raster_odd;
        edges=0;
        while(!valid) begin
            tick();edges=edges+1;
            assert(!rejected && edges<=5) else $fatal(1,"pending request/latency");
        end
        assert(edges==lanes+1 && accepted-start_reads==lanes)
            else $fatal(1,"one synchronous read per lane");
        assert(blue===expected_b && red===expected_r && green===expected_g)
            else $fatal(1,"fetch q=%h mode=%0d page=%0d parity=%0d got %h/%h/%h expected %h/%h/%h",
                q,m,s,p,blue,red,green,expected_b,expected_r,expected_g);
        @(negedge clk);request=0;
        tick();assert(!valid && ready) else $fatal(1,"response not a pulse");
    endtask
    initial begin
        if($value$plusargs("video_half=%d",video_half)) begin end
        // Actual CPU-port writes initialize all 96 KiB, not direct RAM pokes.
        for(integer a=0;a<32768;a=a+1) begin
            @(negedge cpu_clk);
            cpu_address=15'(a);bd=pattern(a,0);rd=pattern(a,1);gd=pattern(a,2);cpu_write=1;
        end
        @(negedge cpu_clk);cpu_write=0;
        @(negedge clk);reset=0;
        for(integer q=0;q<16384;q=q+1) begin
            check_fetch(q,0,0,0);
            for(integer page=0;page<2;page=page+1) begin
                check_fetch(q,1,page,0);
                check_fetch(q,3,0,page);
                check_fetch(q,4,0,page);
            end
            check_fetch(q,2,0,0);
        end
        // Invalid modes cannot silently become a supported graphics format.
        for(integer m=5;m<8;m=m+1) begin
            @(negedge clk);mode=3'(m);request=1;
            tick();assert(rejected && ready && !valid && !read_enable)
                else $fatal(1,"invalid mode accepted");
            @(negedge clk);request=0;tick();
        end
        // Abort at every pipeline seam, then qualify a clean fresh request.
        for(integer delay_edges=0;delay_edges<5;delay_edges=delay_edges+1) begin
            @(negedge clk);base_address=14'h3fff;mode=0;request=1;
            tick();@(negedge clk);request=0;
            repeat(delay_edges) tick();
            @(negedge clk);reset=1;#1;
            assert(!valid && !read_enable && !ready) else $fatal(1,"reset did not mask");
            tick();@(negedge clk);reset=0;
            repeat(6) begin tick();assert(!valid) else $fatal(1,"old response replayed");end
            check_fetch(1023,0,0,0);
        end
        // Separate CPU port and retained RAM contents still read normally.
        @(negedge cpu_clk);cpu_address=15'h7fff;
        @(posedge cpu_clk);#1;
        assert(bc===pattern(32767,0) && rc===pattern(32767,1) && gc===pattern(32767,2))
            else $fatal(1,"CPU port/retention");
        // Actual enabled-CRTC timing generator: start at phase 0, complete
        // before the existing digital shifter's phase-14 load in every scan/
        // width combination. This is a deadline test, not CRTC integration.
        for(integer hi=0;hi<2;hi=hi+1) begin
            for(integer narrow=0;narrow<2;narrow=narrow+1) begin
                integer starts,loads;
                bit completed,in_flight;
                starts=0;loads=0;completed=0;in_flight=0;
                @(negedge clk);timing_reset=1;high_scan=1'(hi);width40=1'(narrow);
                tick();@(negedge clk);timing_reset=0;
                for(integer edge_number=0;edge_number<2048;edge_number=edge_number+1) begin
                    @(negedge clk);request=0;
                    if(step && !phase[0] && phase[4:1]==0) begin
                        assert(ready && !in_flight) else $fatal(1,"missed character admission");
                        request=1;mode=0;base_address=14'(starts);
                        starts=starts+1;in_flight=1;completed=0;
                    end
                    if(step && !phase[0] && phase[4:1]==14 && in_flight) begin
                        assert(completed) else $fatal(1,"missed phase-14 shifter deadline");
                        loads=loads+1;in_flight=0;
                    end
                    tick();
                    if(valid) completed=1;
                    assert(!rejected) else $fatal(1,"timed request rejected");
                end
                @(negedge clk);request=0;
                repeat(6) tick();
                assert(loads>20 && starts-loads<=1) else $fatal(1,"timing fixture missing characters");
            end
        end
        $display("PASS Z sequential GRAM fetch: all base addresses/five modes/pages/parities, frozen metadata, exact one-edge RAM response and reset seams; video half=%0d ps",video_half);
        $finish;
    end
endmodule
