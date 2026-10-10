`timescale 1ns/1ps
module fdc_bus_events_tb;
    reg clk=0;
    always #15.625 clk=~clk;
    reg reset=0, ce=0, selected=0, rd=0, wr=0;
    reg [7:0] response=0, write_value=0;
    wire read_accept, write_accept;
    wire [7:0] read_value, captured_write, accepted_write_value;
    x1_fdc_bus_events dut(clk,reset,ce,selected,rd,wr,response,write_value,
                          read_accept,write_accept,read_value,captured_write,accepted_write_value);
    bit read_seen=0, write_seen=0;
    byte held=0, stored=0;
    integer reads=0, writes=0, consumed_reads=0, consumed_writes=0;
    always @(posedge clk) begin
        if(read_accept) consumed_reads++;
        if(write_accept) begin
            assert(accepted_write_value===write_value) else $fatal(1,"same-edge write consumer mismatch");
            consumed_writes++;
        end
    end
    task automatic step(input bit r,c,s,rr,ww,input byte q,d);
        bit ra,wa;
        @(negedge clk);
        reset=r; ce=c; selected=s; rd=rr; wr=ww; response=q; write_value=d;
        #1;
        ra=!r && c && s && rr && !ww && !read_seen;
        wa=!r && c && s && ww && !rr && !write_seen;
        assert(read_accept===ra && write_accept===wa) else
            $fatal(1,"bus acceptance mismatch: duplicate/missing event");
        assert(read_value===(read_seen ? held : q)) else $fatal(1,"held response changed before edge");
        if(ra) reads++;
        if(wa) writes++;
        @(posedge clk);
        if(r) begin read_seen=0; write_seen=0; held=0; stored=0; end
        else begin
            if(!rr) read_seen=0;
            else if(ra) begin read_seen=1; held=q; end
            if(!ww) write_seen=0;
            else if(wa) begin write_seen=1; stored=d; end
        end
        #1;
        assert(read_value===(read_seen ? held : q) && captured_write===stored) else
            $fatal(1,"bus capture mismatch");
        assert(consumed_reads==reads && consumed_writes==writes) else $fatal(1,"bus consumer mismatch");
    endtask
    initial begin
        step(1,0,1,1,1,8'hff,8'hff);
        // Ineligible/DAM start becoming eligible while raw strobe is held.
        step(0,1,0,1,0,8'h11,0);
        step(0,0,1,1,0,8'h22,0);
        step(0,1,1,1,0,8'h33,0);
        repeat(17) step(0,1,1,1,0,8'h44,0);
        step(0,1,0,1,0,8'h45,0);
        step(0,1,1,1,0,8'h46,0); // reselection is not raw release
        // Release while CE stops; the next real access must still be new.
        step(0,0,0,0,0,8'h55,0);
        step(0,1,1,1,0,8'h66,0);
        step(0,0,1,0,0,0,0);
        step(0,1,1,0,1,0,8'ha1);
        repeat(17) step(0,1,1,0,1,0,8'hb2);
        step(0,1,0,0,1,0,8'hb3);
        step(0,1,1,0,1,0,8'hb4);
        step(0,0,0,0,0,0,0);
        step(0,1,1,0,1,0,8'hc3);
        // Simultaneous strobes are ineligible, not two transfers.
        step(0,0,0,0,0,0,0);
        repeat(4) step(0,1,1,1,1,8'hd4,8'he5);
        step(0,0,0,0,0,0,0);
        // Every eligible access has one acceptance despite arbitrary holds.
        for(integer i=0;i<256;i++) begin
            step(0,0,1,1,0,8'(i),0);
            step(0,1,1,1,0,8'(i),0);
            for(integer n=0;n<(i%9)+1;n++) step(0,n[0],1,1,0,8'(~i),0);
            step(0,0,0,0,0,0,0);
            step(0,1,1,0,1,0,8'(i));
            for(integer n=0;n<(i%7)+1;n++) step(0,n[0],1,0,1,0,8'(~i));
            step(0,0,0,0,0,0,0);
        end
        step(0,1,1,1,0,8'hf6,0);
        step(1,0,1,1,0,8'ha7,0); // reset works with CE stopped
        step(0,1,1,1,0,8'hb8,0);
        step(0,0,0,0,0,0,0);
        step(0,1,1,0,1,0,8'hc9);
        step(1,0,1,0,1,0,8'hda);
        step(0,1,1,0,1,0,8'heb);
        step(0,0,0,0,0,0,0);
        assert(reads==260 && writes==260) else $fatal(1,"bus coverage count mismatch %0d %0d",reads,writes);
        $display("PASS FDC bus events: 260 reads/260 writes, held responses, reselection, stopped-CE release/reset, synchronous consumers");
        $finish;
    end
endmodule
