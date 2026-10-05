// SPDX-License-Identifier: GPL-2.0-or-later
// Original reset-request retention for the shared CPU/DMA ownership seam.
// Integration must keep DMA and its target progressing while draining. CPU
// execution stops immediately, but its real ACK must survive until BUSRQ is
// released. Already-started writes may commit; this is not rollback.
module x1_dma_reset (
    input wire clk, reset_request,
    input wire dma_busak_n, dma_busrq_n,
    output wire machine_reset, cpu_run, dma_reset, draining
);
    reg pending = 0;
    reg [2:0] hold_count = 0;
    wire owned = !dma_busak_n && !dma_busrq_n;
    wire requested = pending || reset_request;
    assign machine_reset = requested && !owned;
    assign cpu_run = !requested;
    assign dma_reset = requested;
    assign draining = requested && owned;
    // Catch a pulse ending before the next SYS edge, including with CE stopped.
    always @(posedge clk or posedge reset_request)
        if (reset_request) pending <= 1;
        else if (!owned && hold_count == 3) pending <= 0;
    always @(posedge clk or posedge reset_request)
        if (reset_request) hold_count <= 0;
        else if (pending && !owned) hold_count <= hold_count + 1'b1;
        else hold_count <= 0;
endmodule
