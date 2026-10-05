// SPDX-License-Identifier: GPL-2.0-or-later
// Original pin-driven format matrix; expected bytes derived independently
// from the public register contract, not from DUT state or emulator code.
`timescale 1ns/1ps
module sio_formats_tb;
    reg clk=0, ce=0, reset=1;
    always #5 clk=~clk;
    integer period=1, edges=0, cases=0;
    always @(negedge clk) begin edges=edges+1; ce=(edges%period)==0; end
    reg cpu_cs=0, cpu_rd_n=1, cpu_wr_n=1;
    reg [1:0] address=0;
    reg [7:0] cpu_din=0;
    wire [7:0] cpu_dout;
    reg [1:0] rx_tick=0, tx_tick=0, rxd=3, cts_n=3, dcd_n=3;
    wire [1:0] txd,rts_n,dtr_n;
    wire unsupported;
    x1_sio_async dut(.*);
    task automatic step;
        do begin @(posedge clk); #1; end while(!ce);
    endtask
    task automatic put(input reg [1:0] port_number,input reg [7:0] value);
        @(negedge clk); #1;
        address=port_number; cpu_din=value; cpu_cs=1; cpu_wr_n=0;
        repeat(3) step();
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
    endtask
    task automatic check(input reg [1:0] port_number,input reg [7:0] expected);
        reg [7:0] value;
        @(negedge clk); #1;
        address=port_number; cpu_cs=1; cpu_rd_n=0;
        step(); value=cpu_dout;
        if(value!==expected) $fatal(1,"case %0d port %0d got %h expected %h",cases,port_number,value,expected);
        repeat(3) begin step(); if(cpu_dout!==value) $fatal(1,"held read changed"); end
        @(negedge clk); #1; cpu_cs=0; cpu_rd_n=1; step();
    endtask
    task automatic rr1(input reg channel,input reg [7:0] expected);
        put({channel,1'b1},1); check({channel,1'b1},expected);
    endtask
    function automatic [1:0] length_code(input integer bits);
        case(bits) 5:length_code=0; 6:length_code=2; 7:length_code=1; default:length_code=3; endcase
    endfunction
    function automatic reg parity_bit(input reg [7:0] value,input integer bits,input integer parity_mode);
        reg result;
        result=0;
        for(integer i=0;i<bits;i=i+1) result=result^value[i];
        return parity_mode==1 ? result : !result; // 1 even, 2 odd
    endfunction
    function automatic [7:0] received(input reg [7:0] value,input integer bits,
        input integer parity_mode,input reg corrupt);
        reg [7:0] result;
        result=8'hff;
        for(integer i=0;i<bits;i=i+1) result[i]=value[i];
        if(parity_mode!=0 && bits<8) result[bits]=parity_bit(value,bits,parity_mode)^corrupt;
        return result;
    endfunction
    task automatic configure(input integer bits,parity_mode,stops,rate);
        reg [7:0] format;
        format=(8'(rate)<<6)|(8'(stops)<<2);
        if(parity_mode!=0) format=format|1;
        if(parity_mode==1) format=format|2;
        for(integer channel=0;channel<2;channel=channel+1) begin
            put({1'(channel),1'b1},8'h18);
            put({1'(channel),1'b1},4); put({1'(channel),1'b1},format);
            put({1'(channel),1'b1},3); put({1'(channel),1'b1},{length_code(bits),6'b000001});
            put({1'(channel),1'b1},5); put({1'(channel),1'b1},{1'b1,length_code(bits),5'b01010});
        end
        if(unsupported) $fatal(1,"valid format rejected");
    endtask
    task automatic receive_pair(input reg [7:0] a,b,input integer bits,parity_mode,divisor,
        input reg corrupt_a,bad_stop_a);
        rx_tick=3; rxd=0; repeat(divisor) step();
        for(integer i=0;i<bits;i=i+1) begin rxd={b[i],a[i]}; repeat(divisor) step(); end
        if(parity_mode!=0) begin
            rxd={parity_bit(b,bits,parity_mode),parity_bit(a,bits,parity_mode)^corrupt_a};
            repeat(divisor) step();
        end
        // Receiver checks one stop regardless of the configured TX length.
        rxd={1'b1,!bad_stop_a}; repeat(divisor) step();
        rxd=3; repeat(divisor) step(); rx_tick=0;
    endtask
    task automatic transmit_pair(input reg [7:0] a,b,input integer bits,parity_mode,stops,divisor);
        reg [1:0] expected;
        integer duration, final_bit;
        put(0,a); put(2,b);
        tx_tick=3; step(); tx_tick=0;
        check(1,4); check(3,4); rr1(0,0); rr1(1,0);
        final_bit=bits+1+(parity_mode!=0 ? 1 : 0);
        for(integer i=0;i<=final_bit;i=i+1) begin
            if(i==0) expected=0;
            else if(i<=bits) expected={b[i-1],a[i-1]};
            else if(i<final_bit) expected={parity_bit(b,bits,parity_mode),parity_bit(a,bits,parity_mode)};
            else expected=3;
            duration=i==final_bit ? (stops==1 ? divisor : stops==2 ? divisor+divisor/2 : divisor*2) : divisor;
            for(integer tick=0;tick<duration;tick=tick+1) begin
                if(txd!==expected) $fatal(1,"case %0d TX bit %0d tick %0d got %b expected %b",cases,i,tick,txd,expected);
                // Freeze serial progression just before completion and prove
                // all-sent remains low through the entire programmed stop.
                if(i==final_bit && tick==duration-1) begin tx_tick=0; rr1(0,0); rr1(1,0); end
                tx_tick=3; step();
            end
        end
        tx_tick=0; rr1(0,1); rr1(1,1);
        if(txd!==3) $fatal(1,"TX idle not high");
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        repeat(8) step(); reset=0;
        for(integer bits=5;bits<=8;bits=bits+1)
            for(integer parity_mode=0;parity_mode<3;parity_mode=parity_mode+1)
                for(integer stops=1;stops<=3;stops=stops+1)
                    for(integer rate=1;rate<=3;rate=rate+1) begin
                        integer divisor;
                        divisor=8<<rate; cases=cases+1;
                        configure(bits,parity_mode,stops,rate);
                        receive_pair(8'h69,8'h96,bits,parity_mode,divisor,0,0);
                        rr1(0,1); rr1(1,1);
                        check(0,received(8'h69,bits,parity_mode,0));
                        check(2,received(8'h96,bits,parity_mode,0));
                        check(1,4); check(3,4);
                        transmit_pair(8'ha6,8'h39,bits,parity_mode,stops,divisor);
                        if(parity_mode!=0) begin
                            receive_pair(8'h53,8'hac,bits,parity_mode,divisor,1,0);
                            rr1(0,8'h11); rr1(1,1);
                            check(0,received(8'h53,bits,parity_mode,1));
                            check(2,received(8'hac,bits,parity_mode,0));
                            rr1(0,8'h11); put(1,8'h30); rr1(0,1);
                        end
                        receive_pair(8'h17,8'he8,bits,parity_mode,divisor,0,1);
                        rr1(0,8'h41); rr1(1,1);
                        check(0,received(8'h17,bits,parity_mode,0));
                        check(2,received(8'he8,bits,parity_mode,0));
                        rr1(0,1); rr1(1,1);
                        if(unsupported) $fatal(1,"format exercise flagged unsupported");
                    end
        if(cases!=108) $fatal(1,"matrix incomplete");
        // RX and TX word lengths are independent. Also verify parity errors
        // wait behind an older good word before becoming sticky at the head.
        configure(5,2,2,3);
        receive_pair(8'h53,8'hac,5,2,64,0,0);
        receive_pair(8'h17,8'he8,5,2,64,1,0);
        rr1(0,1); rr1(1,1);
        check(0,received(8'h53,5,2,0)); rr1(0,8'h11);
        check(0,received(8'h17,5,2,1)); rr1(0,8'h11);
        put(1,8'h30); rr1(0,1);
        check(2,received(8'hac,5,2,0)); check(2,received(8'he8,5,2,0)); rr1(1,1);
        put(1,5); put(1,8'hea); put(3,5); put(3,8'hea);
        transmit_pair(8'ha6,8'h39,8,2,2,64);
        receive_pair(8'h53,8'hac,5,2,64,0,0);
        check(0,received(8'h53,5,2,0)); check(2,received(8'hac,5,2,0));
        if(unsupported) $fatal(1,"independent RX/TX lengths rejected");
        // Unsupported modes must remain explicit, not silently look complete.
        put(1,1); put(1,8'h18); if(!unsupported) $fatal(1,"IRQ mode falsely supported");
        configure(8,0,1,1);
        put(1,5); put(1,8'hfa); if(!unsupported) $fatal(1,"break falsely supported");
        configure(8,0,1,1);
        put(1,4); put(1,8'h40); if(!unsupported) $fatal(1,"sync mode falsely supported");
        configure(8,0,1,1);
        put(0,8'h69); tx_tick=1; step(); tx_tick=0;
        put(1,5); put(1,8'hea);
        if(!unsupported) $fatal(1,"live TX reconfiguration falsely supported");
        $display("PASS: 108 dual-channel SIO formats, exact TX duration, short RX fill/parity, parity/framing/reset CE=%0d",period);
        $finish;
    end
    initial begin #100000000; $fatal(1,"format fixture watchdog"); end
endmodule
