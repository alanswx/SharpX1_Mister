`timescale 1ns/1ps
// Original raw-bus + external-DR fixture. Not CPU, WD, SD or native timing.
// The ONLY physical DR owner is this fixture's SYS process. Its explicit
// read-arrival-over-store tie priority is a diagnostic policy, not chip law.
module fdc_stream_external_dr_tb;
    reg clk=0;
    always #15.625 clk=~clk;
    reg reset=0, ce=0, begin_read=0, arm_write=0, launch_write=0, stop=0;
    reg bus_reset=0, owner_reset=0, bus_ce=1, selected=1, rd=0, wr=0;
    reg [1:0] port=3;
    reg [7:0] din=0, physical_dr=0;
    reg [10:0] length=0;
    reg previous_rd=0;
    wire bus_read_accept, bus_write_accept, read_accept, write_accept;
    wire [7:0] bus_response, read_value, captured_write, accepted_write_value;
    wire [7:0] source_byte, dr_value, read_dr_value, response_data, write_byte;
    wire read_dr_load, drq, active, armed, lost, done, initial_abort;
    wire response_valid, read_ack, arrival, write_emit;
    wire [10:0] byte_index, generation, response_generation, write_index;
    wire read_release=previous_rd && !rd;
    wire [7:0] write_value=accepted_write_value;
    assign bus_response=(port==3)?dr_value:8'h60;
    assign read_accept=bus_read_accept && port==3;
    assign write_accept=bus_write_accept && port==3;
    x1_fdc_bus_events bus_events(.clk(clk),.reset(bus_reset),.bus_ce(bus_ce),.selected(selected),
        .rd(rd),.wr(wr),.response(bus_response),.write_value(din),.read_accept(bus_read_accept),
        .write_accept(bus_write_accept),.read_value(read_value),.captured_write(captured_write),
        .accepted_write_value(accepted_write_value));
    x1_fdc_stream_adapter #(.EXTERNAL_DR(1)) dut(.*,.fdc_ce(ce));
    always @(posedge clk) begin
        previous_rd<=rd;
        if(owner_reset) physical_dr<=0;
        else if(read_dr_load) physical_dr<=read_dr_value;
        else if(write_accept) physical_dr<=accepted_write_value;
    end
    integer divider=16, cycles=0, chips=0, due=0, scenario=0, cases=0;
    integer arrivals=0, loads=0, acks=0, stores=0, ties=0;
    bit force_ce=0, paused=0, running=0;
    bit ra=0, rwmode=0, rf=0, rarmed=0, rloss=0, rrvalid=0;
    bit read_seen=0, write_seen=0;
    reg [7:0] r_dr=0, r_response=0, r_bus_response=0, r_captured_write=0;
    integer r_remaining=0, r_index=0, r_generation=0, r_response_generation=0;
    function automatic [7:0] payload(input integer i);
        return 8'((i*73)^(i>>3)^(scenario*19)^8'h91);
    endfunction
    assign source_byte=payload(int'(byte_index));
    task automatic step;
        bit br, bw, accept_read, accept_write, read_event, consume_read, consume_write;
        bit is_due, load_dr, emit, complete, aborted, acked;
        reg [7:0] old_dr, emitted_byte;
        integer emitted_index;
        @(negedge clk);
        ce=force_ce || (!paused && cycles%divider==0); force_ce=0;
        br=!bus_reset && bus_ce && selected && rd && !wr && !read_seen;
        bw=!bus_reset && bus_ce && selected && wr && !rd && !write_seen;
        #1;
        assert(bus_read_accept==br && bus_write_accept==bw &&
               accepted_write_value==(bw?din:r_captured_write)) else $fatal(1,"raw bus first-event/bypass mismatch");
        accept_read=br && port==3; accept_write=bw && port==3;
        old_dr=r_dr;
        is_due=running && ce && chips+1==due;
        if(ce) chips++;
        load_dr=!reset && !stop && !begin_read && !arm_write && ra && !rwmode && is_due && r_remaining>0;
        assert(read_dr_load==load_dr && (!load_dr || read_dr_value==payload(r_index)))
            else $fatal(1,"same-edge physical DR load intent/value mismatch SYS=%0d",cycles);
        read_event=accept_read && (!rrvalid || read_release);
        consume_read=read_event && !rwmode && rf;
        consume_write=accept_write && rwmode && (rarmed || (ra && r_remaining>0)) && !rf;
        emit=0; complete=0; aborted=0; acked=0; emitted_byte=0; emitted_index=0;
        if(bus_reset) begin read_seen=0; write_seen=0; r_bus_response=0; r_captured_write=0; end
        else begin
            if(!rd) read_seen=0;
            else if(br) begin read_seen=1; r_bus_response=(port==3)?old_dr:8'h60; end
            if(!wr) write_seen=0;
            else if(bw) begin write_seen=1; r_captured_write=din; end
        end
        if(reset) begin
            ra=0; rarmed=0; rwmode=0; rf=0; r_remaining=0; rloss=0;
            r_index=0; r_generation=0; rrvalid=0; r_response=0; r_response_generation=0; running=0;
        end else begin
            if(read_release) rrvalid=0;
            if(read_event) begin rrvalid=1; r_response=old_dr; r_response_generation=r_generation; end
            if(stop) begin ra=0; rarmed=0; rf=0; r_remaining=0; running=0; end
            else if(begin_read || arm_write) begin
                ra=begin_read; rarmed=arm_write; rwmode=arm_write; rf=0;
                r_remaining=int'(length); rloss=0; r_index=0; r_generation=0; rrvalid=0;
                running=begin_read; due=chips+32;
            end else begin
                if(consume_read) begin rf=0; acked=1; end
                if(consume_write) rf=1;
                if(launch_write && rarmed) begin
                    rarmed=0;
                    if(!rf) begin rloss=1; aborted=1; complete=1; r_remaining=0; end
                    else begin
                        emit=1; emitted_byte=consume_write?din:old_dr; emitted_index=0;
                        rf=0; ra=1; r_remaining--; r_index=1; r_generation=1;
                        running=1; due=chips+32;
                    end
                end else if(ra && is_due) begin
                    due+=32;
                    if(r_remaining>0) begin
                        if(rwmode) begin
                            emit=1; emitted_index=r_index;
                            emitted_byte=rf ? (consume_write?din:old_dr) : 8'd0;
                            if(!rf) rloss=1;
                            rf=0;
                        end else begin if(rf) rloss=1; rf=1; end
                        r_remaining--; r_index++; r_generation++;
                    end else begin
                        if(!rwmode && rf) rloss=1;
                        rf=0; ra=0; running=0; complete=1;
                    end
                end
            end
        end
        // Owner model is independent of write_emit/registered arrival.
        if(owner_reset) r_dr=0;
        else if(load_dr) begin r_dr=payload(r_index-1); if(accept_write) ties++; end
        else if(accept_write) r_dr=din;
        if(accept_write) stores++;
        @(posedge clk); #1;
        assert(physical_dr==r_dr && dr_value==r_dr) else $fatal(1,"authoritative physical DR mismatch");
        assert(read_value==(read_seen?r_bus_response:((port==3)?r_dr:8'h60)))
            else $fatal(1,"raw held response changed");
        assert(captured_write==r_captured_write) else $fatal(1,"raw captured write mismatch");
        assert(active==ra && armed==rarmed && lost==rloss && done==complete && initial_abort==aborted &&
               arrival==load_dr && write_emit==emit) else $fatal(1,"external stream slot/state/loss mismatch SYS=%0d",cycles);
        assert(read_ack==acked && response_valid==rrvalid && response_data==r_response &&
               int'(response_generation)==r_response_generation) else $fatal(1,"external response/generation mismatch");
        assert(int'(byte_index)==r_index && int'(generation)==r_generation &&
               drq==(rwmode?((rarmed || (ra && r_remaining>0)) && !rf):rf))
            else $fatal(1,"external DRQ/generation mismatch");
        if(emit) begin
            assert(write_byte==emitted_byte && int'(write_index)==emitted_index)
                else $fatal(1,"external captured DSR/zero mismatch");
            loads++;
        end
        if(load_dr) arrivals++;
        if(acked) acks++;
        cycles++;
        begin_read=0; arm_write=0; launch_write=0; stop=0;
    endtask
    task automatic to_chip(input integer target);
        while(chips<target) step();
    endtask
    task automatic release_bus;
        rd=0; wr=0; bus_ce=0; step(); bus_ce=1;
    endtask
    task automatic put(input [7:0] value);
        port=3; selected=1; wr=1; rd=0; bus_ce=1; din=value; step(); release_bus();
    endtask
    task automatic get;
        port=3; selected=1; rd=1; wr=0; bus_ce=1; step(); release_bus();
    endtask
    task automatic read_stream(input integer n, input integer missing);
        integer anchor;
        scenario++; length=11'(n); begin_read=1; step(); anchor=chips;
        for(int i=0;i<n;i++) begin
            to_chip(anchor+32*(i+1));
            if(i!=missing) begin to_chip(anchor+32*(i+1)+1+(i%20)); get(); end
        end
        to_chip(anchor+32*(n+1));
        assert(done && lost==(missing>=0) && physical_dr==payload(n-1)) else $fatal(1,"external read final/readback");
        cases++;
    endtask
    task automatic write_stream(input integer n, input integer missing);
        integer anchor;
        scenario++; length=11'(n); arm_write=1; step(); put(payload(0)); launch_write=1; step(); anchor=chips;
        for(int i=1;i<n;i++) begin
            if(i!=missing) begin to_chip(anchor+32*(i-1)+1+(i%20)); put(payload(i)); end
            to_chip(anchor+32*i);
        end
        to_chip(anchor+32*n); assert(done && lost==(missing>=0)) else $fatal(1,"external write final"); cases++;
    endtask
    initial begin
        if($value$plusargs("divider=%d",divider)) begin end
        assert(divider==16 || divider==32) else $fatal(1,"explicit 1/2 MHz enables only");
        reset=1; bus_reset=1; owner_reset=1; step(); reset=0; bus_reset=0; owner_reset=0;
        put(8'hc7); get(); assert(read_value==8'hc7 && physical_dr==8'hc7 && !read_ack)
            else $fatal(1,"idle DR write/readback");
        for(int n=128;n<=1024;n*=2) begin
            read_stream(n,-1); read_stream(n,0); read_stream(n,n/2); read_stream(n,n-1);
            write_stream(n,-1); write_stream(n,n/2); write_stream(n,n-1);
        end
        read_stream(6,-1); read_stream(6,0); read_stream(6,3); read_stream(6,5);
        // Non-DRQ prefilled store replaces authoritative DR before launch.
        length=2; arm_write=1; step(); put(8'ha5); assert(!drq) else $fatal(1,"prefill");
        put(8'hb6); launch_write=1; step();
        assert(write_byte==8'hb6) else $fatal(1,"non-DRQ prefill replacement ignored");
        begin : raw_writes
            integer anchor;
            anchor=chips;
            // Status-register store must not fill adapter DR or physical DR.
            port=0; wr=1; din=8'he9; step(); release_bus();
            assert(drq && physical_dr==8'hb6) else $fatal(1,"non-data acceptance leaked");
            // Hold raw write before bus CE eligibility: no premature store.
            port=3; wr=1; bus_ce=0; din=8'h11; repeat(5) step();
            bus_ce=1; din=8'h7d; step(); bus_ce=0; din=8'h34;
            to_chip(anchor+32);
            assert(write_byte==8'h7d && physical_dr==8'h7d && !drq) else $fatal(1,"same-edge DIN capture/held store");
            release_bus(); put(8'hd8); // tail has DRQ low; owner still stores
            to_chip(anchor+64);
            assert(done && !lost && physical_dr==8'hd8) else $fatal(1,"tail store disturbed DSR completion");
        end
        // No initial byte despite a nonzero physical DR: valid is separate.
        length=128; arm_write=1; step(); launch_write=1; step();
        assert(initial_abort && !write_emit && physical_dr==8'hd8) else $fatal(1,"missing prefill/DR confused");
        length=2; arm_write=1; step(); put(8'hac); launch_write=1; step();
        to_chip(chips+32);
        assert(write_emit && write_byte==0 && physical_dr==8'hac && lost)
            else $fatal(1,"underrun zero altered DR");
        to_chip(chips+32);
        // Immediate next SYS restart WITH CE asserted: exactly 32 future CE.
        force_ce=1; length=2; begin_read=1; step();
        begin : raw_reads
            integer anchor;
            reg [7:0] held;
            anchor=chips;
            // Data read before arrival consumes retained physical DR, not zero.
            port=3; rd=1; bus_ce=1; step(); held=read_value;
            assert(held==8'hac && !read_ack) else $fatal(1,"pre-arrival external response");
            bus_ce=0; to_chip(anchor+32); to_chip(anchor+64); to_chip(anchor+96);
            assert(done && lost && read_value==held) else $fatal(1,"held read completion");
            // New command invalidates adapter response, never raw bus capture.
            force_ce=1; length=1; begin_read=1; step(); anchor=chips;
            to_chip(anchor+32); assert(read_value==held && drq) else $fatal(1,"held response across new command");
            release_bus(); assert(drq) else $fatal(1,"late release acknowledged new generation");
            get(); to_chip(anchor+64); assert(done && !lost) else $fatal(1,"post-release recovery");
        end
        // Illegal DATA store/read-arrival tie: explicitly read-load wins in
        // fixture owner, and load intent must be consumed on that SAME edge.
        length=1; begin_read=1; step();
        begin : arrival_store_tie
            integer anchor;
            anchor=chips; to_chip(anchor+31); while(cycles%divider!=0) step();
            port=3; wr=1; din=8'hee; step();
            assert(arrival && physical_dr==payload(0) && drq && ties==1)
                else $fatal(1,"explicit owner collision policy");
            release_bus(); get(); to_chip(anchor+64);
        end
        // Stop/reset cancel slots; raw held response belongs to bus helper.
        for(int r=0;r<2;r++) begin
            length=2; begin_read=1; step(); to_chip(chips+32);
            port=3; rd=1; bus_ce=1; step(); bus_ce=0;
            if(r!=0) reset=1; else stop=1;
            step(); reset=0;
            repeat(70*divider) step();
            assert(!active && !drq && read_value==r_bus_response) else $fatal(1,"cancel/held response ownership");
            release_bus();
        end
        // Paused chip clock preserves partial-slot phase independently of bus.
        length=1; begin_read=1; step(); to_chip(chips+17);
        paused=1; repeat(80) step(); paused=0; to_chip(due); get(); to_chip(due);
        // Real same-edge accepted DATA write + initial launch, then a second
        // accepted DATA write exactly at the periodic load. Owner updates DR
        // post-edge, so adapter MUST bypass the accepted DIN on this edge.
        length=2; arm_write=1; step();
        port=3; wr=1; rd=0; bus_ce=1; din=8'hd2; launch_write=1; step();
        assert(write_emit && write_byte==8'hd2 && physical_dr==8'hd2)
            else $fatal(1,"same-edge external initial write bypass");
        begin : same_edge_write
            integer anchor;
            anchor=chips; release_bus(); to_chip(anchor+31);
            while(cycles%divider!=0) step();
            wr=1; din=8'h39; step();
            assert(write_emit && write_byte==8'h39 && physical_dr==8'h39)
                else $fatal(1,"same-edge external periodic write bypass");
            release_bus(); to_chip(anchor+64);
            assert(done && !lost) else $fatal(1,"same-edge writes completion");
        end
        $display("PASS external DR raw-bus divider=%0d cases=%0d arrivals=%0d loads=%0d acks=%0d stores=%0d ties=%0d",divider,cases,arrivals,loads,acks,stores,ties);
        $finish;
    end
    initial begin #500000000; $fatal(1,"external DR fixture timeout"); end
endmodule
