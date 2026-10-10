// SPDX-License-Identifier: GPL-2.0-only
// Original exhaustive CZ-880 pin-address oracle; no native font bytes.
`timescale 1ns/1ps
module z_kanji_address_tb;
    logic level1_enable, level2_enable, half;
    logic [3:0] bank, raster;
    logic [7:0] character;
    wire [16:0] rom_address;
    wire [1:0] rom_oe_n;
    wire [17:0] byte_address;
    wire address_valid;
    wire [16:0] faulty_address;
    integer fault=0, count=0, expected_local, expected_physical;
    bit visited [0:262143];
    x1_z_kanji_address dut(.*);
    // Matched negative: a tempting earlier-model half-major layout.
    assign faulty_address={half,bank,character,raster};
    initial begin
        if($value$plusargs("FAULT=%d",fault)) begin end
        for(integer i=0;i<262144;i++) visited[i]=0;
        for(integer level=0;level<2;level++)
            for(integer b=0;b<16;b++)
                for(integer c=0;c<256;c++)
                    for(integer r=0;r<16;r++)
                        for(integer h=0;h<2;h++) begin
                            bank=4'(b);character=8'(c);raster=4'(r);half=1'(h);
                            level1_enable=(level==0);level2_enable=(level==1);#1;
                            expected_local=b*8192+c*32+r*2+h;
                            expected_physical=level*131072+expected_local;
                            assert((fault==1 ? faulty_address : rom_address)==17'(expected_local) &&
                                   byte_address==18'(expected_physical) && address_valid &&
                                   rom_oe_n==(level==0 ? 2'b10 : 2'b01))
                                else $fatal(1,"Z ROM pin address/selection");
                            assert(!visited[expected_physical]) else $fatal(1,"Z ROM address alias");
                            visited[expected_physical]=1;count++;
                            level1_enable=0;level2_enable=0;#1;
                            assert(rom_oe_n==2'b11 && !address_valid && rom_address==17'(expected_local))
                                else $fatal(1,"Z disabled ROM selection");
                            level1_enable=1;level2_enable=1;#1;
                            assert(rom_oe_n==2'b00 && !address_valid)
                                else $fatal(1,"Z dual-selected ROM incorrectly valid");
                        end
        assert(count==262144) else $fatal(1,"Z ROM incomplete coverage");
        for(integer i=0;i<262144;i++)
            assert(visited[i]) else $fatal(1,"Z ROM byte not visited %0d",i);
        $display("PASS Z physical Kanji decoder: 262144 unique bytes, both levels/banks/glyphs/rows/halves; disabled and dual-select isolation");
        $finish;
    end
endmodule
