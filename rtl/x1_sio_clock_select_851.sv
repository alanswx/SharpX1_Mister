// SPDX-License-Identifier: GPL-2.0-or-later
// Original CZ-851/852 IC51 LS157 channel-A clock selection only.
// Pin 1 S is the ACTIVE-LOW SIO DTRB output level, not WR5 bit 7.
// Pins 2/5 receive external ST2/RT after the RS232 receivers; pins 3/6
// share an alternate clock net whose upstream route is supplied by caller.
// TI SDLS058 function table: S=0 selects A, S=1 selects B, G=0 enabled.
// Inputs are synchronous clock levels (data); external pin CDC is separate.
// No guessed CTC assignment and no CZ-880 wiring equivalence is implied.
module x1_sio_clock_select_851 (
    input wire dtr_b_n, external_tx_clock, external_rx_clock, alternate_clock,
    output wire rx_clock_a, tx_clock_a
);
    assign rx_clock_a=dtr_b_n ? alternate_clock : external_rx_clock;
    assign tx_clock_a=dtr_b_n ? alternate_clock : external_tx_clock;
endmodule
