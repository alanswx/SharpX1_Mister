// SPDX-License-Identifier: GPL-2.0-only
// x1_tap_sd_stream + the real x1_cassette_transport against an hps_io-style
// SD block model. Logs every accepted sample; tests/test_tap_sd_stream.py
// compares the log with an independently decoded TAP image.
`timescale 1ns/1ps
module tap_sd_stream_tb;
    parameter int SYS_HZ = 64000;
    parameter int LATENCY = 200;
    parameter bit RUNTIME = 0;
    parameter int MIN_HZ = 8000;
    parameter int MAX_HZ = 8000;

    logic clk = 0;
    always #5 clk = !clk;
    logic reset = 1;

    logic [7:0] image[0:2097151];
    longint size;
    string path, log_path, mode;
    int fd, remount_after, max_cycles;

    logic img_mounted = 0;
    logic [63:0] img_size = 0;
    wire [31:0] sd_lba;
    wire sd_rd;
    logic sd_ack = 0, sd_buff_wr = 0;
    logic [8:0] sd_buff_addr = 0;
    logic [7:0] sd_buff_dout = 0;
    wire tape_mount, tape_present, tape_empty;
    wire sample_valid, sample_level, sample_last, sample_ready;
    wire loaded, rejected;
    wire [17:0] sample_hz;
    logic cmd_valid = 0;
    logic [7:0] cmd = 0;
    wire waveform, underflow;
    wire [7:0] applied_mode, sensor;

    x1_tap_sd_stream #(.MIN_HZ(MIN_HZ), .MAX_HZ(MAX_HZ)) dut(.clk(clk), .reset(reset),
        .img_mounted(img_mounted), .img_size(img_size),
        .sd_lba(sd_lba), .sd_rd(sd_rd), .sd_ack(sd_ack),
        .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout), .sd_buff_wr(sd_buff_wr),
        .tape_mount(tape_mount), .tape_present(tape_present), .tape_empty(tape_empty),
        .sample_valid(sample_valid), .sample_level(sample_level), .sample_last(sample_last),
        .sample_ready(sample_ready), .sample_hz(sample_hz), .loaded(loaded), .rejected(rejected));

    x1_cassette_transport #(.SYS_HZ(SYS_HZ), .RUNTIME_RATE(RUNTIME)) transport(.clk_sys(clk), .reset(1'b0),
        .mount(tape_mount), .present(tape_present), .empty(tape_empty),
        .cmd_valid(cmd_valid), .cmd(cmd),
        .sample_valid(sample_valid), .sample_level(sample_level),
        .sample_last(sample_last), .sample_hz(sample_hz), .sample_ready(sample_ready),
        .waveform(waveform), .applied_mode(applied_mode),
        .sensor(sensor), .underflow(underflow));

    // hps_io-style block reads: request level, delayed ACK, 512 writes, ACK low.
    longint cycle = 0;
    int requests = 0;
    always @(posedge clk) cycle <= cycle + 1;
    initial begin
        forever begin
            @(negedge clk);
            if (sd_rd && !sd_ack) begin
                longint base;
                base = longint'(sd_lba) * 512;
                requests++;
                repeat (LATENCY) @(negedge clk);
                sd_ack = 1;
                for (int i = 0; i < 512; i++) begin
                    @(negedge clk);
                    sd_buff_addr = 9'(i);
                    sd_buff_dout = base + i < size ? image[base + i] : 8'h00;
                    sd_buff_wr = 1;
                    @(negedge clk);
                    sd_buff_wr = 0;
                end
                @(negedge clk);
                sd_ack = 0;
                if (sd_rd) begin
                    $display("FAIL sd_rd still asserted after transfer");
                    $finish;
                end
            end
        end
    end

    // Accepted-sample ledger, sampled before the consuming edge.
    longint accepted = 0;
    always @(posedge clk) begin
        if (sample_valid && sample_ready)
            $fdisplay(fd, "A %0d %0d %0d %0d", cycle, accepted, sample_level, sample_last);
        if (sample_valid && sample_ready) accepted <= accepted + 1;
        if (tape_mount) $fdisplay(fd, "M %0d %0d %0d", cycle, tape_present, tape_empty);
    end

    task automatic mount_image();
        @(negedge clk);
        img_size = 64'(size); img_mounted = 1;
        @(negedge clk);
        img_mounted = 0;
    endtask

    task automatic command(input logic [7:0] value);
        @(negedge clk);
        cmd = value; cmd_valid = 1;
        @(negedge clk);
        cmd_valid = 0;
    endtask

    task automatic wait_ready();
        int guard = 0;
        while (!loaded && !rejected) begin
            @(negedge clk);
            if (++guard > 200000) begin
                $display("FAIL tap stream did not load");
                $finish;
            end
        end
    endtask

    initial begin
        if (!$value$plusargs("image=%s", path)) $fatal(1, "missing +image");
        if (!$value$plusargs("size=%d", size)) $fatal(1, "missing +size");
        if (!$value$plusargs("log=%s", log_path)) $fatal(1, "missing +log");
        if (!$value$plusargs("mode=%s", mode)) mode = "play";
        if (!$value$plusargs("remount=%d", remount_after)) remount_after = 0;
        if (!$value$plusargs("max=%d", max_cycles)) max_cycles = 50000000;
        if (size > 0) $readmemh(path, image, 0, int'(size - 1));
        fd = $fopen(log_path, "w");
        repeat (4) @(negedge clk);
        reset = 0;
        repeat (4) @(negedge clk);
        mount_image();
        wait_ready();
        $fdisplay(fd, "L %0d %0d %0d %0d", cycle, loaded, rejected, sample_hz);
        if (rejected) begin
            // A rejected image must leave the transport ejected and inert.
            command(8'd2);
            repeat (1000) @(negedge clk);
            $fdisplay(fd, "E %0d %0d %0d %0d %0d", cycle, sensor, applied_mode, underflow, requests);
            $fclose(fd);
            $display("DONE tap stream");
            $finish;
        end
        repeat (100) @(negedge clk);
        command(8'd2);
        if (mode == "remount") begin
            while (accepted < remount_after) @(negedge clk);
            mount_image();
            wait_ready();
            $fdisplay(fd, "L %0d %0d %0d %0d", cycle, loaded, rejected, sample_hz);
            repeat (100) @(negedge clk);
            command(8'd2);
        end
        while (sensor != 8'h02 && !underflow && applied_mode == 8'd2 && cycle < max_cycles) @(negedge clk);
        if (sensor != 8'h02 && !underflow && applied_mode != 8'd2) begin
            // Empty media never enters PLAY; give it a moment to settle.
            repeat (10) @(negedge clk);
        end
        $fdisplay(fd, "E %0d %0d %0d %0d %0d", cycle, sensor, applied_mode, underflow, requests);
        $fclose(fd);
        $display("DONE tap stream");
        $finish;
    end
endmodule
