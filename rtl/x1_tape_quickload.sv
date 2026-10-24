// SPDX-License-Identifier: GPL-2.0-only
// Original board-only tape quick start. It decodes the first program of a
// mounted TAP in the X1 IPL's own tape format straight from the SD stream and
// offers it to the IPL as a ROM cartridge (the machine's CART_PORT, CZ-8RB
// 0E00-0E03). The IPL checks the cartridge before floppy and tape and boots a
// small stub from it, which copies the program and leaves the machine as the
// IPL's tape boot does; the tape is then left just after that program, so a
// loader reads the rest of the tape as usual.
//
// Format (X1 IPL 0x0564-0x0641; the Turbo IPL is identical):
//   bit    a rising edge, then the level DELAY later (1 = still high), with
//          DELAY = 175 us of samples; the next edge is searched from there.
//   block  N zeros, N ones (N = 40 header, 20 program), one edge, bits until
//          a 1, then bytes of 8 bits MSB first each followed by one edge, then
//          a 16-bit count of the data 1 bits (high byte first).
//   header 32 bytes: +00 attribute (01 = machine code), +12 size, +14 load,
//          +16 exec. As a ROM the IPL takes the program's ROM address from
//          +1D..+1F (D:E:L = 1F:1E:1D).
// Why a stub: loaders may inspect the IPL. Zero Fighter's reads the return
// address at FFFE (0083 after a tape boot) and the CALLs before it to find
// the IPL's tape routines; after a ROM boot FFFE holds 00BE. ROM layout:
//   000000 stub header (the tape's name, 46 bytes to FFA0, exec FFA0)
//   000020 stub: IPL ROM on (OUT 1Dxx), the IPL's ROM copy routine 0146
//          reads 000100 (tape header) to FF00 and 000120 (program) to its
//          load address, then FFFE = 0083, SP = 0 and JP 0083: the IPL's own
//          tape-boot ending (trampoline, exec from FF16). FF90-FFEF is unused
//          by the X1 and Turbo IPLs; their boot paths 0083-00BE are the same.
//          10 of the MAME list's 124 machine-code tapes load above FFA0 and
//          are not quick-started (all have more data after the first block).
// 175 us decodes every bootable machine-code TAP of the MAME 0.289 list (124
// of 163; the rest are BASIC or data tapes) at 8-48 kHz.
//
// Sequence after a mount or OSD rewind (enable on):
//   1. Check: decode the header and the program and compare both counts. The
//      deck does not see the tape meanwhile, and a CPU read of the port waits.
//   2. Pass: no machine-code program (BASIC, data, no sync within 30 s of
//      tape, bad count, ends above FFA0): the tape is presented normally
//      and the port reads FF.
//   3. Boot: rewind, decode again and hand each program byte to the CPU as the
//      IPL reads it. If the IPL had not read the port during the check (a
//      tape mounted after the IPL looked), request a machine reset.
//   4. Done: the deck gets the tape positioned after the program, in STOP (the
//      IPL's tape routine stops the deck after a program, 0x057A).
// A user reset (rearm) repeats step 3 while the tape stays eligible. Mounting
// a disk in drive A or ejecting the tape makes it ineligible (the newest
// medium boots).
`timescale 1ns/1ps
module x1_tape_quickload (
    input  logic        clk,
    input  logic        reset,         // board reset
    input  logic        enable,        // OSD quick start
    input  logic        tape_insert,   // pulse: non-empty TAP mounted, or OSD rewind
    input  logic        disarm,        // pulse: drive A mounted, or tape ejected
    input  logic        rearm,         // level: user machine reset
    // x1_tap_sd_stream
    output logic        stream_rewind, // pulse
    input  logic        stream_mount, stream_present, stream_empty,
    input  logic        stream_valid, stream_level, stream_last, stream_rejected,
    output logic        stream_ready,
    input  logic [17:0] stream_hz,
    // x1_cassette_transport
    input  logic        deck_ready,
    output logic        deck_mount, deck_present, deck_empty,
    // machine CART_PORT
    input  logic [23:0] cart_addr,
    input  logic        cart_read,
    output logic  [7:0] cart_data,
    output logic        cart_ready,
    output logic        reset_request,
    output logic        busy           // checking or booting
);
    typedef enum logic [2:0] {OFF, LOAD, CHECK, RELOAD, BOOT, DONE} state_t;
    state_t state;
    // Decoder position: sync zeros/ones, the edge after sync, the start bit,
    // data bits, the separator edge after each byte.
    typedef enum logic [2:0] {P_ZERO, P_ONE, P_EDGE, P_START, P_DATA, P_SEP} proto_t;
    proto_t proto;

    logic        eligible, from_mount, port_seen;
    logic        hdr_block;          // decoding the header block (else program)
    logic  [7:0] hdr [0:31];
    logic [15:0] size;
    logic [15:0] index;              // byte in block, then the two count bytes
    logic [15:0] ones;
    logic  [7:0] sum_high, shifter;
    logic  [2:0] bitn;
    logic  [5:0] run;                // sync run length
    logic  [5:0] delay, countdown;   // DELAY in samples; samples left to the bit
    logic        in_delay, prev;
    logic [23:0] search, search_limit;
    logic  [7:0] out_byte;
    logic        out_full;           // program byte decoded, not yet read
    logic        taking;             // the current CPU read was answered with it
    logic [15:0] served;             // program bytes read by the CPU
    logic [16:0] reset_count;
    logic        old_rearm;

    // round(hz * 175 us) = (hz * 1468 + 2^22) >> 23: 1 at 8 kHz, 34 at 192 kHz.
    wire [28:0] delay_product = 29'(stream_hz) * 29'd1468 + 29'h0040_0000;
    wire [5:0]  delay_calc = delay_product[28:23] == 0 ? 6'd1 : delay_product[28:23];
    wire [23:0] limit_calc = 24'({stream_hz, 5'd0}) - 24'({stream_hz, 1'd0});   // 30 s

    wire owning = state == LOAD || state == CHECK || state == RELOAD || state == BOOT;
    wire step = (state == CHECK || (state == BOOT && !out_full)) && stream_valid;
    wire edge_now = stream_level && !prev;
    wire [15:0] block_bytes = hdr_block ? 16'd32 : size;
    wire data_byte = index < block_bytes;
    wire last_byte = index == block_bytes + 16'd1;
    wire [23:0] program_addr = 24'h120 + 24'(served);

    localparam int STUB_LEN = 46;
    // Programs must end at or below FFA0. Above it are the stub and the IPL's
    // stack; programs that load there (3D Bomberman, FFDE-00D5) overwrite the
    // stack of the IPL's tape routine to start themselves, which the ROM
    // routine's different stack does not reproduce: play those normally.
    wire [16:0] load_end = 17'({hdr[21], hdr[20]}) + 17'({hdr[19], hdr[18]});
    wire over_stub = load_end > 17'h0ffa0;
    function automatic logic [7:0] stub(input logic [5:0] i);
        case (i)
            0: stub = 8'h01;  1: stub = 8'h00;  2: stub = 8'h1d;  // ld bc,1D00
            3: stub = 8'hed;  4: stub = 8'h79;                    // out (c),a: IPL ROM on
            5: stub = 8'hd9;                                      // exx
            6: stub = 8'h01;  7: stub = 8'h00;  8: stub = 8'h0e;  // ld bc,0E00
            9: stub = 8'h11; 10: stub = 8'h01; 11: stub = 8'h00;  // ld de,0001
           12: stub = 8'h2e; 13: stub = 8'h00;                    // ld l,00: ROM 000100
           14: stub = 8'hd9;                                      // exx
           15: stub = 8'h21; 16: stub = 8'h00; 17: stub = 8'hff;  // ld hl,FF00
           18: stub = 8'h01; 19: stub = 8'h20; 20: stub = 8'h00;  // ld bc,0020
           21: stub = 8'hcd; 22: stub = 8'h46; 23: stub = 8'h01;  // call 0146: header
           24: stub = 8'h2a; 25: stub = 8'h14; 26: stub = 8'hff;  // ld hl,(FF14)
           27: stub = 8'hed; 28: stub = 8'h4b; 29: stub = 8'h12; 30: stub = 8'hff; // ld bc,(FF12)
           31: stub = 8'hcd; 32: stub = 8'h46; 33: stub = 8'h01;  // call 0146: program
           34: stub = 8'h21; 35: stub = 8'h83; 36: stub = 8'h00;  // ld hl,0083
           37: stub = 8'h22; 38: stub = 8'hfe; 39: stub = 8'hff;  // ld (FFFE),hl
           40: stub = 8'h31; 41: stub = 8'h00; 42: stub = 8'h00;  // ld sp,0000
           43: stub = 8'hc3; 44: stub = 8'h83; 45: stub = 8'h00;  // jp 0083
           default: stub = 8'hff;
        endcase
    endfunction

    assign stream_ready = owning ? step : deck_ready;
    assign busy = owning;
    assign reset_request = reset_count != 0;
    // The deck sees ejects at once and mounts only while the tape is not owned;
    // after a boot it gets the tape at the current position.
    assign deck_mount = state == DONE || (stream_mount && (!owning || !stream_present));
    assign deck_present = state == DONE || stream_present;
    assign deck_empty = state != DONE && stream_empty;

    task automatic start_block(input logic header);
        hdr_block <= header;
        proto <= P_ZERO; run <= 0; index <= 0; ones <= 0; bitn <= 0; search <= 0;
    endtask

    always_ff @(posedge clk) begin
        stream_rewind <= 0;
        old_rearm <= rearm;
        if (reset_count != 0) reset_count <= reset_count - 17'd1;
        if (reset) begin
            state <= OFF; eligible <= 0; from_mount <= 0; port_seen <= 0;
            out_full <= 0; taking <= 0; served <= 0; reset_count <= 0;
            in_delay <= 0; prev <= 0; hdr_block <= 1; proto <= P_ZERO; size <= 0; index <= 0;
        end else begin
            if (cart_read && (state == LOAD || state == CHECK)) port_seen <= 1;
            // A program byte is taken when the CPU read that returned it ends.
            if (state == BOOT && cart_read && out_full && cart_addr == program_addr) taking <= 1;
            if (taking && !cart_read) begin
                taking <= 0; out_full <= 0; served <= served + 16'd1;
            end

            if (tape_insert) begin
                eligible <= 0; out_full <= 0; taking <= 0; served <= 0;
                state <= enable ? LOAD : OFF;
                from_mount <= 1; port_seen <= 0;
            end else if (disarm) begin
                eligible <= 0;
                if (owning) stream_rewind <= 1;
                state <= OFF;
            end else if (rearm && !old_rearm && eligible && enable) begin
                state <= RELOAD; from_mount <= 0; out_full <= 0; taking <= 0; served <= 0;
                stream_rewind <= 1;
            end else if (owning && stream_rejected) begin
                eligible <= 0; state <= OFF;
            end else case (state)
                LOAD, RELOAD: if (stream_valid && !stream_rewind && !stream_mount) begin
                    // The stream holds the first sample: decode from here.
                    delay <= delay_calc;
                    search_limit <= limit_calc;
                    in_delay <= 0; prev <= 0;
                    start_block(1);
                    state <= state == LOAD ? CHECK : BOOT;
                end
                CHECK, BOOT: if (step) begin
                    prev <= stream_level;
                    if (state == CHECK && (proto == P_ZERO || proto == P_ONE)) search <= search + 24'd1;
                    if (stream_last || (state == CHECK && search == search_limit)) begin
                        // No complete machine-code program: play the tape normally.
                        eligible <= 0; state <= OFF; stream_rewind <= 1;
                    end else if (in_delay) begin
                        if (countdown == 6'd1) begin
                            in_delay <= 0;
                            // This sample is the bit.
                            case (proto)
                                P_ZERO:
                                    if (stream_level) run <= 0;
                                    else if (run + 6'd1 == (hdr_block ? 6'd40 : 6'd20)) begin
                                        run <= 0; proto <= P_ONE;
                                    end else run <= run + 6'd1;
                                P_ONE:
                                    if (!stream_level) begin run <= 0; proto <= P_ZERO; end
                                    else if (run + 6'd1 == (hdr_block ? 6'd40 : 6'd20)) begin
                                        run <= 0; proto <= P_EDGE;
                                    end else run <= run + 6'd1;
                                P_START: if (stream_level) begin proto <= P_DATA; bitn <= 0; end
                                P_DATA: begin
                                    shifter <= {shifter[6:0], stream_level};
                                    if (data_byte) ones <= ones + 16'(stream_level);
                                    bitn <= bitn + 3'd1;
                                    if (bitn == 3'd7) proto <= P_SEP;
                                end
                                default: ;
                            endcase
                        end else countdown <= countdown - 6'd1;
                    end else if (edge_now) begin
                        if (proto == P_EDGE) proto <= P_START;
                        else if (proto == P_SEP) begin
                            // Separator edge: the byte in shifter is complete.
                            if (data_byte) begin
                                if (hdr_block) hdr[index[4:0]] <= shifter;
                                else if (state == BOOT) begin out_byte <= shifter; out_full <= 1; end
                            end
                            if (index == block_bytes) sum_high <= shifter;
                            if (!last_byte) begin
                                index <= index + 16'd1; proto <= P_DATA; bitn <= 0;
                            end else if ({sum_high, shifter} != ones ||
                                         (hdr_block && (hdr[0] != 8'h01 || {hdr[19], hdr[18]} == 0 || over_stub))) begin
                                eligible <= 0; state <= OFF; stream_rewind <= 1;
                            end else if (hdr_block) begin
                                size <= {hdr[19], hdr[18]};
                                start_block(0);
                            end else if (state == CHECK) begin
                                // Checked: boot it from the beginning of the tape.
                                eligible <= 1; state <= RELOAD; stream_rewind <= 1;
                                if (from_mount && !port_seen) reset_count <= 17'h1ffff;
                            end else state <= DONE;
                        end else begin
                            in_delay <= 1; countdown <= delay;
                        end
                    end
                end
                DONE: state <= OFF;
                default: ;
            endcase
        end
    end

    // Port: the stub, the checked header, then the program as it decodes; FF
    // without an eligible tape. Reads wait while the tape is being checked.
    always_comb begin
        cart_ready = 1; cart_data = 8'hff;
        if (state == LOAD || state == CHECK) cart_ready = 0;
        else if (state == RELOAD || state == BOOT) begin
            if (cart_addr < 24'h20)
                case (cart_addr[4:0])
                    5'h12: cart_data = 8'(STUB_LEN);
                    5'h13, 5'h1e, 5'h1f: cart_data = 8'h00;
                    5'h14, 5'h16: cart_data = 8'ha0;
                    5'h15, 5'h17: cart_data = 8'hff;
                    5'h1d: cart_data = 8'h20;
                    default: cart_data = hdr[cart_addr[4:0]];   // attribute 01, name
                endcase
            else if (cart_addr < 24'h20 + 24'(STUB_LEN))
                cart_data = stub(6'(cart_addr - 24'h20));
            else if (cart_addr[23:5] == 19'h8)                   // 000100-00011F
                cart_data = hdr[cart_addr[4:0]];
            else if (cart_addr == program_addr) begin
                cart_ready = out_full; cart_data = out_byte;
            end
        end
    end
endmodule
