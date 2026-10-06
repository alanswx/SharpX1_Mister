// SPDX-License-Identifier: GPL-2.0-or-later
// Original synthetic sequential transfer/search status fixture. No forced
// engine state or CPU/native assets. Pure search remains fail-closed.
`timescale 1ns/1ps
module dma_compare_tb;
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
    integer period=1,edges=0,reads=0,writes=0,tests=0,stop_writes=0;
    logic old_rd=1,old_wr=1;
    logic [15:0] old_address=0;
    logic [7:0] old_data=0;
    x1_dma dut(.iei(1'b1),.acknowledge(1'b0),.reti(1'b0),
        .irq(),.ieo(),.irq_pending(),.irq_in_service(),.ack_vector(),.*);
    always_comb data_in=source[address[1:0]];
    always @(negedge clk) begin
        edges++;ce=(edges%period)==0;
        if(edges>20000000) $fatal(1,"DMA comparison watchdog");
        if(!old_rd && rd_n) reads++;
        if(!old_wr && wr_n) begin
            assert(writes<4 && old_data==source[writes])
                else $fatal(1,"comparison corrupted destination byte");
            writes++;
            if(stop_writes!=0 && writes==stop_writes) rdy=1;
        end
        if(!rd_n || !wr_n) begin
            assert(!busak_n && !busrq_n && mreq_n!=iorq_n)
                else $fatal(1,"comparison bus without ownership");
            if((!old_rd && !rd_n) || (!old_wr && !wr_n))
                assert(address==old_address && data_out==old_data)
                    else $fatal(1,"comparison changed held bus");
            old_address=address;old_data=data_out;
        end
        old_rd=rd_n;old_wr=wr_n;
        // Synchronous synthetic host, not electrical/half-clock pin timing.
        busak_n=busrq_n;
    end
    task automatic tick; @(posedge clk);#1;endtask
    task automatic ctick;do tick();while(!ce);endtask
    task automatic put(input logic [7:0] value);
        @(negedge clk);#1;cpu_cs=1;cpu_wr_n=0;cpu_data_in=value;
        repeat(3) ctick();@(negedge clk);#1;cpu_cs=0;cpu_wr_n=1;ctick();
    endtask
    task automatic status(output logic [7:0] value);
        put(8'hbf);@(negedge clk);#1;cpu_cs=1;cpu_rd_n=0;ctick();value=cpu_data_out;
        repeat(3) begin ctick();assert(cpu_data_out==value) else $fatal(1,"held status changed");end
        @(negedge clk);#1;cpu_cs=0;cpu_rd_n=1;ctick();
    endtask
    task automatic fresh;
        reset=1;cpu_cs=0;cpu_rd_n=1;cpu_wr_n=1;wait_n=1;rdy=0;
        repeat(8) tick();reset=0;repeat(4) ctick();reads=0;writes=0;stop_writes=0;
    endtask
    task automatic configure(input logic a_source,input integer mode,
                             input logic [7:0] mask,value,input logic search,
                             input logic stop_match=0);
        logic [15:0] a,b;
        a=a_source ? 16'h1000 : 16'h2000;b=a_source ? 16'h2000 : 16'h1000;
        put(a_source ? (search ? 8'h7f : 8'h7d) : (search ? 8'h7b : 8'h79));
        put(a[7:0]);put(a[15:8]);put(3);put(0);
        put(8'h14);put(8'h10); // Incrementing memory on both ports.
        put(stop_match ? 8'h9c : 8'h98);put(mask);put(value);
        put(8'h8d | 8'(mode<<5));put(b[7:0]);put(b[15:8]);put(8'h92);put(8'hcf);
        assert(!unsupported) else $fatal(1,"valid compare stream rejected");
    endtask
    task automatic finish_block;
        wait(dut.end_of_block && busrq_n && busak_n);repeat(4) ctick();
        assert(reads==4 && writes==4 && dut.byte_counter==3)
            else $fatal(1,"compare changed sequential block count");
    endtask
    initial begin
        logic [7:0] value;
        if($value$plusargs("CE_PERIOD=%d",period)) begin end
        for(integer mask=0;mask<256;mask++) begin
            // Each ignored-bit pattern matches; flip every compared bit for
            // the negative case. FF necessarily matches every possible byte.
            for(integer direction=0;direction<2;direction++)
                for(integer mode=0;mode<3;mode++) for(integer positive=0;positive<2;positive++) begin
                    fresh();
                    for(integer i=0;i<4;i++) source[i]=positive!=0 ? (8'ha5 ^ 8'(mask)) :
                        (8'ha5 ^ ~8'(mask));
                    configure(1'(direction),mode,8'(mask),8'ha5,1);
                    status(value);assert(value[4] && value[5]) else $fatal(1,"LOAD match/EOB not clear");
                    put(8'h87);finish_block();status(value);
                    assert(value[4]==!(positive!=0 || mask==255) && !value[5])
                        else $fatal(1,"masked compare status mask=%h positive=%0d status=%h",8'(mask),positive,value);
                    // Ordinary status reads/disable cannot clear the latch.
                    status(value);assert(value[4]==!(positive!=0 || mask==255))
                        else $fatal(1,"match not sticky across status read");
                    put(8'h83);put(8'h8b);status(value);
                    assert(value[5:4]==3 && value[0] && value[1])
                        else $fatal(1,"8B did not clear only match/EOB with request/Ready retained");
                    tests++;
                end
        end
        // A late match remains sticky after later nonmatching destination
        // writes; a plain transfer never compares parsed mask/match bytes.
        for(integer position=0;position<4;position++) begin
            fresh();for(integer i=0;i<4;i++) source[i]=i==position ? 8'h87 : 8'h36;
            configure(1,1,0,8'h87,1);put(8'h87);finish_block();status(value);
            assert(!value[4]) else $fatal(1,"positioned match lost");
            put(8'hcf);status(value);assert(value[4]) else $fatal(1,"LOAD retained old match");
        end
        fresh();for(integer i=0;i<4;i++) source[i]=8'h87;
        configure(1,1,0,8'h87,1);put(8'h87);
        wait(!wr_n);wait_n=0;repeat(12) ctick();
        assert(!dut.match_found && writes==0 && data_out==8'h87)
            else $fatal(1,"match became visible before destination completion");
        wait_n=1;finish_block();status(value);assert(!value[4]) else $fatal(1,"stalled write lost match");
        put(8'hd3);status(value);assert(value[4]) else $fatal(1,"CONTINUE retained old match");
        // A repeated block clears match/EOB on its automatic reload while
        // retaining the real mask/match programming for the next block.
        fresh();for(integer i=0;i<4;i++) source[i]=8'h87;
        configure(1,0,0,8'h87,1);put(8'hb2);stop_writes=4;put(8'h87);
        wait(writes==4 && busrq_n && busak_n);status(value);
        assert(value[5:4]==3 && dut.mask_byte==0 && dut.match_byte==8'h87 && dut.byte_counter==0)
            else $fatal(1,"automatic reload compare/status state");
        // Clear an actually set latch through both reset mechanisms.
        fresh();for(integer i=0;i<4;i++) source[i]=8'h87;
        configure(1,1,0,8'h87,1);put(8'h87);finish_block();
        put(8'hc3);status(value);
        assert(value[5:4]==3 && !value[0] && dut.mask_byte==0 && dut.match_byte==8'h87)
            else $fatal(1,"partial software reset match/status/retained programming");
        fresh();status(value);assert(value[5:4]==3 && !value[0])
            else $fatal(1,"hardware reset match/status");
        fresh();for(integer i=0;i<4;i++) source[i]=8'h87;
        configure(1,1,0,8'h87,0);put(8'h87);finish_block();status(value);
        assert(value[4]) else $fatal(1,"plain transfer fabricated a match");
        // Table 12's unambiguous Byte sequential stop contract: no extra
        // source read, destination completes, count M-1, no automatic restart
        // on a match even when it coincides with end of block.
        for(integer direction=0;direction<2;direction++)
        for(integer mask=0;mask<256;mask++)
        for(integer position=0;position<4;position++) begin
            integer operations;
            fresh();
            for(integer i=0;i<4;i++) source[i]=i==position ? 8'ha5 : (8'ha5 ^ ~8'(mask));
            operations=mask==255 ? 1 : position+1;
            configure(1'(direction),0,8'(mask),8'ha5,1,1);
            put(8'hb2); // Auto restart must not override a match stop.
            put(8'h87);
            wait(dut.match_found && busrq_n && busak_n);repeat(20) ctick();
            assert(!dut.enabled && reads==operations && writes==operations &&
                   dut.byte_counter==16'(operations-1) && dut.remaining==17'(4-operations) &&
                   dut.end_of_block==(operations==4) &&
                   (direction!=0 ? dut.counter_a : dut.counter_b)==16'(32'h1000+operations) &&
                   (direction!=0 ? dut.counter_b : dut.counter_a)==16'(32'h2000+operations-1))
                else $fatal(1,"Byte stop count/address/restart mask=%0d position=%0d",mask,position);
            status(value);
            assert(!value[4] && value[5]==(operations!=4))
                else $fatal(1,"Byte stop status");
            tests++;
        end
        fresh();for(integer i=0;i<4;i++) source[i]=8'h87;
        configure(1,0,0,8'h87,1,1);put(8'h87);
        wait(!wr_n);wait_n=0;repeat(12) ctick();
        assert(!dut.match_found && writes==0 && dut.enabled)
            else $fatal(1,"Byte stop occurred before WAIT-stalled write completed");
        // A stopped clock enable must not complete the held transaction.
        begin
            integer saved_period;
            saved_period=period;period=100000000;
            repeat(20) tick();
            assert(!wr_n && !dut.match_found && writes==0)
                else $fatal(1,"Byte stop ignored stopped CE");
            period=saved_period;
        end
        wait_n=1;wait(dut.match_found && busrq_n && busak_n);repeat(20) ctick();
        assert(reads==1 && writes==1 && !dut.enabled && dut.byte_counter==0)
            else $fatal(1,"Byte WAIT stop did not drain exactly one pair");
        fresh();for(integer i=0;i<4;i++) source[i]=8'h36;
        configure(1,0,0,8'h87,1,1);put(8'h87);finish_block();status(value);
        assert(value[4] && !value[5]) else $fatal(1,"Byte nonmatching stop did not reach EOB");
        fresh();for(integer i=0;i<4;i++) source[i]=8'h87;
        configure(1,0,0,8'h87,1,1);put(8'hc4); // WR3 enable + Stop on Match.
        wait(dut.match_found && busrq_n && busak_n);repeat(20) ctick();
        assert(reads==1 && writes==1 && !dut.enabled)
            else $fatal(1,"WR3 immediate Byte stop enable failed");
        // Fail closed for ambiguous continuous stop/pure search.
        fresh();configure(1,1,0,8'h87,1);
        put(8'h84);assert(unsupported) else $fatal(1,"stop-on-match accepted without stop engine");
        put(8'h07);assert(unsupported) else $fatal(1,"continuous sequential stop accepted without resolved contract");
        $display("PASS DMA comparison/Byte-stop %0d mask/direction/mode/position cases, sticky/status/LOAD/CONTINUE/8B/WAIT/stopped CE/WR3 enable, CE=%0d",tests,period);
        $finish;
    end
endmodule
