// SPDX-License-Identifier: GPL-2.0-only
// Original asset-free pin-level decoder fixture. No native ROM or firmware.
`timescale 1ns/1ps
module kanji_decode_tb;
    logic decode_enable;
    logic [7:0] attribute,dkan,dcha;
    logic [3:0] raster;
    wire [3:0] glyph_oe_n,rom_oe_n;
    wire kace_n,level1_select,level2_select;
    wire [14:0] rom_address;
    wire [16:0] byte_address;
    integer count=0,selected_count=0;
    bit visited [0:131071];
    x1_kanji_decode dut(.*);
    initial begin
        for(integer index=0;index<131072;index++) visited[index]=0;
        for(integer enable=0;enable<2;enable++)
            for(integer pcg=0;pcg<2;pcg++)
                for(integer kan=0;kan<256;kan++)
                    for(integer character=0;character<256;character++)
                        for(integer row=0;row<16;row++) begin
                            integer bank,half,physical,local_addr,source,chip;
                            bit kan_selected,first_level;
                            decode_enable=1'(enable);attribute=8'(pcg*32);
                            dkan=8'(kan);dcha=8'(character);raster=4'(row);#1;
                            // Independent integer truth table for the LS139:
                            // A=PCG, B=Kanji. Only B=1/A=0 enables /KACE.
                            source=(kan/128)*2+pcg;
                            kan_selected=enable!=0 && source==2;
                            first_level=kan_selected && (kan/16)%2==0;
                            assert(glyph_oe_n==(enable!=0 ? 4'(15-(1<<source)) : 4'hf))
                                else $fatal(1,"first LS139 truth table");
                            assert(kace_n==!kan_selected && level1_select==first_level &&
                                   level2_select==(kan_selected && !first_level))
                                else $fatal(1,"KACE/level gate");
                            bank=kan%16;half=(kan/64)%2;chip=half*2+bank/8;
                            local_addr=(bank%8)*4096+character*16+row;
                            physical=half*65536+bank*4096+character*16+row;
                            assert(rom_address==15'(local_addr) && byte_address==17'(physical))
                                else $fatal(1,"physical pins");
                            assert(rom_oe_n==(first_level ? 4'(15-(1<<chip)) : 4'hf))
                                else $fatal(1,"PCG/ANK/disabled/level2 must not select level1");
                            // Each first-level byte occurs twice: underline
                            // DKAN5 changes no chip/address or decode pin.
                            if(first_level) begin visited[physical]=1;selected_count++;end
                            count++;
                        end
        assert(count==4194304 && selected_count==262144)
            else $fatal(1,"incomplete exhaustive decode coverage");
        for(integer index=0;index<131072;index++)
            assert(visited[index]) else $fatal(1,"unvisited ROM byte %0d",index);
        // All non-PCG attribute bits are outside this decoder, including
        // color, reverse/blink and per-cell width/height.
        decode_enable=1;dkan=8'hcf;dcha=8'ha7;raster=4'hd;
        for(integer attr=0;attr<256;attr++) begin
            attribute=8'(attr);#1;
            assert(kace_n==1'((attr/32)%2) && byte_address==17'h1fa7d &&
                   rom_oe_n==((attr/32)%2==0 ? 4'b0111 : 4'b1111))
                else $fatal(1,"irrelevant attribute bit changed decode");
        end
        $display("PASS Kanji display decoder: 4194304 pin combinations, all 131072 physical bytes, PCG priority, disabled/ANK/level2 isolation, all attributes");
        $finish;
    end
endmodule
