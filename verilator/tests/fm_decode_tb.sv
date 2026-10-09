// SPDX-License-Identifier: GPL-2.0-or-later
// Original inclusive-address oracle, independent of DUT bit slicing.
module fm_decode_tb;
    timeunit 1ns;timeprecision 1ps;
    reg enabled=0,reset=0,dam=0,m1_n=1,mreq_n=1,iorq_n=1,rd_n=1,wr_n=1;
    reg [15:0] address=0;
    wire selected,read_access,write_access;
    x1_fm_decode dut(.*);
    bit eligible,expected_read,expected_write;
    integer checks=0;
    initial begin
        for(integer addr=0;addr<65536;addr++)
            for(integer control=0;control<256;control++) begin
                address=16'(addr);
                {enabled,reset,dam,m1_n,mreq_n,iorq_n,rd_n,wr_n}=8'(control);
                #1;
                eligible=enabled && !reset && !dam && m1_n && mreq_n && !iorq_n &&
                         addr>=16'h0700 && addr<=16'h0701;
                expected_read=eligible && !rd_n && wr_n;
                expected_write=eligible && rd_n && !wr_n;
                assert(selected==(expected_read || expected_write) &&
                       read_access==expected_read && write_access==expected_write)
                    else $fatal(1,"FM decode mismatch address=%h control=%h",address,control);
                checks++;
            end
        $display("PASS %0d exhaustive FM address/control cases: enabled/reset/DAM/ACK/memory/RD-WR isolation",checks);
        $finish;
    end
endmodule
