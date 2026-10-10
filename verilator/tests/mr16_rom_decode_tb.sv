// SPDX-License-Identifier: GPL-2.0-only
// Exhaustive decode/alias test, not an active-machine or native MCU map.
module mr16_rom_decode_tb;
    logic [15:0] address;
    logic memory_cs;
    wire old_rom,old_ram,new_rom,new_ram;
    wire [11:0] old_word,new_word;
    x1_mr16_rom_decode legacy(address,memory_cs,old_rom,old_ram,old_word);
    x1_mr16_rom_decode #(.EXTENDED(1)) expanded(address,memory_cs,new_rom,new_ram,new_word);
    initial begin
        for(integer cs=0;cs<2;cs++) begin
            memory_cs=1'(cs);
            for(integer a=0;a<65536;a++) begin
                address=16'(a);#1;
                assert(old_rom==(memory_cs && !address[12]) && old_ram==(memory_cs && address[12]) &&
                    old_word=={1'b0,address[11:1]}) else $fatal(1,"MR16 legacy decode mismatch");
                assert(new_rom==(memory_cs && (a<4096 || (a>=16384 && a<20480))) &&
                    new_ram==(memory_cs && a>=4096 && a<8192) &&
                    new_word=={address[14],address[11:1]} && !(new_rom && new_ram))
                    else $fatal(1,"MR16 extended decode/alias mismatch at %h",address);
            end
        end
        $display("PASS: MR16 legacy/extended decode exhausts 131072 address/CS cases; ROM banks do not alias RAM or unsupported regions");
        $finish;
    end
endmodule
