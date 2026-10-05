// SPDX-License-Identifier: GPL-2.0-only
// Original connected CTC/IRQ-bridge fixture; synthetic bus/trigger inputs.
// No CPU, MR16 firmware, BIOS or board validation is implied by this bench.
// Run: verilator --binary --timing --assert --timescale 1ns/1ps \
//   --top-module x1_ctc_irq_tb --Mdir /tmp/x1-ctc-irq-build \
//   rtl/x1_ctc.sv rtl/x1_irq_bridge.sv verilator/tests/x1_ctc_irq_tb.sv
`timescale 1ns/1ps
module x1_ctc_irq_tb;
    logic clk = 0, reset = 1, ce = 0, wr = 0;
    logic [1:0] channel = 0;
    logic [7:0] din = 0;
    wire [7:0] dout, ctc_vector, ack_vector;
    logic [3:0] external_trigger = 0;
    logic cascade = 0;
    wire [3:0] zc;
    wire [3:0] trigger = {cascade ? zc[0] : external_trigger[3], external_trigger[2:0]};
    logic m1_n = 1, mreq_n = 1, iorq_n = 1, rd_n = 1;
    logic [7:0] data = 0, keyboard_vector = 8'h52;
    logic keyboard_irq = 0;
    wire irq, ctc_irq, ctc_ieo, ctc_iei;
    wire ctc_ack, ctc_reti, keyboard_ack, ctc_selected;
    int cycles = 0, ack_events = 0, reti_events = 0, keyboard_ack_edges = 0;
    int terminal_events [0:3];

    x1_ctc ctc (
        .clk(clk), .reset(reset), .ce(ce), .wr(wr), .channel(channel),
        .din(din), .dout(dout), .trigger(trigger), .iei(ctc_iei),
        .irq(ctc_irq), .ieo(ctc_ieo), .ack(ctc_ack), .reti(ctc_reti),
        .vector(ctc_vector), .zc(zc)
    );
    x1_irq_bridge bridge (
        .clk(clk), .reset(reset), .m1_n(m1_n), .mreq_n(mreq_n),
        .iorq_n(iorq_n), .rd_n(rd_n), .data(data),
        .keyboard_irq(keyboard_irq), .keyboard_vector(keyboard_vector),
        .ctc_irq(ctc_irq), .ctc_ieo(ctc_ieo), .ctc_vector(ctc_vector),
        .irq(irq), .keyboard_ack(keyboard_ack), .ctc_ack(ctc_ack),
        .ctc_iei(ctc_iei), .ctc_reti(ctc_reti),
        .ctc_selected(ctc_selected), .ack_vector(ack_vector)
    );
    always #15.625 clk = !clk; // 32 MHz sys clock; CE can be completely stopped.

    task automatic check(input bit ok, input string message);
        if (!ok)
            $fatal(1, "cycle %0d: %s (irq=%b ctc_irq=%b ieo=%b candidate=%02x bus=%02x ack=%b reti=%b zc=%b)",
                   cycles, message, irq, ctc_irq, ctc_ieo, ctc_vector,
                   ack_vector, ctc_ack, ctc_reti, zc);
    endtask

    // Call with inputs driven at a falling edge. Count events as actually
    // sampled by the CTC, before NBA changes retire the combinational ACK.
    task automatic tick(input bit enable_tick = 0);
        ce = enable_tick;
        @(posedge clk);
        if (!reset) begin
            if (ctc_ack) ack_events++;
            if (ctc_reti) reti_events++;
            if (keyboard_ack) keyboard_ack_edges++;
        end
        #1;
        cycles++;
        for (int i = 0; i < 4; i++)
            if (!reset && zc[i]) terminal_events[i]++;
        @(negedge clk);
    endtask

    task automatic reset_pair;
        reset = 1; wr = 0; external_trigger = 0; cascade = 0;
        m1_n = 1; mreq_n = 1; iorq_n = 1; rd_n = 1;
        keyboard_irq = 0; keyboard_vector = 8'h52; data = 0;
        repeat (2) tick();
        reset = 0; tick();
        check(ctc_iei && ctc_ieo && !irq && !ctc_ack && !ctc_reti,
              "reset leaves both devices idle");
        ack_events = 0; reti_events = 0; keyboard_ack_edges = 0;
        for (int i = 0; i < 4; i++) terminal_events[i] = 0;
    endtask

    task automatic write_byte(input int ch, input logic [7:0] value);
        channel = 2'(ch); din = value; wr = 1;
        tick(); wr = 0;
    endtask

    task automatic program_channel(input int ch, input logic [7:0] ctrl,
                                   input logic [7:0] tc);
        write_byte(ch, ctrl); write_byte(ch, tc);
    endtask

    task automatic read_count(input int ch, input int expected);
        channel = 2'(ch); #1;
        check(dout == 8'(expected), $sformatf("channel %0d expected count %0d", ch, expected));
    endtask

    task automatic rising(input int ch);
        external_trigger[ch] = 0; tick();
        external_trigger[ch] = 1; tick();
    endtask

    // Forty sampled bus edges. Optional disturbances happen after edge one:
    // a second request from the serviced channel, then a higher channel 2
    // request. Neither request may change ACK ownership or the held vector.
    task automatic ctc_ack_hold(input logic [7:0] expected, input bit disturb = 0);
        int saved_ack, saved_keyboard;
        saved_ack = ack_events; saved_keyboard = keyboard_ack_edges;
        check(ctc_irq && ctc_vector == expected, "CTC pre-ACK eligible vector");
        m1_n = 0; iorq_n = 0; #1;
        check(ctc_ack && ctc_selected && !keyboard_ack && ack_vector == expected,
              "bridge presents candidate at first ACK edge");
        for (int n = 0; n < 40; n++) begin
            if (disturb && n == 3) external_trigger[3] = 0;
            if (disturb && n == 4) external_trigger[3] = 1;
            if (disturb && n == 8) external_trigger[2] = 1;
            tick();
            check(!ce && !ctc_ack && ctc_selected && !keyboard_ack,
                  "held CTC ACK generates only its first sampled event");
            check(ack_vector == expected, "CTC ACK vector held for all 40 clocks");
            check(ack_events == saved_ack + 1 && keyboard_ack_edges == saved_keyboard,
                  "no duplicate CTC ACK or accidental mailbox read");
            if (disturb && n == 0)
                check(!ctc_irq && ctc_vector == 8'h40 && !ctc_ieo && !irq,
                      "ACK retires candidate; real service blocks keyboard");
            if (disturb && n >= 8)
                check(ctc_irq && irq && ctc_vector == 8'h44 && !ctc_ieo,
                      "higher pending candidate changes while bus vector stays 46");
        end
        m1_n = 1; iorq_n = 1; #1;
        check(!ctc_selected && !ctc_ack && !keyboard_ack, "ACK bus release");
        tick();
    endtask

    // Stretched opcode fetches, followed by bus release. RETI is observed
    // before the release edge and must be consumed once by the real CTC.
    task automatic opcode(input logic [7:0] value, input bit expected_reti = 0);
        int saved_reti;
        saved_reti = reti_events;
        data = value; m1_n = 0; mreq_n = 0; rd_n = 0; iorq_n = 1;
        repeat (12) begin
            tick(); check(!ctc_reti, "held opcode fetch cannot release service");
        end
        mreq_n = 1; rd_n = 1; #1;
        check(ctc_reti == expected_reti, "RETI decoded at opcode bus release");
        tick();
        check(!ctc_reti && reti_events == saved_reti + int'(expected_reti),
              "exactly one decoded RETI event");
        m1_n = 1;
        repeat (4) tick();
        check(reti_events == saved_reti + int'(expected_reti), "no stretched-fetch duplicate RETI");
    endtask

    task automatic return_irq;
        opcode(8'hed); opcode(8'h4d, 1);
    endtask

    task automatic cascade_case(input bit rising_edge);
        int before_count, after_count, total;
        reset_pair(); cascade = 1;
        write_byte(0, 8'h40);
        program_channel(0, 8'h07, 8'h01); // /16 auto timer, interrupts disabled
        program_channel(3, rising_edge ? 8'hd7 : 8'hc7, 8'h02);
        repeat (37) tick();
        read_count(0, 1); read_count(3, 2);
        check(terminal_events[0] == 0 && terminal_events[3] == 0,
              "cascade timer cannot advance with CE stopped");
        for (int n = 1; n <= 64; n++) begin
            total = n / 16;
            before_count = 2 - (((n-1) / 16) % 2);
            after_count = 2 - (total % 2);
            tick(1); // 4 MHz tick, with seven sys clocks until the next tick.
            check(zc[0] == (n % 16 == 0), "cascade source /16 phase");
            read_count(3, before_count);
            tick();
            check(!ce && !zc[0], "source ZC clears with CE stopped");
            read_count(3, rising_edge ? after_count : before_count);
            if (n % 16 == 0)
                check(zc[3] == (rising_edge && total % 2 == 0), "rising cascade sample phase");
            tick();
            read_count(3, after_count);
            if (n % 16 == 0)
                check(zc[3] == (!rising_edge && total % 2 == 0), "falling cascade sample phase");
            repeat (5) tick();
            check(terminal_events[0] == total && terminal_events[3] == total / 2,
                  "one cascade decrement per selected edge, no doubled count");
            if (n == 7 || n == 33) begin
                repeat (40) tick();
                read_count(0, 1); read_count(3, after_count);
                check(terminal_events[0] == total && terminal_events[3] == total / 2,
                      "partial prescaler and pending cascade survive CE stall");
            end
        end
        check(irq && ctc_irq && !ctc_ieo && ctc_vector == 8'h46,
              "real cascade generates channel 3 IRQ candidate");
        ctc_ack_hold(8'h46);
        check(!irq && !ctc_ieo, "cascade IRQ moves into service");
        return_irq();
        check(!irq && ctc_ieo, "decoded RETI releases cascade service without CE");
    endtask

    initial begin
        @(negedge clk);
        reset_pair();
        write_byte(0, 8'h40);
        program_channel(2, 8'hd7, 8'h01);
        program_channel(3, 8'hd7, 8'h01);
        keyboard_irq = 1;
        rising(3);
        check(irq && ctc_irq && !ctc_ieo && ctc_vector == 8'h46,
              "real channel 3 request wins simultaneous keyboard");
        ctc_ack_hold(8'h46, 1);
        check(ctc_irq && ctc_vector == 8'h44, "channel 2 pending at bus release");
        return_irq(); // release ch3 service while ch2 remains pending
        check(ctc_irq && irq && ctc_vector == 8'h44 && !ctc_ieo,
              "RETI releases lower service and preserves higher pending IRQ");
        ctc_ack_hold(8'h44);
        check(!ctc_irq && !irq && !ctc_ieo, "channel 2 service blocks pending ch3 and keyboard");
        opcode(8'hed); opcode(8'h45); // RETN must not release CTC service.
        check(!irq && !ctc_ieo && reti_events == 1, "RETN cannot release connected CTC");
        return_irq();
        check(ctc_irq && irq && ctc_vector == 8'h46, "RETI exposes retained channel 3 request");
        ctc_ack_hold(8'h46);
        return_irq();
        check(!ctc_irq && ctc_ieo && irq, "keyboard becomes eligible after final CTC RETI");
        check(ack_events == 3 && reti_events == 3, "three actual CTC ACK/RETI events");

        // Downstream keyboard ownership must also remain fixed if a real CTC
        // request appears after the keyboard's third-edge mailbox capture.
        begin
            int saved_ack, saved_keyboard;
            saved_ack = ack_events; saved_keyboard = keyboard_ack_edges;
            m1_n = 0; iorq_n = 0; #1;
            check(keyboard_ack && !ctc_ack && !ctc_selected && ack_vector == 8'h52,
                  "keyboard selected only while CTC IEO permits it");
            for (int n = 0; n < 40; n++) begin
                if (n == 3) begin
                    keyboard_vector = 8'ha7; keyboard_irq = 0;
                    external_trigger[2] = 0;
                end
                if (n == 4) external_trigger[2] = 1;
                tick();
                check(keyboard_ack && !ctc_ack && !ctc_selected && ack_vector == 8'h52,
                      "held keyboard owner/vector despite new real CTC request");
                if (n >= 4)
                    check(ctc_irq && irq && ctc_vector == 8'h44,
                          "CTC stays eligible during downstream keyboard ACK");
            end
            check(ack_events == saved_ack && keyboard_ack_edges == saved_keyboard + 40,
                  "keyboard ACK remains a bus level; CTC gets no ACK event");
            m1_n = 1; iorq_n = 1; tick();
        end
        ctc_ack_hold(8'h44); return_irq();
        check(!irq && ctc_ieo && ack_events == 4 && reti_events == 4,
              "connected CTC requests and service fully drained");

        // Spurious acknowledge cannot consume a mailbox or invent service.
        m1_n = 0; iorq_n = 0;
        repeat (40) begin
            #1;
            check(!ctc_ack && !keyboard_ack && !ctc_selected && ack_vector == 8'hff,
                  "spurious ACK has no owner");
            tick();
        end
        m1_n = 1; iorq_n = 1; tick();
        check(ack_events == 4 && keyboard_ack_edges == 40, "spurious ACK changes no event counts");
        $display("PASS: connected counter vectors 44/46, 40-clock ACK holds without CE, pending/service, decoded RETI and CTC-first keyboard arbitration");

        cascade_case(1);
        cascade_case(0);
        $display("PASS: both channel 0 -> 3 cascade edges, /16 timer CE phase/stalls, connected cascade ACK/RETI; %0d sys edges, time=%0t", cycles, $time);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "connected CTC/IRQ bench timeout");
    end
endmodule
