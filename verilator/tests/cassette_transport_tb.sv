// SPDX-License-Identifier: GPL-2.0-only
// Synthetic held-sample producer; independent integer interval oracle.
`timescale 1ns/1ps
module cassette_transport_tb;
    parameter int unsigned SYS_HZ = 32000000;
    parameter int unsigned SAMPLE_HZ = 8000;
    parameter bit PARAMETER_ONLY = 0;
    logic clk;
    initial begin clk = 0; forever #5 clk = !clk; end
    logic reset, mount, present, empty;
    logic cmd_valid;
    logic [7:0] cmd;
    logic valid, level, last;
    wire ready, wave, underflow;
    wire [7:0] mode, sensor;
    // External CPU enables deliberately stopped/irregular; not a DUT input.
    logic external_ce;
    x1_cassette_transport #(.SYS_HZ(SYS_HZ), .SAMPLE_HZ(SAMPLE_HZ)) dut(
        .clk_sys(clk), .reset(reset), .mount(mount), .present(present), .empty(empty),
        .cmd_valid(cmd_valid), .cmd(cmd), .sample_valid(valid),
        .sample_level(level), .sample_last(last), .sample_ready(ready),
        .waveform(wave), .applied_mode(mode), .sensor(sensor), .underflow(underflow));
    task automatic tick;
        @(posedge clk); #1; @(negedge clk);
    endtask
    task automatic command(input logic [7:0] value);
        cmd_valid = 1; cmd = value; #1;
        if (value <= 2 && ready) $fatal(1, "command must block stream handshake");
        tick(); cmd_valid = 0;
    endtask
    task automatic load(input logic is_empty = 0);
        mount = 1; present = 1; empty = is_empty; #1;
        if (ready) $fatal(1, "mount must block stream handshake");
        tick(); mount = 0;
        if (mode != 1 || sensor != (is_empty ? 2 : 3)) $fatal(1, "mount sensor/mode");
    endtask
    function automatic logic value(input int index);
        return ((index * 37 + index / 3) % 11) < 5;
    endfunction
    integer accepted;
    logic boundary;
    longint unsigned elapsed;
    longint unsigned expected;
    initial begin
        reset = 0; mount = 0; present = 0; empty = 0;
        cmd_valid = 0; cmd = 0; valid = 0; level = 0; last = 0;
        external_ce = 0;
        if (PARAMETER_ONLY) begin
            // Large unsigned clock/rate: exercise the sum's extra carry bit.
            load(); valid = 1; level = 1; last = 0; command(2); tick();
            accepted = 1; elapsed = 0;
            while (accepted < 9) begin
                #1; boundary = ready;
                tick(); elapsed++;
                if (boundary) begin
                    expected = (64'(accepted) * SYS_HZ + 64'(SAMPLE_HZ) - 1) / 64'(SAMPLE_HZ);
                    if (elapsed != expected) $fatal(1, "cassette widened sum lost carry");
                    accepted++;
                end
                if (mode != 2 || !wave || underflow) $fatal(1, "cassette widened sum interval");
                if (elapsed > 32) $fatal(1, "cassette widened sum lost carry");
            end
            $display("PASS cassette widened sum SYS_HZ=%0d SAMPLE_HZ=%0d", SYS_HZ, SAMPLE_HZ);
            $finish;
        end
        tick();
        if (mode != 0 || sensor != 0 || wave || ready) $fatal(1, "initial eject");
        command(2); if (mode != 0) $fatal(1, "play absent");
        load(); command(2);
        // No unbounded startup stretch: FIRST ready edge must be prebuffered.
        #1; if (!ready || wave || underflow) $fatal(1, "first-load ready");
        tick();
        if (mode != 1 || !underflow || sensor != 3 || wave || ready)
            $fatal(1, "cassette first-load underflow must stop");
        repeat (13) tick();
        if (mode != 1 || !underflow) $fatal(1, "initial miss remains stopped");
        load(); valid = 1; level = value(0); last = 0; command(2);
        #1; if (!ready) $fatal(1, "prebuffered first-load ready");
        tick();
        accepted = 1; elapsed = 0;
        level = value(1);
        while (mode == 2) begin
            #1;
            boundary = ready;
            tick(); elapsed++;
            expected = (64'(accepted) * SYS_HZ + 7999) / 8000;
            if (boundary) begin
                if (elapsed != expected) $fatal(1, "fractional exact cumulative interval");
                accepted++;
                if (wave != value(accepted - 1)) $fatal(1, "held waveform sample");
                level = value(accepted); last = accepted == 999;
            end else if (mode == 2 && wave != value(accepted - 1))
                $fatal(1, "held valid changed waveform before acceptance");
            if (elapsed % 17 == 0) external_ce = 0;
            if (elapsed % 113 == 0) external_ce = !external_ce;
            if (elapsed > 64'(SYS_HZ) / 7) $fatal(1, "bounded playback timeout");
        end
        expected = (64'd1000 * SYS_HZ + 7999) / 8000;
        if (accepted != 1000 || elapsed != expected || sensor != 2 || wave || ready || underflow)
            $fatal(1, "complete final sample interval before EOF");
        command(2); if (mode != 1) $fatal(1, "EOF must not replay");
        // Pause and warm reset retain a partially spent sample/fraction.
        load(); command(2); valid = 1; level = 1; last = 0; tick();
        level = 0; elapsed = 0;
        repeat (123) begin tick(); elapsed++; end
        command(1); if (wave || ready) $fatal(1, "stop idle");
        repeat (71) tick(); command(8'hff);
        if (mode != 1 || sensor != 3 || underflow) $fatal(1, "unsupported stop command");
        command(2);
        repeat (99) begin tick(); elapsed++; end
        reset = 1; #1; if (ready) $fatal(1, "reset blocks handshake");
        tick(); reset = 0;
        if (mode != 1 || sensor != 3 || wave) $fatal(1, "warm reset retained media");
        repeat (43) tick(); command(2);
        // Unsupported command must not steal a sample tick or pause phase.
        cmd_valid = 1; cmd = 8'h07;
        while (!ready) begin tick(); elapsed++; end
        tick(); elapsed++; cmd_valid = 0;
        if (elapsed != (64'(SYS_HZ) + 7999) / 8000 || wave) $fatal(1, "pause/resume exact phase");
        // Starve the NEXT boundary: sticky diagnostic, not invented EOF.
        valid = 0; elapsed = 0;
        expected = (64'd2 * SYS_HZ + 7999) / 8000 - (64'(SYS_HZ) + 7999) / 8000;
        while (elapsed < expected) begin tick(); elapsed++; end
        if (!underflow || mode != 1 || wave || sensor != 3)
            $fatal(1, "cassette underflow must stop");
        reset = 1; tick(); reset = 0;
        if (!underflow || sensor != 3) $fatal(1, "warm reset retains diagnostic");
        command(2); valid = 1; level = 1; last = 1; #1;
        if (!ready) $fatal(1, "underflow restart awaits new sample");
        // Eject wins mount/ready, with no dropped accepted host transaction.
        mount = 1; present = 1; cmd_valid = 1; cmd = 0; #1;
        if (ready) $fatal(1, "eject blocks ready");
        tick(); mount = 0; cmd_valid = 0;
        if (mode != 0 || sensor != 0 || wave || underflow) $fatal(1, "eject priority");
        load(1); command(2); if (mode != 1 || ready || sensor != 2) $fatal(1, "empty mount EOF");
        // Mount wins reset/PLAY and discards old stream state intentionally.
        mount = 1; present = 1; empty = 0; reset = 1; cmd_valid = 1; cmd = 2;
        tick(); mount = 0; reset = 0; cmd_valid = 0;
        if (mode != 1 || sensor != 3 || ready) $fatal(1, "mount priority");
        mount = 1; present = 0; tick(); mount = 0;
        if (mode != 0 || sensor != 0 || ready) $fatal(1, "absent mount");
        $display("PASS cassette transport SYS_HZ=%0d: 1000 exact fractional waveform intervals, pause/reset/EOF/priorities/unsupported/underflow; no native baud/loading claim", SYS_HZ);
        $finish;
    end
endmodule
