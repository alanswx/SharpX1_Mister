// SPDX-License-Identifier: GPL-2.0-or-later
// Original synchronous functional flow test, not physical W/RDY timing.
`timescale 1ns/1ps
module sio_flow_tb;
    reg clk=0,ce=0,reset=1,pause_ce=0;
    always #5 clk=~clk;
    integer period=1,edges=0;
    always @(negedge clk) begin edges=edges+1; ce=!pause_ce && edges%period==0; end
    reg cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
    reg [1:0] address=0;
    reg [7:0] cpu_din=0;
    wire [7:0] cpu_dout;
    reg [1:0] rx_tick=0,tx_tick=0,rxd=3,cts_n=3,dcd_n=3;
    wire [1:0] txd,rts_n,dtr_n,wait_n,ready_n;
    wire unsupported,irq,ieo;
    wire [7:0] ack_vector;
    reg iei=1,acknowledge=0,reti=0;
    x1_sio_interrupt #(.FLOW_ENABLE(1)) dut(.*);
    task automatic step;
        do begin @(posedge clk); #1; end while(!ce);
    endtask
    task automatic release_bus;
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; cpu_rd_n=1; step();
    endtask
    task automatic put(input reg [1:0] p,input reg [7:0] value);
        @(negedge clk); #1; address=p; cpu_din=value; cpu_cs=1; cpu_wr_n=0;
        repeat(5) begin step(); if(!wait_n[p[1]]) $fatal(1,"unexpected WAIT in put"); end
        release_bus();
    endtask
    task automatic check(input reg [1:0] p,input reg [7:0] value);
        @(negedge clk); #1; address=p; cpu_cs=1; cpu_rd_n=0;
        repeat(5) begin step(); if(cpu_dout!==value || !wait_n[p[1]]) $fatal(1,"read mismatch %h/%h",cpu_dout,value); end
        release_bus();
    endtask
    task automatic wr(input reg ch,input reg [7:0] index,value);
        put({ch,1'b1},index); put({ch,1'b1},value);
    endtask
    task automatic receive_a(input reg [7:0] value);
        rx_tick=1; rxd[0]=0; repeat(16) step();
        for(integer i=0;i<8;i=i+1) begin rxd[0]=value[i]; repeat(16) step(); end
        rxd[0]=1; repeat(32) step(); rx_tick=0;
    endtask
    task automatic transmit_b(input reg [7:0] value);
        reg [9:0] frame;
        frame={1'b1,value,1'b0}; tx_tick=2;
        for(integer i=0;i<10;i=i+1) repeat(16) begin
            if(txd[1]!==frame[i]) $fatal(1,"TX byte %h bit %0d mismatch",value,i);
            step();
        end
        tx_tick=0;
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        repeat(8) step(); reset=0;
        for(integer ch=0;ch<2;ch=ch+1) begin
            wr(1'(ch),4,8'h44); wr(1'(ch),3,8'hc1); wr(1'(ch),5,8'hea);
        end
        wr(0,1,8'ha0); wr(1,1,8'h80); put(2,8'h69);
        // Empty RX read stalls; neither read latch nor pop may complete early.
        @(negedge clk); #1; address=0; cpu_cs=1; cpu_rd_n=0;
        repeat(40) begin step(); if(wait_n!==2 || unsupported) $fatal(1,"empty RX didn't stall/other channel stalled"); end
        receive_a(8'h53);
        repeat(20) begin step(); if(wait_n!==3 || cpu_dout!==8'h53) $fatal(1,"completed held RX re-stalled/changed"); end
        release_bus(); check(1,4); // one pop, not one per held edge
        // Full TX write stalls without replacing 69 or flagging overflow.
        @(negedge clk); #1; address=2; cpu_din=8'h17; cpu_cs=1; cpu_wr_n=0;
        repeat(40) begin step(); if(wait_n!==1 || unsupported) $fatal(1,"full TX didn't stall"); end
        tx_tick=2; step(); tx_tick=0; step();
        repeat(20) begin step(); if(wait_n!==3 || unsupported) $fatal(1,"completed TX write re-stalled"); end
        release_bus(); check(3,0);
        transmit_b(8'h69); tx_tick=2; step(); tx_tick=0;
        transmit_b(8'h17); check(3,4);
        // Ready is independent of selection until any SIO CPU transfer.
        wr(0,1,8'he0); wr(1,1,8'hc0);
        if(ready_n!==1 || wait_n!==3) $fatal(1,"RX-empty/TX-empty Ready polarity");
        receive_a(8'ha6); if(ready_n!==0) $fatal(1,"RX available Ready not active");
        @(negedge clk); #1; address=3; cpu_cs=1; cpu_rd_n=0; #1;
        if(ready_n!==3 || wait_n!==3) $fatal(1,"control transfer did not release both Ready outputs");
        repeat(5) step(); release_bus(); if(ready_n!==0) $fatal(1,"Ready did not return after control release");
        check(0,8'ha6); if(ready_n!==1) $fatal(1,"one RX pop didn't release Ready");
        put(2,8'h71); if(ready_n!==3) $fatal(1,"TX-full Ready polarity");
        tx_tick=2; step(); tx_tick=0; if(ready_n!==1) $fatal(1,"TX holding take didn't assert Ready");
        wr(0,1,0); wr(1,1,0); if(ready_n!==3 || wait_n!==3) $fatal(1,"disabled flow not released");
        if(unsupported || irq) $fatal(1,"flow-only configuration affected IRQ/diagnostic");
        // Chip reset releases flow on SYS even with advancement stopped.
        wr(0,1,8'ha0); @(negedge clk); #1; address=0; cpu_cs=1; cpu_rd_n=0;
        step(); if(wait_n[0]) $fatal(1,"reset fixture missing RX stall");
        pause_ce=1; @(negedge clk); #1; reset=1; @(posedge clk); #1;
        if(wait_n!==3 || ready_n!==3 || unsupported) $fatal(1,"stopped-CE reset retained flow");
        $display("PASS: SIO selected RX/TX WAIT defers effects, held completion, real queued TX pins, Ready polarity/global CPU suppression/reset CE=%0d",period);
        $finish;
    end
    initial begin #20000000; $fatal(1,"SIO flow watchdog"); end
endmodule
