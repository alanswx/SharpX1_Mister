`timescale 1ns/1ps
// Original raw-media register/SD-handshake fixture; no external disk assets.
module fdc_sd_abort_tb;
    reg clk = 0, reset = 1, wr = 0, rd = 0, ack = 0;
    reg [1:0] address = 0;
    reg [7:0] data = 0;
    reg [8:0] host_address = 0;
    always #5 clk = !clk;
    wire busy, drq, irq, sd_rd, sd_wr;
    wire [31:0] lba;
    wire [7:0] host_data;
    wd1793 #(.RWMODE(1), .EDSK(0)) dut (
        // Shared machine freezes CPU/FDC enables during reset. Host ACK still
        // runs on clk_sys and must not disappear while the enable is stopped.
        .clk_sys(clk), .ce(!reset), .reset(reset), .io_en(1'b1), .rd(rd), .wr(wr),
        .addr(address), .din(data), .dout(), .busy(busy), .drq(drq), .intrq(irq),
        .wp(1'b0), .fmt_wp(), .size_code(3'd1), .layout(1'b0), .side(1'b0),
        .ready(1'b1), .fm_mode(1'b0), .img_mounted(1'b0), .img_size(20'd8192),
        .img_size_id(24'd8192), .disk_index(3'd0), .prepare(), .sd_lba(lba),
        .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(ack), .sd_buff_addr(host_address),
        .sd_buff_dout(8'd0), .sd_buff_din(host_data), .sd_buff_wr(1'b0),
        .input_active(1'b0), .input_addr(20'd0), .input_data(8'd0),
        .input_wr(1'b0), .buff_addr(), .buff_read(), .buff_din(8'd0)
    );
    task send(input [1:0] select, input [7:0] value);
        @(negedge clk); address = select; data = value; wr = 1;
        @(negedge clk); wr = 0;
    endtask
    task host_complete;
        ack = 1;
        repeat (10) @(negedge clk);
        assert(!sd_rd && !sd_wr) else $fatal(1, "request not released after ACK rise");
        ack = 0;
        repeat (15) @(negedge clk);
    endtask
    task start_read(input [7:0] sector);
        send(2, sector);
        send(0, 8'h80);
        wait(sd_rd);
        @(negedge clk);
        assert(busy && !drq && !sd_wr) else $fatal(1, "invalid pending read");
    endtask
    task exercise(input bit resetting, input bit ack_high, input bit writing, input bit held_reset = 0);
        if (writing) begin
            send(2, 1);
            send(0, 8'hA0);
            wait(sd_rd); // Read-modify-write preserves the neighboring sector.
            @(negedge clk); host_complete();
            for (int i = 0; i < 256; i++) begin
                wait(drq);
                send(3, 8'(i));
                wait(!drq);
            end
            wait(sd_wr);
            @(negedge clk);
        end else start_read(1);
        assert(lba == 0) else $fatal(1, "first sector LBA");
        if (ack_high) begin
            ack = 1;
            repeat (10) @(negedge clk);
            assert(!sd_rd && !sd_wr) else $fatal;
        end
        if (resetting) reset = 1;
        else send(0, 8'hD0);
        repeat (20) @(negedge clk);
        assert(lba == 0) else $fatal(1, "pending LBA changed on abort/reset");
        assert(!drq && !irq) else $fatal(1, "abort/reset left DRQ/INTRQ");
        if (writing) begin
            host_address = 37; repeat (3) @(negedge clk);
            assert(host_data == 37) else $fatal(1, "pending write buffer changed on abort/reset");
            host_address = 201; repeat (3) @(negedge clk);
            assert(host_data == 201) else $fatal(1, "pending write buffer bank changed on abort/reset");
        end
        if (!resetting) assert(busy) else $fatal(1, "abort completed before outstanding SD handshake drained");
        if (!ack_high) assert(writing ? sd_wr : sd_rd) else $fatal(1, "reset cancelled an unacknowledged request");
        if (!held_reset) reset = 0;
        // Ordinary commands cannot reuse the transport while the old ACK is
        // absent or still high. This used to alias the old transfer's completion.
        send(2, 3);
        send(0, 8'h80);
        repeat (20) @(negedge clk);
        assert(lba == 0 && (ack_high || (writing ? sd_wr : sd_rd))) else $fatal(1, "new command reused pending transport");
        if (!ack_high) host_complete();
        else begin ack = 0; repeat (15) @(negedge clk); end
        if (held_reset) assert(!dut.transport_active) else $fatal(1, "ACK did not drain with CE stopped during reset");
        assert(!busy && !drq && !irq) else $fatal(1, "aborted transfer did not finish silently");
        reset = 0;
        repeat (15) @(negedge clk);
        start_read(3);
        assert(lba == 1) else $fatal(1, "subsequent command did not use fresh LBA");
        send(0, 8'hD0);
        host_complete();
        assert(!busy && !drq && !irq) else $fatal;
    endtask
    initial begin
        repeat (3) @(negedge clk); reset = 0;
        for (int writing = 0; writing < 2; writing++) begin
            exercise(0, 0, 1'(writing));
            exercise(0, 1, 1'(writing));
            exercise(1, 0, 1'(writing));
            exercise(1, 1, 1'(writing));
            exercise(1, 0, 1'(writing), 1);
            exercise(1, 1, 1'(writing), 1);
        end
        $display("PASS: 12 FDC pending-read/write D0/reset cases before/during ACK, held reset, stable LBA/buffer, fresh command");
        $finish;
    end
    initial begin #10000000; $fatal(1, "SD abort timeout"); end
endmodule
