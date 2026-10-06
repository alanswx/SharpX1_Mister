// SPDX-License-Identifier: GPL-2.0-only
// Original exhaustive electrical-address fixture; no font/firmware bytes.
`timescale 1ns/1ps
module kanji_address_tb;
    logic level1_enable;
    logic [7:0] dkan,dcha;
    logic [3:0] raster;
    wire [14:0] rom_address;
    wire [3:0] rom_oe_n;
    wire [16:0] byte_address;
    bit visited [0:131071];
    integer count=0,physical,chip,local_address;
    x1_kanji_address dut(.*);
    initial begin
        for(integer index=0;index<131072;index++) visited[index]=0;
        // Software's bank/character/half/row are tested via integer formulas,
        // independent of the RTL's concatenations. Every physical byte occurs.
        for(integer half=0;half<2;half++)
            for(integer bank=0;bank<16;bank++)
                for(integer character=0;character<256;character++)
                    for(integer row=0;row<16;row++) begin
                        dkan=8'(bank+half*64);
                        dcha=8'(character);raster=4'(row);level1_enable=1;#1;
                        chip=half*2+bank/8;
                        local_address=(bank%8)*4096+character*16+row;
                        physical=chip*32768+local_address;
                        assert(rom_address==15'(local_address) && byte_address==17'(physical) &&
                               rom_oe_n==~(4'b0001 << chip)) else $fatal(1,"ROM pin address/selection");
                        assert(!visited[physical]) else $fatal(1,"Kanji address alias");
                        visited[physical]=1;count++;
                        // DKAN4/5/7 are outside this address decoder. Selection
                        // policy/second-level/underline are caller contracts.
                        dkan=dkan ^ 8'hb0;#1;
                        assert(byte_address==17'(physical) && rom_address==15'(local_address) &&
                               rom_oe_n==~(4'b0001 << chip)) else $fatal(1,"unmapped attribute changed address");
                        level1_enable=0;#1;
                        assert(rom_oe_n==4'hf && byte_address==17'(physical))
                            else $fatal(1,"disabled ROM drove data select");
                    end
        assert(count==131072) else $fatal(1,"incomplete physical ROM coverage");
        for(integer index=0;index<131072;index++)
            assert(visited[index]) else $fatal(1,"unvisited physical ROM address %0d",index);
        $display("PASS first-level Kanji physical decoder: 131072 unique bytes/all banks, glyphs, halves, rows; ignored attribute pins and inactive chip selection");
        $finish;
    end
endmodule
