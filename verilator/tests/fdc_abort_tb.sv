`timescale 1ns/1ps
// Original register-level fixture; no ROM, game or disk image required.
module fdc_abort_tb;
    reg clk = 0, reset = 1, wr = 0, rd = 0;
    reg [7:0] command = 0;
    always #5 clk = !clk;
    wire irq, busy, drq;
    wd1793 #(.RWMODE(0), .EDSK(0)) dut (
        .clk_sys(clk), .ce(1'b1), .reset(reset), .io_en(1'b1), .rd(rd), .wr(wr),
        .addr(2'd0), .din(command), .dout(), .drq(drq), .intrq(irq), .busy(busy),
        .wp(1'b0), .fmt_wp(), .size_code(3'd1), .layout(1'b0), .side(1'b0),
        .ready(1'b1), .fm_mode(1'b0), .img_mounted(1'b0), .img_size(20'd0),
        .img_size_id(24'd0), .disk_index(3'd0), .prepare(), .sd_lba(), .sd_rd(),
        .sd_wr(), .sd_ack(1'b0), .sd_buff_addr(9'd0), .sd_buff_dout(8'd0),
        .sd_buff_din(), .sd_buff_wr(1'b0), .input_active(1'b0),
        .input_addr(20'd0), .input_data(8'd0), .input_wr(1'b0), .buff_addr(),
        .buff_read(), .buff_din(8'd0)
    );
    task send(input [7:0] value);
        @(negedge clk); command = value; wr = 1;
        @(negedge clk); wr = 0;
    endtask
    task check_abort(input bit active, input bit interrupt_expected);
        if (active) begin
            send(8'h80); // READ SECTOR: busy during the pre-transfer wait.
            repeat (10) @(negedge clk);
            assert(busy && !irq) else $fatal(1, "command failed to start");
        end
        send(interrupt_expected ? 8'hD8 : 8'hD0);
        repeat (20) @(negedge clk);
        assert(!busy && !drq && irq == interrupt_expected)
            else $fatal(1, "abort active=%0d expected_irq=%0d actual_irq=%0d busy=%0d drq=%0d",
                        active, interrupt_expected, irq, busy, drq);
        // D0 must also clear an interrupt left by D8.
        send(8'hD0);
        repeat (10) @(negedge clk);
        assert(!busy && !drq && !irq) else $fatal(1, "D0 did not clear interrupt");
    endtask
    initial begin
        repeat (3) @(negedge clk); reset = 0;
        check_abort(0, 0);
        check_abort(1, 0);
        check_abort(0, 1);
        check_abort(1, 1);
        // A normal subsequent command must still raise completion INTRQ.
        send(8'h00); // RESTORE has a deterministic completion wait, no media.
        repeat (4100) @(negedge clk);
        assert(!busy && irq) else $fatal(1, "normal completion was suppressed");
        rd = 1;
        repeat (3) @(negedge clk);
        rd = 0;
        repeat (3) @(negedge clk);
        assert(!irq) else $fatal(1, "status read did not acknowledge completion");
        reset = 1;
        repeat (3) @(negedge clk);
        assert(!busy && !drq && !irq) else $fatal(1, "reset did not clear flags");
        $display("PASS: FDC idle/busy D0 silent abort, D8 interrupt, subsequent completion/status acknowledgement/reset");
        $finish;
    end
    initial begin #100000; $fatal(1, "abort timeout"); end
endmodule
