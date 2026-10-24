`timescale 1ns/1ps
// x1_tape_quickload with the real x1_tap_sd_stream on a simulated SD slot.
// Tapes are built here in the X1 IPL format (old TAP header) at 8 and
// 44.1 kHz: machine code with data after it, BASIC, and a bad program count.
module tape_quickload_tb;
    reg clk = 0;
    always #5 clk = !clk;

    // ---- tape image -------------------------------------------------------
    localparam int MAX_SAMPLES = 1 << 20;
    reg samples [0:MAX_SAMPLES-1];
    integer n;                       // samples written
    integer hz, one_hi, one_lo, zero_hi, zero_lo;
    integer end_sample;              // sample after the program's last edge
    reg [7:0] image [0:MAX_SAMPLES/8 + 8];
    integer image_bytes;

    task pulse(input integer hi, input integer lo);
        for (integer i = 0; i < hi; i++) begin samples[n] = 1; n++; end
        for (integer i = 0; i < lo; i++) begin samples[n] = 0; n++; end
    endtask
    task bit_out(input b); if (b) pulse(one_hi, one_lo); else pulse(zero_hi, zero_lo); endtask
    task gap(input integer count); for (integer i = 0; i < count; i++) begin samples[n] = 0; n++; end endtask
    task byte_out(input [7:0] v, inout integer ones);
        for (integer i = 7; i >= 0; i--) begin bit_out(v[i]); ones += v[i]; end
        end_sample = n + 1;          // the separator's rising edge is sample n
        bit_out(1);
    endtask
    task block(input integer sync, input integer count, input [7:0] data [0:255], input integer corrupt);
        integer ones, dummy;
        ones = 0; dummy = 0;
        // Leader of ones, then exactly N zeros and N ones: the IPL drops the
        // zero that follows 40 counted zeros and counts again.
        for (integer i = 0; i < 100; i++) bit_out(1);
        for (integer i = 0; i < sync; i++) bit_out(0);
        for (integer i = 0; i < sync; i++) bit_out(1);
        bit_out(0);                  // the edge after sync
        bit_out(0); bit_out(0); bit_out(1);   // start: bits until a 1
        for (integer i = 0; i < count; i++) byte_out(data[i], ones);
        ones += corrupt;
        byte_out(ones[15:8], dummy);
        byte_out(ones[7:0], dummy);
    endtask

    reg [7:0] header [0:255], body [0:255];
    // The stub (FFA0): ld bc,1D00; out (c),a; exx; ld bc,0E00; ld de,0001;
    // ld l,0; exx; ld hl,FF00; ld bc,20; call 0146; ld hl,(FF14);
    // ld bc,(FF12); call 0146; ld hl,0083; ld (FFFE),hl; ld sp,0; jp 0083.
    localparam logic [7:0] stub [0:45] = '{
        8'h01, 8'h00, 8'h1d, 8'hed, 8'h79, 8'hd9, 8'h01, 8'h00, 8'h0e, 8'h11,
        8'h01, 8'h00, 8'h2e, 8'h00, 8'hd9, 8'h21, 8'h00, 8'hff, 8'h01, 8'h20,
        8'h00, 8'hcd, 8'h46, 8'h01, 8'h2a, 8'h14, 8'hff, 8'hed, 8'h4b, 8'h12,
        8'hff, 8'hcd, 8'h46, 8'h01, 8'h21, 8'h83, 8'h00, 8'h22, 8'hfe, 8'hff,
        8'h31, 8'h00, 8'h00, 8'hc3, 8'h83, 8'h00};
    integer program_size;
    task build(input integer rate, input [7:0] attr, input integer corrupt, input [15:0] load = 16'hc000);
        hz = rate;
        if (rate == 8000) begin one_hi = 2; one_lo = 2; zero_hi = 1; zero_lo = 1; end
        else begin one_hi = 12; one_lo = 8; zero_hi = 4; zero_lo = 6; end
        n = 0;
        program_size = 40;
        foreach (header[i]) header[i] = 0;
        header[0] = attr;
        header[1] = "Q"; header[2] = "L";
        header[8'h12] = program_size[7:0]; header[8'h13] = 0;
        header[8'h14] = load[7:0]; header[8'h15] = load[15:8];
        header[8'h16] = load[7:0]; header[8'h17] = load[15:8];   // exec
        header[8'h1d] = 8'h55; header[8'h1e] = 8'h66; header[8'h1f] = 8'h77;
        for (integer i = 0; i < 256; i++) body[i] = 8'(i * 37 + 11);
        gap(hz / 10);
        block(40, 32, header, 0);
        gap(hz / 20);
        block(20, program_size, body, corrupt);
        // A loader's next part: more pulses after the program.
        for (integer i = 0; i < 400; i++) bit_out(i[0]);
        gap(hz / 10);
        image[0] = hz[7:0]; image[1] = hz[15:8]; image[2] = hz[23:16]; image[3] = hz[31:24];
        image_bytes = 4 + (n + 7) / 8;
        for (integer i = 0; i < (n + 7) / 8; i++) begin
            image[4 + i] = 0;
            for (integer b = 0; b < 8; b++) image[4 + i][7 - b] = (i * 8 + b < n) ? samples[i * 8 + b] : 1'b0;
        end
    endtask

    // ---- SD slot -----------------------------------------------------------
    reg img_mounted = 0;
    reg [63:0] img_size = 0;
    wire [31:0] sd_lba;
    wire sd_rd;
    reg sd_ack = 0, sd_buff_wr = 0;
    reg [8:0] sd_buff_addr = 0;
    reg [7:0] sd_buff_dout = 0;
    always @(posedge clk) if (sd_rd && !sd_ack) begin
        repeat (20) @(posedge clk);
        sd_ack <= 1;
        for (integer i = 0; i < 512; i++) begin
            @(posedge clk);
            sd_buff_addr <= 9'(i);
            sd_buff_dout <= (sd_lba * 512 + i < image_bytes) ? image[sd_lba * 512 + i] : 8'h00;
            sd_buff_wr <= 1;
        end
        @(posedge clk); sd_buff_wr <= 0;
        @(posedge clk); sd_ack <= 0;
    end

    // ---- DUT ---------------------------------------------------------------
    wire stream_rewind, stream_ready, s_mount, s_present, s_empty, s_valid, s_level, s_last;
    wire [17:0] s_hz;
    wire loaded, rejected;
    wire [31:0] position, length;
    x1_tap_sd_stream #(.MIN_HZ(4000), .MAX_HZ(192000)) stream (
        .clk(clk), .reset(1'b0), .img_mounted(img_mounted), .rewind(stream_rewind), .img_size(img_size),
        .sd_lba(sd_lba), .sd_rd(sd_rd), .sd_ack(sd_ack),
        .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout), .sd_buff_wr(sd_buff_wr),
        .tape_mount(s_mount), .tape_present(s_present), .tape_empty(s_empty),
        .sample_valid(s_valid), .sample_level(s_level), .sample_last(s_last),
        .sample_ready(stream_ready), .sample_hz(s_hz),
        .loaded(loaded), .rejected(rejected), .position(position), .length(length));

    reg enable = 1, tape_insert = 0, disarm = 0, rearm = 0;
    reg [23:0] cart_addr = 0;
    reg cart_read = 0;
    wire [7:0] cart_data;
    wire cart_ready, reset_request, busy, deck_mount, deck_present, deck_empty;
    x1_tape_quickload dut (
        .clk(clk), .reset(1'b0), .enable(enable), .tape_insert(tape_insert), .disarm(disarm), .rearm(rearm),
        .stream_rewind(stream_rewind), .stream_mount(s_mount), .stream_present(s_present), .stream_empty(s_empty),
        .stream_valid(s_valid), .stream_level(s_level), .stream_last(s_last), .stream_rejected(rejected),
        .stream_ready(stream_ready), .stream_hz(s_hz),
        .deck_ready(1'b0), .deck_mount(deck_mount), .deck_present(deck_present), .deck_empty(deck_empty),
        .cart_addr(cart_addr), .cart_read(cart_read), .cart_data(cart_data), .cart_ready(cart_ready),
        .reset_request(reset_request), .busy(busy));

    // Deck view: count mounts with a tape and remember the position at each.
    integer deck_mounts, deck_ejects, reset_cycles;
    reg [31:0] mount_position;
    reg deck_has_tape;
    always @(posedge clk) begin
        if (deck_mount) begin
            if (deck_present) begin deck_mounts++; mount_position <= position; end else deck_ejects++;
            deck_has_tape <= deck_present && !deck_empty;
        end
        if (reset_request) reset_cycles++;
    end

    // One IPL-style port read: the board answers when ready, the CPU holds
    // the strobe a few more cycles.
    integer wait_cycles;
    task port_read(input [23:0] address, output [7:0] value);
        cart_addr = address;
        @(negedge clk); cart_read = 1;
        wait_cycles = 0;
        while (!cart_ready) begin @(negedge clk); wait_cycles++; end
        value = cart_data;
        repeat (3) begin @(negedge clk); assert(cart_ready && cart_data == value) else $fatal(1, "unstable read %h", address); end
        cart_read = 0;
        repeat (4) @(negedge clk);
    endtask

    task mount();
        deck_mounts = 0; deck_ejects = 0; reset_cycles = 0;
        @(negedge clk); img_mounted = 1; img_size = 64'(image_bytes); tape_insert = 1;
        @(negedge clk); img_mounted = 0; tape_insert = 0;
    endtask

    task check_boot(input bit expect_wait);
        reg [7:0] v;
        // The IPL's presence check (address 0), then the header, then the program.
        port_read(0, v);
        assert(v == 8'h01) else $fatal(1, "presence byte %h", v);
        if (expect_wait) assert(wait_cycles > 100) else $fatal(1, "presence read did not wait (%0d)", wait_cycles);
        // Stub header: the tape's name, 46 bytes to FFA0, exec FFA0, at 000020.
        for (integer i = 0; i < 32; i++) begin
            port_read(24'(i), v);
            assert(v == (i == 32'h12 ? 8'd46 : i == 32'h14 || i == 32'h16 ? 8'ha0 :
                         i == 32'h15 || i == 32'h17 ? 8'hff : i == 32'h1d ? 8'h20 :
                         i == 32'h13 || i >= 32'h1e ? 8'h00 : header[i]))
                else $fatal(1, "stub header %0d %h", i, v);
        end
        for (integer i = 0; i < 46; i++) begin
            port_read(24'h20 + 24'(i), v);
            assert(v == stub[i]) else $fatal(1, "stub byte %0d %h", i, v);
        end
        // What the stub reads with the IPL's routine: the tape header, then
        // the program from 000120.
        for (integer i = 0; i < 32; i++) begin
            port_read(24'h100 + 24'(i), v);
            assert(v == header[i]) else $fatal(1, "header %0d %h", i, v);
        end
        assert(deck_mounts == 0) else $fatal(1, "deck saw the tape during the boot");
        for (integer i = 0; i < program_size; i++) begin
            port_read(24'h120 + 24'(i), v);
            assert(v == body[i]) else $fatal(1, "program byte %0d %h want %h", i, v, body[i]);
        end
        wait (deck_mounts == 1);
        @(negedge clk);
        assert(mount_position == 32'(end_sample)) else $fatal(1, "deck position %0d want %0d", mount_position, end_sample);
        assert(deck_has_tape) else $fatal(1, "deck mount without tape");
        port_read(0, v);
        assert(v == 8'hff) else $fatal(1, "port after boot %h", v);
    endtask

    task check_pass(input string what);
        reg [7:0] v;
        wait (deck_mounts == 1);
        @(negedge clk);
        assert(mount_position == 0) else $fatal(1, "%s: deck position %0d", what, mount_position);
        port_read(0, v);
        assert(v == 8'hff && wait_cycles == 0) else $fatal(1, "%s: port %h", what, v);
        assert(reset_cycles == 0) else $fatal(1, "%s: reset requested", what);
    endtask

    initial begin
        reg [7:0] v;
        repeat (10) @(negedge clk);
        for (integer r = 0; r < 2; r++) begin
            // A: IPL waits at the presence check during the check; no reset.
            build(r == 0 ? 8000 : 44100, 8'h01, 0);
            mount();
            repeat (5) @(negedge clk);
            check_boot(1);
            assert(reset_cycles == 0) else $fatal(1, "reset requested although the IPL read the port");
            assert(dut.delay == (r == 0 ? 6'd1 : 6'd8)) else $fatal(1, "delay %0d", dut.delay);
            // E: a user reset boots it again (no check, no reset request).
            deck_mounts = 0;
            @(negedge clk); rearm = 1; repeat (3) @(negedge clk); rearm = 0;
            check_boot(0);
            assert(reset_cycles == 0) else $fatal(1, "rearm requested a reset");
            // B: mounted after the IPL looked: the check requests a reset.
            mount();
            wait (dut.state == dut.BOOT);
            assert(reset_cycles > 0 || reset_request) else $fatal(1, "no reset request");
            wait (!reset_request);
            check_boot(0);
            // F: a disk mounted afterwards wins: a reset no longer boots the tape.
            @(negedge clk); disarm = 1; @(negedge clk); disarm = 0;
            @(negedge clk); rearm = 1; repeat (3) @(negedge clk); rearm = 0;
            repeat (20) @(negedge clk);
            port_read(0, v);
            assert(v == 8'hff && !busy) else $fatal(1, "disarmed tape still offered");
            // C: BASIC: presented normally from the start.
            build(r == 0 ? 8000 : 44100, 8'h02, 0);
            mount();
            check_pass("basic");
            // D: bad program count.
            build(r == 0 ? 8000 : 44100, 8'h01, 1);
            mount();
            check_pass("bad count");
            // G: a program over the stub (FF80 + 40 bytes reaches FFA7).
            build(r == 0 ? 8000 : 44100, 8'h01, 0, 16'hff80);
            mount();
            check_pass("over the stub");
            // H: a program over the IPL stack that wraps past FFFF (as 3D
            // Bomberman's FFDE + F8): the tape plays normally.
            build(r == 0 ? 8000 : 44100, 8'h01, 0, 16'hfff0);
            mount();
            check_pass("over the stack");
            $display("PASS: quick start at %0d Hz: waiting check, header/program served, deck after the program, rearm, reset request, disarm, BASIC, bad-count, over-stub and over-stack fallback", hz);
        end
        // Quick start off: the tape goes to the deck as before.
        enable = 0;
        build(8000, 8'h01, 0);
        mount();
        check_pass("disabled");
        $display("PASS: quick start off presents the tape unchanged");
        $finish;
    end
    initial begin #2000000000; $fatal(1, "timeout"); end
endmodule
