`timescale 1ns/1ps
// Original register-level fixture for DEFER_BLOCKED_COMMAND; no private media.
// Board FDC configuration (indexed strict D88, two physical drives) with an
// in-testbench one-sector D88 image and a host that answers each SD request
// only after LATENCY clocks, as MiSTer's HPS does. A RESTORE written while
// the mount scan owns the transport must report BUSY at once and complete
// after the scan (DEFER=1); with DEFER=0 it is dropped (negative control).
module fdc_defer_tb #(parameter DEFER=1, LATENCY=4000);
    reg clk = 0, reset = 1, wr = 0, rd = 0;
    reg [7:0] din = 0;
    reg [1:0] addr = 0;
    reg img_mounted = 0, sd_ack = 0, sd_buff_wr = 0;
    reg [8:0] sd_buff_addr = 0;
    reg [7:0] sd_buff_dout = 0;
    always #5 clk = !clk;
    wire irq, busy, drq, sd_rd, sd_wr, transport_idle;
    wire [31:0] sd_lba;
    wire [7:0] dout;
    wd1793 #(.RWMODE(1), .EDSK(1), .HEADLOAD_STATUS(1), .INDEX_CYCLES(20000),
             .D88_ONLY(1), .PHYSICAL_DRIVES(2), .DEFER_BLOCKED_COMMAND(DEFER)) dut (
        .drive_select(1'b0), .drive_connected(1'b1), .transport_idle(transport_idle),
        .clk_sys(clk), .ce(1'b1), .reset(reset), .io_en(1'b1), .rd(rd), .wr(wr),
        .addr(addr), .din(din), .dout(dout), .drq(drq), .intrq(irq), .busy(busy),
        .wp(1'b1), .fmt_wp(), .size_code(3'd1), .layout(1'b0), .side(1'b0),
        .ready(1'b1), .fm_mode(1'b0), .img_mounted(img_mounted), .img_size(20'd1024),
        .img_size_id(24'd1024), .disk_index(3'd0), .prepare(), .sd_lba(sd_lba), .sd_rd(sd_rd),
        .sd_wr(sd_wr), .sd_ack(sd_ack), .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout),
        .sd_buff_din(), .sd_buff_wr(sd_buff_wr), .input_active(1'b0),
        .input_addr(20'd0), .input_data(8'd0), .input_wr(1'b0), .buff_addr(),
        .buff_read(), .buff_din(8'd0), .hd_selected(1'b0), .raw_2d(1'b0), .fdc_ce(1'b0)
    );
    // Minimal D88: 0x2B0 header, track 0 at 0x2B0 with one 256-byte sector
    // (C0 H0 R1 N1, MFM), disk size 0x3C0; padded to two SD blocks.
    reg [7:0] image [0:1023];
    initial begin
        for (integer i = 0; i < 1024; i++) image[i] = 0;
        image[8'h1c] = 8'hc0; image[8'h1d] = 8'h03;              // disk size 0x3C0
        image[8'h20] = 8'hb0; image[8'h21] = 8'h02;              // track 0 offset
        image[10'h2b0+2] = 8'h01; image[10'h2b0+3] = 8'h01;     // R=1, N=1
        image[10'h2b0+4] = 8'h01;                                // one sector
        image[10'h2b0+14] = 8'h00; image[10'h2b0+15] = 8'h01;   // data size 256
        for (integer i = 0; i < 256; i++) image[10'h2c0+i] = 8'(i);
    end
    // Host: hold each request for LATENCY clocks, then ACK and stream 512 bytes.
    integer requests = 0;
    initial forever begin
        @(negedge clk);
        if (sd_rd && !sd_ack) begin
            repeat (LATENCY) @(negedge clk);
            requests++;
            sd_ack = 1;
            for (integer i = 0; i < 512; i++) begin
                sd_buff_addr = 9'(i);
                sd_buff_dout = (sd_lba < 2) ? image[sd_lba * 512 + i] : 8'h00;
                sd_buff_wr = 1; @(negedge clk); sd_buff_wr = 0; @(negedge clk);
            end
            sd_ack = 0;
            repeat (4) @(negedge clk);
        end
    end
    task send(input [1:0] a, input [7:0] value);
        @(negedge clk); addr = a; din = value; wr = 1;
        @(negedge clk); wr = 0;
    endtask
    initial begin
        repeat (3) @(negedge clk); reset = 0;
        repeat (3) @(negedge clk);
        img_mounted = 1; repeat (4) @(negedge clk); img_mounted = 0;
        // Wait until the mount scan has issued its first (slow) SD request.
        wait (sd_rd);
        repeat (20) @(negedge clk);
        assert(!transport_idle && !irq) else $fatal(1, "scan did not own the transport");
        send(2'd0, 8'h02); // RESTORE
        repeat (4) @(negedge clk);
        if (!busy) $fatal(1, "RESTORE during scan: BUSY did not rise (dropped)");
        // It must complete after the scan: INTRQ, BUSY clear, track 0.
        fork
            begin wait (irq && !busy); end
            begin repeat (LATENCY * 8 + 400000) @(negedge clk);
                  $fatal(1, "deferred RESTORE never completed (busy=%0d irq=%0d)", busy, irq); end
        join_any
        disable fork;
        assert(transport_idle && requests >= 2) else $fatal(1, "completed before the scan finished");
        assert(dut.wdreg_track == 0) else $fatal(1, "track register %0d after RESTORE", dut.wdreg_track);
        $display("PASS deferred RESTORE during a %0d-clock-latency scan: BUSY at once, INTRQ after %0d SD requests",
                 LATENCY, requests);
        $finish;
    end
endmodule
