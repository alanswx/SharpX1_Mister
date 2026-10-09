// SPDX-License-Identifier: GPL-2.0-or-later
// Original functional CZ-851 chain: SIO -> DMA -> CTC -> keyboard.
// Standalone integration, not a physical daisy propagation/pin-phase model.
// Upstream external-device IUS must qualify RETI before it reaches this unit.
module x1_sio_irq_bridge (
    input wire clk, reset,
    input wire m1_n, mreq_n, iorq_n, rd_n,
    input wire [7:0] data,
    input wire upstream_iei,
    input wire sio_irq, sio_ieo, sio_in_service,
    input wire [7:0] sio_vector,
    input wire dma_irq, dma_ieo, dma_in_service,
    input wire [7:0] dma_vector,
    input wire ctc_irq, ctc_ieo, keyboard_irq,
    input wire [7:0] ctc_vector, keyboard_vector,
    output wire irq, sio_ack, sio_iei, sio_reti,
    output wire dma_ack, dma_iei, dma_reti,
    output wire ctc_ack, ctc_iei, ctc_reti, keyboard_ack,
    output wire [7:0] ack_vector
);
    reg ack_quarantine;
    wire upper_ack, decoded_reti;
    wire upper_irq=sio_irq || dma_irq || ctc_irq;
    wire [7:0] upper_vector=sio_irq ? sio_vector : dma_irq ? dma_vector : ctc_vector;
    always @(posedge clk or posedge reset)
        if(reset) ack_quarantine<=1;
        else if(m1_n || iorq_n) ack_quarantine<=0;
    assign sio_iei=upstream_iei;
    assign dma_iei=sio_ieo;
    assign ctc_iei=dma_ieo;
    assign sio_ack=upper_ack && sio_irq;
    assign dma_ack=upper_ack && !sio_irq && dma_irq;
    assign ctc_ack=upper_ack && !sio_irq && !dma_irq && ctc_irq;
    assign sio_reti=decoded_reti && sio_in_service;
    assign dma_reti=decoded_reti && !sio_in_service && dma_in_service;
    assign ctc_reti=decoded_reti && !sio_in_service && !dma_in_service;
    x1_irq_bridge owner (
        .clk(clk),.reset(reset),.m1_n(m1_n || ack_quarantine),
        .mreq_n(mreq_n),.iorq_n(iorq_n),.rd_n(rd_n),.data(data),
        .ctc_irq(upper_irq),.ctc_ieo(sio_ieo && dma_ieo && ctc_ieo),
        .ctc_vector(upper_vector),.keyboard_irq(keyboard_irq),.keyboard_vector(keyboard_vector),
        .irq(irq),.ctc_ack(upper_ack),.ctc_reti(decoded_reti),
        .ctc_iei(),.ctc_selected(),.keyboard_ack(keyboard_ack),.ack_vector(ack_vector)
    );
endmodule
