// SPDX-License-Identifier: GPL-2.0-or-later
// Original SIO clock-level adapter; no native X1 wiring is implied.
// All inputs must already be synchronous to clk. External pin CDC belongs
// to the caller. RX samples on a rising level edge, TX on a falling edge.
// Each channel/direction has one pending event. Stopped CE is not unlimited
// buffering: a second unconsumed event sets sticky overflow and is dropped,
// preserving the oldest RX sample. Consume + arrival retains the new event.
// Reset works with CE stopped and tracks clock levels without inventing an
// edge on release. Outputs are meaningful only at the accepting clk edge.
module x1_sio_edge_clock (
    input wire clk, reset, ce,
    input wire [1:0] rx_clock, tx_clock, rxd,
    output wire [1:0] rx_tick, tx_tick, sampled_rxd,
    output reg [1:0] rx_overflow, tx_overflow
);
    reg [1:0] rx_previous, tx_previous;
    reg [1:0] rx_pending, tx_pending, rx_sample;
    wire [1:0] rising = rx_clock & ~rx_previous;
    wire [1:0] falling = ~tx_clock & tx_previous;
    assign rx_tick = {2{ce && !reset}} & (rx_pending | rising);
    assign tx_tick = {2{ce && !reset}} & (tx_pending | falling);
    assign sampled_rxd = (rx_sample & rx_pending) | (rxd & ~rx_pending);

    always @(posedge clk) begin
        rx_previous <= rx_clock;
        tx_previous <= tx_clock;
        if (reset) begin
            rx_pending <= 0;
            tx_pending <= 0;
            rx_sample <= 2'b11;
            rx_overflow <= 0;
            tx_overflow <= 0;
        end else begin
            for (integer ch=0; ch<2; ch=ch+1) begin
                if (ce) begin
                    // An old event consumes the slot; simultaneous arrival
                    // uses the newly available slot rather than overflowing.
                    rx_pending[ch] <= rx_pending[ch] && rising[ch];
                    tx_pending[ch] <= tx_pending[ch] && falling[ch];
                    if (rising[ch]) rx_sample[ch] <= rxd[ch];
                end else begin
                    if (rising[ch]) begin
                        if (rx_pending[ch]) rx_overflow[ch] <= 1;
                        else begin
                            rx_pending[ch] <= 1;
                            rx_sample[ch] <= rxd[ch];
                        end
                    end
                    if (falling[ch]) begin
                        if (tx_pending[ch]) tx_overflow[ch] <= 1;
                        else tx_pending[ch] <= 1;
                    end
                end
            end
        end
    end
endmodule
