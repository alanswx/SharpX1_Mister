// SPDX-License-Identifier: GPL-2.0-or-later
// Original register-stream auto-restart EOB fixture, no forced state.
`timescale 1ns/1ps
module dma_restart_irq_tb;
    logic clk=0,ce=0,reset=1,pause_ce=0;
    always #5 clk=!clk;
    logic cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
    logic [7:0] cpu_data_in=0;
    wire [7:0] cpu_data_out,data_out,ack_vector;
    wire [15:0] address;
    wire [7:0] data_in=address[7:0]^8'h5a;
    logic busak_n=1,wait_n=1,rdy=1,iei=1,acknowledge=0,reti=0;
    wire busrq_n,mreq_n,iorq_n,rd_n,wr_n,unsupported;
    wire irq,ieo,irq_pending,irq_in_service;
    integer period=1,edges=0,reads=0,writes=0,cases=0,mode=0,kind=0;
    logic old_rd=1,old_wr=1;
    x1_dma #(.COMPLETION_IRQ(1),.RESTART_IRQ(1)) dut(.*);
    always @(negedge clk) begin
        edges++;ce=!pause_ce && edges%period==0;
        if(ce) busak_n=busrq_n;
        if(!old_rd && rd_n) reads++;
        if(!old_wr && wr_n) begin
            assert(address>=16'h2000 && address<16'h2004 &&
                data_out==(address[7:0]^8'h5a)) else $fatal(1,"restart data/address");
            writes++;
        end
        old_rd=rd_n;old_wr=wr_n;
        assert(reads<=8 && writes<=8) else $fatal(1,"restart block overran retained interrupt");
        assert(!(irq && (!busrq_n || !busak_n))) else $fatal(1,"restart IRQ before grant drain");
        assert(edges<50000000) else $fatal(1,"restart watchdog");
    end
    task automatic tick;@(posedge clk);#1;endtask
    task automatic ctick;do begin tick();end while(!ce);endtask
    task automatic put(input logic [7:0] value);
        @(negedge clk);#1;cpu_cs=1;cpu_wr_n=0;cpu_data_in=value;
        repeat(3) ctick();@(negedge clk);#1;cpu_cs=0;cpu_wr_n=1;ctick();
    endtask
    task automatic fresh;
        pause_ce=0;cpu_cs=0;cpu_rd_n=1;cpu_wr_n=1;acknowledge=0;reti=0;iei=1;
        reset=1;repeat(3) ctick();reset=0;repeat(3) ctick();reads=0;writes=0;
    endtask
    task automatic configure(input logic [7:0] vector_byte,control);
        put(kind==0 ? 8'h7d : 8'h7e);put(0);put(8'h10);
        put(kind!=0 && mode==1 ? 4 : 3);put(0);
        put(8'h14);put(8'h10);put(8'ha0);
        put(8'h9d|(8'(mode)<<5));put(0);put(8'h20);put(control);put(vector_byte);
        put(8'hba);put(8'hcf);
    endtask
    initial begin
        integer baseline_reads,baseline_writes;
        if($value$plusargs("CE_PERIOD=%d",period)) begin end
        for(kind=0;kind<2;kind++)
        for(mode=0;mode<3;mode++)
        for(integer vector_byte=0;vector_byte<256;vector_byte++) begin
            fresh();configure(8'(vector_byte),8'h12);
            assert(!unsupported) else $fatal(1,"restart IRQ configuration rejected");
            iei=0;put(8'h87);
            wait(irq_pending && busrq_n && busak_n);repeat(8) ctick();
            assert(reads==4 && writes==(kind==0 ? 4 : 0) && !irq &&
                   !dut.end_of_block && dut.remaining==4 && dut.byte_counter==0 &&
                   dut.counter_a==16'h1000 && dut.counter_b==16'h2000)
                else $fatal(1,"restart lost event/reload or transferred before ACK");
            put(8'haf);repeat(4) ctick();
            assert(irq_pending && !irq && busrq_n && dut.restart_interrupts.terminal_latched)
                else $fatal(1,"AF erased pending restart event");
            put(8'hab);
            // IRQ remains pending behind IEI, including stopped transfer CE.
            pause_ce=1;repeat(12) tick();iei=1;tick();
            acknowledge=1;tick();
            repeat(12) begin
                tick();assert(irq_in_service && !irq_pending && !irq &&
                    ack_vector==8'(vector_byte) && busrq_n && busak_n &&
                    !dut.end_of_block) else $fatal(1,"restart held ACK/vector/EOB");
            end
            acknowledge=0;pause_ce=0;
            // A register read disables DMA, but may not fabricate EOB status.
            put(8'hbf);@(negedge clk);#1;cpu_cs=1;cpu_rd_n=0;ctick();
            assert((cpu_data_out&8'h38)==8'h38) else $fatal(1,"restart RR0 after ACK");
            @(negedge clk);#1;cpu_cs=0;cpu_rd_n=1;ctick();
            put(8'h87);repeat(8) ctick();
            assert(reads==4 && writes==(kind==0 ? 4 : 0) && busrq_n)
                else $fatal(1,"restart ENABLE escaped IUS");
            baseline_reads=reads;baseline_writes=writes;
            reti=1;tick();reti=0;
            wait(irq_pending && busrq_n && busak_n);repeat(4) ctick();
            assert(reads==baseline_reads+4 && writes==baseline_writes+(kind==0 ? 4 : 0) &&
                   irq && !irq_in_service && !dut.end_of_block)
                else $fatal(1,"restart second block/event");
            put(8'ha3);repeat(4) ctick();
            assert(!irq_pending && !irq_in_service && !irq && ieo)
                else $fatal(1,"restart A3 latch reset");
            cases++;
        end
        kind=0;mode=1;
        for(integer phase=0;phase<2;phase++) begin
            fresh();configure(8'hc3,8'h12);put(8'h9a);put(8'hba);
            wait_n=phase!=0;put(8'h87);
            if(phase==0) wait(!rd_n && dut.cycle_left==1);
            else begin wait(!wr_n);wait_n=0;wait(dut.cycle_left==1);end
            pause_ce=1;reset=1;tick();reset=0;
            repeat(12) begin
                tick();assert(!irq_pending && !irq && !irq_in_service &&
                    !busrq_n && !busak_n && dut.reset_pending)
                    else $fatal(1,"owned restart reset released an active pair");
            end
            pause_ce=0;repeat(4) ctick();assert(!busrq_n && !irq);
            wait_n=1;wait(busrq_n && busak_n);repeat(8) ctick();
            assert(reads==1 && writes==1 && !dut.loaded && !irq_pending &&
                !irq_in_service && !dut.restart_interrupts.terminal_latched)
                else $fatal(1,"owned restart reset drain count/state");
        end
        fresh();configure(8'hc3,8'h12);put(8'h87);wait(irq);
        acknowledge=1;tick();pause_ce=1;reset=1;tick();reset=0;
        repeat(12) tick();
        assert(!irq_pending && !irq_in_service && !irq && !dut.loaded &&
            !dut.restart_interrupts.terminal_latched)
            else $fatal(1,"restart stopped-CE reset/held ACK");
        acknowledge=0;pause_ce=0;
        // Explicitly unsupported combinations must stay fail-closed.
        kind=0;mode=1;
        fresh();configure(8'hc3,8'h32);assert(unsupported)
            else $fatal(1,"status-modified restart should be rejected");
        put(8'h87);repeat(12) ctick();assert(reads==0 && writes==0 && !irq);
        $display("PASS restart EOB IRQ CE=%0d: %0d transfer/search mode/vector/reload/ACK/RETI/RR0 cases",period,cases);
        $finish;
    end
endmodule
