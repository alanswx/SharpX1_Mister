// SPDX-License-Identifier: GPL-2.0-only
// Original bus fixture exercising the inherited MR16 firmware, not a mailbox mock.
// From the repository root (build into a fresh temporary directory):
// Run: verilator --binary --timing --assert -j 4 --top-module sub_irq_ack_tb \
//   --Mdir /tmp/x1-sub-irq-ack rtl/mr16core.v rtl/mr16_x1.v rtl/sub_rom.v \
//   rtl/sub_cpu.v rtl/dpram.sv rtl/x1_irq_bridge.sv \
//   ./verilator/tests/sub_irq_ack_tb.sv -Wno-fatal
`timescale 1ns/1ps
module sub_irq_ack_tb #(parameter CLOCK_HZ = 32000000);
    reg clk = 0, reset = 1;
    always #(500000000.0 / CLOCK_HZ) clk = !clk;
    reg cs = 0, rd = 0, wr = 0;
    reg [7:0] host_data = 0;
    reg ps2_clk = 1, ps2_data = 1;
    reg m1_n = 1, mreq_n = 1, iorq_n = 1, rd_n = 1;
    wire [7:0] sub_data, ack_vector;
    wire int_n, tx_busy, rx_busy;
    wire irq, keyboard_ack, ctc_ack, ctc_iei, ctc_reti, ctc_selected;
    wire [7:0] bus_data = !m1_n && !iorq_n ? ack_vector : sub_data;

    x1_irq_bridge bridge (
        .clk(clk), .reset(reset), .m1_n(m1_n), .mreq_n(mreq_n),
        .iorq_n(iorq_n), .rd_n(rd_n), .data(bus_data),
        .keyboard_irq(!int_n), .ctc_irq(1'b0), .ctc_ieo(1'b1),
        .ctc_vector(8'hd4), .keyboard_vector(sub_data), .irq(irq),
        .keyboard_ack(keyboard_ack), .ctc_ack(ctc_ack), .ctc_iei(ctc_iei),
        .ctc_reti(ctc_reti), .ctc_selected(ctc_selected), .ack_vector(ack_vector)
    );
    x1_sub #(.CLOCK_HZ(CLOCK_HZ), .PS2_RECEIVE_ONLY(1), .IRQ_ACK_ONCE(1)) dut (
        .I_reset(reset), .I_clk(clk), .I_cs(cs), .I_rd(rd), .I_wr(wr),
        .I_M1_n(m1_n), .I_D(host_data), .O_D(sub_data), .O_DOE(), .O_clk1(),
        .O_FDC_DRQ_n(), .I_FDCS(1'b0), .I_RFSH_n(1'b1), .I_RFSH_STB_n(1'b1),
        .I_DMA_CS(1'b0), .O_DMA_BANK(), .O_DMA_A(), .I_DMA_D(8'hff), .O_DMA_D(),
        .O_DMA_MREQ_n(), .O_DMA_IORQ_n(), .O_DMA_RD_n(), .O_DMA_WR_n(),
        .O_DMA_BUSRQ_n(), .I_DMA_BUSAK_n(1'b1), .I_DMA_RDY(1'b0),
        .I_DMA_WAIT_n(1'b1), .I_DMA_IEI(1'b1), .O_DMA_INT_n(), .O_DMA_IEO(),
        .O_PCM(), .O_FD_LAMP(), .I_fa(13'd0), .I_fcs(1'b0),
        .I_PS2C(ps2_clk), .I_PS2D(ps2_data), .O_PS2CT(), .O_PS2DT(),
        .O_TX_BSY(tx_busy), .O_RX_BSY(rx_busy), .O_KEY_BRK_n(),
        .I_SPM1(keyboard_ack), .I_RETI(1'b0), .I_IEI(1'b1), .O_INT_n(int_n),
        .O_JOY_A(), .O_JOY_B(), .dot_7seg(), .num_7seg()
    );

    // Observe consumption without forcing firmware, RAM, or interrupt state.
    integer ack_consumes = 0;
    integer ack_edges = 0;
    always @(posedge clk) begin
        if (reset || m1_n || iorq_n) ack_edges = 0;
        else begin
            ack_edges++;
            if (dut.main_re) begin
                ack_consumes++;
                assert(ack_edges == 3)
                    else $fatal(1, "mailbox consumed on ACK edge %0d, expected 3", ack_edges);
            end
        end
    end

    task automatic tick;
        @(posedge clk); #1; @(negedge clk);
    endtask
    task automatic check(input bit ok, input string message);
        if (!ok) $fatal(1, "t=%0t clock=%0d: %s (sub=%02x vector=%02x IRQ=%b RX_busy=%b)",
                        $time, CLOCK_HZ, message, sub_data, ack_vector, irq, rx_busy);
    endtask
    task automatic write_host(input [7:0] value);
        wait (!tx_busy);
        @(negedge clk); cs = 1; wr = 1; host_data = value;
        repeat (8) tick();
        cs = 0; wr = 0;
        wait (!tx_busy);
    endtask
    task automatic send_ps2(input [7:0] value);
        reg [10:0] packet;
        packet = {1'b1, ~^value, value, 1'b0};
        for (integer i = 0; i < 11; i++) begin
            ps2_data = packet[i];
            #50000; ps2_clk = 0;
            #50000; ps2_clk = 1;
        end
        ps2_data = 1;
    endtask
    task automatic read_host(input [7:0] expected);
        wait (!rx_busy);
        @(negedge clk); cs = 1;
        repeat (4) tick(); // Select and settle synchronous mailbox RAM first.
        check(sub_data == expected, "response byte before consumption");
        rd = 1;
        repeat (8) tick();
        rd = 0; cs = 0;
        repeat (4) tick();
    endtask
    task automatic start_ack;
        @(negedge clk); m1_n = 0; iorq_n = 0;
    endtask
    task automatic end_ack;
        m1_n = 1; iorq_n = 1;
        repeat (4) tick();
    endtask

    initial begin
        repeat (64) @(negedge clk);
        reset = 0;
        #5000000; // Real firmware initialization; no ROM/game/snapshot loading.
        write_host(8'he4);
        write_host(8'h52);
        #20000000;
        send_ps2(8'h2b); // F make -> IRQ vector 52, then response B7 46.
        wait (irq);
        start_ack();
        repeat (3) tick();
        check(ack_vector == 8'h52, "third-edge keyboard vector capture");
        check(ack_consumes == 1, "one vector consumption");
        // Keep the ACK bus asserted for 200 us. MR16 continues executing at
        // the real master frequency; there is deliberately no CPU CE gating.
        repeat ((CLOCK_HZ + 4999) / 5000) begin
            tick();
            check(keyboard_ack && !ctc_ack && !ctc_selected,
                  "keyboard ownership held throughout stretched ACK");
            check(ack_vector == 8'h52, "held vector remains 52 as firmware advances");
            check(ack_consumes == 1, "stretched ACK must not consume response");
        end
        check(!rx_busy && sub_data == 8'hb7,
              "real firmware published B7 without it being consumed during ACK");
        end_ack();
        check(!irq, "keyboard vector acknowledged");

        // B7 is now a full, non-interrupt mailbox. An unsupported ACK must
        // neither select the keyboard nor consume this pending response.
        start_ack();
        repeat ((CLOCK_HZ + 4999) / 5000) begin
            tick();
            check(!keyboard_ack && !ctc_ack && ack_vector == 8'hff,
                  "spurious ACK has no owner and returns FF");
            check(ack_consumes == 1 && !rx_busy, "spurious ACK retains full mailbox");
        end
        end_ack();
        read_host(8'hb7);
        read_host(8'h46);
        #200000;
        check(rx_busy && !irq, "both response bytes drained, no residual IRQ");
        $display("PASS: real MR16 receive-only E4/52 F make, third-edge vector capture, 200-us ACK hold, spurious ACK preserves B7, response B7/46; clock=%0d time=%0t", CLOCK_HZ, $time);
        $finish;
    end
    initial begin
        #100000000;
        $fatal(1, "MR16 IRQ ACK bench timeout (IRQ=%b TX_busy=%b RX_busy=%b)", irq, tx_busy, rx_busy);
    end
endmodule
