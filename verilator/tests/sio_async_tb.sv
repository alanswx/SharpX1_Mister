// SPDX-License-Identifier: GPL-2.0-or-later
// Original pin-driven standalone SIO polled 8N1 tests, no firmware assets.
`timescale 1ns/1ps
module sio_async_tb;
    reg clk=0, ce=0, reset=1, pause_ce=0;
    always #5 clk=~clk;
    integer period=1, edges=0;
    always @(negedge clk) begin edges=edges+1; ce=!pause_ce && (edges%period)==0; end
    reg cpu_cs=0, cpu_rd_n=1, cpu_wr_n=1;
    reg [1:0] address=0;
    reg [7:0] cpu_din=0;
    wire [7:0] cpu_dout;
    reg [1:0] rx_tick=0,tx_tick=0,rxd=3,cts_n=3,dcd_n=3;
    wire [1:0] txd,rts_n,dtr_n;
    wire unsupported;
    x1_sio_async dut(.*);
    task automatic step;
        do begin @(posedge clk); #1; end while(!ce);
    endtask
    task automatic put(input reg [1:0] port_number,input reg [7:0] value);
        @(negedge clk); #1;
        address=port_number; cpu_din=value; cpu_cs=1; cpu_wr_n=0;
        repeat(5) step();
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1;
        step();
    endtask
    task automatic get(input reg [1:0] port_number,output reg [7:0] value);
        @(negedge clk); #1;
        address=port_number; cpu_cs=1; cpu_rd_n=0;
        step(); value=cpu_dout;
        repeat(5) begin step(); if(cpu_dout!==value) $fatal(1,"held read changed"); end
        @(negedge clk); #1; cpu_cs=0; cpu_rd_n=1;
        step();
    endtask
    task automatic config_channel(input reg channel);
        reg [1:0] ctrl;
        ctrl={channel,1'b1};
        put(ctrl,4); put(ctrl,8'h44);
        put(ctrl,3); put(ctrl,8'hc1);
        put(ctrl,5); put(ctrl,8'hea); // 8N1 enabled, RTS/DTR asserted.
    endtask
    task automatic receive_two(input reg [7:0] a,b,input reg bad_stop);
        rx_tick=3; rxd=0;
        repeat(16) step();
        for(integer bit_number=0;bit_number<8;bit_number=bit_number+1) begin
            rxd={b[bit_number],a[bit_number]}; repeat(16) step();
        end
        rxd=bad_stop ? 0 : 3; repeat(16) step();
        rxd=3; repeat(16) step(); rx_tick=0;
    endtask
    task automatic check_byte(input reg [1:0] port_number,input reg [7:0] expected);
        reg [7:0] actual;
        get(port_number,actual);
        if(actual!==expected) $fatal(1,"port %0d byte %h expected %h",port_number,actual,expected);
    endtask
    reg [7:0] value;
    reg [9:0] expected_a,expected_b;
    task automatic receive_pop_collision(input integer occupancy);
        // Wait on the naturally reached completion phase, then issue an
        // ordinary CPU read on that same enabled edge. No DUT state forcing.
        fork
            receive_two(8'h64,8'hb4,0);
            begin
                wait(dut.channels[0].unit.rx_push);
                @(negedge clk); #1;
                address=0; cpu_cs=1; cpu_rd_n=0;
                do begin @(posedge clk);
                    if(ce && !dut.channels[0].unit.rx_push)
                        $fatal(1,"fixture missed RX completion/pop collision");
                    #1;
                end while(!ce);
                if(cpu_dout!==8'h61) $fatal(1,"collision did not return old FIFO head");
                repeat(3) step();
                @(negedge clk); #1; cpu_cs=0; cpu_rd_n=1; step();
            end
        join
        for(integer i=1;i<occupancy;i=i+1) check_byte(0,8'h61+8'(i));
        check_byte(0,8'h64); check_byte(1,4);
        put(1,1); check_byte(1,1); // simultaneous pop prevents overrun.
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        repeat(8) step(); reset=0;
        check_byte(1,4); check_byte(3,4);
        config_channel(0); config_channel(1);
        if(unsupported || rts_n!==0 || dtr_n!==0) $fatal(1,"supported config rejected");
        // False start shorter than half a bit must not enter either FIFO.
        rx_tick=3; rxd=0; repeat(3) step(); rxd=3; repeat(160) step(); rx_tick=0;
        check_byte(1,4); check_byte(3,4);
        receive_two(8'h35,8'hc2,0);
        receive_two(8'ha6,8'h19,0);
        receive_two(8'h71,8'he8,0);
        check_byte(1,5); check_byte(3,5);
        // A held data read must pop once, never once per enabled edge.
        check_byte(0,8'h35); check_byte(2,8'hc2);
        check_byte(0,8'ha6); check_byte(2,8'h19);
        check_byte(0,8'h71); check_byte(2,8'he8);
        check_byte(1,4); check_byte(3,4);
        receive_two(1,8'h91,0); receive_two(2,8'h92,0);
        receive_two(3,8'h93,0); receive_two(4,8'h94,0);
        // The overwritten third character carries overrun, not the older
        // first/second words. Once visible, its error persists until reset.
        put(1,1); check_byte(1,1); put(3,1); check_byte(3,1);
        check_byte(0,1); check_byte(0,2);
        put(1,1); check_byte(1,8'h21); check_byte(0,4);
        check_byte(2,8'h91); check_byte(2,8'h92);
        put(3,1); check_byte(3,8'h21); check_byte(2,8'h94);
        put(1,8'h30); put(3,8'h30);
        put(1,1); check_byte(1,1); put(3,1); check_byte(3,1);
        receive_two(8'h5a,8'ha5,1); receive_two(8'h87,8'h78,0);
        put(1,1); check_byte(1,8'h41); put(3,1); check_byte(3,8'h41);
        check_byte(0,8'h5a); check_byte(2,8'ha5);
        put(1,1); check_byte(1,1); put(3,1); check_byte(3,1);
        check_byte(0,8'h87); check_byte(2,8'h78);
        // Separate TX holding/shifter: RR0 empty while RR1 not all sent.
        put(0,8'h69); put(2,8'h96); tx_tick=3; step(); tx_tick=0;
        // SYS and CPU advances alone must not move serial shifters.
        repeat(100) begin step(); if(txd!==0) $fatal(1,"paused serial clock advanced TX"); end
        check_byte(1,4); put(1,1); check_byte(1,0);
        put(0,8'h17); put(2,8'he8); check_byte(1,0); check_byte(3,0);
        expected_a={1'b1,8'h69,1'b0}; expected_b={1'b1,8'h96,1'b0};
        tx_tick=3;
        for(integer bit_number=0;bit_number<10;bit_number=bit_number+1) begin
            if(txd!=={expected_b[bit_number],expected_a[bit_number]}) $fatal(1,"TX bit mismatch %0d",bit_number);
            repeat(16) step();
        end
        step(); // next holding byte enters shifter on the next tick.
        expected_a={1'b1,8'h17,1'b0}; expected_b={1'b1,8'he8,1'b0};
        for(integer bit_number=0;bit_number<10;bit_number=bit_number+1) begin
            if(txd!=={expected_b[bit_number],expected_a[bit_number]}) $fatal(1,"second TX bit mismatch %0d",bit_number);
            repeat(16) step();
        end
        tx_tick=0;
        put(1,1); check_byte(1,1); put(3,1); check_byte(3,1);
        if(txd!==3 || unsupported) $fatal(1,"idle TX/supported slice mismatch");
        // RX completion plus CPU pop at every nonempty FIFO occupancy.
        for(integer occupancy=1;occupancy<=3;occupancy=occupancy+1) begin
            put(1,8'h18); put(3,8'h18); config_channel(0); config_channel(1);
            for(integer i=0;i<occupancy;i=i+1) receive_two(8'h61+8'(i),8'hb1+8'(i),0);
            receive_pop_collision(occupancy);
        end
        // Taking TX holding data and replacing it with a CPU write on the
        // same edge must transmit both characters, without an overflow flag.
        put(1,8'h18); put(3,8'h18); config_channel(0); config_channel(1);
        put(0,8'h69);
        @(negedge clk); #1;
        address=0; cpu_din=8'h17; cpu_cs=1; cpu_wr_n=0; tx_tick=1;
        step(); tx_tick=0;
        repeat(3) step();
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
        check_byte(1,0); put(1,1); check_byte(1,0);
        expected_a={1'b1,8'h69,1'b0}; tx_tick=1;
        for(integer i=0;i<10;i=i+1) begin
            if(txd[0]!==expected_a[i]) $fatal(1,"TX collision first byte bit %0d",i);
            repeat(16) step();
        end
        step(); expected_a={1'b1,8'h17,1'b0};
        for(integer i=0;i<10;i=i+1) begin
            if(txd[0]!==expected_a[i]) $fatal(1,"TX collision replacement byte bit %0d",i);
            repeat(16) step();
        end
        tx_tick=0; put(1,1); check_byte(1,1);
        if(unsupported) $fatal(1,"simultaneous accesses flagged unsupported");
        // Independent pins, unsupported modes, and channel-reset isolation.
        cts_n=2'b10; dcd_n=2'b01;
        check_byte(1,8'h24); check_byte(3,8'h0c);
        put(1,4); put(1,8'h08); if(!unsupported) $fatal(1,"x1 half-bit synchronization falsely supported");
        put(1,8'h18); if(unsupported) $fatal(1,"channel reset retained unsupported");
        if(rts_n!==2'b01 || dtr_n!==2'b01) $fatal(1,"A reset disturbed B modem outputs");
        check_byte(1,8'h24); check_byte(3,8'h0c);
        // Reset remains effective on SYS while advancement CE is stopped.
        pause_ce=1; @(negedge clk); #1;
        if(ce) $fatal(1,"fixture failed to stop advancement CE");
        reset=1; @(posedge clk); #1; reset=0;
        if(txd!==3 || rts_n!==3 || dtr_n!==3 || unsupported)
            $fatal(1,"chip reset ineffective with CE stopped");
        $display("PASS: two-channel polled SIO 8N1 pins, FIFO/errors, TX buffering, parser/reset CE=%0d",period);
        $finish;
    end
    initial begin #10000000; $fatal(1,"SIO fixture watchdog"); end
endmodule
