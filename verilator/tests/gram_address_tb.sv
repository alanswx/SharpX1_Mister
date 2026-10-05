`timescale 1ns/1ps
// Exhaustive independent arithmetic oracle: every SCRN byte, RA and MA.
module gram_address_tb;
    reg [7:0] scrn;
    reg [4:0] raster;
    reg [10:0] ma;
    wire [14:0] turbo_address, base_address;
    x1_gram_address #(.TURBO(1)) turbo(scrn,raster,ma,turbo_address);
    x1_gram_address #(.TURBO(0)) base(scrn,raster,ma,base_address);
    integer bank, row, expected;
    initial begin
        for (int control=0; control<256; control++) begin
            scrn=8'(control);
            for (int ra=0; ra<32; ra++) begin
                raster=5'(ra);
                // Mode 01 ignores display bank; 11 repeats adjacent rasters.
                bank=(control&3)==1 ? ra%2 : (control/8)%2;
                row=(control&1)!=0 ? (ra/2)%8 : ra%8;
                for (int address=0; address<2048; address++) begin
                    ma=11'(address); #1;
                    expected=bank*16384+row*2048+address;
                    assert(turbo_address==15'(expected))
                        else $fatal(1,"SCRN=%h RA=%d MA=%d got=%h expected=%h",scrn,ra,address,turbo_address,expected);
                    assert(base_address==15'((ra%8)*2048+address))
                        else $fatal(1,"base changed by Turbo control");
                end
            end
        end
        $display("PASS: all 256 SCRN bytes x 32 rasters x 2048 MA addresses; base isolation");
        $finish;
    end
endmodule
