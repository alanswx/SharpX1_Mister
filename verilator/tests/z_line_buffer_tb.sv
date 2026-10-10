// SPDX-License-Identifier: GPL-2.0-only
// Original clock/edge oracle. No native captured assets or private bytes.
`timescale 1ps/1ps
module z_line_buffer_tb #(parameter integer W_HALF=35000, R_HALF=55000, R_PHASE=0);
    logic wck=0,rck=0,wrun=1,rrun=1;
    logic wrst=0,rrst=0,we=1,re=1;
    logic [7:0] din=0,begin_din=0,q;
    wire owned;
    integer fault=0,writes=0,reads=0,wraps=0,disables=0;
    always #(W_HALF) if(wrun) wck=!wck;
    initial begin if(R_PHASE!=0) #(R_PHASE);forever begin #(R_HALF);if(rrun) rck=!rck;end end
    always @(posedge wck) begin_din<=din;
    // Matched negative feeds prior cycle's DIN: a same-edge/generic FIFO
    // policy must fail the unchanged ending-edge byte oracle.
    x1_z_line_buffer dut(.write_clock(wck),.read_clock(rck),
        .write_reset_n(wrst),.read_reset_n(rrst),.write_enable_n(we),.read_enable_n(re),
        .data_in(fault==1 ? begin_din : din),.data_out(q),.output_owned(owned));
    logic [7:0] expected [0:909];
    bit initialized[0:909];
    bit byte_seen[0:255];
    time last_write_time=0,last_read_time=0;
    integer last_write_address=-1,last_read_address=-1;
    integer wn=0,rn=0,pending=0;
    bit pending_valid=0;
    logic [7:0] read_expected;
    bit check_read;
    bit expected_owned;
    always @(posedge wck) begin
        if(pending_valid) begin
            assert(!(last_read_time==$time && last_read_address==pending))
                else $fatal(1,"fixture attempted unqualified same-address collision");
            last_write_time=$time;last_write_address=pending;
            expected[pending]=din;initialized[pending]=1;writes++;
        end
        pending_valid=!we;
        if(!wrst) wn=0;
        if(!we) begin pending=wn;wn=(wn+1)%910;if(wn==0) wraps++;end
    end
    always @(posedge rck) begin
        expected_owned=!re;
        if(!rrst) rn=0;
        check_read=!re && initialized[rn];
        if(check_read) begin
            assert(!(last_write_time==$time && last_write_address==rn))
                else $fatal(1,"fixture attempted unqualified same-address collision");
            last_read_time=$time;last_read_address=rn;
            read_expected=expected[rn];byte_seen[read_expected]=1;reads++;
        end
        if(!re) rn=(rn+1)%910;else disables++;
        #1;
        assert(owned==expected_owned) else $fatal(1,"line-buffer output ownership expected=%b actual=%b RE=%b",expected_owned,owned,re);
        if(check_read) assert(q==read_expected)
            else $fatal(1,"line-buffer ending-edge/reset/wrap byte oracle expected=%h actual=%h",read_expected,q);
    end
    task automatic wt;@(negedge wck);#1;endtask
    task automatic rt;@(negedge rck);#1;endtask
    function automatic logic [7:0] pattern(input integer a,input integer pass);
        return 8'(a*37+(a/256)*71+pass*113+19);
    endfunction
    initial begin
        if($value$plusargs("FAULT=%d",fault)) begin end
        assert(fault==0 || fault==1) else $fatal(1,"invalid negative");
        // Controls are changed on falling edges, away from chip setup/hold.
        wt();we=0;wrst=0;din=8'hde;wt();
        wrst=1;
        // DIN here closes address zero, not the newly selected address one.
        for(integer a=0;a<910;a++) begin din=pattern(a,0);wt();end
        we=1;din=pattern(0,1);wt(); // Complete the already-open wrapped zero.
        assert(expected[0]==pattern(0,1) && expected[909]==pattern(909,0))
            else $fatal(1,"direct write chronology");
        // Disabled cycles must neither rewrite nor advance an address.
        repeat(17) begin din=8'hc7;wt();end
        rt();re=0;rrst=0;rt();rrst=1;
        repeat(1821) rt(); // Two whole lines plus a wrap successor.
        re=1;repeat(13) rt();
        // Repeated reset cycles read zero repeatedly, never clear storage.
        re=0;rrst=0;repeat(7) rt();rrst=1;repeat(5) rt();
        re=1;rt();

        // Pending write survives a stopped WCK, changing DIN while stopped,
        // and WE disable on the closing edge. Zero was previously initialized.
        wt();wrst=0;we=0;din=8'h12;wt();
        wrst=1;we=1;wrun=0;din=8'h6d;
        repeat(12) rt();
        assert(expected[0]==pattern(0,1)) else $fatal(1,"stopped WCK committed early");
        wrun=1;wt();repeat(12) wt(); // Do not qualify a sub-ten-cycle delay.
        rt();re=0;rrst=0;rt();re=1;rrst=1;rt();
        assert(expected[0]==8'h6d && q==8'h6d) else $fatal(1,"pending disable/stop completion");

        // Noncolliding simultaneous accesses: read upper addresses while
        // independent WCK rewrites the low range. No collision value accepted.
        re=0;rrst=0;rt();rrst=1;repeat(599) rt();
        wt();we=0;wrst=0;din=8'h55;wt();wrst=1;
        for(integer a=0;a<250;a++) begin din=pattern(a,2);wt();end
        we=1;din=pattern(250,2);wt();
        re=1;rt();
        // Replay the changed line at an independent rate, including its wrap.
        re=0;rrst=0;rt();rrst=1;repeat(911) rt();
        re=1;rt();
        // RCK stop retains last output and ownership until an actual edge.
        rrun=0;re=0;#1000000;
        assert(!owned) else $fatal(1,"RE was sampled without RCK");
        rrun=1;rt();assert(owned) else $fatal(1,"RCK recovery failed");
        assert(wraps>=1 && reads>=3000 && disables>=10) else $fatal(1,"insufficient coverage");
        for(integer a=0;a<910;a++) assert(initialized[a]) else $fatal(1,"unwritten location accepted");
        for(integer b=0;b<256;b++) assert(byte_seen[b]) else $fatal(1,"missing byte value %h",b);
        $display("PASS line-buffer 910-word replay/wrap, ending-edge DIN, reset/enable/clock stops and noncolliding clocks writes=%0d reads=%0d",writes,reads);
        $finish;
    end
    initial begin #1000000000;$fatal(1,"line-buffer timeout");end
endmodule
