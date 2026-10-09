// SPDX-License-Identifier: GPL-2.0-or-later
// Original externally bit-synchronized asynchronous x1 serial fixture.
// UM0081 printed 286-287 permits x1; SYS must exceed 4.5x data rate.
`timescale 1ns/1ps
module sio_x1_tb;
    reg clk=0,ce=0,reset=1;
    always #5 clk=~clk;
    integer period=1,edges=0,cases=0;
    always @(negedge clk) begin edges++;ce=(edges%period)==0;end
    reg cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
    reg [1:0] address=0;
    reg [7:0] cpu_din=0;
    wire [7:0] cpu_dout;
    reg [1:0] rx_tick=0,tx_tick=0,rxd=3,cts_n=3,dcd_n=3;
    wire [1:0] txd,rts_n,dtr_n;
    wire unsupported;
    x1_sio_async dut(.*);
    task automatic step;
        do begin @(posedge clk);#1;end while(!ce);
    endtask
    task automatic put(input [1:0] p,input [7:0] value);
        @(negedge clk);#1;address=p;cpu_din=value;cpu_cs=1;cpu_wr_n=0;
        repeat(3) step();
        @(negedge clk);#1;cpu_cs=0;cpu_wr_n=1;step();
    endtask
    task automatic check(input [1:0] p,input [7:0] expected);
        @(negedge clk);#1;address=p;cpu_cs=1;cpu_rd_n=0;step();
        repeat(3) begin
            assert(cpu_dout==expected)
                else $fatal(1,"x1 case %0d port %0d got %h expected %h",cases,p,cpu_dout,expected);
            step();
        end
        @(negedge clk);#1;cpu_cs=0;cpu_rd_n=1;step();
    endtask
    task automatic wr(input bit ch,input [7:0] index,value);
        put({ch,1'b1},index);put({ch,1'b1},value);
    endtask
    task automatic rr1(input bit ch,input [7:0] expected);
        put({ch,1'b1},1);check({ch,1'b1},expected);
    endtask
    function automatic [1:0] length_code(input integer bits);
        case(bits) 5:return 0;6:return 2;7:return 1;default:return 3;endcase
    endfunction
    function automatic bit parity(input [7:0] value,input integer bits,mode);
        bit v;v=0;for(integer i=0;i<bits;i++) v^=value[i];
        return mode==1 ? v : !v;
    endfunction
    function automatic [7:0] received(input [7:0] value,input integer bits,mode,input bit corrupt);
        reg [7:0] v;v=8'hff;
        for(integer i=0;i<bits;i++) v[i]=value[i];
        if(mode!=0 && bits<8) v[bits]=parity(value,bits,mode)^corrupt;
        return v;
    endfunction
    task automatic pulse_rx(input [1:0] value);
        @(negedge clk);#1;rxd=value;rx_tick=3;step();rx_tick=0;
        repeat(7) step(); // one bit event per eight device clocks, not x8 mode
    endtask
    task automatic pulse_tx;
        @(negedge clk);#1;tx_tick=3;step();tx_tick=0;
        repeat(7) step();
    endtask
    task automatic configure(input integer bits,mode,stops);
        for(integer ch=0;ch<2;ch++) begin
            put({1'(ch),1'b1},8'h18);
            wr(1'(ch),4,(8'(stops)<<2)|(mode==0 ? 8'd0 : mode==1 ? 8'd3 : 8'd1));
            wr(1'(ch),3,{length_code(bits),6'b000001});
            wr(1'(ch),5,{1'b1,length_code(bits),5'b01010});
        end
        assert(!unsupported) else $fatal(1,"asynchronous x1 legal format rejected");
    endtask
    task automatic receive_pair(input [7:0] a,b,input integer bits,mode,input bit bad_parity,bad_stop);
        pulse_rx(0);
        for(integer i=0;i<bits;i++) pulse_rx({b[i],a[i]});
        if(mode!=0) pulse_rx({parity(b,bits,mode),parity(a,bits,mode)^bad_parity});
        pulse_rx({1'b1,!bad_stop});rxd=3;
        rr1(0,8'h01|(bad_stop ? 8'h40 : 0)|(bad_parity ? 8'h10 : 0));
        rr1(1,1);
        check(0,received(a,bits,mode,bad_parity));
        check(2,received(b,bits,mode,0));
        check(1,4);check(3,4);
    endtask
    task automatic transmit_pair(input [7:0] a,b,input integer bits,mode,stops);
        reg [1:0] expected;
        put(0,bits==5 ? a & 8'h1f : a);put(2,bits==5 ? b & 8'h1f : b);
        pulse_tx();assert(txd==0) else $fatal(1,"x1 TX missing start");
        rr1(0,0);rr1(1,0);
        for(integer i=0;i<bits;i++) begin
            pulse_tx();expected={b[i],a[i]};
            assert(txd==expected) else $fatal(1,"x1 TX data bit %0d",i);
        end
        if(mode!=0) begin
            pulse_tx();assert(txd=={parity(b,bits,mode),parity(a,bits,mode)})
                else $fatal(1,"x1 TX parity");
        end
        pulse_tx();assert(txd==3) else $fatal(1,"x1 TX stop");
        for(integer i=0;i<(stops==1 ? 1 : 2);i++) begin
            rr1(0,0);rr1(1,0);repeat(16) step(); // stopped serial clocks
            pulse_tx();
        end
        rr1(0,1);rr1(1,1);assert(txd==3 && !unsupported) else $fatal(1,"x1 final TX state");
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        repeat(8) step();reset=0;
        for(integer bits=5;bits<=8;bits++)
            for(integer mode=0;mode<3;mode++)
                for(integer stops=1;stops<=3;stops+=2) begin
                    configure(bits,mode,stops);
                    receive_pair(8'ha5,8'h5a,bits,mode,0,0);
                    transmit_pair(8'ha5,8'h5a,bits,mode,stops);cases++;
                end
        configure(8,1,1);receive_pair(8'h36,8'hc9,8,1,1,0);cases++;
        configure(8,0,1);receive_pair(8'h63,8'h9c,8,0,0,1);cases++;
        // No half-bit event exists on this interface: don't silently shorten
        // x1 1.5-stop TX to one bit, or accept a synchronous-mode UART alias.
        configure(8,0,1);wr(0,4,8'h08);
        assert(unsupported) else $fatal(1,"x1 fractional stop silently accepted");
        put(1,8'h18);wr(0,4,0);
        assert(unsupported) else $fatal(1,"synchronous UART alias accepted");
        $display("PASS x1 externally synchronized A/B RX/TX %0d formats/errors CE=%0d; exact stops, held reads and unsupported half-bit/sync guards",cases,period);
        $finish;
    end
endmodule
