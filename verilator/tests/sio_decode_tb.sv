// SPDX-License-Identifier: GPL-2.0-or-later
module sio_decode_tb;
    timeunit 1ns;timeprecision 1ps;
    reg enabled=0,reset=0,dam=0,m1_n=1,iorq_n=1,rd_n=1,wr_n=1;
    reg [15:0] address=0;
    wire selected,read_access,write_access;
    x1_sio_decode dut(.*);
    bit eligible,expected_read,expected_write;
    integer checks=0;
    initial begin
        for(integer addr=0;addr<65536;addr++)
            for(integer control=0;control<128;control++) begin
                address=16'(addr);
                {enabled,reset,dam,m1_n,iorq_n,rd_n,wr_n}=7'(control);
                #1;
                // Independent inclusive range oracle, not DUT bit slicing.
                eligible=enabled && !reset && !dam && m1_n && !iorq_n &&
                         addr>=16'h1f90 && addr<=16'h1f93;
                expected_read=eligible && rd_n==0 && wr_n==1;
                expected_write=eligible && rd_n==1 && wr_n==0;
                assert(selected==(expected_read || expected_write) &&
                       read_access==expected_read && write_access==expected_write)
                    else $fatal(1,"SIO decode mismatch address=%h control=%h",address,control);
                checks++;
            end
        $display("PASS: %0d exhaustive SIO address/control decode cases",checks);
        $finish;
    end
endmodule
