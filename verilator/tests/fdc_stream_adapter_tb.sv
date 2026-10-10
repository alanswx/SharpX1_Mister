`timescale 1ns/1ps
// Original event-by-event standalone oracle. No private media/forced state.
// The expected byte clock uses an absolute count of externally supplied CE
// edges, not the helper's counter, boundary output or adapter byte_index.
module fdc_stream_adapter_tb;
    reg clk=0;
    always #15.625 clk=~clk;
    reg reset=0, ce=0, begin_read=0, arm_write=0, launch_write=0, stop=0;
    reg read_accept=0, read_release=0, write_accept=0;
    reg [10:0] length=0;
    reg [7:0] write_value=0;
    wire [7:0] source_byte, dr_value, response_data, write_byte;
    wire drq, active, armed, lost, done, initial_abort, response_valid;
    wire read_ack, arrival, write_emit;
    wire [10:0] byte_index, generation, response_generation, write_index;
    integer divider=16, cycles=0, chip_edges=0, due=0, cases=0;
    integer observed_arrivals=0, observed_writes=0, observed_acks=0;
    integer scenario=0;
    function automatic [7:0] payload(input integer index_value);
        // Each logical position also carries its independent 11-bit index;
        // bytes alone cannot be unique over a 1024-byte 8-bit payload.
        return 8'((index_value*73) ^ (index_value>>3) ^ (scenario*19) ^ 8'ha6);
    endfunction
    assign source_byte=payload(int'(byte_index));
    x1_fdc_stream_adapter dut(.*,.fdc_ce(ce));

    bit r_active=0, r_armed=0, r_writing=0, r_full=0, r_lost=0;
    bit r_response_valid=0, clock_running=0;
    reg [7:0] r_holding=0, r_response=0;
    integer r_index=0, r_generation=0, r_response_generation=0, r_remaining=0;
    task automatic step;
        bit event_due, read_event, consume_read, consume_write;
        bit expect_arrival, expect_write, expect_ack, expect_done, expect_abort;
        reg [7:0] expect_write_byte;
        integer expect_write_index;
        @(negedge clk);
        ce=(cycles%divider)==0;
        // Deliberately change live DIN every edge except an accepted store.
        if(!write_accept) write_value=8'(cycles*11+scenario);
        event_due=clock_running && ce && chip_edges+1==due;
        if(ce) chip_edges++;
        read_event=read_accept && (!r_response_valid || read_release);
        consume_read=read_event && !r_writing && r_full;
        consume_write=write_accept && r_writing && (r_active || r_armed) && !r_full;
        expect_arrival=0; expect_write=0; expect_ack=0; expect_done=0; expect_abort=0;
        expect_write_byte=0; expect_write_index=0;
        if(reset) begin
            r_active=0; r_armed=0; r_writing=0; r_full=0; r_holding=0;
            r_remaining=0; r_lost=0; r_index=0; r_generation=0;
            r_response_valid=0; r_response=0; r_response_generation=0;
            clock_running=0;
        end else begin
            if(read_release) r_response_valid=0;
            if(read_event) begin
                r_response_valid=1; r_response=r_holding; r_response_generation=r_generation;
            end
            if(stop) begin
                r_active=0; r_armed=0; r_full=0; r_remaining=0; clock_running=0;
            end else if(begin_read || arm_write) begin
                r_active=begin_read; r_armed=arm_write; r_writing=arm_write;
                r_full=0; r_remaining=int'(length); r_lost=0; r_index=0; r_generation=0;
                r_response_valid=0; clock_running=begin_read; due=chip_edges+32;
            end else begin
                if(consume_read) begin r_full=0; expect_ack=1; end
                if(consume_write) begin r_full=1; r_holding=write_value; end
                if(launch_write && r_armed) begin
                    r_armed=0;
                    if(!r_full) begin
                        r_lost=1; expect_abort=1; expect_done=1; r_remaining=0;
                    end else begin
                        r_active=1; expect_write=1; expect_write_byte=r_holding;
                        expect_write_index=0; r_full=0; r_index=1; r_generation=1;
                        r_remaining--; clock_running=1; due=chip_edges+32;
                    end
                end else if(r_active && event_due) begin
                    due+=32;
                    if(r_remaining>0) begin
                        if(r_writing) begin
                            expect_write=1; expect_write_index=r_index;
                            expect_write_byte=r_full ? r_holding : 8'd0;
                            if(!r_full) r_lost=1;
                            r_full=0;
                        end else begin
                            expect_arrival=1;
                            if(r_full) r_lost=1;
                            r_holding=payload(r_index); r_full=1;
                        end
                        r_index++; r_generation++; r_remaining--;
                    end else begin
                        if(!r_writing && r_full) r_lost=1;
                        r_full=0; r_active=0; expect_done=1; clock_running=0;
                    end
                end
            end
        end
        @(posedge clk); #1;
        assert(arrival==expect_arrival && write_emit==expect_write && done==expect_done)
            else $fatal(1,"stream slot/event mismatch SYS=%0d chip=%0d due=%0d",cycles,chip_edges,due);
        assert(active==r_active && armed==r_armed && lost==r_lost && initial_abort==expect_abort)
            else $fatal(1,"stream state/loss mismatch SYS=%0d",cycles);
        assert(read_ack==expect_ack && response_valid==r_response_valid && response_data==r_response &&
               int'(response_generation)==r_response_generation)
            else $fatal(1,"held response/generation mismatch SYS=%0d",cycles);
        assert(dr_value==r_holding && int'(byte_index)==r_index && int'(generation)==r_generation)
            else $fatal(1,"DR/index mismatch SYS=%0d",cycles);
        assert(drq==(r_writing ? ((r_armed || (r_active && r_remaining!=0)) && !r_full) : r_full))
            else $fatal(1,"DRQ level mismatch SYS=%0d",cycles);
        if(expect_write) begin
            assert(write_byte==expect_write_byte && int'(write_index)==expect_write_index)
                else $fatal(1,"captured write/zero/index mismatch SYS=%0d",cycles);
            observed_writes++;
        end
        if(expect_arrival) observed_arrivals++;
        if(expect_ack) observed_acks++;
        cycles++;
        begin_read=0; arm_write=0; launch_write=0; stop=0;
        read_accept=0; read_release=0; write_accept=0;
    endtask
    task automatic to_chip(input integer target);
        while(chip_edges<target) step();
    endtask
    task automatic read_once;
        read_accept=1; step(); read_release=1; step();
    endtask
    task automatic put(input [7:0] value);
        write_value=value; write_accept=1; step();
    endtask
    task automatic reads(input integer count, input integer missing);
        integer anchor, before_arrivals, before_acks;
        scenario++; length=11'(count); begin_read=1; step(); anchor=chip_edges;
        before_arrivals=observed_arrivals; before_acks=observed_acks;
        for(int i=0;i<count;i++) begin
            to_chip(anchor+32*(i+1));
            assert(dr_value==payload(i) && int'(generation)==i+1)
                else $fatal(1,"read position payload");
            if(i!=missing) begin
                // All ordinary successful services safely inside 27-clock
                // guarantee; no oracle claim about its exact failure edge.
                to_chip(anchor+32*(i+1)+1+(i%20)); read_once();
            end
        end
        to_chip(anchor+32*(count+1));
        assert(done && !drq && lost==(missing>=0) && dr_value==payload(count-1) &&
               observed_arrivals-before_arrivals==count &&
               observed_acks-before_acks==count-((missing>=0)?1:0))
            else $fatal(1,"read final miss/count/readback");
        cases++;
    endtask
    task automatic writes(input integer count, input integer missing);
        integer anchor, before_writes;
        scenario++; length=11'(count); arm_write=1; step();
        before_writes=observed_writes;
        // Arbitrarily chosen pre-stream launch latency, not native ID timing.
        to_chip(chip_edges+7); put(payload(0));
        launch_write=1; step(); anchor=chip_edges;
        assert(write_emit && write_byte==payload(0)) else $fatal(1,"initial DSR load");
        for(int i=1;i<count;i++) begin
            if(i!=missing) begin
                to_chip(anchor+32*(i-1)+1+(i%20)); put(payload(i));
            end
            to_chip(anchor+32*i);
            assert(write_emit && write_byte==((i==missing)?8'd0:payload(i)))
                else $fatal(1,"write slot payload/miss");
        end
        to_chip(anchor+32*count);
        assert(done && !drq && lost==(missing>=0) && observed_writes-before_writes==count)
            else $fatal(1,"write final/count");
        cases++;
    endtask
    initial begin
        if($value$plusargs("divider=%d",divider)) begin end
        assert(divider==16 || divider==32) else $fatal(1,"explicit nominal chip rates only");
        reset=1; step(); reset=0;
        // First response before arrival returns reset DR, acknowledges nothing.
        length=6; begin_read=1; step(); read_accept=1; step();
        assert(response_data==0 && !read_ack) else $fatal(1,"pre-arrival read contract");
        stop=1; step(); assert(response_valid && response_data==0) else $fatal(1,"stop lost held response");
        read_release=1; step();
        for(int n=128;n<=1024;n*=2) begin
            reads(n,-1); reads(n,0); reads(n,n/2); reads(n,n-1);
            writes(n,-1); writes(n,n/2); writes(n,n-1);
        end
        // Six bytes supplied as an ID field, including supplied CRC bytes.
        // This adapter schedules opaque bytes; it does not compute ID CRC.
        reads(6,-1); reads(6,0); reads(6,3); reads(6,5);
        writes(1,-1); // no extra DRQ after sole first byte
        // Initial prefill miss aborts with zero stream bytes, even on CE edge.
        length=128; arm_write=1; step();
        begin : initial_miss
            integer before_writes;
            before_writes=observed_writes; launch_write=1; step();
            assert(initial_abort && done && lost && !drq && !active && observed_writes==before_writes)
                else $fatal(1,"initial-write abort touched stream");
            repeat(70*divider) step();
        end
        // Held response spans multiple arrivals; duplicate acceptance cannot
        // acknowledge the new generation, and release cannot either.
        scenario++; length=6; begin_read=1; step();
        begin : held_read
            integer anchor, acks;
            reg [7:0] old_response;
            anchor=chip_edges; to_chip(anchor+32); read_accept=1; step();
            old_response=response_data; acks=observed_acks;
            to_chip(anchor+64); read_accept=1; step();
            assert(response_data==old_response && observed_acks==acks && drq)
                else $fatal(1,"duplicate read acknowledged new generation");
            to_chip(anchor+96); read_release=1; step();
            assert(drq && int'(generation)==3) else $fatal(1,"release acknowledged newer DR");
            read_once();
            for(int i=3;i<6;i++) begin to_chip(anchor+32*(i+1)); read_once(); end
            to_chip(anchor+224); assert(done && lost) else $fatal(1,"held read recovery");
        end
        // Service/arrival tie captures old DR, leaves new DR pending; read
        // release+accept on one edge begins a fresh response generation.
        scenario++; length=2; begin_read=1; step();
        begin : ties
            integer anchor;
            anchor=chip_edges; to_chip(anchor+32); to_chip(anchor+63);
            while((cycles%divider)!=0) step();
            read_accept=1; step();
            assert(arrival && response_data==payload(0) && response_generation==1 && drq && !lost)
                else $fatal(1,"read/arrival tie policy");
            read_release=1; read_accept=1; step();
            assert(response_data==payload(1) && response_generation==2 && !drq)
                else $fatal(1,"same-edge response replacement");
            read_release=1; step(); to_chip(anchor+96);
            // Next SYS after done must restart despite registered internal stop.
            length=1; begin_read=1; step(); anchor=chip_edges;
            to_chip(anchor+32); read_once(); to_chip(anchor+64);
            assert(done && !lost) else $fatal(1,"immediate read restart");
            length=2; arm_write=1; step(); put(8'ha5); launch_write=1; step(); anchor=chip_edges;
            to_chip(anchor+31); while((cycles%divider)!=0) step();
            write_value=8'h3c; write_accept=1; step();
            assert(write_emit && write_byte==8'h3c && !lost) else $fatal(1,"write/load tie policy");
            to_chip(anchor+64); assert(done) else $fatal(1,"write tail complete");
            length=1; arm_write=1; step();
            write_value=8'hd2; write_accept=1; launch_write=1; step(); anchor=chip_edges;
            to_chip(anchor+32); assert(done && !lost) else $fatal(1,"prefill/launch restart");
        end
        // External stop beats launch/service and consumes no stream byte.
        length=2; arm_write=1; step(); put(8'hb1);
        stop=1; launch_write=1; write_accept=1; step();
        assert(!active && !write_emit && !drq) else $fatal(1,"external stop priority");
        // Read/write abort and reset cancel partial slots; no stale boundaries.
        for(int w=0;w<2;w++) for(int r=0;r<2;r++) begin
            length=128;
            if(w!=0) begin arm_write=1; step(); put(8'he5); launch_write=1; step(); end
            else begin begin_read=1; step(); end
            to_chip(chip_edges+17);
            if(r!=0) reset=1; else stop=1;
            step(); reset=0;
            repeat(70*divider) step();
            assert(!active && !drq) else $fatal(1,"abort/reset stale stream");
            length=1; begin_read=1; step(); to_chip(chip_edges+32); read_once(); to_chip(due);
        end
        $display("PASS stream adapter divider=%0d cases=%0d arrivals=%0d writes=%0d acks=%0d held/ties/restart/abort/reset",divider,cases,observed_arrivals,observed_writes,observed_acks);
        $finish;
    end
    initial begin #500000000; $fatal(1,"stream fixture timeout"); end
endmodule
