`timescale 1ns/1ps
module font16_tb;
    reg cpu_clk=0,video_clk=0,load=0;
    reg [24:0] address=0;
    reg [7:0] data=0;
    reg [11:0] display_address=0;
    wire [7:0] display_data;
    wire loaded;
    always #5 cpu_clk=!cpu_clk;
    always #7 video_clk=!video_clk;
    x1_font16 dut(cpu_clk,video_clk,load,address,data,display_address,display_data,loaded);
    task put(input integer a);
        @(negedge cpu_clk); load=1; address=25'(a); data=8'(a ^ (a>>8));
        @(negedge cpu_clk); load=0;
    endtask
    initial begin
        repeat(4) @(negedge video_clk);
        assert(!loaded && display_data==0) else $fatal(1,"unloaded font not blank");
        put(0); put(4095);
        repeat(4) @(negedge video_clk);
        assert(!loaded && display_data==0) else $fatal(1,"partial/out-of-order font accepted");
        for(integer a=0;a<4096;a=a+1) put(a);
        repeat(4) @(negedge video_clk);
        assert(loaded) else $fatal(1,"complete font not published");
        for(integer a=0;a<4096;a=a+1) begin
            @(negedge video_clk); display_address=12'(a);
            @(negedge video_clk);
            assert(display_data==8'(a ^ (a>>8))) else $fatal(1,"font row/address alias %h",a);
        end
        put(4096); repeat(4) @(negedge video_clk);
        assert(!loaded && display_data==0) else $fatal(1,"oversize load did not invalidate");
        $display("PASS: externally loaded 16-row ANK, all 4096 addresses, blank/partial/order/overflow/CDC");
        $finish;
    end
endmodule
