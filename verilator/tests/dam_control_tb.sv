`timescale 1ps/1ps
module dam_control_tb;
    reg clk=0,reset=1,mode5=1,rd=0,wr=0;
    wire dam;
    integer redirected=0;
    always #15625 clk=~clk;
    x1_dam_control dut(clk,reset,mode5,rd,wr,dam);
    always @(posedge clk) if(wr && dam) redirected<=redirected+1;
    task automatic tick;
        @(posedge clk);#1;@(negedge clk);
    endtask
    initial begin
        tick();reset=0;tick();
        for(integer length=1;length<=64;length=length+1) begin
            mode5=1;tick();wr=1;tick();mode5=0;
            repeat(length) begin
                tick();assert(!dam) else $fatal(1,"DAM redirected held control OUT");
            end
            assert(redirected==0) else $fatal(1,"control write leaked to GRAM");
            wr=0;tick();assert(dam) else $fatal(1,"next OUT not armed");
            rd=1;tick();assert(!dam) else $fatal(1,"IN did not clear DAM");
            rd=0;tick();
        end
        mode5=1;tick();wr=1;tick();mode5=0;tick();
        reset=1;tick();mode5=1;wr=0;reset=0;tick();
        assert(!dam) else $fatal(1,"pending arming survived reset");
        mode5=0;rd=1;tick();rd=0;tick();
        assert(!dam) else $fatal(1,"read-clear priority lost");
        mode5=1;tick();mode5=0;tick();
        assert(dam) else $fatal(1,"inactive-bus transition not armed");
        $display("PASS: 64 held control widths, no GRAM redirect, next-write arming, IN clear and pending reset");
        $finish;
    end
endmodule
