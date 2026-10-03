`timescale 1ns/1ps
module joystick_tb;
    reg [31:0] joystick;
    wire [7:0] pins_n;
    x1_joystick_map dut (.joystick(joystick), .pins_n(pins_n));
    integer bits_in, expected;
    initial begin
        // Exhaust all combinations; ignored higher bits must not affect pins.
        for (bits_in = 0; bits_in < 64; bits_in = bits_in + 1) begin
            joystick = 32'hffffffc0 | bits_in;
            expected = 255;
            if (bits_in & 1) expected = expected & ~8;
            if (bits_in & 2) expected = expected & ~4;
            if (bits_in & 4) expected = expected & ~2;
            if (bits_in & 8) expected = expected & ~1;
            if (bits_in & 16) expected = expected & ~32;
            if (bits_in & 32) expected = expected & ~64;
            #1;
            assert (pins_n == 8'(expected)) else $fatal(1, "joystick mapping %x -> %x expected %x", joystick, pins_n, expected);
        end
        $display("PASS: all 64 MiSTer joystick combinations map to X1 directions/buttons");
        $finish;
    end
endmodule
