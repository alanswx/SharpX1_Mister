// SPDX-License-Identifier: GPL-2.0-or-later
module sio_clock_select_tb;
    timeunit 1ns; timeprecision 1ps;
    reg dtr_b_n=0,external_tx_clock=0,external_rx_clock=0,alternate_clock=0;
    wire rx_clock_a,tx_clock_a;
    reg [3:0] ctc_clock=0;
    wire [1:0] rx_clock,tx_clock;
    x1_sio_clock_select_851 dut(.*);
    x1_sio_clocks_851 routing(.dtr_b_n(dtr_b_n),.external_tx_clock(external_tx_clock),
        .external_rx_clock(external_rx_clock),.ctc_clock(ctc_clock),
        .rx_clock(rx_clock),.tx_clock(tx_clock));
    initial begin
        for(integer pattern=0;pattern<16;pattern++) begin
            {dtr_b_n,external_tx_clock,external_rx_clock,alternate_clock}=4'(pattern);
            #1;
            if(pattern>=8) begin
                assert(rx_clock_a==alternate_clock && tx_clock_a==alternate_clock)
                    else $fatal(1,"851 alternate-clock selector polarity mismatch");
            end else begin
                assert(rx_clock_a==external_rx_clock && tx_clock_a==external_tx_clock)
                    else $fatal(1,"851 external RX/TX selector mapping mismatch");
            end
        end
        for(integer pattern=0;pattern<128;pattern++) begin
            {dtr_b_n,external_tx_clock,external_rx_clock,ctc_clock}=7'(pattern);
            #1;
            assert(rx_clock[1]==ctc_clock[2] && tx_clock[1]==ctc_clock[2])
                else $fatal(1,"851 B must use CTC2, not CTC0/1/3");
            if(pattern>=64) begin
                assert(rx_clock[0]==ctc_clock[1] && tx_clock[0]==ctc_clock[1])
                    else $fatal(1,"851 alternate A must use CTC1, not CTC0/2/3");
            end else begin
                assert(rx_clock[0]==external_rx_clock && tx_clock[0]==external_tx_clock)
                    else $fatal(1,"851 external A must remain independent of CTC");
            end
        end
        $display("PASS: 16 CZ-851 selector pin-level truth cases");
        $display("PASS: 128 CZ-851 CTC/selector net-routing truth cases");
        $finish;
    end
endmodule
