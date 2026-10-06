// SPDX-License-Identifier: GPL-2.0-or-later
// Original synthetic pure Byte search fixture; no forced device state.
`timescale 1ns/1ps
module dma_search_tb;
    logic clk=0,ce=0,reset=1;
    always #5 clk=!clk;
    logic cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
    logic [7:0] cpu_data_in=0;
    wire [7:0] cpu_data_out;
    wire busrq_n,mreq_n,iorq_n,rd_n,wr_n,unsupported;
    logic busak_n=1,wait_n=1,rdy=0;
    wire [15:0] address;
    wire [7:0] data_out;
    logic [7:0] data_in;
    logic [7:0] source[0:3];
    integer period=1,edges=0,reads=0,tests=0;
    logic old_rd=1;
    logic [15:0] held_address=0;
    logic held_io=0,expect_io=0;
    x1_dma dut(.*);
    always_comb data_in=source[address[1:0]];
    always @(negedge clk) begin
        edges++;ce=(edges%period)==0;
        if(edges>40000000) $fatal(1,"pure search watchdog");
        assert(wr_n) else $fatal(1,"pure search emitted a destination write");
        if(!old_rd && rd_n) reads++;
        if(!rd_n) begin
            assert(!busrq_n && !busak_n && mreq_n!=iorq_n && iorq_n==!expect_io)
                else $fatal(1,"search read without ownership");
            if(!old_rd) assert(address==held_address && iorq_n==held_io)
                else $fatal(1,"held search address/type changed");
            held_address=address;held_io=iorq_n;
        end
        old_rd=rd_n;busak_n=busrq_n;
    end
    task automatic tick;@(posedge clk);#1;endtask
    task automatic ctick;do tick();while(!ce);endtask
    task automatic put(input logic [7:0] value);
        @(negedge clk);#1;cpu_cs=1;cpu_wr_n=0;cpu_data_in=value;
        repeat(3) ctick();@(negedge clk);#1;cpu_cs=0;cpu_wr_n=1;ctick();
    endtask
    task automatic get(output logic [7:0] value);
        @(negedge clk);#1;cpu_cs=1;cpu_rd_n=0;ctick();value=cpu_data_out;
        repeat(3) begin ctick();assert(cpu_data_out==value) else $fatal(1,"held search readback changed");end
        @(negedge clk);#1;cpu_cs=0;cpu_rd_n=1;ctick();
    endtask
    task automatic fresh;
        reset=1;cpu_cs=0;cpu_rd_n=1;cpu_wr_n=1;wait_n=1;rdy=0;
        repeat(8) tick();reset=0;repeat(4) ctick();reads=0;
    endtask
    task automatic configure(input logic direction,stop_match,input logic [7:0] mask,
                             input logic [7:0] config_source=8'h10,input logic [15:0] start=16'h1000,
                             input logic [15:0] block_length=16'd3);
        logic [15:0] a,b;
        a=direction ? start : 16'h2000;b=direction ? 16'h2000 : start;
        expect_io=config_source[3];
        put(direction ? 8'h7e : 8'h7a);put(a[7:0]);put(a[15:8]);
        put(block_length[7:0]);put(block_length[15:8]);
        put(direction ? (config_source | 8'h04) : 8'h14);
        put(direction ? 8'h10 : config_source);
        put(stop_match ? 8'h9c : 8'h98);put(mask);put(8'ha5);
        put(8'h8d);put(b[7:0]);put(b[15:8]);put(8'h92);put(8'hcf);
        assert(!unsupported) else $fatal(1,"pure Byte search rejected");
    endtask
    task automatic released;
        wait(!dut.enabled && busrq_n && busak_n);repeat(12) ctick();
    endtask
    initial begin
        logic [7:0] value;
        integer operations,count;
        if($value$plusargs("CE_PERIOD=%d",period)) begin end
        for(integer direction=0;direction<2;direction++)
        for(integer mask=0;mask<256;mask++)
        for(integer position=0;position<5;position++)
        for(integer stop_match=0;stop_match<2;stop_match++) begin
            fresh();
            for(integer i=0;i<4;i++) source[i]=i==position ? 8'ha5 : (8'ha5 ^ ~8'(mask));
            configure(1'(direction),1'(stop_match),8'(mask));put(8'h87);released();
            operations=stop_match!=0 && (position<4 || mask==255) ?
                (mask==255 ? 1 : position+1) : 4;
            count=stop_match!=0 && (position<4 || mask==255) ? operations : 3;
            assert(reads==operations && dut.byte_counter==16'(count) &&
                   dut.remaining==17'(4-operations) && dut.end_of_block==(operations==4) &&
                   (direction!=0 ? dut.counter_a : dut.counter_b)==16'(32'h1000+operations) &&
                   (direction!=0 ? dut.counter_b : dut.counter_a)==0)
                else $fatal(1,"search counters/read totals mask=%0d position=%0d stop=%0d",mask,position,stop_match);
            put(8'hbf);get(value);
            assert(value[4]==!(position<4 || mask==255) && value[5]==(operations!=4))
                else $fatal(1,"search RR0 match/EOB");
            put(8'h8b);put(8'hbf);get(value);
            assert(value[5:4]==3) else $fatal(1,"search clear status");
            tests++;
        end
        // Memory and I/O, fixed/inc/dec/wrap: nonmatching full blocks.
        for(integer direction=0;direction<2;direction++)
        for(integer io=0;io<2;io++)
        for(integer mode=0;mode<3;mode++) begin
            logic [7:0] config_source;
            logic [15:0] start,expected;
            fresh();for(integer i=0;i<4;i++) source[i]=8'h36;
            config_source=8'(io<<3) | (mode==0 ? 8'h10 : mode==1 ? 8'h00 : 8'h20);
            start=mode==0 ? 16'hfffe : 16'h0001;
            expected=mode==0 ? start+16'd4 : mode==1 ? start-16'd4 : start;
            configure(1'(direction),1,0,config_source,start);put(8'h87);released();
            assert(reads==4 && dut.byte_counter==3 &&
                   (direction!=0 ? dut.counter_a : dut.counter_b)==expected &&
                   (direction!=0 ? dut.counter_b : dut.counter_a)==0)
                else $fatal(1,"search source memory/io/step/wrap");
        end
        // Ready drops during a WAIT-stalled matching read. No early match,
        // no extra read; CE stop and abort/reset must drain this same read.
        for(integer abort_kind=0;abort_kind<4;abort_kind++) begin
            fresh();for(integer i=0;i<4;i++) source[i]=8'ha5;
            configure(1,1,0);put(8'h87);wait(!rd_n);wait_n=0;rdy=1;
            repeat(12) ctick();assert(!dut.match_found && reads==0)
                else $fatal(1,"search matched before completed read");
            if(abort_kind==1) put(8'h83);
            if(abort_kind==2) put(8'hc3);
            begin
                integer saved_period;
                saved_period=period;period=100000000;
                if(abort_kind==3) begin reset=1;tick();reset=0;end
                repeat(20) tick();
                assert(!rd_n && reads==0 && !dut.match_found)
                    else $fatal(1,"search abort/CE stop truncated read");
                period=saved_period;
            end
            wait_n=1;released();
            assert(reads==1) else $fatal(1,"search abort lost or duplicated read");
            if(abort_kind<2) assert(dut.match_found && dut.byte_counter==1)
                else $fatal(1,"search matching drained read lost status");
            else assert(!dut.match_found && !dut.loaded)
                else $fatal(1,"search reset retained active block/match");
        end
        // Preserve inherited N+1/zero-wrap policy at long search boundaries.
        // No destination access even through address/byte-counter rollover.
        for(integer direction=0;direction<2;direction++)
        for(integer size_case=0;size_case<3;size_case++) begin
            logic [15:0] n;
            integer total;
            n=size_case==0 ? 16'd255 : size_case==1 ? 16'hffff : 16'd0;
            total=size_case==0 ? 256 : size_case==1 ? 65536 : 65537;
            fresh();for(integer i=0;i<4;i++) source[i]=8'h36;
            configure(1'(direction),0,0,8'h10,16'h1000,n);put(8'h87);released();
            assert(reads==total && dut.byte_counter==n && dut.remaining==0 &&
                   dut.end_of_block && !dut.match_found &&
                   (direction!=0 ? dut.counter_a : dut.counter_b)==16'(32'h1000+total) &&
                   (direction!=0 ? dut.counter_b : dut.counter_a)==0)
                else $fatal(1,"search long count/wrap size_case=%0d",size_case);
        end
        fresh();configure(1,1,0);put(8'hb2);
        assert(unsupported) else $fatal(1,"search auto restart accepted without contract");
        put(8'h92);put(8'hc1);
        assert(unsupported) else $fatal(1,"pure Burst pipeline accepted without implementation");
        put(8'ha1);
        assert(unsupported) else $fatal(1,"pure continuous pipeline accepted without implementation");
        $display("PASS pure Byte search %0d masks/directions/positions/stop cases, memory/io/address modes, WAIT/Ready/CE/abort/reset, CE=%0d",tests,period);
        $finish;
    end
endmodule
