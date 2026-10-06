// SPDX-License-Identifier: GPL-2.0-or-later
// Original pin/CPU-bus first-character and CTS/DCD tests. No forced state.
`timescale 1ns/1ps
module sio_first_status_tb;
    reg clk=0,ce=0,reset=1,pause_ce=0;
    always #5 clk=~clk;
    integer period=1,edges=0,acks=0;
    always @(negedge clk) begin edges=edges+1; ce=!pause_ce && edges%period==0; end
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
    x1_sio_interrupt dut(.*);
    task automatic step;
        do begin @(posedge clk); #1; end while(!ce);
    endtask
    task automatic put(input reg [1:0] p,input reg [7:0] value);
        @(negedge clk); #1; address=p; cpu_din=value; cpu_cs=1; cpu_wr_n=0;
        repeat(5) step(); @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
    endtask
    task automatic check(input reg [1:0] p,input reg [7:0] expected);
        @(negedge clk); #1; address=p; cpu_cs=1; cpu_rd_n=0;
        step(); if(cpu_dout!==expected) $fatal(1,"port %0d got %h expected %h",p,cpu_dout,expected);
        repeat(5) begin step(); if(cpu_dout!==expected) $fatal(1,"held read changed"); end
        @(negedge clk); #1; cpu_cs=0; cpu_rd_n=1; step();
    endtask
    task automatic wr(input reg ch,input reg [7:0] index,value);
        put({ch,1'b1},index); put({ch,1'b1},value);
    endtask
    task automatic rr1(input reg ch,input reg [7:0] value);
        put({ch,1'b1},1); check({ch,1'b1},value);
    endtask
    task automatic setup(input reg [7:0] a,b);
        for(integer ch=0;ch<2;ch=ch+1) begin
            put({1'(ch),1'b1},8'h18);
            wr(1'(ch),4,8'h44); wr(1'(ch),3,8'hc1); wr(1'(ch),5,8'hea);
        end
        wr(1,2,8'ha1); wr(0,1,a); wr(1,1,b|4);
        if(irq || !ieo || unsupported) $fatal(1,"setup mismatch");
    endtask
    task automatic receive(input reg [1:0] channels,input reg [7:0] a,b,input reg bad_stop,parity);
        rx_tick=channels; rxd=~channels; repeat(16) step();
        for(integer i=0;i<8;i=i+1) begin rxd={b[i],a[i]}|~channels; repeat(16) step(); end
        if(parity) begin rxd=3; repeat(16) step(); end // corrupt odd parity for A=31
        rxd=bad_stop ? ~channels : 3; repeat(16) step(); rxd=3; repeat(16) step(); rx_tick=0;
    endtask
    task automatic ack(input reg [7:0] expected);
        #1; if(!irq) $fatal(1,"no eligible IRQ for %h",expected);
        @(negedge clk); #1; acknowledge=1; #1;
        if(ack_vector!==expected) $fatal(1,"vector %h expected %h",ack_vector,expected);
        repeat(40) begin @(posedge clk); #1; if(ack_vector!==expected) $fatal(1,"held ACK changed"); end
        @(negedge clk); #1; acknowledge=0; @(posedge clk); #1; acks=acks+1;
    endtask
    task automatic return_local;
        @(negedge clk); #1; reti=1; @(posedge clk); #1;
        @(negedge clk); #1; reti=0;
    endtask
    task automatic no_irq;
        #1; if(irq) $fatal(1,"unexpected IRQ vector %h",ack_vector);
    endtask
    task automatic reset_completion_collision(input integer occupancy);
        setup(8'h08,8'h08);
        receive(1,8'h41,0,1,0);
        for(integer i=1;i<occupancy;i=i+1) receive(1,8'h41+8'(i),0,0,0);
        ack(8'haf); put(1,8'h20);
        fork
            receive(1,8'h44,0,0,0);
            begin
                // Observe a naturally reached completion phase; issue a real
                // WR0 Error Reset on the same enabled edge, never force state.
                wait(dut.channels[0].unit.rx_push);
                @(negedge clk); #1; address=1; cpu_din=8'h30; cpu_cs=1; cpu_wr_n=0;
                do begin
                    @(posedge clk);
                    if(ce && !dut.channels[0].unit.rx_push) $fatal(1,"missed Error Reset/completion collision");
                    #1;
                end while(!ce);
                repeat(5) step();
                @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
            end
        join
        rr1(0,1); return_local();
        for(integer i=1;i<occupancy;i=i+1) begin no_irq(); check(0,8'h41+8'(i)); end
        ack(8'had); check(0,8'h44); return_local(); no_irq(); check(1,4);
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        repeat(8) step(); reset=0;
        setup(8'h08,8'h08);
        // Explicit arming, not an assumed reset-time first-character policy.
        receive(3,8'h11,8'h91,0,0); no_irq(); check(0,8'h11); check(2,8'h91);
        put(1,8'h20); put(3,8'h20); receive(3,8'h12,8'h92,0,0);
        ack(8'had); check(0,8'h12); return_local();
        ack(8'ha5); check(2,8'h92); return_local(); no_irq();
        receive(1,8'h21,0,0,0); receive(1,8'h22,0,0,0);
        put(1,8'h20); receive(1,8'h23,0,0,0);
        no_irq(); check(0,8'h21); no_irq(); check(0,8'h22);
        ack(8'had); check(0,8'h23); return_local(); no_irq();
        // Framing locks the offending byte even after repeated data reads.
        receive(1,8'h41,0,1,0); receive(1,8'h42,0,0,0);
        ack(8'haf); rr1(0,8'h41); check(0,8'h41); check(0,8'h41);
        rr1(0,8'h41); put(1,8'h30); rr1(0,1); return_local(); no_irq();
        check(0,8'h42); check(1,4);
        // Fourth byte replaces third, then locks only when it reaches head.
        for(integer i=0;i<4;i=i+1) receive(1,8'h51+8'(i),0,0,0);
        no_irq(); check(0,8'h51); no_irq(); check(0,8'h52);
        ack(8'haf); rr1(0,8'h21); check(0,8'h54); check(0,8'h54);
        put(1,8'h30); rr1(0,1); check(1,4); return_local(); no_irq();
        // Parity-only errors neither lock nor produce a special first-mode vector.
        wr(0,4,8'h45); receive(1,8'h31,0,0,1);
        no_irq(); rr1(0,8'h11); check(0,8'h31); put(1,8'h30);
        put(1,8'h20); receive(1,8'h31,0,0,1);
        ack(8'had); rr1(0,8'h11); check(0,8'h31); put(1,8'h30); return_local(); no_irq();
        reset_completion_collision(1); reset_completion_collision(3);
        // External snapshots: a one-SYS-edge pulse is retained with CE stopped.
        setup(1,1); pause_ce=1; @(negedge clk); #1;
        cts_n=2; @(posedge clk); #1;
        cts_n=3; @(posedge clk); #1;
        if(!irq || ce) $fatal(1,"CTS pulse lost while CE stopped");
        pause_ce=0; check(1,8'h26); check(3,4);
        ack(8'hab); return_local(); // ACK/RETI don't clear the source snapshot.
        if(!irq) $fatal(1,"RETI cleared external pending");
        put(1,8'h10); no_irq(); check(1,4);
        // Both pins/channels transition; A external outranks B external.
        cts_n=0; dcd_n=0; step();
        check(1,8'h2e); check(3,8'h2c); ack(8'hab);
        cts_n=3; dcd_n=3; step(); // snapshot must stay at the first transition.
        check(1,8'h2e); check(3,8'h2c);
        put(1,8'h10); no_irq(); // A service still blocks B even after source reset.
        check(1,6); return_local(); ack(8'ha3);
        put(3,8'h10); return_local(); no_irq(); check(1,4); check(3,4);
        // All six real sources at once establish full internal priority.
        setup(8'h13,8'h13); put(0,8'h69); put(2,8'h96); tx_tick=3; step(); tx_tick=0;
        receive(3,8'h61,8'hb1,0,0); cts_n=0; step();
        ack(8'had); check(0,8'h61); return_local();
        ack(8'ha9); put(1,8'h28); return_local();
        ack(8'hab); put(1,8'h10); return_local();
        ack(8'ha5); check(2,8'hb1); return_local();
        ack(8'ha1); put(3,8'h28); return_local();
        ack(8'ha3); put(3,8'h10); return_local(); no_irq();
        // Disabling external interrupts removes pending, not service. Pin
        // levels remain readable live while disabled, without replay on enable.
        setup(1,0); cts_n[0]=!cts_n[0]; step(); ack(8'hab);
        wr(0,1,0); no_irq(); if(ieo) $fatal(1,"external disable incorrectly released service");
        return_local(); if(!ieo) $fatal(1,"external disabled service did not return");
        cts_n[0]=!cts_n[0]; step(); no_irq();
        wr(0,1,1); no_irq();
        if(!ieo || unsupported) $fatal(1,"final priority/diagnostic state");
        pause_ce=1; @(negedge clk); #1; cts_n[0]=!cts_n[0];
        @(posedge clk); #1; if(!irq) $fatal(1,"reset fixture lacks pending external source");
        reset=1; @(posedge clk); #1; reset=0;
        if(irq || !ieo || unsupported || txd!==3) $fatal(1,"external pending survived stopped-CE chip reset");
        $display("PASS: first-character arm/FIFO markers, framing/overrun locks/Error Reset, parity exclusion, CTS/DCD snapshots, stopped-CE pulses, six-source priority CE=%0d ACKs=%0d",period,acks);
        $finish;
    end
    initial begin #20000000; $fatal(1,"first/status fixture watchdog"); end
endmodule
