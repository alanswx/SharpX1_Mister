// SPDX-License-Identifier: GPL-2.0-or-later
// Original external-pin/CPU-port auto-enable diagnostic; no forced DUT state.
`timescale 1ns/1ps
module sio_auto_enable_tb;
    reg clk=0, ce=0, reset=1, pause_ce=0;
    always #5 clk=~clk;
    integer period=1, edges=0;
    always @(negedge clk) begin edges=edges+1; ce=!pause_ce && (edges%period)==0; end
    reg cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
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
    task automatic put(input reg [1:0] port_number,input reg [7:0] data_byte);
        @(negedge clk); #1;
        address=port_number; cpu_din=data_byte; cpu_cs=1; cpu_wr_n=0;
        repeat(5) step();
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
    endtask
    task automatic check(input reg [1:0] port_number,input reg [7:0] expected);
        @(negedge clk); #1;
        address=port_number; cpu_cs=1; cpu_rd_n=0;
        step();
        if(cpu_dout!==expected) $fatal(1,"auto-enable port %0d got %h expected %h",port_number,cpu_dout,expected);
        repeat(3) begin step(); if(cpu_dout!==expected) $fatal(1,"held status/data changed"); end
        @(negedge clk); #1; cpu_cs=0; cpu_rd_n=1; step();
    endtask
    task automatic configure(input reg auto_enable,rx_enable,tx_enable);
        for(integer channel=0;channel<2;channel=channel+1) begin
            put({1'(channel),1'b1},4); put({1'(channel),1'b1},8'h44);
            put({1'(channel),1'b1},3); put({1'(channel),1'b1},8'hc0|(auto_enable ? 8'h20 : 0)|(rx_enable ? 1 : 0));
            put({1'(channel),1'b1},5); put({1'(channel),1'b1},8'he2|(tx_enable ? 8'h08 : 0));
        end
        if(unsupported) $fatal(1,"auto-enable configuration rejected");
    endtask
    task automatic fresh;
        reset=1; rx_tick=0; tx_tick=0; rxd=3; cts_n=3; dcd_n=3;
        repeat(8) step(); reset=0;
    endtask
    task automatic receive_pair(input reg [7:0] a,b);
        rx_tick=3; rxd=0; repeat(16) step();
        for(integer i=0;i<8;i=i+1) begin rxd={b[i],a[i]}; repeat(16) step(); end
        rxd=3; repeat(32) step(); rx_tick=0;
    endtask
    task automatic transmit_pair(input reg [7:0] a,b);
        reg [9:0] frame_a,frame_b;
        frame_a={1'b1,a,1'b0}; frame_b={1'b1,b,1'b0};
        tx_tick=3; step();
        for(integer bit_number=0;bit_number<10;bit_number=bit_number+1)
            repeat(16) begin
                if(txd!=={frame_b[bit_number],frame_a[bit_number]}) $fatal(1,"auto-enable TX pin mismatch");
                step();
            end
        tx_tick=0;
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        fresh(); configure(1,1,1);
        put(0,8'h69); put(2,8'h96);
        tx_tick=3; repeat(200) begin step(); if(txd!==3) $fatal(1,"inactive CTS started TX"); end
        tx_tick=0; check(1,0); check(3,0);
        // DCD enables RX independently of CTS. A's absent carrier cannot
        // fill its FIFO; B must receive exactly one byte.
        dcd_n=1; receive_pair(8'h35,8'hc2);
        check(1,0); check(3,9); check(2,8'hc2); check(3,8);
        dcd_n=2; receive_pair(8'h64,8'hb4);
        check(1,9); check(0,8'h64); check(1,8); check(3,0);
        dcd_n=3;
        // Pins may change with advancement CE stopped, but no byte is taken
        // until CE and a serial tick actually resume.
        pause_ce=1; cts_n=0; tx_tick=3;
        repeat(20) begin @(posedge clk); #1; if(txd!==3) $fatal(1,"stopped CE advanced TX"); end
        tx_tick=0; pause_ce=0;
        transmit_pair(8'h69,8'h96);
        check(1,8'h24); check(3,8'h24);
        put(1,1); check(1,1); put(3,1); check(3,1);
        // Active carrier loss abandons an incomplete receive character;
        // a fresh start after carrier returns must not reuse partial bits.
        cts_n=3; dcd_n=0; receive_pair(8'h53,8'hac);
        rx_tick=3; rxd=0; repeat(16) step();
        rxd=3; repeat(16) step(); dcd_n=3; repeat(160) step(); rx_tick=0;
        check(1,5); check(3,5); // Already completed FIFO entries survive.
        dcd_n=0; receive_pair(8'h5a,8'ha5);
        check(1,8'h0d); check(3,8'h0d);
        check(0,8'h53); check(2,8'hac); check(0,8'h5a); check(2,8'ha5);
        // Auto Enables does not override either software enable.
        fresh(); configure(1,0,0); cts_n=0; dcd_n=0;
        put(0,8'h69); put(2,8'h96); receive_pair(8'h35,8'hc2);
        tx_tick=3; repeat(200) begin step(); if(txd!==3) $fatal(1,"CTS overrode WR5 disable"); end
        tx_tick=0; check(1,8'h28); check(3,8'h28);
        // Test each software enable independently: disabling one direction
        // must not stop the other, even with both modem inputs active.
        for(integer direction=0;direction<2;direction=direction+1) begin
            fresh(); configure(1,direction==0,direction==1); cts_n=0; dcd_n=0;
            put(0,8'h69); put(2,8'h96); receive_pair(8'h35,8'hc2);
            if(direction==0) begin
                check(0,8'h35); check(2,8'hc2);
                tx_tick=3; repeat(200) begin step(); if(txd!==3) $fatal(1,"RX enable overrode TX disable"); end
                tx_tick=0; check(1,8'h28); check(3,8'h28);
            end else begin
                check(1,8'h28); check(3,8'h28);
                transmit_pair(8'h69,8'h96); check(1,8'h2c); check(3,8'h2c);
            end
        end
        // With auto-enable off, inactive modem inputs remain status-only.
        fresh(); configure(0,1,1);
        receive_pair(8'h35,8'hc2); check(1,5); check(3,5);
        check(0,8'h35); check(2,8'hc2);
        put(0,8'h69); put(2,8'h96); transmit_pair(8'h69,8'h96);
        check(1,4); check(3,4);
        if(unsupported) $fatal(1,"supported auto-enable sequence rejected");
        pause_ce=1; reset=1;
        repeat(5) begin @(posedge clk); #1; end
        if(txd!==3 || rts_n!==3 || dtr_n!==3 || unsupported) $fatal(1,"stopped-CE reset retained modem state");
        reset=0; pause_ce=0; check(1,4); check(3,4);
        $display("PASS: WR3 auto CTS/DCD A/B gating, independent RX/TX, manual-enable AND, non-auto status-only, receive restart, stopped-CE pins/reset CE=%0d",period);
        $finish;
    end
    initial begin #10000000; $fatal(1,"auto-enable watchdog"); end
endmodule
