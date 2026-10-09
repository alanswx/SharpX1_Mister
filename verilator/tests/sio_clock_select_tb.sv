// SPDX-License-Identifier: GPL-2.0-or-later
module sio_clock_select_tb;
    timeunit 1ns; timeprecision 1ps;
    reg dtr_b_n=0,external_tx_clock=0,external_rx_clock=0,alternate_clock=0;
    wire rx_clock_a,tx_clock_a;
    x1_sio_clock_select_851 dut(.*);
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
        $display("PASS: 16 CZ-851 selector pin-level truth cases");
        $finish;
    end
endmodule
