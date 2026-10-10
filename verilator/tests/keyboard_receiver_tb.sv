`timescale 1ns/1ps
// Run inherited MR16 firmware against the same one-way PS/2 stream as HPS.
module keyboard_receiver_tb #(parameter CLOCK_HZ = 32000000,
                              parameter RECEIVE_ONLY = 1);
    reg clk = 0, reset = 1, ps2_clk = 1, ps2_data = 1;
    always #(500000000.0/CLOCK_HZ) clk = !clk;
    x1_sub #(.CLOCK_HZ(CLOCK_HZ), .PS2_RECEIVE_ONLY(RECEIVE_ONLY)) dut(
        .I_reset(reset), .I_rtc_power_reset(1'b0), .I_clk(clk), .I_cs(1'b0), .I_rd(1'b0), .I_wr(1'b0),
        .I_M1_n(1'b1), .I_D(8'd0), .O_D(), .O_DOE(), .O_clk1(),
        .O_FDC_DRQ_n(), .I_FDCS(1'b0), .I_RFSH_n(1'b1), .I_RFSH_STB_n(1'b1),
        .I_DMA_CS(1'b0), .O_DMA_BANK(), .O_DMA_A(), .I_DMA_D(8'd0), .O_DMA_D(),
        .O_DMA_MREQ_n(), .O_DMA_IORQ_n(), .O_DMA_RD_n(), .O_DMA_WR_n(),
        .O_DMA_BUSRQ_n(), .I_DMA_BUSAK_n(1'b1), .I_DMA_RDY(1'b0),
        .I_DMA_WAIT_n(1'b1), .I_DMA_IEI(1'b0), .O_DMA_INT_n(), .O_DMA_IEO(),
        .O_PCM(), .O_FD_LAMP(), .I_fa(13'd0), .I_fcs(1'b0),
        .I_PS2C(ps2_clk), .I_PS2D(ps2_data), .O_PS2CT(), .O_PS2DT(),
        .O_TX_BSY(), .O_RX_BSY(), .O_KEY_BRK_n(), .I_SPM1(1'b0),
        .I_RETI(1'b0), .I_IEI(1'b1), .O_INT_n(), .O_JOY_A(), .O_JOY_B(),
        .dot_7seg(), .num_7seg());

    integer tx_modes = 0, responses = 0;
    reg [15:0] last_response = 0;
    reg [15:0] expected [0:5];
    reg [10:0] rom_addr = 0;
    wire [15:0] original_word, receive_word;
    reg rom_verified = 0;
    sub_rom #(.PS2_RECEIVE_ONLY(0)) original_rom(clk, rom_addr, original_word);
    sub_rom #(.PS2_RECEIVE_ONLY(1)) receive_rom(clk, rom_addr, receive_word);
    initial begin
        for (integer index = 0; index < 2048; index++) begin
            @(negedge clk); rom_addr = 11'(index);
            @(posedge clk); #1;
            if (index == 'h22e) begin
                assert(original_word == 16'h7100 && receive_word == 16'h2ffb)
                    else $fatal(1, "PS2_TX profile instruction mismatch");
            end else
                assert(original_word == receive_word)
                    else $fatal(1, "unrelated ROM word changed: %0h", index);
        end
        rom_verified = 1;
    end
    always @(posedge clk) begin
        if (RECEIVE_ONLY && !reset && $time >= 1000000)
            assert(dut.OP2[1:0] == 2'b11)
                else $fatal(1, "receive-only firmware drove PS/2 outputs");
        if (!reset && dut.wram_cs && dut.mem_we) begin
            if (dut.sub_addr == 16'h109c && dut.wdata[7:6] != 0) begin
                tx_modes++;
                $display("TRACE t_ns=%0t scnt=%04x transmit mode", $time, dut.wdata);
            end
            if (dut.sub_addr == 16'h109c && dut.wdata == 11)
                $display("TRACE t_ns=%0t receiver armed", $time);
            if (dut.sub_addr == 16'h109e && dut.wdata == 0)
                $display("TRACE t_ns=%0t timeout stopped", $time);
            if (dut.sub_addr == 16'h10b8 && dut.wdata != last_response) begin
                last_response = dut.wdata;
                $display("TRACE t_ns=%0t key=%04x", $time, dut.wdata);
                // Polling mode keeps the latest event in the first buffer word.
                if (dut.wdata != 16'h00ff) begin
                    if (RECEIVE_ONLY)
                        assert(responses < 6 && dut.wdata == expected[responses])
                            else $fatal(1, "response %0d = %04x", responses, dut.wdata);
                    responses++;
                end
            end
        end
    end
    task send_at(input integer ms, input [7:0] value);
        reg [10:0] packet;
        if ($time < ms*1000000) #(ms*1000000 - $time);
        packet = {1'b1, ~^value, value, 1'b0};
        $display("TRACE t_ns=%0t input=%02x", $time, value);
        for (integer bit_index = 0; bit_index < 11; bit_index++) begin
            ps2_data = packet[bit_index];
            #50000; ps2_clk = 0;
            #50000; ps2_clk = 1;
        end
        ps2_data = 1;
    endtask
    initial begin
        $timeformat(-9, 0, "", 0);
        expected[0] = 16'h46b7; expected[1] = 16'h00f7;
        expected[2] = 16'h49b7; expected[3] = 16'h00f7;
        expected[4] = 16'h4ab7; expected[5] = 16'h00f7;
        repeat (64) @(negedge clk);
        reset = 0;
        send_at(25, 'h2b); send_at(45, 'hf0); send_at(47, 'h2b);
        send_at(60, 'h43); send_at(80, 'hf0); send_at(82, 'h43);
        send_at(100, 'h3b); send_at(120, 'hf0); send_at(122, 'h3b);
        #2000000;
        if (RECEIVE_ONLY)
            assert(responses == 6 && tx_modes == 0 && rom_verified)
                else $fatal(1, "responses=%0d transmit_modes=%0d", responses, tx_modes);
        else
            assert(responses == 4 && tx_modes > 0)
                else $fatal(1, "historical profile no longer reproduces missing I");
        $display("RESULT: clock=%0d responses=%0d transmit_modes=%0d", CLOCK_HZ, responses, tx_modes);
        $finish;
    end
endmodule
