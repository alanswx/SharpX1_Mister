// SPDX-License-Identifier: GPL-2.0-only
// Original Sharp X1 project implementation, 2026. No inherited CTC RTL copied.
// Behavioral reference: local MAME src/devices/machine/z80ctc.cpp/.h
// (BSD-3-Clause, Wilbert Pol; original version Tatsuyuki Satoh, 1997).
// Reference semantics audited: constant-before-control/vector parsing, 0=256,
// vector mask, edge polarity, interrupt-disable clearing pending, and RETI
// preserving pending. This is an independently written CE-based RTL design.
// Primary reference: Zilog Z80 CPU Peripherals User Manual UM008101-0601,
// https://www.zilog.com/docs/z80/um0081.pdf, PDF pp. 23, 38-39 and 46:
// an operating channel finishes its current down-count before loading an
// updated time constant; software reset terminates counting/timing; RETI
// releases interrupt service. The primary reload rule takes precedence over
// MAME's immediate down-counter/time-period restart on a constant write.
// No software-reset service-clear behavior is specified there. Preserve both
// interrupt states as in MAME write(), unless bit7 disables pending requests.
//
// All inputs are synchronous to clk. ce is a 4 MHz device tick; only timer
// prescaling uses it. wr, ack and reti are one-clk events, not bus levels:
// holding any of them high represents an event on EACH clock. vector is the
// combinational eligible candidate BEFORE ACK; the bus bridge must latch it
// on ACK and hold it for the bus cycle. With no candidate it is the base.
// zc is a one-clk terminal-count event on all four channels (including ch3,
// whose event has no physical ZC pin on a standard discrete Z80 CTC).
//
// Synchronous global reset stops counting and clears pending/service. Software
// channel reset stops counting but preserves pending/service; bit7=0 still
// clears pending without releasing service. A constant write starts a stopped
// channel with a fresh divider; on a running channel it updates only the
// reload value, preserving down-count, divider phase and trigger-wait state.
// A start trigger consumes no timer tick, even if ce coincides. Bus writes
// supersede counting on their channel; interrupt-disable clears pending.
// ACK/RETI select pre-edge state. A coincident terminal count survives ACK as
// a fresh pending request. RETI releases the highest service independently of
// IEI, which can be low because an upstream device is servicing an interrupt.
`timescale 1ns/1ps
module x1_ctc (
    input  logic       clk,
    input  logic       reset,
    input  logic       ce,
    input  logic       wr,
    input  logic [1:0] channel,
    input  logic [7:0] din,
    output logic [7:0] dout,
    input  logic [3:0] trigger,
    input  logic       iei,
    output logic       irq,
    output logic       ieo,
    input  logic       ack,
    input  logic       reti,
    output logic [7:0] vector,
    output logic [3:0] zc
);
    logic [7:0] control [0:3];
    logic [8:0] constant_value [0:3];
    logic [8:0] down [0:3];
    logic [7:0] prescaler [0:3];
    logic [3:0] running, waiting_trigger, pending, in_service;
    logic [3:0] trigger_previous;
    logic [7:3] vector_base;
    logic eligible_valid, service_valid, blocked;
    logic [1:0] eligible_channel, service_channel;

    // An in-service channel blocks itself and lower priorities. Requests
    // above it remain eligible, permitting nested higher-priority service.
    always_comb begin
        eligible_valid = 1'b0;
        eligible_channel = 2'd0;
        service_valid = 1'b0;
        service_channel = 2'd0;
        blocked = 1'b0;
        for (int i = 0; i < 4; i++) begin
            if (in_service[i]) begin
                blocked = 1'b1;
                if (!service_valid) begin
                    service_valid = 1'b1;
                    service_channel = 2'(i);
                end
            end
            if (!blocked && pending[i] && !eligible_valid) begin
                eligible_valid = 1'b1;
                eligible_channel = 2'(i);
            end
        end
        irq = iei && eligible_valid;
        ieo = iei && !eligible_valid && !service_valid;
        vector = {vector_base, eligible_channel, 1'b0};
        dout = down[channel][7:0]; // 256 reads as zero.
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            running <= 4'b0;
            waiting_trigger <= 4'b0;
            pending <= 4'b0;
            in_service <= 4'b0;
            trigger_previous <= trigger;
            vector_base <= 5'b0;
            zc <= 4'b0;
            for (int i = 0; i < 4; i++) begin
                control[i] <= 8'h02;
                constant_value[i] <= 9'd256;
                down[i] <= 9'd256;
                prescaler[i] <= 8'd0;
            end
        end else begin
            trigger_previous <= trigger;
            zc <= 4'b0;
            if (reti && service_valid)
                in_service[service_channel] <= 1'b0;
            if (ack && irq) begin
                pending[eligible_channel] <= 1'b0;
                in_service[eligible_channel] <= 1'b1;
            end

            for (int i = 0; i < 4; i++) begin
                if (wr && channel == 2'(i)) begin
                    if (control[i][2]) begin
                        // This byte is ALWAYS data, regardless of bits 0/1/7.
                        constant_value[i] <= din == 0 ? 9'd256 : {1'b0, din};
                        control[i][2:1] <= 2'b00;
                        // Without software reset, complete the current count
                        // using its existing phase. New mode bits were already
                        // applied by the preceding control write.
                        if (!running[i]) begin
                            down[i] <= din == 0 ? 9'd256 : {1'b0, din};
                            prescaler[i] <= 8'd0;
                            running[i] <= 1'b1;
                            waiting_trigger[i] <= !control[i][6] && control[i][3];
                        end
                    end else if (!din[0]) begin
                        if (i == 0)
                            vector_base <= din[7:3];
                    end else begin
                        control[i] <= din;
                        // MAME write(): disabling interrupts discards pending,
                        // but must not release an already in-service channel.
                        if (!din[7])
                            pending[i] <= 1'b0;
                        if (din[1]) begin
                            running[i] <= 1'b0;
                            waiting_trigger[i] <= 1'b0;
                            prescaler[i] <= 8'd0;
                        end
                    end
                end else if (running[i]) begin
                    if (waiting_trigger[i]) begin
                        if (trigger[i] != trigger_previous[i] &&
                            trigger[i] == control[i][4])
                            waiting_trigger[i] <= 1'b0;
                    end else if (control[i][6] ?
                                 (trigger[i] != trigger_previous[i] &&
                                  trigger[i] == control[i][4]) : ce) begin
                        if (control[i][6] || prescaler[i] ==
                            (control[i][5] ? 8'd255 : 8'd15)) begin
                            prescaler[i] <= 8'd0;
                            if (down[i] == 9'd1) begin
                                down[i] <= constant_value[i];
                                zc[i] <= 1'b1;
                                if (control[i][7])
                                    pending[i] <= 1'b1;
                            end else begin
                                down[i] <= down[i] - 9'd1;
                            end
                        end else begin
                            prescaler[i] <= prescaler[i] + 8'd1;
                        end
                    end
                end
            end
        end
    end
endmodule
