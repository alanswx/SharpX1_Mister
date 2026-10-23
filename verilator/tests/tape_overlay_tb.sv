`timescale 1ns/1ps
// x1_tape_status + x1_tape_overlay on independent SYS/video clocks: m:ss and
// fill from a stepped cursor, toggle handoff, then pixels of a 320x200 raster.
module tape_overlay_tb;
    reg clk = 0, vclk = 0;
    always #5 clk = !clk;
    always #7 vclk = !vclk;
    reg loaded = 1, playing = 1, fast = 1, enable = 1;
    reg [31:0] position = 0, length = 32'd8000 * 75 + 32'd100;
    reg [17:0] hz = 18'd8000;
    wire [41:0] status; wire req, ack;
    x1_tape_status st(.clk(clk), .loaded(loaded), .playing(playing), .fast(fast),
        .position(position), .length(length), .hz(hz), .status(status), .req(req), .ack(ack));
    reg hblank = 1, vblank = 1;
    wire [11:0] rgb;
    x1_tape_overlay ov(.clk(vclk), .ce_pix(1'b1), .hblank(hblank), .vblank(vblank), .enable(enable),
        .status(status), .req(req), .ack(ack), .rgb_in(12'h123), .rgb_out(rgb));

    integer x, y;
    reg [11:0] text_px, box_px, outside_px;
    // One 320x200 frame (80 blank pixels per line, 20 blank lines); sample
    // three pixels while they are on the bus.
    task frame;
        for (y = 0; y < 220; y++) begin
            for (x = 0; x < 400; x++) begin
                @(negedge vclk);
                hblank = x >= 320; vblank = y >= 200;
                #1;
                if (x == 7 && y == 180) text_px = rgb;      // 'T' top bar, box at (4,178)
                if (x == 5 && y == 178) box_px = rgb;       // box margin
                if (x == 300 && y == 10) outside_px = rgb;
            end
        end
    endtask

    initial begin
        repeat (200) @(posedge clk);
        assert(st.total == 16'h0115) else $fatal(1, "total %h", st.total);
        repeat (8000 * 3 + 5) begin @(negedge clk); position = position + 1; end
        repeat (3) @(posedge clk);
        assert(st.elapsed == 16'h0003) else $fatal(1, "elapsed %h", st.elapsed);
        assert(st.fill == 7'd2) else $fatal(1, "fill %0d", st.fill);
        frame(); frame();
        assert(ov.shown == status) else $fatal(1, "handoff");
        assert(text_px == 12'hFFF && box_px == 12'h000 && outside_px == 12'h123)
            else $fatal(1, "playing pixels %h %h %h", text_px, box_px, outside_px);
        playing = 0;
        frame(); frame();
        assert(text_px == 12'h123 && box_px == 12'h123) else $fatal(1, "stopped pixels %h %h", text_px, box_px);
        playing = 1; enable = 0;
        frame(); frame();
        assert(text_px == 12'h123) else $fatal(1, "disabled pixel %h", text_px);
        @(negedge clk); position = 0;
        repeat (3) @(posedge clk);
        assert(st.elapsed == 0 && st.fill == 0) else $fatal(1, "rewind");
        $display("PASS: tape status 1:15 total, 0:03 elapsed, fill 2/64; overlay text/box/pass-through, hidden when stopped or disabled");
        $finish;
    end
endmodule
