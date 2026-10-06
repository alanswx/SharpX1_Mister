// SPDX-License-Identifier: GPL-2.0-or-later
// Original status-vector formation, 2026. Zilog February 1980 Product
// Specification, PDF p9 Figure 8b: vector bits 2:1 = EOB:match, with 00
// for Ready, 01 match, 10 EOB, 11 both. UM008101's printed Figure 44 has
// damaged/repeated-zero rows; its prose identifies the same two bit positions.
// Use CURRENT status, not interrupt-mask bits or a fabricated last-event tag.
// Auto Restart + EOB IRQ + status modification is prohibited by the manual;
// the caller must reject that combination, not synthesize an EOB cause here.
module x1_dma_vector (
    input logic [7:0] base_vector,
    input logic status_affects_vector, match_found, end_of_block,
    output logic [7:0] vector
);
    assign vector = status_affects_vector ?
        {base_vector[7:3], end_of_block, match_found, base_vector[0]} : base_vector;
endmodule
