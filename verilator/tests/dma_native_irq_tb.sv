// SPDX-License-Identifier: GPL-2.0-or-later
// Original real register-stream/completion/service fixture. No forced state.
`timescale 1ns/1ps
module dma_native_irq_tb;
    logic clk=0,ce=0,reset=1,pause_ce=0;
    always #5 clk=!clk;
    logic cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
    logic [7:0] cpu_data_in=0;
    wire [7:0] cpu_data_out;
    wire busrq_n,mreq_n,iorq_n,rd_n,wr_n,unsupported;
    logic busak_n=1,wait_n=1,rdy=1,iei=1,acknowledge=0,reti=0;
    wire irq,ieo,irq_pending,irq_in_service;
    wire [7:0] ack_vector;
    wire [15:0] address;
    wire [7:0] data_out;
    wire [7:0] data_in=profile!=0 && address[1:0]==(profile==1 ? 0 : 3) ? 8'ha5 : 8'h55;
    integer period=1,edges=0,profile=0,reads=0,writes=0,cases=0;
    logic old_rd=1,old_wr=1;
    x1_dma #(.COMPLETION_IRQ(1)) dut(.*);
    always @(negedge clk) begin
        edges++; ce=!pause_ce && edges%period==0;
        if(ce) busak_n=busrq_n;
        if(!old_rd && rd_n) reads++;
        if(!old_wr && wr_n) writes++;
        old_rd=rd_n;old_wr=wr_n;
        assert(!(irq && (!busrq_n || !busak_n))) else $fatal(1,"IRQ before owner drain");
        assert(edges<80000000) else $fatal(1,"native IRQ watchdog");
    end
    task automatic ctick;
        do begin @(posedge clk);#1;end while(!ce);
    endtask
    task automatic tick;@(posedge clk);#1;endtask
    task automatic put(input logic [7:0] value);
        @(negedge clk);#1;cpu_cs=1;cpu_wr_n=0;cpu_data_in=value;
        repeat(3) ctick();@(negedge clk);#1;cpu_cs=0;cpu_wr_n=1;ctick();
    endtask
    task automatic status(input logic [7:0] expected);
        put(8'hbf);
        @(negedge clk);#1;cpu_cs=1;cpu_rd_n=0;ctick();
        repeat(3) begin
            assert((cpu_data_out&8'h3b)==expected)
                else $fatal(1,"native RR0 %h expected %h",cpu_data_out,expected);
            ctick();
        end
        @(negedge clk);#1;cpu_cs=0;cpu_rd_n=1;ctick();
    endtask
    task automatic fresh;
        pause_ce=0;cpu_cs=0;cpu_rd_n=1;cpu_wr_n=1;acknowledge=0;reti=0;iei=1;
        reset=1;repeat(3) ctick();reset=0;repeat(3) ctick();reads=0;writes=0;
    endtask
    task automatic configure(input logic [7:0] control,value,input logic irq_on);
        put(profile==0 ? 8'h7d : 8'h7e);put(0);put(8'h10);
        put(profile==0 ? 3 : 4);put(0);put(8'h14);put(8'h10);
        put((profile==0 ? 8'h80 : 8'h9c)|(irq_on ? 8'h20 : 0));
        if(profile!=0) begin put(0);put(8'ha5);end
        put(8'hbd);put(0);put(8'h20);put(control);
        if(control[3]) put(8'hc3); // associated data, not a RESET command
        if(control[4]) put(value); // includes every command-shaped byte
        put(8'h8a);put(8'hcf);
    endtask
    initial begin
        logic match_status,eob_status,eligible,clear_before;
        logic [7:0] expected_vector,expected_status;
        if($value$plusargs("CE_PERIOD=%d",period)) begin end
        for(integer vector_byte=0;vector_byte<256;vector_byte++)
        for(integer kind=0;kind<3;kind++)
        for(integer modify=0;modify<2;modify++)
        for(integer mask=0;mask<4;mask++)
        for(integer late=0;late<2;late++) begin
            fresh();profile=kind;
            configure(8'h10|8'(mask)|(modify!=0 ? 8'h20 : 0),8'(vector_byte),late==0);
            assert(!unsupported && !irq_pending && !irq_in_service)
                else $fatal(1,"native associated interrupt/vector bytes rejected");
            // IEI cannot prevent storing a real completed condition.
            iei=0;put(8'h87);
            wait(!dut.enabled && busrq_n && busak_n);repeat(8) ctick();
            match_status=kind!=0;eob_status=kind!=1;
            eligible=(match_status && (mask&1)!=0)||(eob_status && (mask&2)!=0);
            assert(reads==(kind==0 ? 4 : kind==1 ? 2 : 5) && writes==(kind==0 ? 4 : 0))
                else $fatal(1,"native IRQ altered completion reads=%d writes=%d",reads,writes);
            assert(irq_pending==(eligible && late==0) && !irq && !irq_in_service)
                else $fatal(1,"masked/disabled/upstream condition storage");
            if(late!=0) put(8'hab);
            repeat(4) ctick();assert(irq_pending==eligible)
                else $fatal(1,"AB did not expose retained completion");
            expected_status=(eob_status ? 0 : 8'h20)|(match_status ? 0 : 8'h10)|
                (eligible ? 0 : 8'h08)|8'h03;
            status(expected_status);
            if(eligible) begin
                put(8'haf);iei=1;repeat(3) ctick();
                assert(irq_pending && !irq && !ieo) else $fatal(1,"AF cleared IP");
                // The primary WR6 table clears only match/EOB. IP remains
                // until ACK/A3/reset; candidate vector reflects current flags.
                clear_before=vector_byte[0];
                if(clear_before) begin put(8'h8b);match_status=0;eob_status=0;end
                assert(irq_pending) else $fatal(1,"8B incorrectly cleared native IP");
                put(8'hab);repeat(3) ctick();assert(irq) else $fatal(1,"AB lost pending request");
                expected_vector=modify!=0 ? (8'(vector_byte)&8'hf9)|
                    (eob_status ? 8'h04 : 0)|(match_status ? 8'h02 : 0) : 8'(vector_byte);
                acknowledge=1;#1;
                assert(ack_vector==expected_vector) else $fatal(1,"native current-status candidate");
                tick();pause_ce=1;
                repeat(16) begin
                    tick();assert(irq_in_service && !irq_pending && !irq && !ieo &&
                                  ack_vector==expected_vector)
                        else $fatal(1,"native held ACK/stopped CE/vector");
                end
                acknowledge=0;pause_ce=0;put(8'haf);
                assert(irq_in_service && !ieo) else $fatal(1,"AF cleared native IUS");
                // Native re-enable while servicing must not issue BUSRQ.
                if(vector_byte==0 && mask==3 && modify==1 && late==0) begin
                    put(8'hd3);put(8'h87);repeat(12) ctick();
                    assert(dut.enabled && busrq_n && busak_n && irq_in_service)
                        else $fatal(1,"IUS failed to block real ENABLE DMA request");
                    put(8'h83);
                end
                put(8'hb3);assert(dut.force_ready) else $fatal(1,"FORCE READY setup");
                put(8'ha3);repeat(3) ctick();
                assert(!irq_pending && !irq_in_service && !dut.wr3[5] &&
                       !dut.force_ready && ieo && !irq)
                    else $fatal(1,"native A3 did not clear IP/IUS/enable/Ready");
            end
            cases++;
        end

        // Native RETI releases service with upstream IEI low, clears no
        // completion flags, and an uncleared condition subsequently re-pends.
        fresh();profile=0;configure(8'h32,8'hc3,1);put(8'h87);
        wait(irq);acknowledge=1;tick();acknowledge=0;tick();
        iei=0;reti=1;tick();reti=0;repeat(3) tick();
        assert(!irq_in_service && irq_pending && !irq)
            else $fatal(1,"native upstream-blocked RETI/re-pend");
        // One sampled reset edge with CE stopped clears native service and
        // programmed DMA state. No already-held ACK may turn into new IUS.
        iei=1;acknowledge=1;tick();pause_ce=1;reset=1;tick();reset=0;
        repeat(10) tick();
        assert(!irq_pending && !irq_in_service && !dut.loaded && ack_vector==0)
            else $fatal(1,"native stopped-CE reset/held-ACK quarantine");
        acknowledge=0;pause_ce=0;
        fresh();profile=0;configure(8'h32,8'ha3,1);put(8'h87);
        wait(irq);acknowledge=1;tick();acknowledge=0;tick();
        assert(irq_in_service) else $fatal(1,"C3 service setup");
        put(8'hc3);repeat(4) ctick();
        assert(!irq_pending && !irq_in_service && !dut.loaded && !dut.wr3[5] &&
               !dut.match_found && !dut.end_of_block && !irq && ieo)
            else $fatal(1,"native C3 did not reset completion service/program state");
        for(integer owned_phase=0;owned_phase<2;owned_phase++) begin
            fresh();profile=0;configure(8'h32,8'ha3,1);put(8'h9a);
            wait_n=owned_phase!=0;put(8'h87);
            if(owned_phase==0) wait(!rd_n && dut.cycle_left==1);
            else begin
                wait(!wr_n);wait_n=0;
                wait(dut.cycle_left==1);
            end
            pause_ce=1;reset=1;tick();reset=0;
            repeat(12) begin
                tick();assert(dut.reset_pending && !busrq_n && !busak_n &&
                              !irq_pending && !irq_in_service && !irq)
                    else $fatal(1,"native owned reset lost drain or invented IRQ");
            end
            pause_ce=0;repeat(4) ctick();
            assert(!busrq_n && !busak_n && !irq)
                else $fatal(1,"owned reset ignored stopped WAIT");
            wait_n=1;wait(busrq_n && busak_n);repeat(8) ctick();
            assert(reads==1 && writes==1 && !dut.loaded && !irq_pending &&
                   !irq_in_service && !irq && !dut.match_found && !dut.end_of_block)
                else $fatal(1,"native owned reset did not drain exactly one pair");
        end
        for(integer option=0;option<5;option++) begin
            fresh();profile=0;
            configure(option==0 ? 8'h50 : option==1 ? 8'h14 :
                      option==2 ? 8'h18 : option==3 ? 8'h90 : 8'h12,8'h87,1);
            if(option==4) put(8'hab); // command path cannot repair unsupported mode
            if(option==4) put(8'hba); // WR5 auto restart, EOB IRQ rejected
            assert(unsupported) else $fatal(1,"unsupported Ready/pulse/reserved/restart IRQ option %d",option);
            put(8'h87);repeat(12) ctick();
            assert(busrq_n && !irq && !irq_pending && reads==0 && writes==0)
                else $fatal(1,"unsupported IRQ option gained bus/service");
        end
        $display("PASS native DMA IRQ CE=%0d: %0d vector/mask/status/enable cases, RR0 AF/AB/A3/8B, IUS request inhibition, RETI/owned-pair stopped-CE/WAIT reset and rejected Ready/pulse/restart",period,cases);
        $finish;
    end
endmodule
