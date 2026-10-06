// SPDX-License-Identifier: GPL-2.0-or-later
// Original connected serial-pin/service fixture. No X1 assets or forced state.
`timescale 1ns/1ps
module sio_irq_tb;
    reg clk=0, ce=0, reset=1, pause_ce=0;
    always #5 clk=~clk;
    integer period=1, edges=0, ack_count=0;
    always @(negedge clk) begin edges=edges+1; ce=!pause_ce && (edges%period)==0; end
    reg cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
    reg [1:0] address=0;
    reg [7:0] cpu_din=0;
    wire [7:0] cpu_dout;
    reg [1:0] rx_tick=0,tx_tick=0,rxd=3,cts_n=3,dcd_n=3;
    wire [1:0] txd,rts_n,dtr_n;
    wire unsupported;
    reg iei=1,acknowledge=0,reti=0;
    wire irq,ieo;
    wire [7:0] ack_vector;
    reg hold_check=0;
    reg [7:0] hold_vector;
    x1_sio_interrupt dut(.*);
    always @(posedge clk) if(hold_check && ack_vector!==hold_vector)
        $fatal(1,"stretched ACK changed vector %h/%h",ack_vector,hold_vector);
    task automatic step;
        do begin @(posedge clk); #1; end while(!ce);
    endtask
    task automatic put(input reg [1:0] port_number,input reg [7:0] value);
        @(negedge clk); #1; address=port_number; cpu_din=value; cpu_cs=1; cpu_wr_n=0;
        repeat(5) step(); @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
    endtask
    task automatic check(input reg [1:0] port_number,input reg [7:0] expected);
        reg [7:0] value;
        @(negedge clk); #1; address=port_number; cpu_cs=1; cpu_rd_n=0;
        step(); value=cpu_dout;
        if(value!==expected) $fatal(1,"port %d got %h expected %h",port_number,value,expected);
        repeat(5) begin step(); if(cpu_dout!==value) $fatal(1,"held read changed"); end
        @(negedge clk); #1; cpu_cs=0; cpu_rd_n=1; step();
    endtask
    task automatic wr(input reg channel,input reg [7:0] index,value);
        put({channel,1'b1},index); put({channel,1'b1},value);
    endtask
    task automatic setup;
        for(integer ch=0;ch<2;ch=ch+1) begin
            put({1'(ch),1'b1},8'h18);
            wr(1'(ch),4,8'h44); wr(1'(ch),3,8'hc1); wr(1'(ch),5,8'hea);
        end
        wr(1,2,8'ha1); wr(0,2,8'h55); // only B supplies the vector.
        wr(0,1,8'h12); wr(1,1,8'h16);
        if(irq || !ieo || unsupported) $fatal(1,"IRQ merely from enabling empty TX");
    endtask
    task automatic receive(input reg [1:0] channels,input reg [7:0] a,b,input reg bad_stop);
        rx_tick=channels; rxd=~channels; repeat(16) step();
        for(integer i=0;i<8;i=i+1) begin rxd={b[i],a[i]}|~channels; repeat(16) step(); end
        rxd=bad_stop ? ~channels : 3; repeat(16) step();
        rxd=3; repeat(16) step(); rx_tick=0;
    endtask
    task automatic parity_error;
        reg [7:0] value;
        // 31 has three ones, so odd parity should be zero; send one instead.
        value=8'h31;
        rx_tick=1; rxd[0]=0; repeat(16) step();
        for(integer i=0;i<8;i=i+1) begin rxd[0]=value[i]; repeat(16) step(); end
        rxd[0]=1; repeat(16) step(); // corrupt parity
        rxd[0]=1; repeat(32) step(); rx_tick=0;
    endtask
    task automatic ack_start(input reg [7:0] expected);
        #1;
        if(!irq) $fatal(1,"expected eligible interrupt %h (ACKs=%0d)",expected,ack_count);
        @(negedge clk); #1; acknowledge=1; #1;
        if(ack_vector!==expected) $fatal(1,"ACK got %h expected %h",ack_vector,expected);
        @(posedge clk); #1;
        hold_vector=expected; hold_check=1; ack_count=ack_count+1;
    endtask
    task automatic ack_finish;
        repeat(40) begin @(posedge clk); #1; end
        @(negedge clk); #1; hold_check=0; acknowledge=0;
        @(posedge clk); #1;
    endtask
    task automatic return_local;
        @(negedge clk); #1; reti=1;
        @(posedge clk); #1;
        @(negedge clk); #1; reti=0;
    endtask
    task automatic rr2_check(input reg [7:0] expected);
        put(3,2); check(3,expected);
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        repeat(8) step(); reset=0; setup(); rr2_check(8'ha7);
        receive(2,0,8'hb1,0); check(1,6); check(3,5); rr2_check(8'ha5);
        iei=0; #1; if(irq || ieo) $fatal(1,"upstream IEI not respected");
        iei=1; ack_start(8'ha5); ack_finish();
        if(irq || ieo) $fatal(1,"B RX service failed to block itself/downstream");
        // RX request survives ACK until the real FIFO read consumes it.
        rr2_check(8'ha5); check(2,8'hb1);
        put(0,8'h69); tx_tick=1; step(); tx_tick=0;
        if(txd[0]!==0 || !irq) $fatal(1,"actual TX holding take did not request IRQ");
        ack_start(8'ha9);
        pause_ce=1; @(negedge clk); #1;
        repeat(40) begin @(posedge clk); #1; if(ce) $fatal(1,"CE pause fixture failed"); end
        if(irq || ieo) $fatal(1,"held ACK repeatedly cleared service");
        pause_ce=0;
        receive(1,8'h31,0,0); // higher priority arrives during held A-TX ACK.
        if(!irq || ack_vector!==8'ha9) $fatal(1,"nesting changed held ACK");
        ack_finish(); ack_start(8'had); ack_finish();
        check(0,8'h31); put(1,8'h38); // release A RX only; A TX/B RX remain.
        if(irq || ieo) $fatal(1,"WR0 returned more than highest service");
        put(1,8'h28); return_local();
        if(irq || ieo) $fatal(1,"B service lost when returning A TX");
        return_local();
        if(irq || !ieo) $fatal(1,"final service not released");
        rr2_check(8'ha7);
        // Simultaneous real RX/TX across both channels obeys A RX, A TX,
        // B RX, B TX. ACK itself does not remove the source condition.
        setup(); put(0,8'h21); put(2,8'h42); tx_tick=3; step(); tx_tick=0;
        receive(3,8'h53,8'ha6,0);
        ack_start(8'had); ack_finish(); check(0,8'h53); return_local();
        ack_start(8'ha9); ack_finish(); put(1,8'h28); return_local();
        ack_start(8'ha5); ack_finish(); check(2,8'ha6); return_local();
        ack_start(8'ha1); ack_finish(); put(3,8'h28); return_local();
        if(irq || !ieo) $fatal(1,"simultaneous sources did not drain");
        // Fixed vector mode and framing-special vector.
        setup(); wr(1,1,8'h12); receive(1,8'h37,0,1);
        ack_start(8'ha1); ack_finish(); check(0,8'h37); return_local();
        wr(1,1,8'h16); receive(1,8'h38,0,1);
        rr2_check(8'haf); ack_start(8'haf); ack_finish(); check(0,8'h38); return_local();
        // B-only reset preserves A service; A reset clears prioritization.
        receive(1,8'h39,0,0); ack_start(8'had); ack_finish();
        put(3,8'h18); if(ieo) $fatal(1,"B reset erased A service");
        put(1,8'h18); if(!ieo || irq || unsupported) $fatal(1,"A reset did not clear priority");
        // Spurious held ACK stays FF even if a request arrives mid-cycle.
        setup(); acknowledge=1; @(posedge clk); #1; hold_vector=8'hff; hold_check=1;
        receive(1,8'h71,0,0); ack_finish();
        if(!irq) $fatal(1,"spurious ACK swallowed late RX");
        ack_start(8'had); ack_finish(); check(0,8'h71); return_local();
        if(irq || !ieo || unsupported) $fatal(1,"final IRQ state");
        // Parity changes the vector only in mode 10, not mode 11; RR1
        // still records parity in both. Framing is special in both modes.
        setup(); wr(0,4,8'h45); parity_error(); rr2_check(8'haf);
        ack_start(8'haf); ack_finish(); put(1,1); check(1,8'h11);
        check(0,8'h31); put(1,8'h30); return_local();
        wr(0,1,8'h1a); parity_error(); rr2_check(8'had);
        ack_start(8'had); ack_finish(); put(1,1); check(1,8'h11);
        check(0,8'h31); put(1,8'h30); return_local();
        // A reset clears the prioritizer, not B's FIFO or its pending source.
        setup(); receive(2,0,8'h91,0); ack_start(8'ha5); ack_finish();
        put(1,8'h18);
        if(!irq) $fatal(1,"A reset lost B pending condition");
        ack_start(8'ha5); ack_finish(); check(2,8'h91); return_local();
        // B-only RR2 and A-only return are enforced, not silently accepted.
        put(1,2); check(1,8'hff); if(!unsupported) $fatal(1,"A RR2 falsely supported");
        put(1,8'h18); put(3,8'h38); if(!unsupported) $fatal(1,"B return falsely supported");
        setup(); wr(0,1,8'h08); if(!unsupported) $fatal(1,"first-character mode falsely supported");
        setup(); wr(0,1,8'h01); if(!unsupported) $fatal(1,"external/status mode falsely supported");
        // Same-edge holding take/write keeps the buffer full: no phantom
        // empty request until the replacement itself enters the shifter.
        setup(); put(0,8'h69);
        @(negedge clk); #1; address=0; cpu_din=8'h17; cpu_cs=1; cpu_wr_n=0; tx_tick=1;
        step(); tx_tick=0; repeat(3) step();
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
        if(irq) $fatal(1,"same-edge TX replacement generated phantom empty IRQ");
        check(1,0);
        tx_tick=1;
        for(integer i=0;i<10;i=i+1) begin
            reg [9:0] frame;
            frame={1'b1,8'h69,1'b0};
            repeat(16) begin
                if(txd[0]!==frame[i] || irq) $fatal(1,"TX collision first frame/IRQ mismatch");
                step();
            end
        end
        step(); tx_tick=0; ack_start(8'ha9); ack_finish(); put(1,8'h28); return_local();
        tx_tick=1;
        for(integer i=0;i<10;i=i+1) begin
            reg [9:0] frame;
            frame={1'b1,8'h17,1'b0};
            repeat(16) begin
                if(txd[0]!==frame[i]) $fatal(1,"TX collision replacement frame mismatch");
                step();
            end
        end
        tx_tick=0; if(irq) $fatal(1,"TX empty interrupt was not suppressed by WR0 reset");
        // Whole-chip reset still clears service and diagnostics with CE off.
        pause_ce=1; @(negedge clk); #1; reset=1;
        @(posedge clk); #1; reset=0;
        if(irq || !ieo || unsupported || txd!==3) $fatal(1,"stopped-CE chip reset failed");
        $display("PASS: real RX/TX SIO IRQ vectors, priority/nesting, held ACK without CE, WR0/RETI, reset and spurious ACK CE=%0d ACKs=%0d",period,ack_count);
        $finish;
    end
    initial begin #20000000; $fatal(1,"SIO IRQ fixture watchdog"); end
endmodule
