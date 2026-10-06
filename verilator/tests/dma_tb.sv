// SPDX-License-Identifier: GPL-2.0-or-later
// Original register-stream and synthetic bus-host fixture; no firmware bytes.
`timescale 1ns/1ps
module dma_tb;
    logic clk=0, ce=0, reset=1;
    always #5 clk=~clk;
    logic cpu_cs=0, cpu_rd_n=1, cpu_wr_n=1;
    logic [7:0] cpu_data_in=0, cpu_data_out;
    logic busrq_n, busak_n=1, mreq_n, iorq_n, rd_n, wr_n;
    logic [15:0] address;
    logic [7:0] data_out, data_in;
    logic wait_n=1, rdy=0, unsupported;
    x1_dma dut(.*);

    logic [7:0] memory [0:65535];
    integer clock_edges=0, ce_period=1, ack_delay=4, ack_counter=0;
    integer reads=0, writes=0, io_reads=0, io_writes=0, grants=0;
    integer tests=0, ack_ce_edges=0, strobe_ce_edges=0;
    integer stop_after_writes=0;
    logic pause_ce=0, allow_ack=1;
    logic previous_rd=1, previous_wr=1, previous_io=0;
    logic [15:0] previous_address;
    logic [7:0] previous_data;
    logic [7:0] io_log [0:65537];
    logic [15:0] write_log [0:65537];
    logic [15:0] read_log [0:65537];
    logic [7:0] write_data_log [0:65537];
    assign data_in = !iorq_n ? (8'(io_reads) ^ 8'ha6) : memory[address];
    always @(posedge clk) if (ce) begin
        if (!busak_n && !busrq_n) ack_ce_edges=ack_ce_edges+1;
        else ack_ce_edges=0;
        if (!rd_n || !wr_n) strobe_ce_edges=strobe_ce_edges+1;
    end

    // Side effects occur once, at strobe completion, not every held clock.
    // ACK stays granted until BUSRQ releases, then remains low three clocks.
    always @(negedge clk) begin
        clock_edges = clock_edges+1;
        if (clock_edges>25000000) $fatal(1,"fixture watchdog state=%0d reads=%0d writes=%0d rate=%0d",dut.state,reads,writes,ce_period);
        ce = !pause_ce && (clock_edges % ce_period == 0);
        if (!rd_n || !wr_n) begin
            if (busak_n || busrq_n) $fatal(1,"bus strobe without ownership");
            if (ack_ce_edges<2) $fatal(1,"bus strobe before two qualified ACK edges");
            if (mreq_n == iorq_n) $fatal(1,"bad memory/I/O strobes");
            if (!rd_n && !wr_n) $fatal(1,"simultaneous read/write");
        end
        if (!previous_rd && rd_n) begin
            if (strobe_ce_edges < (previous_io?4:3)) $fatal(1,"short read cycle");
            read_log[reads] = previous_address;
            reads = reads+1;
            if (previous_io) io_reads = io_reads+1;
        end
        if (!previous_wr && wr_n) begin
            if (strobe_ce_edges < (previous_io?4:3)) $fatal(1,"short write cycle");
            write_log[writes] = previous_address;
            write_data_log[writes] = previous_data;
            if (previous_io) begin
                io_log[io_writes] = previous_data;
                io_writes = io_writes+1;
            end else memory[previous_address] = previous_data;
            writes = writes+1;
            if(stop_after_writes!=0 && writes==stop_after_writes) rdy=1;
        end
        if (!rd_n || !wr_n) begin
            if (previous_rd && previous_wr) strobe_ce_edges=0;
            if ((!previous_rd && !rd_n) || (!previous_wr && !wr_n)) begin
                if (address != previous_address || data_out != previous_data ||
                    !iorq_n != previous_io)
                    $fatal(1,"pending bus cycle changed");
            end
            previous_address = address;
            previous_data = data_out;
            previous_io = !iorq_n;
        end
        previous_rd = rd_n; previous_wr = wr_n;
        if (busrq_n) begin
            if (!busak_n) begin
                if (ack_counter >= 3) begin busak_n=1; ack_counter=0; end
                else ack_counter=ack_counter+1;
            end else ack_counter=0;
        end else if (allow_ack && busak_n) begin
            if (ack_counter >= ack_delay) begin
                busak_n=0; ack_counter=0; grants=grants+1;
            end else ack_counter=ack_counter+1;
        end
    end

    task automatic tick;
        @(posedge clk); #1;
    endtask
    task automatic ctick;
        do tick(); while (!ce);
    endtask
    task automatic put(input logic [7:0] value);
        @(negedge clk); #1;
        cpu_cs=1; cpu_wr_n=0; cpu_data_in=value;
        repeat (4) ctick(); // deliberately stretched: exactly one write
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1;
        ctick();
    endtask
    task automatic get(output logic [7:0] value);
        @(negedge clk); #1; cpu_cs=1; cpu_rd_n=0;
        ctick(); value=cpu_data_out;
        repeat (3) begin ctick(); if (cpu_data_out !== value) $fatal(1,"held read changed"); end
        @(negedge clk); #1; cpu_cs=0; cpu_rd_n=1;
        ctick();
    endtask
    task automatic fresh;
        reset=1; pause_ce=0; wait_n=1; rdy=0; allow_ack=1;
        cpu_cs=0; cpu_rd_n=1; cpu_wr_n=1;
        repeat (5) tick(); reset=0;
        repeat (6) ctick();
        reads=0; writes=0; io_reads=0; io_writes=0; grants=0;
        stop_after_writes=0;
        for (integer j=0; j<65536; j=j+1) memory[j]=8'(j) ^ 8'(j>>8) ^ 8'h5d;
    endtask
    task automatic configure(input logic [15:0] a,b,n,
        input logic [7:0] ac,bc,mode,ready_config,
        input logic a_source);
        put(a_source ? 8'h7d : 8'h79);
        put(a[7:0]); put(a[15:8]); put(n[7:0]); put(n[15:8]);
        put(ac); put(bc); put(8'h80);
        put(8'h8d | mode); put(b[7:0]); put(b[15:8]);
        put(ready_config);
        if (!busrq_n || reads != 0 || writes != 0) $fatal(1,"programming requested bus");
    endtask
    task automatic read_word(input logic [7:0] mask, output logic [15:0] value);
        logic [7:0] lo,hi;
        put(8'hbb); put(mask); put(8'ha7); get(lo); get(hi); value={hi,lo};
    endtask
    task automatic idle;
        integer timeout;
        timeout=0;
        while (!(busrq_n && busak_n && dut.state == dut.IDLE)) begin
            tick(); timeout=timeout+1;
            if (timeout>12000000) $fatal(1,"timeout state=%0d writes=%0d",dut.state,writes);
        end
        repeat (2) tick();
    endtask
    task automatic finish_block;
        integer timeout;
        timeout=0;
        while (!dut.end_of_block) begin
            tick(); timeout=timeout+1;
            if (timeout>12000000) $fatal(1,"EOB timeout state=%0d writes=%0d",dut.state,writes);
        end
        idle();
    endtask
    task automatic check(input logic condition, input string label_text);
        if (!condition) $fatal(1,"FAIL %s period=%0d",label_text,ce_period);
    endtask
    task automatic passed(input string label_text);
        tests=tests+1;
        $display("PASS period=%0d %s",ce_period,label_text);
        $fflush();
    endtask

    task automatic parser_checks;
        logic [7:0] value;
        logic [15:0] retained;
        // Every WR0 pointer subset, payload looks like WR6 commands.
        for (integer bits=0; bits<16; bits=bits+1) begin
            fresh(); put(8'h05 | (8'(bits)<<3));
            if ((bits & 1) != 0) put(8'hc3);
            if ((bits & 2) != 0) put(8'h83);
            if ((bits & 4) != 0) put(8'h87);
            if ((bits & 8) != 0) put(8'hbb);
            check(dut.follows==0 && dut.start_a ==
                  {((bits&2)!=0 ? 8'h83 : 8'h00),((bits&1)!=0 ? 8'hc3 : 8'h00)},"WR0 queue");
            check(dut.length == {((bits&8)!=0 ? 8'hbb : 8'h00),((bits&4)!=0 ? 8'h87 : 8'h00)},"WR0 length data");
        end
        fresh(); put(8'h54); put(8'h83); put(8'h50); put(8'h87);
        check(dut.timing_a==8'h83 && dut.timing_b==8'h87 && unsupported,"timing grammar/reject");
        put(8'hc7); put(8'hcb); check(unsupported,"reserved WR0 remains unsupported");
        put(8'h05); check(!unsupported,"timing reset restores standard transfer");
        passed("WR0 subsets and timing follow bytes");
        for (integer nested=0; nested<4; nested=nested+1) begin
            fresh(); put(8'h98); put(8'hc3); put(8'h87);
            check(dut.mask_byte==8'hc3 && dut.match_byte==8'h87,"WR3 follows");
            put(8'h9d); put(8'h83); put(8'hbb); put(8'(nested)<<3);
            if ((nested & 1) != 0) put(8'hc3);
            if ((nested & 2) != 0) put(8'h87);
            check(dut.start_b==16'hbb83 && dut.follows==0,"WR4 nested queue");
            if ((nested & 1) != 0) check(dut.pulse_control==8'hc3,"pulse follow");
            if ((nested & 2) != 0) check(dut.interrupt_vector==8'h87,"vector follow");
        end
        // Interrupt a five-byte WR4 stream at every position; six C3 recover.
        for (integer position=0; position<=5; position=position+1) begin
            fresh(); put(8'h9d);
            for (integer j=0; j<position; j=j+1) put(j==2 ? 8'h18 : 8'h87);
            repeat (6) put(8'hc3);
            check(dut.follows==0 && !dut.enabled && !dut.bad_command,"six RESET recovery");
        end
        fresh(); put(8'hbb); put(8'h83);
        check(dut.read_mask==3 && dut.bad_command,"read mask payload not DISABLE");
        fresh(); put(8'h7d); get(value);
        check(dut.follows==14'hf,"read does not consume pending write queue");
        put(8'hc3); put(8'h83); put(8'h87); put(8'hbb);
        check(dut.start_a==16'h83c3 && dut.length==16'hbb87,"command payload after intervening read");
        passed("WR3/WR4 nested grammar, BB and six-RESET recovery");
        fresh(); configure(16'h1234,16'habcd,16'd1,8'h14,8'h10,0,8'h92,1);
        put(8'hcf); read_word(8'h18,retained); check(retained==16'h1234,"LOAD source readback");
        put(8'hbb); put(8'h7f); put(8'ha7);
        get(value); check((value & 8'h3b)==8'h3a,"status defined bits before grant");
        get(value); check(value==0,"RR1"); get(value); check(value==0,"RR2");
        get(value); check(value==8'h34,"RR3"); get(value); check(value==8'h12,"RR4");
        get(value); check(value==0,"RR5 destination not LOADed"); get(value); check(value==0,"RR6");
        get(value); check((value&8'h3b)==8'h3a,"read sequence wraps");
        put(8'hbb); put(8'h08); put(8'ha7); repeat(3) begin get(value); check(value==8'h34,"single read repeats"); end
        put(8'hc3); idle(); get(value); check(value==8'h34,"software RESET retains read sequence");
        passed("read masks/order/wrap/stretch and partial software RESET");
        // Fail closed: search, IRQ, forbidden mode, command/timing.
        for (integer option_id=0; option_id<5; option_id=option_id+1) begin
            fresh(); configure(16'h100,16'h200,1,8'h14,8'h10,0,8'h92,1); put(8'hcf);
            case(option_id)
                0: begin put(8'ha1); put(8'h07); put(8'h84); end // Sequential non-Byte match-stop still unresolved.
                1: put(8'ha0);
                2: put(8'he1);
                3: put(8'hb7);
                4: begin put(8'h54); put(8'hc0); end
            endcase
            put(8'h87); repeat(15) ctick();
            check(unsupported && busrq_n && writes==0,"unsupported ENABLE blocked");
        end
        passed("unsupported search/IRQ/mode/RETI/timing cannot enable");
    endtask

    task automatic memory_checks;
        logic [15:0] a_read,b_read,count_read;
        integer total;
        // inc/dec/fixed in each direction, variable wrap and primary counters.
        for (integer direction=0; direction<2; direction=direction+1)
            for (integer am=0; am<3; am=am+1)
                for (integer bm=0; bm<3; bm=bm+1) begin
                    fresh();
                    configure(16'hfffe,16'h0010,3,
                        am==0?8'h14:am==1?8'h04:8'h24,
                        bm==0?8'h10:bm==1?8'h00:8'h20,8'h20,8'h92,1'(direction));
                    // Preload fixed destination as a temporary source.
                    put(direction!=0 ? 8'h01 : 8'h05); put(8'hcf);
                    put(direction!=0 ? 8'h05 : 8'h01); put(8'hcf);
                    put(8'h87); finish_block();
                    check(reads==4 && writes==4,"address-mode pair count");
                    for (integer j=0; j<4; j=j+1) begin
                        logic [15:0] expected_address;
                        logic [15:0] expected_source;
                        integer dm,sm;
                        dm=direction!=0 ? bm : am;
                        expected_address=(direction!=0 ? 16'h0010 : 16'hfffe) +
                            16'(dm==0 ? j : dm==1 ? -j : 0);
                        check(write_log[j]==expected_address,"destination address sequence");
                        sm=direction!=0 ? am : bm;
                        expected_source=(direction!=0 ? 16'hfffe : 16'h0010) +
                            16'(sm==0 ? j : sm==1 ? -j : 0);
                        check(read_log[j]==expected_source,"source address sequence");
                        check(write_data_log[j]==(expected_source[7:0]^expected_source[15:8]^8'h5d),"address-mode payload");
                    end
                    read_word(8'h18,a_read); read_word(8'h60,b_read); read_word(8'h06,count_read);
                    check(count_read==3,"Table11 stopped byte count");
                    check(a_read==16'hfffe + 16'(am==0 ? (direction!=0?4:3) : am==1 ? -(direction!=0?4:3) : 0),"A source-next/dest-last");
                    check(b_read==16'h0010 + 16'(bm==0 ? (direction!=0?3:4) : bm==1 ? -(direction!=0?3:4) : 0),"B source-next/dest-last");
                end
        passed("18 direction/address combinations with wrap and primary readback");
        fresh(); configure(16'h1000,16'h3000,1,8'h14,8'h10,8'h20,8'h92,1);
        put(8'hcf); put(8'h87); finish_block();
        check(memory[16'h3000]==memory[16'h1000] && memory[16'h3001]==memory[16'h1001],"memory copy payload");
        put(8'hd3); repeat(8) ctick(); check(writes==2 && busrq_n,"CONTINUE is not ENABLE");
        // Changing start registers without LOAD must not alter live counters.
        put(8'h1d); put(8'haa); put(8'hbb); put(8'h8d); put(8'hcc); put(8'hdd);
        put(8'h87); finish_block();
        check(writes==4 && write_log[2]==16'h3002 && write_log[3]==16'h3003,"CONTINUE no duplicate boundary or implicit reload");
        check(memory[16'h3002]==memory[16'h1002] && memory[16'h3003]==memory[16'h1003],"continued payload");
        passed("memory payload, CONTINUE and start/live separation");
        for (integer big=0; big<3; big=big+1) begin
            fresh(); configure(16'h2200,16'h4400,big==0?16'd255:big==1?16'hffff:16'h0000,
                8'h24,8'h20,8'h20,8'h92,1);
            put(8'h01); put(8'hcf); put(8'h05); put(8'hcf); put(8'h87);
            finish_block(); total=big==0?256:big==1?65536:65537;
            check(writes==total && reads==total,"256/65536/65537 total");
            read_word(8'h06,count_read);
            check(count_read==(big==0?16'd255:big==1?16'hffff:16'h0000),"large terminal count readback");
        end
        passed("N=255/65535 and primary special zero=65537");
    endtask

    task automatic io_and_ownership_checks;
        logic [7:0] status_value;
        logic [15:0] fixed_value;
        integer before_writes;
        logic [31:0] held_bus;
        for(integer direction=0; direction<2; direction=direction+1)
            for(integer kinds=0; kinds<4; kinds=kinds+1) begin
                fresh();
                configure(16'h1200,16'h2400,2,
                    kinds[0]?8'h2c:8'h14,kinds[1]?8'h28:8'h10,
                    8'h20,8'h92,1'(direction));
                put(direction!=0 ? 8'h01:8'h05); put(8'hcf);
                put(direction!=0 ? 8'h05:8'h01); put(8'hcf); put(8'h87);
                finish_block(); check(writes==3 && reads==3,"memory/I/O matrix count");
                for(integer j=0; j<3; j=j+1) begin
                    logic source_io,dest_io;
                    logic [15:0] source_addr,dest_addr;
                    source_io=direction!=0?kinds[0]:kinds[1];
                    dest_io=direction!=0?kinds[1]:kinds[0];
                    source_addr=(direction!=0?16'h1200:16'h2400)+16'(source_io?0:j);
                    dest_addr=(direction!=0?16'h2400:16'h1200)+16'(dest_io?0:j);
                    check(read_log[j]==source_addr && write_log[j]==dest_addr,"memory/I/O matrix addresses");
                    check(write_data_log[j]==(source_io?(8'(j)^8'ha6):(source_addr[7:0]^source_addr[15:8]^8'h5d)),"memory/I/O matrix payload");
                end
            end
        passed("both directions and all memory/I/O pairings, original payloads");
        // Fixed I/O destination must NOT be eagerly loaded by true-source LOAD.
        fresh(); configure(16'h1100,16'h0042,1,8'h14,8'h28,0,8'h92,1);
        put(8'hcf); read_word(8'h60,fixed_value); check(fixed_value==0,"fixed destination requires workaround");
        put(8'h01); put(8'hcf); put(8'h05); put(8'hcf);
        read_word(8'h60,fixed_value); check(fixed_value==16'h42,"temporary-source LOAD");
        put(8'h87); finish_block();
        check(io_writes==2 && write_log[0]==16'h42 && write_log[1]==16'h42,"fixed I/O writes");
        check(io_log[0]==memory[16'h1100] && io_log[1]==memory[16'h1101],"I/O destination payload");
        passed("fixed I/O destination two LOADs, native-IPL prerequisite");
        // I/O source, variable memory destination, paced one byte per DRQ.
        fresh(); rdy=1;
        configure(16'h0042,16'h5000,3,8'h2c,8'h10,0,8'h92,1); put(8'hcf); put(8'h87);
        repeat(10) ctick(); check(busrq_n && reads==0,"inactive low Ready gap");
        for (integer j=0; j<4; j=j+1) begin
            rdy=0;
            while (rd_n) tick();
            rdy=1; // Ready loss during read must still complete paired write.
            while(writes<=j) tick(); idle();
            check(memory[16'h5000+16'(j)]==(8'(j)^8'ha6),"DRQ FIFO payload");
            repeat(8) ctick(); check(writes==j+1 && busrq_n,"DRQ gap no free running");
        end
        check(grants==4 && io_reads==4,"byte grant and I/O read counts");
        passed("byte-mode DRQ-paced I/O and Ready loss during read");
        for (integer mode_id=0; mode_id<2; mode_id=mode_id+1) begin
            fresh(); rdy=1;
            configure(16'h6000,16'h7000,3,8'h14,8'h10,mode_id==0?8'h40:8'h20,8'h9a,1);
            put(8'hcf); put(8'h87);
            while(wr_n) tick(); rdy=0;
            while(writes==0) tick(); repeat(12) ctick();
            check(writes==1 && rd_n && wr_n,"Ready loss write/idle pauses pairs");
            check(mode_id==0 ? busrq_n : !busrq_n,"burst release / continuous hold");
            rdy=1; finish_block(); check(writes==4,"high Ready resume");
            check(mode_id==0 ? grants==2 : grants==1,"mode grant count");
        end
        passed("active-high burst/continuous ownership and Ready gaps");
        fresh(); rdy=1; configure(16'h1000,16'h2000,3,8'h14,8'h10,0,8'h92,1);
        put(8'hcf); put(8'hb3); put(8'hbf); get(status_value);
        check((status_value&2)==0,"status reflects pin Ready, not Force Ready");
        put(8'h87); while(writes==0) tick(); idle(); repeat(12) ctick();
        check(writes==1 && !dut.force_ready,"Force Ready clears on byte release");
        put(8'h83); idle();
        passed("Force Ready one byte, status D1 explicit primary-prose policy");
        // No byte transfer when Ready falls before delayed grant. Continuous
        // mode may retain a request on a pulse but must pause actual cycles.
        for(integer mode_id=0; mode_id<3; mode_id=mode_id+1) begin
            fresh(); allow_ack=0;
            configure(16'h1200,16'h2400,1,8'h14,8'h10,
                mode_id==0?8'h00:mode_id==1?8'h40:8'h20,8'h92,1);
            put(8'hcf); put(8'h87); rdy=1; repeat(8) ctick();
            if(mode_id<2) begin
                check(busrq_n && writes==0 && reads==0,"Ready loss before byte/burst grant cancels");
                rdy=0; allow_ack=1; finish_block();
            end else begin
                check(!busrq_n && reads==0,"continuous Ready pulse retains request");
                allow_ack=1; repeat(20) ctick();
                check(!busrq_n && reads==0 && rd_n && wr_n,"continuous granted idle has no strobes");
                rdy=0; finish_block();
            end
            check(writes==2,"pregrant gap resumes remaining block");
        end
        passed("Ready loss before grant in byte/burst/continuous modes");
        // WAIT both source and destination, stopped CE, delayed grant, aborts.
        for (integer abort_kind=0; abort_kind<3; abort_kind=abort_kind+1)
            for (integer phase=0; phase<2; phase=phase+1) begin
                fresh(); allow_ack=0;
                configure(16'h1200,16'h2400,3,8'h14,8'h10,8'h20,8'h92,1);
                put(8'hcf); put(8'h87); repeat(20) ctick();
                check(!busrq_n && rd_n && wr_n && reads==0,"no strobe before real ACK");
                wait_n=0; allow_ack=1;
                while(rd_n) tick();
                if (phase != 0) begin
                    wait_n=1; while(wr_n) tick(); wait_n=0;
                end
                repeat(8) ctick();
                held_bus={address,data_out,mreq_n,iorq_n,rd_n,wr_n,4'b0};
                before_writes=writes;
                repeat(8) ctick();
                check(held_bus=={address,data_out,mreq_n,iorq_n,rd_n,wr_n,4'b0} && writes==before_writes,"WAIT stable");
                pause_ce=1; repeat(20) tick();
                check(held_bus=={address,data_out,mreq_n,iorq_n,rd_n,wr_n,4'b0},"stopped CE stable");
                if (abort_kind==2) reset=1;
                repeat(6) tick();
                check(held_bus=={address,data_out,mreq_n,iorq_n,rd_n,wr_n,4'b0},"reset request does not truncate stopped cycle");
                pause_ce=0;
                if(abort_kind==0) put(8'h83);
                if(abort_kind==1) put(8'hc3);
                wait_n=1; idle();
                check(writes==1 && reads==1,"abort drains exactly one source/destination pair");
                reset=0; repeat(8) ctick(); check(writes==1 && busrq_n,"abort no restart");
            end
        passed("ACK delay, read/write WAIT, CE stop, DISABLE/software/hardware reset drain");
        fresh(); configure(16'h1800,16'h3800,1,8'h14,8'h10,0,8'h92,1);
        put(8'hcf); put(8'hc0); finish_block();
        check(writes==2,"WR3 D6 enabling exception");
        passed("WR3 enable exception");
        // Directed race checks: a control transaction wins over a new
        // request or new owned pair on that same enabled edge.
        fresh(); rdy=1;
        configure(16'h1800,16'h3800,3,8'h14,8'h10,8'h20,8'h92,1);
        put(8'hcf); put(8'h87);
        @(negedge clk); #1; rdy=0; cpu_cs=1; cpu_wr_n=0; cpu_data_in=8'hcf;
        ctick(); check(busrq_n && dut.state==dut.IDLE,"LOAD wins over concurrent request");
        repeat(3) ctick();
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; ctick();
        check(writes==0 && busrq_n,"LOAD remains disabled");
        put(8'h87); while(rd_n) tick(); rdy=1;
        while(writes==0) tick(); repeat(8) ctick();
        check(!busrq_n && dut.state==dut.PAUSE,"owned Ready-inactive gap");
        @(negedge clk); #1; rdy=0; cpu_cs=1; cpu_wr_n=0; cpu_data_in=8'h83;
        ctick(); check(dut.state==dut.PAUSE && rd_n && wr_n,"DISABLE wins over concurrent pair start");
        repeat(3) ctick();
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; ctick(); idle();
        check(reads==1 && writes==1,"boundary DISABLE does not begin another pair");
        passed("control-write precedence at request/pair boundary");
    endtask

    task automatic autorestart_checks;
        logic [15:0] a_read,b_read,count_read;
        logic [7:0] status;
        // Three repeated two-byte blocks, all ownership/address/direction
        // combinations. Pause at the exact terminal strobe completion edge.
        for(integer mode=0;mode<3;mode++)
            for(integer direction=0;direction<2;direction++)
                for(integer am=0;am<3;am++) for(integer bm=0;bm<3;bm++) begin
                    fresh();
                    configure(16'hffff,16'h3000,1,
                        am==0?8'h14:am==1?8'h04:8'h24,
                        bm==0?8'h10:bm==1?8'h00:8'h20,
                        8'(mode<<5),8'hb2,1'(direction));
                    put(direction!=0 ? 8'h01 : 8'h05);put(8'hcf);
                    put(direction!=0 ? 8'h05 : 8'h01);put(8'hcf);
                    check(!unsupported,"auto restart accepted without IRQ");
                    stop_after_writes=6;put(8'h87);
                    while(writes<6) tick();repeat(12) ctick();
                    check(reads==6 && writes==6 && !dut.end_of_block,"three repeated blocks and cleared EOB");
                    if(mode==1) check(!busrq_n && !busak_n,"continuous restart retains paused ownership");
                    else check(busrq_n,"byte/burst restart releases on inactive Ready");
                    put(8'h83);idle();
                    for(integer j=0;j<6;j++) begin
                        integer sm,dm;
                        logic [15:0] source,destination;
                        sm=direction!=0 ? am : bm;dm=direction!=0 ? bm : am;
                        source=(direction!=0 ? 16'hffff : 16'h3000)+
                            16'(sm==0 ? j%2 : sm==1 ? -(j%2) : 0);
                        destination=(direction!=0 ? 16'h3000 : 16'hffff)+
                            16'(dm==0 ? j%2 : dm==1 ? -(j%2) : 0);
                        check(read_log[j]==source && write_log[j]==destination,"auto restart address wrap/direction/fixed");
                    end
                    read_word(8'h18,a_read);read_word(8'h60,b_read);read_word(8'h06,count_read);
                    check(a_read==16'hffff && b_read==16'h3000 && count_read==0,"restart reloads both counters and byte count");
                    put(8'hbf);get(status);check(status[5],"auto restart does not latch EOB status");
                end
        passed("54 auto-restart direction/address/ownership combinations, three blocks and primary reload/status");
        // Program new buffers between byte-mode pairs, without LOAD. The
        // active second pair uses old counters; restart uses the new buffers.
        fresh();configure(16'h1000,16'h3000,1,8'h14,8'h10,0,8'hb2,1);
        put(8'hcf);stop_after_writes=1;put(8'h87);
        while(writes<1) tick();idle();
        put(8'h7d);put(8'h00);put(8'h20);put(1);put(0);
        put(8'h8d);put(8'h00);put(8'h40);
        stop_after_writes=4;rdy=0;put(8'h87);
        while(writes<4) tick();idle();put(8'h83);
        check(reads==4 && read_log[0]==16'h1000 && read_log[1]==16'h1001 &&
            read_log[2]==16'h2000 && read_log[3]==16'h2001 &&
            write_log[0]==16'h3000 && write_log[1]==16'h3001 &&
            write_log[2]==16'h4000 && write_log[3]==16'h4001,
            "new buffers affect restart, not active counters");
        // The documented autoreload includes a fixed destination too.
        fresh();configure(16'h1000,16'h3000,1,8'h14,8'h20,0,8'hb2,1);
        put(8'h01);put(8'hcf);put(8'h05);put(8'hcf);
        stop_after_writes=1;put(8'h87);while(writes<1) tick();idle();
        put(8'h8d);put(8'h00);put(8'h40);
        stop_after_writes=4;rdy=0;put(8'h87);while(writes<4) tick();idle();put(8'h83);
        check(write_log[0]==16'h3000 && write_log[1]==16'h3000 &&
              write_log[2]==16'h4000 && write_log[3]==16'h4000,"fixed destination autoreloads new buffer");
        passed("auto restart buffer updates preserve active block, including fixed destination");
        for(integer size_case=0;size_case<3;size_case++) begin
            integer count;
            logic [15:0] terminal;
            terminal=size_case==0 ? 16'd255 : size_case==1 ? 16'd65535 : 16'd0;
            count=size_case==0 ? 256 : size_case==1 ? 65536 : 65537;
            fresh();configure(16'h1000,16'h3000,terminal,8'h24,8'h20,8'h20,8'hb2,1);
            put(8'h01);put(8'hcf);put(8'h05);put(8'hcf);
            stop_after_writes=count;put(8'h87);while(writes<count) tick();
            repeat(12) ctick();put(8'h83);idle();
            read_word(8'h06,count_read);
            check(reads==count && writes==count && count_read==0 && !dut.end_of_block &&
                dut.remaining==17'(count),"large automatic reload count including special zero");
            stop_after_writes=count+1;rdy=0;put(8'h87);while(writes<count+1) tick();
            repeat(12) ctick();put(8'h83);idle();read_word(8'h06,count_read);
            check(reads==count+1 && writes==count+1 && count_read==1 &&
                read_log[count]==16'h1000 && write_log[count]==16'h3000 &&
                dut.remaining==17'(count-1),"large restarted block executes next genuine pair");
        end
        passed("auto restart 256/65536/65537-byte boundaries and next-block pair/count");
        for(integer abort_kind=0;abort_kind<3;abort_kind++) begin
            fresh();configure(16'h1000,16'h3000,1,8'h14,8'h10,8'h20,8'hb2,1);
            put(8'hcf);put(8'h87);
            while(!(writes==1 && !wr_n)) tick();wait_n=0;repeat(8) ctick();
            check(dut.remaining==1 && writes==1,"auto restart terminal write stalled");
            if(abort_kind==2) begin
                pause_ce=1;reset=1;repeat(20) tick();
                check(!wr_n && !busrq_n && writes==1,"terminal reset retains stopped owned write");
                pause_ce=0;
            end else put(abort_kind==0 ? 8'h83 : 8'hc3);
            wait_n=1;idle();reset=0;repeat(20) ctick();
            check(reads==2 && writes==2 && busrq_n && !dut.enabled,"terminal disable/reset drains without autorestart");
        end
        passed("auto restart terminal DISABLE/software/hardware reset with WAIT/stopped CE");
    endtask

    initial begin
        for(integer rate=0; rate<2; rate=rate+1) begin
            ce_period=rate==0?1:4;
            parser_checks(); memory_checks(); io_and_ownership_checks();autorestart_checks();
        end
        $display("DMA PASS groups=%0d clock_edges=%0d",tests,clock_edges);
        $finish;
    end
endmodule
