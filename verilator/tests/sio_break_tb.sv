// SPDX-License-Identifier: GPL-2.0-or-later
// Original idle Send Break pin/register tests. No receive-break claim.
`timescale 1ns/1ps
module sio_break_tb;
    reg clk=0, ce=0, reset=1, pause_ce=0;
    always #5 clk=~clk;
    integer period=1, edges=0;
    always @(negedge clk) begin edges++; ce=!pause_ce && (edges%period)==0; end
    reg cpu_cs=0, cpu_rd_n=1, cpu_wr_n=1;
    reg [1:0] address=0;
    reg [7:0] cpu_din=0;
    wire [7:0] cpu_dout;
    reg [1:0] rx_tick=0, tx_tick=0, rxd=3, cts_n=3, dcd_n=3;
    wire [1:0] txd, rts_n, dtr_n;
    wire unsupported;
    x1_sio_async dut(.*);
    task automatic step;
        do begin @(posedge clk); #1; end while(!ce);
    endtask
    task automatic put(input reg [1:0] port, input reg [7:0] value);
        @(negedge clk); #1;
        address=port; cpu_din=value; cpu_cs=1; cpu_wr_n=0;
        repeat(8) step(); // Only one parser/data side effect per held strobe.
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
    endtask
    task automatic wr5(input bit channel, input reg [7:0] value);
        put({channel,1'b1},5); put({channel,1'b1},value);
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        assert(period>0) else $fatal(1,"invalid CE period");
        repeat(8) step(); reset=0;
        for(integer c=0;c<2;c++) begin
            put({1'(c),1'b1},4); put({1'(c),1'b1},8'h44);
            wr5(1'(c),8'hea);
        end
        assert(txd==3 && !unsupported && rts_n==0 && dtr_n==0);
        for(integer c=0;c<2;c++) begin
            wr5(1'(c),8'hfa);
            assert(txd==(c==0 ? 2'b10 : 2'b01) && !unsupported)
                else $fatal(1,"idle break pin/isolation");
            @(negedge clk); #1; pause_ce=1; ce=0;
            repeat(80) begin
                @(posedge clk); #1;
                assert(txd==(c==0 ? 2'b10 : 2'b01) && !ce && !unsupported)
                    else $fatal(1,"break required advancement/serial ticks");
            end
            @(negedge clk); #1; pause_ce=0;
            wr5(1'(c),8'hea);
            assert(txd==3 && !unsupported) else $fatal(1,"break release not marking");
            wr5(1'(c),8'hf2); // Break must work even with TX enable clear.
            assert(!txd[c] && !unsupported) else $fatal(1,"break required TX enable");
            put({1'(c),1'b1},8'h18);
            assert(txd==3 && !unsupported) else $fatal(1,"channel reset left break");
            wr5(1'(c),8'hea);
        end
        wr5(0,8'hfa); wr5(1,8'hfa);
        assert(txd==0 && !unsupported);
        put(1,8'h18);
        assert(txd==1 && !unsupported) else $fatal(1,"A reset disturbed B break");
        // Queuing data while breaking is deliberately outside this slice.
        put(2,8'h69);
        assert(unsupported) else $fatal(1,"break queue silently advertised support");
        put(3,8'h18); wr5(0,8'hea);
        put(0,8'ha6); tx_tick=1; step(); tx_tick=0;
        wr5(0,8'hfa);
        assert(unsupported && !txd[0]) else $fatal(1,"busy break falsely advertised support");
        @(negedge clk); #1; pause_ce=1; ce=0; reset=1;
        repeat(4) begin @(posedge clk); #1; end
        assert(txd==3 && !unsupported && !ce && rts_n==3 && dtr_n==3)
            else $fatal(1,"chip reset required serial/CPU advancement");
        $display("PASS: A/B idle Send Break, held WR5, stopped CE/ticks, TX-disable, independent/channel/chip reset and unsupported busy/queue CE=%0d",period);
        $finish;
    end
    initial begin #10000000; $fatal(1,"break fixture watchdog"); end
endmodule
