// SPDX-License-Identifier: GPL-2.0-only
// Original continuously refreshed, coherent diagnostic snapshot transfer.
// Initial state is the power-on contract. No warm-reset input: diagnostic
// transfer must continue independently of machine reset or CPU enables.
//
// Hardware integration REQUIRES audited synchronizer treatment and a bounded
// payload path (at most two destination periods). Do not blanket-false-path
// the bus. Simulation proves the protocol, not metastability/placement safety.
`timescale 1ns/1ps
module x1_cdc_snapshot #(parameter WIDTH = 32) (
    input source_clk, destination_clk,
    input [WIDTH-1:0] source_data,
    output reg [WIDTH-1:0] destination_data = 0,
    output reg destination_valid = 0
);
    reg request = 1;
    reg acknowledgement = 0;
    reg [WIDTH-1:0] held_data = 0;
    (* async_reg = "true" *) reg request_meta = 0, request_sync = 0;
    (* async_reg = "true" *) reg acknowledgement_meta = 0, acknowledgement_sync = 0;

    always @(posedge source_clk) begin
        request_meta <= request;
        request_sync <= request_meta;
        if (request_sync != acknowledgement) begin
            held_data <= source_data;
            acknowledgement <= request_sync;
        end
    end

    always @(posedge destination_clk) begin
        acknowledgement_meta <= acknowledgement;
        acknowledgement_sync <= acknowledgement_meta;
        if (acknowledgement_sync == request) begin
            // held_data has already remained stable through acknowledgement
            // synchronization; the next request cannot overwrite it until
            // after this capture has completed in the destination domain.
            destination_data <= held_data;
            destination_valid <= 1;
            request <= !request;
        end
    end
endmodule
