// SPDX-License-Identifier: GPL-2.0-only
// Original Techknow Appendix A printed-280 ordering decoder.
// Visibility is supplied by the caller: no palette-RGB, zero-index,
// glyph/blackclip or native transparency policy is inferred here.
module x1_z_layer_order (
    input wire enabled, two_screen_mode, selected_screen,
    input wire [7:0] priority_control,
    input wire text_visible, screen0_visible, screen1_visible,
    output reg defined,
    // 0 backdrop, 1 text, 2 graphics bank 0, 3 graphics bank 1.
    output reg [1:0] source
);
    wire paired=two_screen_mode && priority_control[4];
    wire front_screen=paired ? priority_control[3] : selected_screen;
    wire front_visible=front_screen ? screen1_visible : screen0_visible;
    wire back_visible=paired && (front_screen ? screen0_visible : screen1_visible);
    wire [1:0] front_source=front_screen ? 2'd3 : 2'd2;
    wire [1:0] back_source=front_screen ? 2'd2 : 2'd3;
    // Single screen forces bit 1 effectively zero (the manual's note).
    wire [1:0] field={paired && priority_control[1],priority_control[0]};
    always @* begin
        defined=enabled;
        source=0;
        if(enabled) begin
            case(field)
                0: source=text_visible ? 2'd1 : front_visible ? front_source :
                          back_visible ? back_source : 2'd0;
                1: source=front_visible ? front_source : back_visible ? back_source :
                          text_visible ? 2'd1 : 2'd0;
                2: source=front_visible ? front_source : text_visible ? 2'd1 :
                          back_visible ? back_source : 2'd0;
                default: begin defined=0;source=0;end
            endcase
        end
    end
endmodule
