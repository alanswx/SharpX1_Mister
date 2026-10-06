`timescale 1ns/1ps
module pcg_access_tb;
    reg reset = 1, cpu_clk = 0, video_clk = 0;
    integer video_half = 7;
    initial begin
        if ($value$plusargs("VIDEO_HALF=%d", video_half)) begin
            assert (video_half > 0 && video_half < 100) else $fatal(1, "invalid video clock");
        end
    end
    always #5 cpu_clk = !cpu_clk;
    always #(video_half) video_clk = !video_clk;
    reg select = 0, write_enable = 0;
    reg [1:0] plane = 0;
    reg [7:0] data = 0;
    reg [10:0] beam = 0;
    wire wait_n;
    wire [7:0] result, access_data;
    wire [10:0] address;
    wire [2:0] writes;
    wire [7:0] blue, red, green;
    reg [7:0] rom;
    integer write_count = 0, before_count, waits = 0;
    always @(posedge video_clk) begin
        rom <= address[7:0] ^ 8'h5a;
        if (writes != 0) write_count <= write_count + 1;
    end
    x1_pcg_access dut(reset,cpu_clk,video_clk,select,write_enable,plane,data,
                      wait_n,result,beam,address,access_data,writes,rom,blue,red,green,
                      1'b0,11'd0,1'b0,1'b0,12'd0,1'b0,,8'd0,,reset,1'b0,17'd0,1'b0,1'b0,8'd0,,);
    x1_video_ram #(11) b(video_clk,address,access_data,writes[0],blue,video_clk,beam,);
    x1_video_ram #(11) r(video_clk,address,access_data,writes[1],red,video_clk,beam,);
    x1_video_ram #(11) g(video_clk,address,access_data,writes[2],green,video_clk,beam,);
    task transaction(input [10:0] a, input [1:0] p, input w, input [7:0] d, input [7:0] expected);
        begin
            @(negedge cpu_clk);
            beam = a; plane = p; write_enable = w; data = d; select = 1;
            before_count = write_count;
            #1; assert (!wait_n) else $fatal(1, "missing initial WAIT");
            // Move the live beam after its address is captured but before
            // the access completes. The pending transaction must not follow it.
            wait (dut.stage == 1);
            @(negedge video_clk); beam = a ^ 11'h155;
            while (!wait_n) begin
                @(negedge cpu_clk); waits = waits + 1;
            end
            if (!w) assert (result == expected) else $fatal(1, "plane %d addr %x read %x expected %x",p,a,result,expected);
            // Holding the original CPU bus must not retrigger or write a
            // second address as the beam continues to advance.
            beam = a ^ 11'h155;
            repeat (12) @(negedge cpu_clk);
            assert (wait_n && write_count == before_count + int'(w && p != 0))
                else $fatal(1, "duplicate write/request while bus held");
            select = 0;
            repeat (3) @(negedge cpu_clk);
            assert (wait_n) else $fatal(1, "WAIT asserted on inactive bus");
        end
    endtask
    initial begin
        #100000; $fatal(1, "PCG transaction timeout");
    end
    integer p, a;
    initial begin
        repeat (4) @(negedge cpu_clk);
        reset = 0;
        for (p = 1; p <= 3; p = p + 1)
            for (a = 0; a < 4; a = a + 1)
                transaction(11'(a == 3 ? 2047 : a * 683),2'(p),1,8'(p * 32 + a),0);
        for (p = 1; p <= 3; p = p + 1)
            for (a = 0; a < 4; a = a + 1)
                transaction(11'(a == 3 ? 2047 : a * 683),2'(p),0,0,8'(p * 32 + a));
        transaction(11'h7ff,0,0,0,8'ha5);
        transaction(11'h7ff,0,1,8'h00,0);
        transaction(11'h7ff,0,0,0,8'ha5);
        // Reset cancels an unserviced request, including synchronizer phase.
        @(negedge cpu_clk); select = 1; write_enable = 1; plane = 1;
        @(negedge cpu_clk); reset = 1; select = 0;
        repeat (4) @(negedge cpu_clk);
        before_count = write_count;
        reset = 0;
        repeat (10) @(negedge cpu_clk);
        assert (write_count == before_count && wait_n) else $fatal(1, "stale request after reset");
        transaction(0,1,0,0,8'h20);
        assert (waits > 28) else $fatal(1, "wait path not exercised");
        $display("PASS: asynchronous PCG transactions, single writes, all planes/bounds, ROM read-only, reset and WAIT");
        $finish;
    end
endmodule
