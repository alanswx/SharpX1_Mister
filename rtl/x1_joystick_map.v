// Original board adapter. MiSTer: right,left,down,up,A,B in bits 0..5.
// X1 PSG: up,down,left,right,reserved,A,B,reserved, all active low.
// Reference: local MAME sharp/x1.cpp P1/P2; sibling FM-7 MiSTer bit order.
module x1_joystick_map (
    input [31:0] joystick,
    output [7:0] pins_n
);
    assign pins_n = ~{1'b0, joystick[5], joystick[4], 1'b0,
                     joystick[0], joystick[1], joystick[2], joystick[3]};
endmodule
