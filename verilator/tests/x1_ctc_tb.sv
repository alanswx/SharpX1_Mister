// SPDX-License-Identifier: GPL-2.0-only
// Original synthetic unit fixture; no firmware or inherited CTC code.
// Standalone invocation (build outside the source tree):
// Run: verilator --binary --timing --assert --timescale 1ns/1ps --top-module x1_ctc_tb \
//   --Mdir /tmp/x1-ctc-build rtl/x1_ctc.sv verilator/tests/x1_ctc_tb.sv
`timescale 1ns/1ps
module x1_ctc_tb;
    logic clk = 0, reset = 1, ce = 0, wr = 0;
    logic [1:0] channel = 0;
    logic [7:0] din = 0, dout, vector;
    logic [3:0] trigger = 0, zc;
    logic iei = 1, irq, ieo, ack = 0, reti = 0;
    int cycles = 0;
    int pulses [0:3];
    x1_ctc dut (.*);
    // 32 MHz system clock. device_tick supplies one CE every eight edges.
    always #15.625 clk = !clk;

    task automatic check(input bit condition, input string message);
        if (!condition)
            $fatal(1, "cycle %0d: %s (dout=%02x irq=%b ieo=%b vector=%02x zc=%b)",
                   cycles, message, dout, irq, ieo, vector, zc);
    endtask

    task automatic step(input bit enable_tick = 0);
        @(negedge clk);
        ce = enable_tick;
        @(posedge clk);
        #1;
        cycles++;
        for (int i = 0; i < 4; i++)
            if (zc[i]) pulses[i]++;
    endtask

    task automatic device_tick;
        repeat (7) begin
            step();
            check(zc == 0, "timer emitted ZC without CE");
        end
        step(1);
    endtask

    task automatic reset_unit;
        reset = 1;
        wr = 0; ack = 0; reti = 0; trigger = 0; iei = 1;
        step();
        check(!irq && ieo && zc == 0 && vector == 0, "reset outputs");
        reset = 0;
        for (int i = 0; i < 4; i++) pulses[i] = 0;
    endtask

    task automatic write_byte(input int ch, input logic [7:0] value);
        channel = 2'(ch); din = value; wr = 1;
        step(); // Bus writes deliberately occur with CE low.
        wr = 0;
    endtask

    task automatic read_count(input int ch, input int expected);
        channel = 2'(ch);
        #1;
        check(dout == 8'(expected), $sformatf("channel %0d count expected %0d", ch, expected));
    endtask

    task automatic program_channel(input int ch, input logic [7:0] ctrl,
                                   input logic [7:0] tc);
        write_byte(ch, ctrl);
        write_byte(ch, tc);
        read_count(ch, int'(tc));
    endtask

    task automatic edge_on(input int ch, input bit level);
        trigger[ch] = level;
        step();
    endtask

    task automatic rising(input int ch);
        edge_on(ch, 0);
        edge_on(ch, 1);
    endtask

    task automatic accept_irq(input logic [7:0] expected);
        check(irq, "ACK requires eligible request");
        check(vector == expected, "pre-ACK candidate vector");
        ack = 1; step(); ack = 0;
    endtask

    task automatic return_irq;
        reti = 1; step(); reti = 0;
    endtask

    task automatic timer_case(input bit divide256, input int tc);
        int divisor, period, expected;
        reset_unit();
        divisor = divide256 ? 256 : 16;
        period = divisor * tc;
        program_channel(0, divide256 ? 8'h27 : 8'h07, 8'(tc));
        // Idle sys clocks cannot advance the prescaler or down counter.
        repeat (37) step();
        read_count(0, tc);
        for (int n = 1; n <= period * 2; n++) begin
            device_tick();
            check(zc == ((n % period == 0) ? 4'b0001 : 4'b0000),
                  $sformatf("/%0d TC=%0d tick=%0d terminal phase", divisor, tc, n));
            expected = tc - ((n % period) / divisor);
            read_count(0, expected);
            if (n == divisor - 1) begin
                repeat (19) step();
                read_count(0, tc);
            end
        end
        check(pulses[0] == 2 && !irq, "periodic timer reload and masked IRQ");
        step();
        check(zc == 0, "ZC lasts one sys clock");
    endtask

    initial begin
        for (int i = 0; i < 4; i++) pulses[i] = 0;
        reset_unit();
        for (int i = 0; i < 4; i++) read_count(i, 0);
        repeat (40) device_tick();
        check(zc == 0 && !irq, "unprogrammed channels stay stopped");

        timer_case(0, 1);
        timer_case(0, 3);
        timer_case(0, 256);
        timer_case(1, 1);
        timer_case(1, 3);
        timer_case(1, 256);
        $display("PASS: /16, /256, zero=256, periodic reload, readback and CE stalls");

        // UM0081: writing a new constant without reset defers its use until
        // the current terminal count, retaining the partial prescaler phase.
        // TC4 begins at tick zero; at tick 10 it still has down=4 and phase=10.
        reset_unit();
        program_channel(0, 8'h07, 8'h04);
        repeat (10) device_tick();
        read_count(0, 4);
        write_byte(0, 8'h05); // time constant follows, no software reset
        read_count(0, 4);
        write_byte(0, 8'h02); // new reload is 2, not an immediate down-count
        read_count(0, 4);
        repeat (23) step(); // stopped CE also preserves the partial phase
        read_count(0, 4);
        for (int n = 11; n <= 128; n++) begin
            device_tick();
            check(zc == ((n == 64 || n == 96 || n == 128) ? 4'b0001 : 4'b0000),
                  $sformatf("deferred timer reload phase at CE tick %0d", n));
            read_count(0, n < 64 ? 4 - (n / 16) : 2 - ((n % 32) / 16));
        end
        check(pulses[0] == 3 && !irq, "TC4 first terminal at 64, then TC2 every 32 ticks");

        // Updating the reload while awaiting an external start must not
        // accidentally start the timer or replace its initial down-count.
        reset_unit();
        program_channel(0, 8'h1f, 8'h04);
        repeat (10) device_tick();
        write_byte(0, 8'h1d);
        write_byte(0, 8'h02);
        repeat (50) device_tick();
        read_count(0, 4);
        check(pulses[0] == 0, "TC update preserves external-trigger wait");
        rising(0);
        for (int n = 1; n <= 64; n++) begin
            device_tick();
            check(zc == (n == 64 ? 4'b0001 : 4'b0000), "trigger-wait update retains initial TC4 period");
        end
        read_count(0, 2);

        // Counter TC4 has three edges remaining when updated to TC2. The
        // current count must finish before the new two-edge period begins.
        reset_unit();
        program_channel(2, 8'h57, 8'h04);
        rising(2); read_count(2, 3);
        write_byte(2, 8'h55); // constant follows, rising counter, no reset
        write_byte(2, 8'h02);
        read_count(2, 3);
        repeat (23) step(); read_count(2, 3);
        rising(2); read_count(2, 2);
        check(zc == 0, "counter first remaining edge is not terminal");
        rising(2); read_count(2, 1);
        check(zc == 0, "counter second remaining edge is not terminal");
        rising(2); read_count(2, 2);
        check(zc == 4'b0100 && pulses[2] == 1, "third remaining edge reloads new TC2");
        rising(2); read_count(2, 1);
        check(zc == 0, "new counter period first edge");
        rising(2); read_count(2, 2);
        check(zc == 4'b0100 && pulses[2] == 2 && !irq, "new counter two-edge period");
        $display("PASS: running TC updates preserve /16 divider phase and counter remaining count until terminal reload");

        // Constant parsing takes precedence over vector/control, for either
        // bit0 value. Nonzero-channel vector writes leave the base alone.
        reset_unit();
        write_byte(0, 8'hde); // masked vector base D8
        program_channel(0, 8'hd7, 8'h03); // odd constant, not a control
        read_count(0, 3);
        rising(0); read_count(0, 2);
        rising(0); read_count(0, 1);
        rising(0); read_count(0, 3);
        write_byte(1, 8'h20);
        accept_irq(8'hd8);
        return_irq();
        program_channel(0, 8'hd7, 8'h02); // even constant, not vector
        rising(0); read_count(0, 1);
        rising(0);
        accept_irq(8'hd8);
        return_irq();

        // Falling counter edges are sampled on every sys clock, independent
        // of CE, prescale selection and the timer-only wait-trigger bit.
        reset_unit();
        program_channel(1, 8'h6f, 8'h02);
        edge_on(1, 1); read_count(1, 2);
        repeat (9) step(); read_count(1, 2);
        edge_on(1, 0); read_count(1, 1);
        repeat (9) step(); read_count(1, 1);
        edge_on(1, 1); read_count(1, 1);
        edge_on(1, 0); read_count(1, 2);
        check(zc == 4'b0010 && pulses[1] == 1, "falling counter terminal");
        reset_unit();
        program_channel(3, 8'h57, 8'h00);
        for (int n = 1; n <= 512; n++) begin
            rising(3);
            read_count(3, 256 - (n % 256));
            check(zc == ((n % 256 == 0) ? 4'b1000 : 4'b0000), "zero counter period");
        end
        check(pulses[3] == 2, "channel 3 terminal events");

        // Both timer trigger polarities, and a trigger coincident with CE.
        for (int polarity = 0; polarity < 2; polarity++) begin
            reset_unit();
            program_channel(2, polarity == 1 ? 8'h1f : 8'h0f, 8'h02);
            repeat (40) device_tick();
            read_count(2, 2);
            check(pulses[2] == 0, "wait-trigger timer stays stopped");
            trigger[2] = polarity == 0;
            step(); // inactive edge
            repeat (20) device_tick();
            read_count(2, 2);
            trigger[2] = polarity == 1;
            step(1); // start edge does not consume a timer tick
            for (int n = 1; n <= 64; n++) begin
                if (n == 7) trigger[2] = polarity == 0;
                if (n == 8) trigger[2] = polarity == 1; // no retrigger
                device_tick();
                check(zc == ((n % 32 == 0) ? 4'b0100 : 4'b0000), "triggered timer phase");
                read_count(2, 2 - ((n % 32) / 16));
            end
        end
        $display("PASS: constant priority, vectors, both edge polarities, counter CE independence, trigger gating");

        // Simultaneous requests in all channels, keyboard-style IEI blocking,
        // in-service blocking and pre-ACK candidate vectors with CE stopped.
        reset_unit();
        write_byte(0, 8'hee);
        for (int i = 0; i < 4; i++) program_channel(i, 8'hd7, 8'h01);
        trigger = 4'hf; step();
        check(zc == 4'hf && irq && !ieo, "four simultaneous requests");
        iei = 0; #1;
        check(!irq && !ieo, "upstream keyboard request blocks effective IRQ");
        ack = 1; step(); ack = 0;
        check(vector == 8'he8, "candidate remains available while IEI blocks ACK");
        iei = 1; #1;
        for (int i = 0; i < 4; i++) begin
            accept_irq(8'he8 + 8'(2*i));
            check(!irq && !ieo, "service blocks itself and lower channels");
            ack = 1; step(); ack = 0; // no eligible request
            check(vector == 8'he8, "no eligible request presents base vector");
            iei = 0;
            return_irq(); // RETI must work under upstream service.
            check(!irq && !ieo, "IEI still blocks after RETI");
            iei = 1; #1;
            check(irq == (i != 3), "RETI exposes next pending priority");
        end
        check(ieo, "chain released after final RETI");
        return_irq();
        check(!irq && ieo && vector == 8'he8, "spurious RETI harmless");

        // Nested priorities: 3 -> 2 -> 0, then pending in-service requests
        // must survive RETI. Channel 1 remains pending behind service 0.
        reset_unit();
        write_byte(0, 8'hb6);
        for (int i = 0; i < 4; i++) program_channel(i, 8'hd7, 8'h01);
        rising(3); accept_irq(8'hb6);
        rising(2); accept_irq(8'hb4);
        rising(0); accept_irq(8'hb0);
        rising(0); rising(1); rising(2); rising(3);
        check(!irq && !ieo, "own pending blocked while in service");
        return_irq();
        check(irq, "RETI preserves channel 0 pending");
        accept_irq(8'hb0); return_irq();
        accept_irq(8'hb2); return_irq();
        check(!irq && !ieo, "nested channel 2 service still blocks lower");
        return_irq();
        accept_irq(8'hb4); return_irq();
        check(!irq && !ieo, "channel 3 service still blocks its pending");
        return_irq();
        accept_irq(8'hb6); return_irq();
        check(!irq && ieo, "nested stack fully drained");

        // MAME-supported mask clearing pending, retaining service, and no
        // new requests while masked. Re-enabling cannot revive old pending.
        rising(1);
        write_byte(1, 8'h51);
        check(!irq && ieo, "mask clears pending");
        rising(1);
        write_byte(1, 8'hd1);
        check(!irq && ieo, "unmask does not resurrect request");
        rising(1); accept_irq(8'hb2);
        rising(1); write_byte(1, 8'h51);
        check(!irq && !ieo, "mask does not clear service");
        return_irq();
        check(!irq && ieo, "masked pending discarded across RETI");

        // A terminal event coincident with ACK is a fresh pending event.
        rising(0);
        edge_on(0, 0);
        trigger[0] = 1; ack = 1; step(); ack = 0;
        check(vector == 8'hb0 && zc[0] && !irq, "ACK/terminal coincidence");
        return_irq(); check(irq, "coincident request survives ACK");
        accept_irq(8'hb0);

        // Held ACK is repeated events, not an extra edge detector. Arrange
        // two pending channels and RETI in between the two sampled ACKs.
        return_irq();
        write_byte(1, 8'hd1);
        rising(0); rising(1);
        ack = 1; step();
        check(vector == 8'hb0, "first held ACK event");
        reti = 1; step(); reti = 0;
        check(irq, "blocked held ACK and RETI use pre-edge state");
        check(vector == 8'hb2, "held ACK next eligible candidate");
        step(); ack = 0;
        check(vector == 8'hb0 && !irq, "next held ACK event accepts next channel");
        return_irq();
        $display("PASS: IEI, simultaneous priority, nesting, mask audit, ACK/RETI and held event semantics");

        // Software reset stops counting but preserves pending and service,
        // matching MAME. Only global reset clears service; RETI releases it.
        rising(0); accept_irq(8'hb0); rising(0);
        write_byte(0, 8'hd3);
        check(!irq && !ieo, "software reset preserves service blocking");
        rising(0); read_count(0, 1);
        check(zc == 0 && !irq, "reset counter stopped");
        return_irq();
        check(irq && !ieo, "software reset preserves pending across RETI");
        accept_irq(8'hb0); return_irq();
        check(!irq && ieo, "preserved software-reset request drained");
        write_byte(0, 8'hd1); // reset release alone does not restart
        rising(0); check(!irq && zc == 0, "new constant required to restart");
        program_channel(0, 8'hd7, 8'h01);
        rising(0); check(irq, "constant restarts reset channel");
        // Reset with bit7=0 drops pending by the independent interrupt mask,
        // not by software reset; service remains until RETI.
        accept_irq(8'hb0); rising(0);
        write_byte(0, 8'h53);
        check(!irq && !ieo, "masked software reset retains service");
        return_irq();
        check(!irq && ieo, "masked software reset clears only pending");
        // Reprogramming a reset channel must also leave active service alone.
        program_channel(0, 8'hd7, 8'h01);
        rising(0); accept_irq(8'hb0);
        program_channel(0, 8'hd7, 8'h01);
        rising(0);
        check(!irq && !ieo, "reset and constant load preserve service");
        return_irq(); check(irq, "reprogrammed in-service request retained");
        accept_irq(8'hb0); // Global reset below clears live service.
        // Global reset wins over bus, trigger, ACK, RETI and CE together.
        reset = 1; wr = 1; din = 8'hff; ack = 1; reti = 1; trigger = 0;
        step(1);
        check(!irq && ieo && vector == 0 && zc == 0, "global reset priority");
        wr = 0; ack = 0; reti = 0; reset = 0;
        trigger = 4'hf; step();
        repeat (33) device_tick();
        check(!irq && zc == 0, "global reset stops all channels");
        for (int i = 0; i < 4; i++) read_count(i, 0);
        $display("PASS: reset stop/clear/restart; x1_ctc standalone, %0d sys edges, time=%0t", cycles, $time);
        $finish;
    end

    initial begin
        #100000000;
        $fatal(1, "CTC bench timeout");
    end
endmodule
