// SPDX-License-Identifier: GPL-2.0-only
// Original board-only TAP producer for x1_cassette_transport. It reads a
// MiSTer-mounted .TAP image through the hps_io SD block interface and holds
// one MSB-first waveform sample at a time for the transport's valid/ready
// handshake. Format layout reference: MAME src/lib/formats/x1_tap.cpp and
// CSP src/vm/datarec.cpp (no code copied); admission mirrors
// the simulator TAP parser (x1_tap_image.h).
//
// Accepted images (anything else mounts as "no tape"):
//   old header: u32 rate, payload at byte 4, every byte is samples;
//   new header: "TAPE", write-protect flags only bit 4, format flags == 1
//   (constant-rate sampling), u32 rate, u32 bit count with the payload
//   at byte 40 exactly ceil(bits/8) long.
// The rate must lie in MIN_HZ..MAX_HZ and is reported on sample_hz for a
// transport built with RUNTIME_RATE (MAME plays only 8000 Hz; CSP any rate).
// The stored tape position is ignored: every mount starts rewound at sample 0.
// Mounting presents an eject first, then a STOP-state mount once the first
// sample is held, so the transport never sees PLAY without prebuffered data.
// Two 512-byte sector slots keep the current and next sector resident; at
// 8 kHz one sector is 0.512 s of tape.
`timescale 1ns/1ps
module x1_tap_sd_stream #(
    parameter int unsigned MIN_HZ = 8000,
    parameter int unsigned MAX_HZ = 8000
) (
    input  logic        clk,
    input  logic        reset,
    // hps_io image interface for this slot (all synchronous to clk)
    input  logic        img_mounted,
    input  logic        rewind,      // remount the current image at sample 0
    input  logic [63:0] img_size,
    output logic [31:0] sd_lba,
    output logic        sd_rd,
    input  logic        sd_ack,
    input  logic  [8:0] sd_buff_addr,
    input  logic  [7:0] sd_buff_dout,
    input  logic        sd_buff_wr,
    // x1_cassette_transport producer side
    output logic        tape_mount,
    output logic        tape_present,
    output logic        tape_empty,
    output logic        sample_valid,
    output logic        sample_level,
    output logic        sample_last,
    input  logic        sample_ready,
    output logic [17:0] sample_hz,
    // status
    output logic        loaded,
    output logic        rejected
);
    localparam logic [31:0] MAX_BYTES = 32'h1000_0000;

    typedef enum logic [2:0] {IDLE, HEADER, PARSE, PRIME, RUN} state_t;
    state_t state;

    logic [31:0] size;          // image bytes (bounded below)
    logic [31:0] data_off;      // payload byte offset (4 or 40)
    logic [31:0] total_bits;
    logic [31:0] cur_bit;
    logic [7:0]  hdr[0:39];

    // Sector slots: slot = sector[0].
    logic [22:0] slot_tag[0:1];
    logic [1:0]  slot_ok;
    logic        fetching, fetch_slot, fetch_abort, fetch_header;
    logic        ack_seen;

    logic [7:0] buffer[0:1023];
    logic [9:0] rd_addr;
    logic [7:0] rd_q;
    logic [1:0] rd_wait;
    logic [7:0] byte_reg;
    logic       byte_ok;

    wire [31:0] byte_addr = data_off + {3'd0, cur_bit[31:3]};
    wire [22:0] need = byte_addr[31:9];
    wire [22:0] next_sector = need + 23'd1;
    wire [22:0] last_sector = 23'((size - 32'd1) >> 9);
    wire need_ok = slot_ok[need[0]] && slot_tag[need[0]] == need;
    wire next_ok = slot_ok[next_sector[0]] && slot_tag[next_sector[0]] == next_sector;
    wire bits_left = cur_bit < total_bits;

    function automatic logic [31:0] le32(input logic [7:0] b0, b1, b2, b3);
        return {b3, b2, b1, b0};
    endfunction

    wire        new_header = hdr[0] == "T" && hdr[1] == "A" && hdr[2] == "P" && hdr[3] == "E";
    wire [31:0] old_rate = le32(hdr[0], hdr[1], hdr[2], hdr[3]);
    wire [31:0] new_rate = le32(hdr[28], hdr[29], hdr[30], hdr[31]);
    wire [31:0] new_bits = le32(hdr[32], hdr[33], hdr[34], hdr[35]);
    wire [31:0] new_bytes = {3'd0, new_bits[31:3]} + {31'd0, |new_bits[2:0]};
    function automatic logic rate_ok(input logic [31:0] hz);
        return hz >= MIN_HZ && hz <= MAX_HZ;
    endfunction
    wire new_ok = size >= 32'd40 && (hdr[26] & 8'hEF) == 0 && hdr[27] == 8'd1 &&
        rate_ok(new_rate) && new_bytes == size - 32'd40;
    wire old_ok = !new_header && size >= 32'd4 && rate_ok(old_rate);

    assign sample_valid = state == RUN && byte_ok && bits_left;
    assign sample_level = byte_reg[3'd7 - cur_bit[2:0]];
    assign sample_last = cur_bit + 32'd1 == total_bits;
    assign loaded = state == RUN;

    always_ff @(posedge clk) begin
        if (sd_ack && sd_buff_wr) buffer[{fetch_slot, sd_buff_addr}] <= sd_buff_dout;
        rd_q <= buffer[rd_addr];
    end

    always_ff @(posedge clk) begin
        tape_mount <= 0;
        if (reset) begin
            state <= IDLE;
            sd_rd <= 0; sd_lba <= 0;
            fetching <= 0; fetch_abort <= 0; fetch_header <= 0; fetch_slot <= 0;
            ack_seen <= 0;
            slot_ok <= 0;
            byte_ok <= 0; rd_wait <= 0;
            cur_bit <= 0; total_bits <= 0; data_off <= 0; size <= 0; sample_hz <= 18'd8000;
            tape_present <= 0; tape_empty <= 0; rejected <= 0;
        end else begin
            // Shared SD transfer bookkeeping: drop the request once acknowledged,
            // finish when the acknowledge falls.
            if (fetching) begin
                if (sd_ack) begin
                    sd_rd <= 0;
                    ack_seen <= 1;
                    if (fetch_header && sd_buff_wr && sd_buff_addr < 9'd40)
                        hdr[sd_buff_addr[5:0]] <= sd_buff_dout;
                end else if (ack_seen) begin
                    fetching <= 0; ack_seen <= 0;
                    if (!fetch_abort) begin
                        slot_ok[fetch_slot] <= 1;
                        if (fetch_header) state <= PARSE;
                    end
                    fetch_abort <= 0;
                end
            end

            if (img_mounted || (rewind && size != 0)) begin
                // Eject the previous tape immediately; any in-flight transfer
                // completes into an invalid slot.
                tape_mount <= 1; tape_present <= 0; tape_empty <= 0;
                rejected <= 0;
                slot_ok <= 0; byte_ok <= 0; rd_wait <= 0; cur_bit <= 0;
                if (fetching) fetch_abort <= 1;
                if (img_mounted) begin
                    size <= img_size > {32'd0, MAX_BYTES} ? MAX_BYTES : img_size[31:0];
                    state <= img_size == 0 ? IDLE : HEADER;
                    if (img_size > {32'd0, MAX_BYTES}) begin
                        state <= IDLE; rejected <= 1;
                    end
                end else state <= HEADER;
            end else case (state)
                IDLE: ;
                HEADER: if (!fetching) begin
                    sd_lba <= 0; sd_rd <= 1;
                    fetching <= 1; fetch_slot <= 0; fetch_header <= 1;
                    slot_ok[0] <= 0;
                    slot_tag[0] <= 0;
                end
                PARSE: begin
                    fetch_header <= 0;
                    if (new_header ? new_ok : old_ok) begin
                        data_off <= new_header ? 32'd40 : 32'd4;
                        sample_hz <= 18'(new_header ? new_rate : old_rate);
                        total_bits <= new_header ? new_bits : (size - 32'd4) << 3;
                        cur_bit <= 0;
                        state <= PRIME;
                    end else begin
                        rejected <= 1;
                        state <= IDLE;
                    end
                end
                PRIME, RUN: begin
                    if (state == PRIME && (!bits_left || byte_ok)) begin
                        // Media is ready: mount in STOP with the first sample held.
                        tape_mount <= 1; tape_present <= 1; tape_empty <= !bits_left;
                        state <= RUN;
                    end
                    if (state == RUN && sample_valid && sample_ready) begin
                        cur_bit <= cur_bit + 32'd1;
                        if (cur_bit[2:0] == 3'd7) byte_ok <= 0;
                    end
                    // Keep the current and next sector resident.
                    if (!fetching && bits_left) begin
                        if (!need_ok) begin
                            sd_lba <= {9'd0, need}; sd_rd <= 1; fetching <= 1;
                            fetch_slot <= need[0]; slot_ok[need[0]] <= 0;
                            slot_tag[need[0]] <= need;
                        end else if (next_sector <= last_sector && !next_ok) begin
                            sd_lba <= {9'd0, next_sector}; sd_rd <= 1; fetching <= 1;
                            fetch_slot <= next_sector[0]; slot_ok[next_sector[0]] <= 0;
                            slot_tag[next_sector[0]] <= next_sector;
                        end
                    end
                    // Load the byte under the cursor (two-cycle RAM read).
                    if (!byte_ok && bits_left && need_ok &&
                        !(state == RUN && sample_valid && sample_ready)) begin
                        if (rd_wait == 0) begin
                            rd_addr <= {need[0], byte_addr[8:0]};
                            rd_wait <= 1;
                        end else if (rd_wait == 1) rd_wait <= 2;
                        else begin
                            byte_reg <= rd_q; byte_ok <= 1; rd_wait <= 0;
                        end
                    end else rd_wait <= 0;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
