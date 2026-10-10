// SPDX-License-Identifier: GPL-2.0-only
`timescale 1ps/1ps
module z_adc_pinmap_tb;
    bit source_connected=0,sample_valid=0;
    bit [5:0] red_code=0,green_code=0,blue_code=0;
    wire pixel_valid;
    wire [11:0] rgb12;
    bit negative_swap=0,negative_low=0,negative_valid=0;
    wire [5:0] mapped_red=negative_swap ? blue_code : red_code;
    wire [5:0] mapped_blue=negative_swap ? red_code : blue_code;
    x1_z_adc_pinmap dut(
        .source_connected(source_connected),
        .sample_valid(negative_valid ? 1'b1 : sample_valid),
        .red_code(negative_low ? {mapped_red[3:0],2'b00} : mapped_red),
        .green_code(negative_low ? {green_code[3:0],2'b00} : green_code),
        .blue_code(negative_low ? {mapped_blue[3:0],2'b00} : mapped_blue),
        .pixel_valid(pixel_valid),.rgb12(rgb12));
    integer checks=0;
    initial begin
        negative_swap=$test$plusargs("NEGATIVE_SWAP");
        negative_low=$test$plusargs("NEGATIVE_LOW");
        negative_valid=$test$plusargs("NEGATIVE_VALID");
        for(integer connected=0;connected<2;connected++)
        for(integer valid=0;valid<2;valid++)
        for(integer r=0;r<64;r++)
        for(integer g=0;g<64;g++)
        for(integer b=0;b<64;b++) begin
            integer expected;
            bit present;
            source_connected=1'(connected);sample_valid=1'(valid);
            red_code=6'(r);green_code=6'(g);blue_code=6'(b);
            present=connected!=0 && valid!=0;
            // Arithmetic physical-byte significance, not RTL slice copying.
            expected=present ? (r/4)*256+(g/4)*16+b/4 : 0;
            #1;
            assert(pixel_valid==present) else $fatal(1,"ADC sample validity ignored");
            assert(rgb12==12'(expected)) else $fatal(1,
                "ADC pin mapping r=%0d g=%0d b=%0d got=%h expected=%h",r,g,b,rgb12,expected);
            checks++;
        end
        assert(checks==1048576) else $fatal(1,"missing ADC input/validity cases");
        $display("PASS: 1048576 ADC pin/code/absence cases, all discarded-low-bit aliases; not analog sampling or capture");
        $finish;
    end
endmodule
