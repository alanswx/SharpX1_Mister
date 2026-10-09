// SPDX-License-Identifier: GPL-2.0-or-later
// Original diagnostic coupling using traced CZ-851 CTC1/2 net routing.
// CTC0 supplies explicit external diagnostic pulses, not native default wiring.
// x1_ctc's one-master-edge ZC events are NOT qualified physical pin widths.
module sio_ctc_clock_tb;
    timeunit 1ps; timeprecision 1ps;
    reg clk=0,reset=1,ce=0,pause=0;
    integer period=4,phase=0,edges=0,master_hz=32000000;
    time half_period;
    reg wr=0;
    reg [7:0] din=0;
    reg [1:0] ctc_channel=0;
    wire [7:0] dout,vector;
    wire irq,ieo;
    wire [3:0] zc;
    x1_ctc ctc(.clk(clk),.reset(reset),.ce(ce),.wr(wr),.channel(ctc_channel),
        .din(din),.dout(dout),.trigger(4'b0000),.iei(1'b1),.irq(irq),
        .ieo(ieo),.ack(1'b0),.reti(1'b0),.vector(vector),.zc(zc));
    reg [1:0] rxd=3;
    wire [1:0] selected_rx,selected_tx;
    x1_sio_clocks_851 routing(.dtr_b_n(dtr_n[1]),
        .external_rx_clock(zc[0]),.external_tx_clock(zc[0]),.ctc_clock(zc),
        .rx_clock(selected_rx),.tx_clock(selected_tx));
    wire [1:0] rx_tick,tx_tick,sampled_rxd,rx_overflow,tx_overflow;
    bit direct=0;
    reg [1:0] last_rx_clock=0,last_tx_clock=0;
    always @(posedge clk) begin last_rx_clock<=selected_rx;last_tx_clock<=selected_tx;end
    wire [1:0] used_rx_tick=direct ? ({2{ce}} & selected_rx & ~last_rx_clock) : rx_tick;
    wire [1:0] used_tx_tick=direct ? ({2{ce}} & ~selected_tx & last_tx_clock) : tx_tick;
    x1_sio_edge_clock adapter(.clk(clk),.reset(reset),.ce(ce),
        .rx_clock(selected_rx),.tx_clock(selected_tx),.rxd(rxd),
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
    integer tx_events=0,rx_events=0,rx_events_b=0;
    reg [9:0] expected_tx={1'b1,8'ha5,1'b0};
    bit saw_rx,saw_tx;
    integer before_events,before_events_b;

    task automatic step;
        clk=0; ce=!pause && ((edges+phase)%period==0);
        #(half_period);
        saw_rx=used_rx_tick[0]; saw_tx=used_tx_tick[0];
        if(used_rx_tick[1]) rx_events_b++;
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
    task automatic serial_ticks(input integer count,input bit channel=0);
        integer target,waited;
        target=(channel ? rx_events_b : rx_events)+count;
        waited=0;
        while((channel ? rx_events_b : rx_events)<target) begin
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
        // Deliberately different rates expose swapped CTC1/2 or shared clocks.
        for(integer ch=0;ch<3;ch++) begin
            ctc_channel=2'(ch);wr=1;din=8'h07;step();din=8'(ch+1);step();wr=0;
        end
        monitor_tx=1;put(0,8'ha5);
        rxd=2;serial_ticks(16);
        for(integer b=0;b<8;b++) begin
            rxd[0]=1'((32'h96>>b)&1);serial_ticks(16);
        end
        rxd=3;serial_ticks(32);
        rxd[1]=0;serial_ticks(16,1);
        for(integer b=0;b<8;b++) begin
            rxd[1]=1'((32'h3c>>b)&1);serial_ticks(16,1);
        end
        rxd=3;serial_ticks(32,1);
        get(0,8'h96);get(2,8'h3c);
        while(!completed) step();
        put(1,1);get(1,1); // RR1 all sent, no receive errors.
        // Real B WR5 writes drive DTRB's output level into the board selector.
        // Select the traced internal CTC1 source while CTC0/2 keep running.
        put(3,5);put(3,8'h6a);
        repeat(period*2)step();before_events=rx_events;
        repeat(period*128) begin
            step();
            assert(selected_rx[0]==zc[1] && selected_tx[0]==zc[1] &&
                   selected_rx[1]==zc[2] && selected_tx[1]==zc[2]) else $fatal;
        end
        assert(rx_events>before_events && dtr_n[1]) else $fatal;
        // Qualify a complete transmit frame at the traced internal rate too,
        // not just the presence of selected clock levels or idle RX events.
        started=0;completed=0;tx_events=0;put(0,8'ha5);
        while(!completed)step();
        put(1,1);get(1,1);
        // Stop only the actual CTC1 timer: A must stop, B must continue.
        ctc_channel=1;wr=1;din=8'h03;step();wr=0;
        repeat(period*2)step();before_events=rx_events;before_events_b=rx_events_b;
        repeat(period*64) begin
            step();
            assert(!rx_tick[0] && !tx_tick[0] && !selected_rx[0] && !selected_tx[0])
                else $fatal(1,"DTRB deassertion did not select stopped alternate clock");
        end
        assert(rx_events==before_events && rx_events_b>before_events_b && dtr_n[1])
            else $fatal(1,"A clock selection disturbed independent B events");
        put(3,5);put(3,8'hea);serial_ticks(16);
        assert(!dtr_n[1] && !unsupported) else $fatal;
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
