`timescale 1ns/1ps
module pcg_selector_tb;
    reg clk=0;
    always #5 clk=!clk;
    reg tw=0,aw=0,kw=0;
    reg [10:0] address=0;
    reg [7:0] data=0;
    reg [3:0] nibble=0;
    reg [1:0] plane=0;
    reg font16_mode=0;
    wire [10:0] byte_address;
    wire [11:0] font_address;
    wire font16_select,unsupported;
    x1_pcg_selector dut(clk,tw,aw,kw,address,data,nibble,plane,font16_mode,
                        byte_address,font_address,font16_select,unsupported);
    function automatic [10:0] cell_addr(input integer i);
        return i==0 ? 11'h7ff : i==1 ? 11'h3ff : i==2 ? 11'h5ff : 11'h1ff;
    endfunction
    task put(input integer cell_index,input integer kind,input [7:0] value);
        @(negedge clk); address=cell_addr(cell_index); data=value;
        tw=kind==0; aw=kind==1; kw=kind==2;
        @(negedge clk); tw=0; aw=0; kw=0;
    endtask
    integer expected_cell,expected_addr,checks=0;
    initial begin
        #1; assert(unsupported) else $fatal(1,"invented startup metadata");
        for(integer i=0;i<4;i++) begin
            put(i,0,8'(i*57+1)); put(i,2,0);
        end
        // All 16 attribute patterns, independent PCG/ROM selection, 7FF fallback.
        for(integer mask=0;mask<16;mask++) begin
            for(integer i=0;i<4;i++) put(i,1,8'(((mask>>i)&1)*32 | (i*3)));
            for(integer p=0;p<4;p++) begin
                plane=2'(p); nibble=6; font16_mode=0;
                expected_cell=0;
                for(integer i=3;i>=0;i--)
                    if (((mask>>i)&1)==int'(p!=0)) expected_cell=i;
                #1; assert(!unsupported && byte_address==11'((expected_cell*57+1)*8+3))
                    else $fatal(1,"selector mask %x plane %d address %x",mask,p,byte_address);
                checks++;
                font16_mode=1; #1;
                assert(font16_select==(p==0) && font_address==12'((expected_cell*57+1)*16+6))
                    else $fatal(1,"independent ROM selector/font mode");
            end
        end
        // Every glyph/row and all K&90 cases, including even/odd pairing.
        for(integer i=0;i<4;i++) put(i,1,0);
        for(integer k=0;k<4;k++) begin
            put(0,2,8'((k&1)*16+(k>>1)*128));
            for(integer t=0;t<256;t++) begin
                put(0,0,8'(t));
                for(integer n=0;n<16;n++) begin
                    nibble=4'(n);
                    for(integer p=1;p<4;p++) begin
                        plane=2'(p); #1;
                        expected_addr=k==0 ? t*8+(n>>1) : (t&254)*8+n;
                        assert(!unsupported && byte_address==11'(expected_addr))
                            else $fatal(1,"PCG t %x n %x k %d p %d",t,n,k,p);
                        checks++;
                    end
                    plane=0; font16_mode=1; #1;
                    assert(unsupported==(k>=2)) else $fatal(1,"Kanji dispatch b7");
                    if(k<2) begin
                        assert(font16_select && font_address==12'(t*16+n)) else $fatal(1,"ANK16 full range");
                        font16_mode=0; #1;
                        assert(!font16_select && byte_address==11'(t*8+(n>>1))) else $fatal(1,"ANK8 rows");
                    end
                end
            end
        end
        // Noncandidate writes cannot corrupt selector metadata.
        put(0,2,0); put(0,0,65);
        @(negedge clk); address=11'h7fe; data=255; tw=1; aw=1; kw=1;
        @(negedge clk); tw=0; aw=0; kw=0; plane=0; nibble=0; #1;
        assert(!unsupported && byte_address==520) else $fatal(1,"noncandidate shadow alias");
        $display("PASS: %0d selector/address cases, priority/fallback, all glyphs/rows/planes/K masks, unknown/Kanji",checks);
        $finish;
    end
endmodule
