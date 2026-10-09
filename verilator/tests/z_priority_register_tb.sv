// SPDX-License-Identifier: GPL-2.0-only
// Original CPU-bus register tests; reset/read masks are experimental policy.
`timescale 1ps/1ps
module z_priority_register_tb;
    reg clk=0,reset=1,enabled=1,io_read=0,io_write=0,clear_read=0;
    always #15625 clk=~clk;
    reg [15:0] address=16'h1fc0;
    reg [7:0] data=0;
    wire selected,read_hold;
    wire [7:0] read_data,held_data,control;
    integer hold_edges=1;
    x1_z_priority_register dut(.*);
    task automatic tick;
        @(posedge clk);#1;@(negedge clk);
    endtask
    task automatic idle;
        io_read=0;io_write=0;clear_read=1;tick();clear_read=0;
    endtask
    task automatic read_value(input [7:0] expected);
        address=16'h1fc0;io_read=1;tick();
        assert(selected && read_data==expected && read_hold && held_data==expected)
            else $fatal(1,"selected read/response");
        io_read=0;tick();
        assert(!selected && read_data==8'hff && read_hold && held_data==expected)
            else $fatal(1,"late read tail");
        idle();assert(!read_hold && held_data==8'hff) else $fatal(1,"read clear");
    endtask
    initial begin
        if($value$plusargs("HOLD_EDGES=%d",hold_edges)) begin end
        tick();reset=0;idle();read_value(0);
        for(integer value=0;value<256;value=value+1) begin
            address=16'h1fc0;data=8'(value);io_write=1;tick();
            assert(control==8'(value)) else $fatal(1,"accepted OUT");
            data=~8'(value);address=16'h1fc1;
            repeat(hold_edges) begin tick();assert(control==8'(value)) else $fatal(1,"repeated/poisoned OUT");end
            idle();read_value(8'(value));
        end
        // Configuration/reset-to-zero is this profile's explicit policy.
        reset=1;#17;
        assert(control==0 && !selected && !read_hold) else $fatal(1,"raw reset mask");
        reset=0;idle();address=16'h1fc0;data=8'h5a;io_write=1;tick();idle();
        for(integer bit_number=0;bit_number<16;bit_number=bit_number+1) begin
            address=16'h1fc0 ^ (16'd1<<bit_number);data=8'(~bit_number);io_write=1;tick();
            assert(!selected && control==8'h5a) else $fatal(1,"priority alias OUT");
            idle();io_read=1;tick();
            assert(!selected && read_data==8'hff && !read_hold) else $fatal(1,"priority alias IN");
            idle();
        end
        enabled=0;address=16'h1fc0;data=8'hff;io_write=1;tick();
        enabled=1;repeat(hold_edges) tick();
        assert(control==8'h5a) else $fatal(1,"late inactive OUT accepted");
        idle();read_value(8'h5a);
        io_read=1;io_write=1;data=0;tick();
        assert(!selected && control==8'h5a && !read_hold) else $fatal(1,"contradictory strobes");
        io_read=0;tick();assert(control==8'h5a) else $fatal(1,"late contradictory OUT accepted");
        idle();read_value(8'h5a);
        // Pulse reset between physical edges with an old OUT still asserted.
        io_write=1;data=8'hc3;tick();#29;reset=1;#17;reset=0;
        repeat(hold_edges) tick();
        assert(control==0 && !read_hold) else $fatal(1,"stale OUT after pulse reset");
        idle();address=16'h1fc0;data=8'ha5;io_write=1;tick();idle();read_value(8'ha5);
        io_read=1;tick();#29;reset=1;#17;
        assert(!read_hold && held_data==8'hff && control==0) else $fatal(1,"old read survived raw reset");
        reset=0;idle();read_value(0);
        $display("PASS: priority register all 256 values, held poisoned OUT, all single-bit aliases, late/inactive/contradictory accesses, pulsed reset; hold=%0d",hold_edges);
        $finish;
    end
endmodule
