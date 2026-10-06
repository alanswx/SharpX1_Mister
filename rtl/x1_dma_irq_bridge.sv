// SPDX-License-Identifier: GPL-2.0-or-later
// Original completion-IRQ integration, 2026. CZ-851/852 model 20/30 chain:
// absent external/SIO -> DMA -> CTC -> sub-CPU. Not a Turbo Z chain audit.
// Compose the unchanged prefix-aware/held-vector CTC+keyboard bridge with
// real upstream DMA priority. No service latch is invented for the keyboard.
module x1_dma_irq_bridge (
    input wire clk, reset,
    input wire m1_n, mreq_n, iorq_n, rd_n,
    input wire [7:0] data,
    input wire upstream_iei,
    input wire dma_irq, dma_ieo, dma_in_service,
    input wire [7:0] dma_vector,
    input wire ctc_irq, ctc_ieo, keyboard_irq,
    input wire [7:0] ctc_vector, keyboard_vector,
    output wire irq, dma_ack, dma_iei, dma_reti,
    output wire ctc_ack, ctc_iei, ctc_reti, keyboard_ack,
    output wire [7:0] ack_vector
);
    wire upper_ack, decoded_reti;
    wire upper_irq=dma_irq || ctc_irq;
    wire [7:0] upper_vector=dma_irq ? dma_vector : ctc_vector;
    assign dma_iei=upstream_iei;
    assign ctc_iei=dma_ieo;
    // upper_ack is the first-clock event from the existing owner latch.
    // Select before IP drops, never reselect during the held CPU ACK cycle.
    assign dma_ack=upper_ack && dma_irq;
    assign ctc_ack=upper_ack && !dma_irq && ctc_irq;
    // A higher-priority nested DMA service returns to the still-active CTC
    // service. Do not broadcast that RETI into CTC's internal nesting stack.
    assign dma_reti=decoded_reti && dma_in_service;
    assign ctc_reti=decoded_reti && !dma_in_service;
    x1_irq_bridge owner (
        .clk(clk),.reset(reset),.m1_n(m1_n),.mreq_n(mreq_n),.iorq_n(iorq_n),
        .rd_n(rd_n),.data(data),.ctc_irq(upper_irq),.ctc_ieo(dma_ieo && ctc_ieo),
        .ctc_vector(upper_vector),.keyboard_irq(keyboard_irq),.keyboard_vector(keyboard_vector),
        .irq(irq),.ctc_ack(upper_ack),.ctc_reti(decoded_reti),
        .ctc_iei(),.ctc_selected(),.keyboard_ack(keyboard_ack),.ack_vector(ack_vector)
    );
endmodule
