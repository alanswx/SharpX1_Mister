// SPDX-License-Identifier: GPL-2.0-only
// Original synthetic high-speed CG selector fixture. No monitor/font bytes.
`timescale 1ns/1ps
module kanji_cg_selector_tb;
    logic clk=0;
    always #5 clk=!clk;
    logic text_write=0,attr_write=0,kan_write=0;
    logic [10:0] address=0;
    logic [7:0] data=0;
    logic [3:0] nibble=0;
    logic [1:0] plane=0;
    logic font16_mode=0;
    wire [10:0] byte_address;
    wire [11:0] font_address;
    wire font16_select,unsupported,kanji_select;
    wire [16:0] kanji_address;
    x1_pcg_selector #(.KANJI_SUPPORT(1)) dut(.*);
    wire base_unsupported,base_kanji_select;
    wire [16:0] base_kanji_address;
    x1_pcg_selector baseline(
        .clk(clk),.text_write(text_write),.attr_write(attr_write),.kan_write(kan_write),
        .address(address),.data(data),.nibble(nibble),.plane(plane),.font16_mode(font16_mode),
        .byte_address(),.font_address(),.font16_select(),.unsupported(base_unsupported),
        .kanji_select(base_kanji_select),.kanji_address(base_kanji_address)
    );
    function automatic logic [10:0] cell_address(input integer cell_index);
        return cell_index==0 ? 11'h7ff : cell_index==1 ? 11'h3ff :
               cell_index==2 ? 11'h5ff : 11'h1ff;
    endfunction
    task automatic put(input integer cell_index,input integer kind,input logic [7:0] value);
        @(negedge clk);address=cell_address(cell_index);data=value;
        text_write=kind==0;attr_write=kind==1;kan_write=kind==2;
        @(negedge clk);text_write=0;attr_write=0;kan_write=0;#1;
    endtask
    integer expected,checks=0,selected;
    initial begin
        #1;
        assert(unsupported && !kanji_select && kanji_address==0)
            else $fatal(1,"uninitialized Kanji selector");
        for(integer cell_index=0;cell_index<4;cell_index++) begin
            put(cell_index,0,8'(cell_index+1));put(cell_index,2,8'h80);
            put(cell_index,1,0);
            if(cell_index<3) assert(unsupported && !kanji_select)
                else $fatal(1,"partial candidate metadata accepted");
        end
        // Every physical byte, ignored underline bit, both font-mode values.
        for(integer half=0;half<2;half++)
        for(integer bank=0;bank<16;bank++) begin
            for(integer glyph=0;glyph<256;glyph++) begin
                put(0,0,8'(glyph));
                for(integer underline_bit=0;underline_bit<2;underline_bit++) begin
                    put(0,2,8'(128+half*64+bank+underline_bit*32));
                    for(integer row=0;row<16;row++)
                    for(integer mode=0;mode<2;mode++) begin
                        nibble=4'(row);font16_mode=1'(mode);#1;
                        expected=half*65536+bank*4096+glyph*16+row;
                        assert(!unsupported && kanji_select && !font16_select &&
                               kanji_address==17'(expected))
                            else $fatal(1,"Kanji physical address %0d",expected);
                        assert(base_unsupported && !base_kanji_select && base_kanji_address==0)
                            else $fatal(1,"default profile changed");
                        checks++;
                    end
                end
            end
        end
        // Level 2 is absent, never silently aliased to first-level storage.
        put(0,2,8'h90);#1;
        assert(unsupported && !kanji_select && kanji_address==0 && !font16_select)
            else $fatal(1,"second-level alias");
        // Existing four-cell priority/fallback is explicitly bounded, not an
        // ASIC-wide address-selection claim. PCG planes stay PCG, never ROM.
        for(integer mask=0;mask<16;mask++) begin
            for(integer cell_index=0;cell_index<4;cell_index++) begin
                put(cell_index,0,8'(cell_index*43+2));
                put(cell_index,2,8'(128+cell_index*2));
                put(cell_index,1,8'(((mask>>cell_index)&1)*32+7));
            end
            for(integer p=0;p<4;p++) begin
                plane=2'(p);nibble=7;#1;selected=0;
                for(integer cell_index=3;cell_index>=0;cell_index--)
                    if(((mask>>cell_index)&1)==int'(p!=0)) selected=cell_index;
                expected=selected*2*4096+(selected*43+2)*16+7;
                assert(!unsupported && kanji_select==(p==0) && !font16_select)
                    else $fatal(1,"ROM/PCG dispatch");
                if(p==0) assert(kanji_address==17'(expected))
                    else $fatal(1,"candidate priority/fallback");
                else assert(kanji_address==0 && byte_address==11'(((selected*43+2)&254)*8+7))
                    else $fatal(1,"Kanji leaked into PCG plane");
                checks++;
            end
        end
        // Exit to ANK clears backend selection/address, then noncandidate
        // writes cannot recreate a Kanji request or change the selected glyph.
        for(integer cell_index=0;cell_index<4;cell_index++) put(cell_index,1,0);
        put(0,2,0);put(0,0,65);plane=0;font16_mode=1;nibble=3;#1;
        assert(!unsupported && !kanji_select && kanji_address==0 && font16_select && font_address==1043)
            else $fatal(1,"ANK mode exit");
        @(negedge clk);address=11'h7fe;data=8'hff;text_write=1;attr_write=1;kan_write=1;
        @(negedge clk);text_write=0;attr_write=0;kan_write=0;#1;
        assert(!unsupported && !kanji_select && kanji_address==0 && font_address==1043)
            else $fatal(1,"noncandidate metadata alias");
        $display("PASS Kanji CG selector: %0d physical/attribute cases, absent-level2, default isolation, PCG planes and ANK exit",checks);
        $finish;
    end
endmodule
