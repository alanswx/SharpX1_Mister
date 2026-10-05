// SPDX-License-Identifier: GPL-2.0-only
// Original nominal Turbo X3 divider/enable model. No generated fabric clocks.
// X3=42.954540 MHz: half-dot ticks X3 or 2*X3/3; dot rates X3/2 or X3/3.
// Divider phase restarts on a sampled mode/width change, CRTC state does not.
// Exact schematic live-switch/edge equivalence remains a hardware audit gate.
module x1_video_timing (
    input clk, reset, high_scan, width40,
    output step,
    output [4:0] phase
);
    reg [1:0] low_phase;
    reg [3:0] divider;
    reg prescale, old_high, old_width;
    wire changing = high_scan != old_high || width40 != old_width;
    assign step = !reset && !changing && (high_scan || low_phase != 0);
    assign phase = {divider,prescale};
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            low_phase <= 0; divider <= 0; prescale <= 0;
            old_high <= 0; old_width <= 0;
        end else begin
            old_high <= high_scan; old_width <= width40;
            if (changing) begin
                low_phase <= 0; divider <= 0; prescale <= 0;
            end else begin
                low_phase <= low_phase == 2 ? 0 : low_phase + 1'b1;
                if (step) begin
                    prescale <= !prescale && width40;
                    if (!prescale) divider <= divider + 1'b1;
                end
            end
        end
    end
endmodule
