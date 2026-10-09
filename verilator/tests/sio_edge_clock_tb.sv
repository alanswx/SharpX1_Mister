// SPDX-License-Identifier: GPL-2.0-or-later
// Independent bounded queue oracle: check before/after each accepted edge.
module sio_edge_clock_tb;
    timeunit 1ps; timeprecision 1ps;
    reg clk=0, reset=1, ce=0;
    reg [1:0] rx_clock=0, tx_clock=0, rxd=3;
    wire [1:0] rx_tick,tx_tick,sampled_rxd,rx_overflow,tx_overflow;
    x1_sio_edge_clock dut(.*);
    bit last_rx[2],last_tx[2],queued_rx[2],queued_tx[2];
    bit queued_data[2],overflow_rx[2],overflow_tx[2];
    integer checks=0, period=1, master_hz=32000000;
    time half_period;

    task automatic step(input bit rst,input bit enable,
                        input bit[1:0] rx,input bit[1:0] tx,input bit[1:0] data);
        bit re,te,deliver_rx,deliver_tx;
        clk=0; reset=rst; ce=enable; rx_clock=rx; tx_clock=tx; rxd=data;
        #(half_period);
        for(integer ch=0;ch<2;ch++) begin
            re=rx[ch] && !last_rx[ch]; te=!tx[ch] && last_tx[ch];
            deliver_rx=!rst && enable && (queued_rx[ch] || re);
            deliver_tx=!rst && enable && (queued_tx[ch] || te);
            assert(rx_tick[ch]==deliver_rx && tx_tick[ch]==deliver_tx)
                else $fatal(1,"event mismatch step=%0d channel=%0d",checks,ch);
            if(deliver_rx) assert(sampled_rxd[ch]==(queued_rx[ch]?queued_data[ch]:data[ch]))
                else $fatal(1,"RX sample changed while queued step=%0d",checks);
            if(rst) begin
                queued_rx[ch]=0; queued_tx[ch]=0;
                overflow_rx[ch]=0; overflow_tx[ch]=0;
            end else begin
                // Pop first; an edge delivered directly must not be queued.
                if(enable) begin
                    if(queued_rx[ch]) begin
                        queued_rx[ch]=re;
                        if(re) queued_data[ch]=data[ch];
                    end
                    if(queued_tx[ch]) queued_tx[ch]=te;
                end else begin
                    if(re) begin
                        if(queued_rx[ch]) overflow_rx[ch]=1;
                        else begin queued_rx[ch]=1; queued_data[ch]=data[ch]; end
                    end
                    if(te) begin
                        if(queued_tx[ch]) overflow_tx[ch]=1;
                        else queued_tx[ch]=1;
                    end
                end
            end
            last_rx[ch]=rx[ch]; last_tx[ch]=tx[ch];
        end
        clk=1; #(half_period);
        for(integer ch=0;ch<2;ch++)
            assert(rx_overflow[ch]==overflow_rx[ch] && tx_overflow[ch]==overflow_tx[ch])
                else $fatal(1,"overflow mismatch step=%0d",checks);
        checks++;
    endtask

    initial begin
        void'($value$plusargs("CE_PERIOD=%d",period));
        void'($value$plusargs("MASTER_HZ=%d",master_hz));
        half_period=64'd500000000000/64'(master_hz);
        // All clock/data/CE transitions from all previous clock levels,
        // followed by drains; no channel is allowed to affect its neighbor.
        for(integer previous=0;previous<16;previous++)
            for(integer next_levels=0;next_levels<16;next_levels++)
                for(integer data=0;data<4;data++)
                    for(integer enable=0;enable<2;enable++) begin
                        step(1,0,2'(previous),2'(previous>>2),3);
                        step(0,1,2'(previous),2'(previous>>2),0);
                        step(0,1'(enable),2'(next_levels),2'(next_levels>>2),2'(data));
                        step(0,1,2'(next_levels),2'(next_levels>>2),2'(~data));
                    end
        // Explicit consume + new RX/TX arrival, oldest-data overflow retention,
        // stopped enable reset, and reset release with clocks held high/low.
        for(integer levels=0;levels<4;levels++) begin
            step(1,0,2'(levels),2'(~levels),3);
            step(0,0,2'(~levels),2'(levels),1);
            step(0,0,2'(levels),2'(~levels),2);
            step(0,1,2'(~levels),2'(levels),2);
            step(0,1,2'(~levels),2'(levels),1);
            step(0,0,2'(levels),2'(~levels),0);
            step(0,0,2'(~levels),2'(levels),1);
            step(0,0,2'(levels),2'(~levels),2);
            step(0,0,2'(~levels),2'(levels),3);
            step(0,1,2'(~levels),2'(levels),0);
            step(0,0,2'(levels),2'(~levels),2);
            step(0,0,2'(~levels),2'(levels),1);
            step(1,0,2'(~levels),2'(levels),3);
            step(0,1,2'(~levels),2'(levels),0);
        end
        // Deterministic independent source phases and deliberately short clock
        // levels exercise gaps and diagnosed loss rather than hiding overflow.
        for(integer phase=0;phase<7;phase++) begin
            step(1,0,0,3,3);
            for(integer edge_index=0;edge_index<2048;edge_index++)
                step(0,(edge_index+phase)%period==0,
                     {1'((edge_index/5)%2),1'((edge_index/3)%2)},
                     {1'((edge_index/7)%2),1'((edge_index/2)%2)},
                     2'((edge_index*13+phase)%4));
        end
        $display("PASS: SIO edge adapter %0d checked edges CE=%0d master=%0d",checks,period,master_hz);
        $finish;
    end
endmodule
