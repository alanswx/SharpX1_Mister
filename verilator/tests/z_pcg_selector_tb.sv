// SPDX-License-Identifier: GPL-2.0-only
// Original independent highest-cell/source/address oracle. No font assets.
`timescale 1ps/1ps
module z_pcg_selector_tb;
    logic clk;
    initial clk=0;
    always #5 clk=~clk;
    logic text_write=0,attr_write=0,kan_write=0,font16_mode=0;
    logic [10:0] address=0;
    logic [7:0] data=0;
    logic [3:0] nibble=0;
    logic [1:0] plane=0;
    wire [10:0] byte_address;
    wire [11:0] font_address;
    wire [17:0] kanji_address;
    wire font16_select,unsupported,kanji_select;
    x1_z_pcg_selector dut(.*);
    bit visited[262144];
    integer checks=0;
    task automatic put(input integer kind,input integer cell_address,input integer value);
        assert(cell_address>=0 && cell_address<=2047 && value>=0 && value<=255)
            else $fatal(1,"selector fixture write bounds");
        @(negedge clk);address=11'(cell_address);data=8'(value);
        text_write=kind==0;attr_write=kind==1;kan_write=kind==2;
        @(posedge clk);#1;
        @(negedge clk);text_write=0;attr_write=0;kan_write=0;
    endtask
    task automatic check(input integer glyph,input integer attr,input integer kan);
        bit bad,ks,fs;
        integer expected_address,expected_byte,expected_font;
        bad=(((attr/32)%2)!=0)!=(plane!=0);
        ks=!bad && plane==0 && kan>=128;
        fs=!bad && plane==0 && kan<128 && font16_mode;
        expected_address=ks ? ((kan/16)%2)*131072+(kan%16)*8192+glyph*32+
            int'(nibble)*2+(kan/64)%2 : 0;
        expected_byte=(plane!=0 && ((kan/16)%2!=0 || kan>=128))
            ? (glyph/2)*16+int'(nibble) : glyph*8+int'(nibble)/2;
        expected_font=glyph*16+int'(nibble);
        #1;
        assert(unsupported==bad && kanji_select==ks && font16_select==fs &&
               int'(kanji_address)==expected_address &&
               int'(byte_address)==(bad ? 0 : expected_byte) &&
               int'(font_address)==(bad ? 0 : expected_font))
            else $fatal(1,"Z selector source/address mismatch attr=%0d kan=%0d plane=%0d",attr,kan,plane);
        checks++;
    endtask
    initial begin
        #1;
        assert(unsupported && !kanji_select && !font16_select &&
               kanji_address==0 && byte_address==0 && font_address==0)
            else $fatal(1,"uninitialized highest-cell selector");
        foreach(visited[i]) visited[i]=0;
        // Lower fallback cells can neither qualify nor replace highest cell.
        for(integer cell_index=0;cell_index<3;cell_index++) begin
            for(integer kind=0;kind<3;kind++)
                put(kind,cell_index==0 ? 1023 : cell_index==1 ? 1535 : 511,255);
            assert(unsupported && !kanji_select) else $fatal(1,"fallback qualified selector");
        end
        put(0,2047,91);
        assert(unsupported) else $fatal(1,"missing attribute/kan validity");
        put(1,2047,7);
        assert(unsupported) else $fatal(1,"missing kan validity");
        put(2,2047,128);
        plane=0;put(1,2047,7);
        for(integer level=0;level<2;level++)
          for(integer bank=0;bank<16;bank++)
            for(integer half=0;half<2;half++) begin
                put(2,2047,128+level*16+half*64+bank);
                for(integer glyph=0;glyph<256;glyph++) begin
                    put(0,2047,glyph);
                    for(integer row=0;row<16;row++) begin
                        nibble=4'(row);check(glyph,7,128+level*16+half*64+bank);
                        assert(!visited[kanji_address]) else $fatal(1,"duplicate physical byte");
                        visited[kanji_address]=1;
                    end
                end
            end
        foreach(visited[i]) assert(visited[i]) else $fatal(1,"unvisited Z byte %0d",i);
        // Every attribute/kan control byte, all planes/font modes. Independent
        // expected arithmetic checks PCG precedence and ignored control bits.
        put(0,2047,173);
        for(integer attr=0;attr<256;attr++) begin
            put(1,2047,attr);
            for(integer kan=0;kan<256;kan++) begin
                put(2,2047,kan);
                nibble=4'((attr+kan)%16);
                for(integer p=0;p<4;p++)
                  for(integer f=0;f<2;f++) begin
                    plane=2'(p);font16_mode=1'(f);check(173,attr,kan);
                  end
            end
        end
        plane=0;font16_mode=0;put(1,2047,7);put(2,2047,128);nibble=9;
        for(integer kind=0;kind<3;kind++) put(kind,1023,255);
        check(173,7,128);
        // No write strobes: address/data changes are not selector commits.
        @(negedge clk);address=2047;data=255;
        repeat(4) @(posedge clk);
        check(173,7,128);
        $display("PASS Z selector: 262144 unique bytes; 524288 source/plane/control combinations; highest-cell validity/no fallback/no unaccepted writes; checks=%0d",checks);
        $finish;
    end
endmodule
