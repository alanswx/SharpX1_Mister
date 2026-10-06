// SPDX-License-Identifier: GPL-2.0-or-later
// Original DMA interrupt-service engine, 2026; no emulator RTL copied.
// Zilog UM008101-0601 printed 79-88, 100-103, 108-111.
// Preparatory standalone module, NOT connected to x1_dma or the machine yet.
//
// condition is a caller-qualified, persistent interrupt condition, not an
// arbitrary raw match pulse: stop/release, auto-restart and Ready/IOR policies
// must be implemented by the DMA operation engine. Disabled conditions must
// remain stored there so enabling interrupts can subsequently expose them.
// candidate_vector is caller-formed from CURRENT status before ACK; the
// separate x1_dma_vector implements the primary-corroborated WR4 encoding.
//
// All inputs are synchronous to clk. Service/ACK/reset processing deliberately
// has no transfer CE: held ACK is consumed once even with transfer ticks off.
// bus_owned must cover both BUSRQ release and outstanding BUSACK/grant drain.
// reset_interrupts implements the IP/IUS portion of A3; the caller also
// disables interrupts and unforces Ready. irq_enabled alone (AF) clears
// neither IP nor IUS. RETI releases IUS regardless of upstream IEI.
module x1_dma_service (
    input  logic clk, reset,
    input  logic irq_enabled, condition, bus_owned,
    input  logic iei, acknowledge, reti, reset_interrupts,
    input  logic [7:0] candidate_vector,
    output logic pending, in_service,
    output logic irq, ieo, block_bus_request,
    output logic [7:0] ack_vector
);
    logic ack_seen, reti_seen;
    logic [7:0] held_vector;
    logic ack_event;

    always_comb begin
        irq = irq_enabled && pending && !in_service && !bus_owned && iei;
        ieo = iei && !pending && !in_service;
        block_bus_request = in_service;
        ack_event = acknowledge && !ack_seen;
        // Present the live candidate at ACK entry, then hold the accepted
        // value until ACK drops, even if status or programming changes.
        ack_vector = acknowledge && ack_seen ? held_vector : candidate_vector;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            pending <= 0;
            in_service <= 0;
            held_vector <= 0;
            // A cycle already high at reset is not a fresh ACK/RETI later.
            ack_seen <= acknowledge;
            reti_seen <= reti;
        end else begin
            ack_seen <= acknowledge;
            reti_seen <= reti;
            if (reset_interrupts) begin
                pending <= 0;
                in_service <= 0;
            end else if (ack_event && irq) begin
                pending <= 0;
                in_service <= 1;
                held_vector <= candidate_vector;
            end else begin
                if (reti && !reti_seen) in_service <= 0;
                // Conditions are levels. An uncleared condition can request
                // again AFTER RETI; it cannot nest within this DMA's service.
                if (irq_enabled && condition && !in_service)
                    pending <= 1;
            end
        end
    end
endmodule
