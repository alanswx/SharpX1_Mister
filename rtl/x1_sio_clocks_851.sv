// SPDX-License-Identifier: GPL-2.0-or-later
// Original CZ-851/852 sheet-1 clock NET routing, not physical pulse shaping.
// IC53 ZC/TO1 pin 8 -> IC51 LS157 1B/2B; ZC/TO2 pin 9 -> IC52 RxTxCB.
// Caller supplies synchronized clock levels; current x1_ctc.zc is an event,
// not a qualified native pin waveform. Do not infer CZ-880 equivalence.
module x1_sio_clocks_851 (
    input wire dtr_b_n, external_tx_clock, external_rx_clock,
    input wire [3:0] ctc_clock,
    output wire [1:0] rx_clock, tx_clock
);
    x1_sio_clock_select_851 selector(.dtr_b_n(dtr_b_n),
        .external_tx_clock(external_tx_clock),.external_rx_clock(external_rx_clock),
        .alternate_clock(ctc_clock[1]),.rx_clock_a(rx_clock[0]),.tx_clock_a(tx_clock[0]));
    assign rx_clock[1]=ctc_clock[2];
    assign tx_clock[1]=ctc_clock[2];
endmodule
