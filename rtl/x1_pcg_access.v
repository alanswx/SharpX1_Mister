// Original base-X1 CG/PCG clock-domain transaction adapter.
// Address is the renderer's character/row, not the low I/O address byte.
// Bundled request data stays stable until the synchronized acknowledgement;
// response stays stable until the next request. This is CDC latency WAIT,
// not the optional inherited scanline AUTO_WAIT trap. Turbo high-speed mode
// uses a frozen CPU-selected address and provisional asserted-HSYNC window.
module x1_pcg_access #(parameter SEPARATE_VIDEO_RESET = 0, KANJI_SUPPORT = 0) (
    input reset, cpu_clk, video_clk,
    input cpu_select, cpu_write,
    input [1:0] cpu_plane,
    input [7:0] cpu_data,
    output wait_n,
    output reg [7:0] cpu_q,
    input [10:0] beam_addr,
    output reg [10:0] access_addr,
    output [7:0] access_data,
    output [2:0] access_write,
    input [7:0] rom_q, blue_q, red_q, green_q,
    input high_speed,
    input [10:0] selected_addr,
    input selected_font16, selected_unsupported,
    input [11:0] selected_font_addr,
    input video_window,
    output reg [11:0] font_cpu_addr,
    input [7:0] font_cpu_q,
    output reg cpu_read_hold,
    input video_reset,
    input selected_kanji,
    input [16:0] selected_kanji_addr,
    input kanji_available, kanji_cpu_valid,
    input [7:0] kanji_cpu_q,
    output reg [16:0] kanji_cpu_addr,
    output kanji_cpu_read
);
    // With separate reset, the caller must asynchronously assert video_reset
    // with CPU reset and release it only on VID (x1_reset_release in X3).
    // RAM write permission belongs to that local reset, not raw SYS reset.
    wire video_reset_active = SEPARATE_VIDEO_RESET ? video_reset : reset;
    reg request, busy, done, ack;
    reg [1:0] plane;
    reg write_request;
    reg high_speed_request, font16_request, unsupported_request;
    reg kanji_request, kanji_absent;
    reg [10:0] frozen_addr;
    reg [7:0] payload, response;
    (* async_reg = "true" *) reg ack_meta, ack_sync;
    (* async_reg = "true" *) reg request_meta, request_sync;
    reg seen;
    reg [1:0] stage;
    assign wait_n = !cpu_select || done;
    assign access_data = payload;
    assign kanji_cpu_read = !reset && busy && kanji_request && !kanji_absent && !write_request;
    // One video edge writes exactly one byte. ANK ROM writes are ignored.
    assign access_write = !video_reset_active && stage == 1 && write_request && !unsupported_request
                        ? (plane == 1 ? 3'b001 : plane == 2 ? 3'b010
                           : plane == 3 ? 3'b100 : 3'b000) : 3'b000;

    always @(posedge cpu_clk or posedge reset) begin
        if (reset) begin
            request <= 0; busy <= 0; done <= 0;
            ack_meta <= 0; ack_sync <= 0; cpu_q <= 8'hff;
            plane <= 0; write_request <= 0; payload <= 0;
            high_speed_request <= 0; font16_request <= 0;
            unsupported_request <= 0; frozen_addr <= 0; font_cpu_addr <= 0;
            cpu_read_hold <= 0;
            kanji_request <= 0; kanji_absent <= 1; kanji_cpu_addr <= 0;
        end else begin
            ack_meta <= ack;
            ack_sync <= ack_meta;
            if (!cpu_select) done <= 0;
            if (cpu_select && !busy && !done) begin
                plane <= cpu_plane;
                write_request <= cpu_write;
                payload <= cpu_data;
                high_speed_request <= high_speed;
                frozen_addr <= selected_addr;
                font16_request <= high_speed && selected_font16 && cpu_plane == 0;
                unsupported_request <= high_speed && selected_unsupported;
                font_cpu_addr <= selected_font_addr;
                kanji_request <= KANJI_SUPPORT && high_speed && selected_kanji &&
                                 cpu_plane == 0 && !selected_unsupported;
                kanji_absent <= !kanji_available;
                kanji_cpu_addr <= selected_kanji_addr;
                cpu_read_hold <= 0;
                request <= !request;
                busy <= 1;
            end
            if (busy && ack_sync == request &&
                (!kanji_request || kanji_absent || write_request || kanji_cpu_valid)) begin
                // Font CPU port has been held at its frozen address since
                // acceptance. Window/ACK roundtrip exceeds its registered read
                // latency; no sys-clock font data crosses into a video latch.
                // Kanji data stays entirely in the CPU domain. A loaded
                // backend must deliver valid data before WAIT can release;
                // absent ROM terminates with FF rather than a false glyph.
                cpu_q <= unsupported_request ? 8'hff :
                         kanji_request ? (kanji_absent || write_request ? 8'hff : kanji_cpu_q) :
                         font16_request ? font_cpu_q : response;
                cpu_read_hold <= high_speed_request && !write_request;
                busy <= 0;
                done <= cpu_select;
            end
        end
    end

    always @(posedge video_clk or posedge video_reset_active) begin
        if (video_reset_active) begin
            request_meta <= 0; request_sync <= 0; seen <= 0; ack <= 0;
            stage <= 0; access_addr <= 0; response <= 8'hff;
        end else begin
            request_meta <= request;
            request_sync <= request_meta;
            if (stage == 0 && request_sync != seen &&
                (!high_speed_request || video_window)) begin
                seen <= request_sync;
                access_addr <= high_speed_request ? frozen_addr : beam_addr;
                stage <= 1;
            end else if (stage == 1) begin
                // Registered address is sampled by RAM/font on this edge.
                stage <= 2;
            end else if (stage == 2) begin
                response <= plane == 0 ? rom_q : plane == 1 ? blue_q
                          : plane == 2 ? red_q : green_q;
                ack <= seen;
                stage <= 0;
            end
        end
    end
endmodule
