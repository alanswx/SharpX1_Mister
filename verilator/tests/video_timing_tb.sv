`timescale 1ns/1ps
module video_timing_tb;
    reg clk=0, reset=1, high_scan=0, width40=0;
    wire step;
    wire [4:0] phase;
    always #5 clk=!clk;
    x1_video_timing dut(clk,reset,high_scan,width40,step,phase);
    task check_mode(input bit hi, input bit narrow);
        integer dot_period, char_period, last_dot, last_char, dots, chars;
        begin
            @(negedge clk); high_scan=hi; width40=narrow;
            dot_period=(hi ? 2 : 3)*(narrow ? 2 : 1);
            char_period=dot_period*8;
            last_dot=-1; last_char=-1; dots=0; chars=0;
            for(integer edge_number=0;edge_number<4096;edge_number=edge_number+1) begin
                @(posedge clk);
                if(step && !phase[0] && !phase[1]) begin
                    if(last_dot>=0) assert(edge_number-last_dot==dot_period)
                        else $fatal(1,"dot interval hi=%d width=%d",hi,narrow);
                    last_dot=edge_number; dots=dots+1;
                end
                if(step && !phase[0] && phase[4:1]==15) begin
                    if(last_char>=0) assert(edge_number-last_char==char_period)
                        else $fatal(1,"character interval hi=%d width=%d",hi,narrow);
                    last_char=edge_number; chars=chars+1;
                end
            end
            assert(dots>600 && chars>75) else $fatal(1,"missing video enables");
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);
        assert(!step && phase==0) else $fatal(1,"reset phase");
        reset=0;
        check_mode(0,0); check_mode(1,0); check_mode(1,1); check_mode(0,1);
        check_mode(0,0); check_mode(1,1); check_mode(1,0); check_mode(0,1);
        @(negedge clk); reset=1; #1;
        assert(!step && phase==0) else $fatal(1,"warm reset phase");
        @(negedge clk); reset=0;
        check_mode(1,0); check_mode(0,0);
        $display("PASS: exact X3 dot/character enable intervals, all modes/widths/live switches/warm reset");
        $finish;
    end
endmodule
