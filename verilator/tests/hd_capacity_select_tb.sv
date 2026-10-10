// SPDX-License-Identifier: GPL-2.0-only
// Original exhaustive capacity-port decode and asynchronous reset diagnostic.
`timescale 1ns/1ps
module hd_capacity_select_tb;
    logic clk=0,reset=1,read_cycle=0;
    logic [15:0] address=0;
    wire selected;
    always #5 clk=!clk;
    x1_disk_capacity_select dut(clk,reset,read_cycle,address,selected);
    task automatic read_port(input logic [15:0] port);
        @(negedge clk);address=port;read_cycle=1;
        @(negedge clk);read_cycle=0;#1;
    endtask
    initial begin
        repeat(3) @(negedge clk);reset=0;
        assert(!selected) else $fatal(1,"capacity initial reset");
        for(integer port=0;port<65536;port++) begin
            read_port(16'h0fff);read_port(16'(port));
            assert(selected==(port==16'h0ffe))
                else $fatal(1,"capacity low-start decode alias %h",port);
            read_port(16'h0ffe);read_port(16'(port));
            assert(selected==(port!=16'h0fff))
                else $fatal(1,"capacity high-start decode alias %h",port);
        end
        read_port(16'h0ffe);
        @(negedge clk);address=16'h0fff;read_cycle=0;
        repeat(8) @(negedge clk);
        assert(selected) else $fatal(1,"inactive read altered class");
        #2;reset=1;#1;
        assert(!selected) else $fatal(1,"capacity asynchronous reset");
        address=16'h0ffe;read_cycle=1;repeat(8) @(negedge clk);
        assert(!selected) else $fatal(1,"read overrode held reset");
        reset=0;read_cycle=0;
        $display("PASS capacity decode: all 65536 addresses from both classes, inactive hold and asynchronous/held reset; reset policy provisional");
        $finish;
    end
endmodule
