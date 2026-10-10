// SPDX-License-Identifier: GPL-2.0-only
// Original provisional read-only deck primitive, not native baud/mechanics.
// All inputs synchronous to SYS. Host holds valid/level/last until ready.
// Strict producer: prebuffer before PLAY. Missing valid on the FIRST eligible
// ready edge or any successor boundary latches underflow and stops immediately.
// No CPU CE pacing, recording, APSS, speed commands or native error response.
// Sensor bits 0/1 provisionally mean not-ended/inserted; upper mask unresolved.
`timescale 1ns/1ps
module x1_cassette_transport #(
    parameter int unsigned SYS_HZ = 32000000,
    parameter int unsigned SAMPLE_HZ = 8000
) (
    input logic clk_sys, reset,
    input logic mount, present, empty,
    input logic cmd_valid,
    input logic [7:0] cmd,
    input logic sample_valid, sample_level, sample_last,
    output logic sample_ready,
    output logic waveform,
    output logic [7:0] applied_mode,
    output logic [7:0] sensor,
    output logic underflow
);
    localparam logic [7:0] EJECT = 0, STOP = 1, PLAY = 2;
    // Keep illegal zero/one-Hz configurations elaboratable for explicit fatal.
    localparam int PHASE_W = SYS_HZ < 2 ? 1 : $clog2(SYS_HZ);
    logic mounted, ended, have_sample;
    logic held_level, held_last;
    logic [PHASE_W-1:0] phase;
    wire [PHASE_W:0] sum = {1'b0, phase} + (PHASE_W+1)'(SAMPLE_HZ);
    wire due;
    generate
        if (SYS_HZ == 0) begin : zero_rate_placeholder
            assign due = 0; // Invalid configuration: fatal below, no simulation.
        end else begin : valid_threshold
            assign due = sum >= (PHASE_W+1)'(SYS_HZ);
        end
    endgenerate
    wire supported_cmd = cmd_valid && cmd <= PLAY;
    // Eject wins mount, then mount, warm reset, supported commands, playback.
    // Unsupported commands are ignored without stalling natural playback.
    assign sample_ready = !reset && !mount && !supported_cmd &&
        mounted && !ended && applied_mode == PLAY &&
        (!have_sample || (due && !held_last));
    assign waveform = applied_mode == PLAY && have_sample ? held_level : 1'b0;
    assign sensor = !mounted ? 8'h00 : ended ? 8'h02 : 8'h03;
    initial begin
        applied_mode = EJECT; underflow = 0;
        mounted = 0; ended = 0; have_sample = 0;
        held_level = 0; held_last = 0; phase = 0;
    end
    generate
        if (SAMPLE_HZ == 0 || SYS_HZ < 2 || SAMPLE_HZ > SYS_HZ) begin : invalid_rate
            initial $fatal(1, "unsupported cassette sample/system rate");
        end
    endgenerate
    always @(posedge clk_sys) begin
        if (cmd_valid && cmd == EJECT) begin
            mounted <= 0; ended <= 0; have_sample <= 0;
            held_level <= 0; held_last <= 0; phase <= 0;
            applied_mode <= EJECT; underflow <= 0;
        end else if (mount) begin
            mounted <= present; ended <= present && empty;
            have_sample <= 0; held_level <= 0; held_last <= 0;
            phase <= 0; underflow <= 0;
            applied_mode <= present ? STOP : EJECT;
        end else if (reset) begin
            // Retain media, cursor represented by accepted stream, phase/sample.
            applied_mode <= mounted ? STOP : EJECT;
        end else if (supported_cmd) begin
            if (cmd == STOP && mounted) applied_mode <= STOP;
            if (cmd == PLAY && mounted && !ended) applied_mode <= PLAY;
        end else if (applied_mode == PLAY && mounted && !ended) begin
            if (!have_sample) begin
                if (sample_valid) begin
                    held_level <= sample_level; held_last <= sample_last;
                    have_sample <= 1;
                end else begin
                    underflow <= 1; applied_mode <= STOP;
                end
            end else if (due) begin
                phase <= PHASE_W'(sum - (PHASE_W+1)'(SYS_HZ));
                if (held_last) begin
                    ended <= 1; have_sample <= 0; applied_mode <= STOP;
                end else if (sample_valid) begin
                    held_level <= sample_level; held_last <= sample_last;
                end else begin
                    // Boundary missed: do NOT stretch current waveform or fake EOF.
                    have_sample <= 0; underflow <= 1;
                    applied_mode <= STOP; // UNDERFLOW_STOP
                end
            end else phase <= PHASE_W'(sum);
        end
    end
endmodule
