// SPDX-License-Identifier: GPL-2.0-or-later
// Original diagnostic coupling, NOT the native X1 clock netlist. Both SIO
// channels use CTC channel 0 so separate native channel routes are not guessed.
module sio_ctc_clock_tb;
    timeunit 1ps; timeprecision 1ps;
    reg clk=0,reset=1,ce=0,pause=0;
    integer period=4,phase=0,edges=0,master_hz=32000000;
    time half_period;
    reg wr=0;
    reg [7:0] din=0;
    wire [7:0] dout,vector;
    wire irq,ieo;
    wire [3:0] zc;
    x1_ctc ctc(.clk(clk),.reset(reset),.ce(ce),.wr(wr),.channel(2'b00),
        .din(din),.dout(dout),.trigger(4'b0000),.iei(1'b1),.irq(irq),
        .ieo(ieo),.ack(1'b0),.reti(1'b0),.vector(vector),.zc(zc));
    reg [1:0] rxd=3;
    wire [1:0] rx_tick,tx_tick,sampled_rxd,rx_overflow,tx_overflow;
    bit direct=0;
    reg last_zc=0;
    always @(posedge clk) last_zc<=zc[0];
    wire [1:0] used_rx_tick=direct ? {2{ce && zc[0] && !last_zc}} : rx_tick;
    wire [1:0] used_tx_tick=direct ? {2{ce && !zc[0] && last_zc}} : tx_tick;
    x1_sio_edge_clock adapter(.clk(clk),.reset(reset),.ce(ce),
        .rx_clock({2{zc[0]}}),.tx_clock({2{zc[0]}}),.rxd(rxd),
        .rx_tick(rx_tick),.tx_tick(tx_tick),.sampled_rxd(sampled_rxd),
        .rx_overflow(rx_overflow),.tx_overflow(tx_overflow));
    reg cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
    reg [1:0] address=0;
    reg [7:0] cpu_din=0;
    wire [7:0] cpu_dout;
    wire [1:0] txd,rts_n,dtr_n;
    wire unsupported;
    x1_sio_async sio(.clk(clk),.ce(ce),.reset(reset),.cpu_cs(cpu_cs),
        .cpu_rd_n(cpu_rd_n),.cpu_wr_n(cpu_wr_n),.address(address),
        .cpu_din(cpu_din),.cpu_dout(cpu_dout),.rx_tick(used_rx_tick),
        .tx_tick(used_tx_tick),.rxd(direct ? rxd : sampled_rxd),.cts_n(2'b00),.dcd_n(2'b00),
        .txd(txd),.rts_n(rts_n),.dtr_n(dtr_n),.unsupported(unsupported));
    bit monitor_tx=0,started=0,completed=0;
    integer tx_events=0,rx_events=0;
    reg [9:0] expected_tx={1'b1,8'ha5,1'b0};
    bit saw_rx,saw_tx;

    task automatic step;
        clk=0; ce=!pause && ((edges+phase)%period==0);
        #(half_period);
        saw_rx=used_rx_tick[0]; saw_tx=used_tx_tick[0];
        clk=1; #(half_period); edges++;
        if(saw_rx) rx_events++;
        if(monitor_tx && saw_tx) begin
            if(!started && !txd[0]) begin started=1;tx_events=0; end
            if(started && !completed) begin
                if(tx_events<160) begin
                    assert(txd[0]==expected_tx[tx_events/16])
                        else $fatal(1,"CTC-driven TX mismatch event=%0d",tx_events);
                end else begin
                    assert(txd[0]) else $fatal(1,"TX final stop did not complete");
                    completed=1;
                end
                tx_events++;
            end
        end
        assert(rx_overflow==0 && tx_overflow==0)
            else $fatal(1,"unexpected CTC event overflow");
    endtask
    task automatic accepted;
        do step(); while(!ce);
    endtask
    task automatic put(input bit[1:0] port_number,input bit[7:0] data);
        address=port_number; cpu_din=data; cpu_cs=1;cpu_wr_n=0;
        repeat(5) accepted();
        cpu_cs=0;cpu_wr_n=1;accepted();
    endtask
    task automatic get(input bit[1:0] port_number,input bit[7:0] expected);
        address=port_number;cpu_cs=1;cpu_rd_n=0;accepted();
        assert(cpu_dout==expected)
            else $fatal(1,"CTC-driven read port=%0d got=%h expected=%h",port_number,cpu_dout,expected);
        repeat(3) begin accepted(); assert(cpu_dout==expected) else $fatal; end
        cpu_cs=0;cpu_rd_n=1;accepted();
    endtask
    task automatic serial_ticks(input integer count);
        integer target,waited;
        target=rx_events+count;
        waited=0;
        while(rx_events<target) begin
            step();waited++;
            assert(waited<20000) else $fatal(1,"CTC/SIO clock test missed RX events");
        end
    endtask
    initial begin
        void'($value$plusargs("CE_PERIOD=%d",period));
        void'($value$plusargs("PHASE=%d",phase));
        void'($value$plusargs("MASTER_HZ=%d",master_hz));
        void'($value$plusargs("DIRECT=%d",direct));
        half_period=64'd500000000000/64'(master_hz);
        repeat(8) step();reset=0;
        for(integer ch=0;ch<2;ch++) begin
            put({1'(ch),1'b1},4);put({1'(ch),1'b1},8'h44);
            put({1'(ch),1'b1},3);put({1'(ch),1'b1},8'hc1);
            put({1'(ch),1'b1},5);put({1'(ch),1'b1},8'hea);
        end
        // Timer, /16 prescaler, constant follows, software reset then start.
        wr=1;din=8'h07;step();din=1;step();wr=0;
        monitor_tx=1;put(0,8'ha5);
        rxd=0;serial_ticks(16);
        for(integer b=0;b<8;b++) begin
            rxd={1'((32'h3c>>b)&1),1'((32'h96>>b)&1)};serial_ticks(16);
        end
        rxd=3;serial_ticks(32);
        get(0,8'h96);get(2,8'h3c);
        while(!completed) step();
        put(1,1);get(1,1); // RR1 all sent, no receive errors.
        assert(!unsupported) else $fatal(1,"supported diagnostic flagged unsupported");
        // Reset both real devices and adapter while device enables are stopped.
        pause=1;reset=1;repeat(8)step();reset=0;repeat(8)step();
        assert(txd==3 && rx_tick==0 && tx_tick==0) else $fatal;
        // CTS/DCD remain asserted: RR0 contains those pin states after reset.
        monitor_tx=0;pause=0;get(1,8'h2c);get(3,8'h2c);
        $display("PASS: real CTC/SIO clock adapter CE=%0d phase=%0d master=%0d",period,phase,master_hz);
        $finish;
    end
    initial begin #20000000000; $fatal(1,"CTC/SIO clock test timeout"); end
endmodule
