// SPDX-License-Identifier: GPL-2.0-or-later
// Original real-register IOR/IP/IUS and transfer fixture. No forced state.
`timescale 1ns/1ps
module dma_ready_irq_tb;
    logic clk=0, ce=0, reset=1, pause_ce=0;
    always #5 clk=!clk;
    logic cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
    logic [7:0] cpu_data_in=0;
    wire [7:0] cpu_data_out;
    logic busak_n=1,wait_n=1,rdy=1,iei=1,acknowledge=0,reti=0;
    wire busrq_n,mreq_n,iorq_n,rd_n,wr_n,unsupported;
    wire irq,ieo,irq_pending,irq_in_service;
    wire [7:0] ack_vector,data_out;
    wire [15:0] address;
    wire [7:0] data_in=address[7:0]^8'h5a;
    integer period=1,edges=0,reads=0,writes=0,cases=0,mode=0;
    logic old_rd=1,old_wr=1,polarity=1;
    x1_dma #(.COMPLETION_IRQ(1),.READY_IRQ(1)) dut(.*);
    always @(negedge clk) begin
        edges++;ce=!pause_ce && edges%period==0;
        if(ce) busak_n=busrq_n;
        if(!old_rd && rd_n) reads++;
        if(!old_wr && wr_n) begin
            assert(address>=16'h2000 && address<16'h2004 &&
                   data_out==(address[7:0]^8'h5a)) else $fatal(1,"IOR resumed wrong transfer");
            writes++;
        end
        old_rd=rd_n;old_wr=wr_n;
        assert(!(irq && (!busrq_n || !busak_n))) else $fatal(1,"IOR IRQ while owned");
        assert(edges<50000000) else $fatal(1,"IOR watchdog");
    end
    task automatic tick; @(posedge clk);#1;endtask
    task automatic ctick;do begin tick();end while(!ce);endtask
    task automatic put(input logic [7:0] value);
        @(negedge clk);#1;cpu_cs=1;cpu_wr_n=0;cpu_data_in=value;
        repeat(3) ctick();@(negedge clk);#1;cpu_cs=0;cpu_wr_n=1;ctick();
    endtask
    task automatic fresh;
        pause_ce=0;cpu_cs=0;cpu_rd_n=1;cpu_wr_n=1;acknowledge=0;reti=0;iei=1;
        rdy=!polarity;reset=1;repeat(3) ctick();reset=0;repeat(3) ctick();reads=0;writes=0;
    endtask
    task automatic configure(input logic [7:0] vector_byte,input logic modified);
        put(8'h7d);put(0);put(8'h10);put(3);put(0);
        put(8'h14);put(8'h10);put(8'ha0);
        put(8'h9d|(8'(mode)<<5));put(0);put(8'h20);
        put(8'h50|(modified ? 8'h20 : 0));put(vector_byte);
        put(polarity ? 8'h8a : 8'h82);put(8'hcf);put(8'h87);
        assert(!unsupported && dut.enabled && busrq_n && !irq_pending)
            else $fatal(1,"Ready configuration not accepted");
    endtask
    task automatic end_service;
        reti=1;tick();reti=0;repeat(3) tick();
    endtask
    initial begin
        logic [7:0] expected;
        if($value$plusargs("CE_PERIOD=%d",period)) begin end
        for(mode=0;mode<3;mode++)
        for(integer p=0;p<2;p++)
        for(integer modify=0;modify<2;modify++)
        for(integer vector_byte=0;vector_byte<256;vector_byte++) begin
            polarity=1'(p);fresh();configure(8'(vector_byte),modify!=0);
            iei=0;pause_ce=!vector_byte[0];
            if(pause_ce) rdy=polarity;
            else begin
                // Ready arrives immediately before an enabled IDLE edge:
                // the new IOR must win over requesting on this very edge.
                do begin @(negedge clk);#1;end while(!ce);
                rdy=polarity;tick();
                assert(busrq_n && busak_n) else $fatal(1,"Ready edge requested before IOR latched");
            end
            repeat(8) tick();
            assert(irq_pending && !irq && busrq_n && busak_n && reads==0 && writes==0)
                else $fatal(1,"IOR not retained behind IEI/stopped CE or requested early");
            iei=1;tick();assert(irq && !ieo) else $fatal(1,"IOR priority release");
            expected=modify!=0 ? (8'(vector_byte)&8'hf9) : 8'(vector_byte);
            acknowledge=1;tick();
            repeat(12) begin
                tick();assert(irq_in_service && !irq_pending && !irq && !ieo &&
                              ack_vector==expected && busrq_n)
                    else $fatal(1,"IOR held ACK/service/vector/ownership");
            end
            acknowledge=0;pause_ce=0;
            // RETI alone cannot clear IOR. The same persistent cause re-pends.
            end_service();repeat(4) ctick();
            assert(irq && irq_pending && busrq_n && reads==0)
                else $fatal(1,"RETI incorrectly cleared IOR");
            acknowledge=1;tick();acknowledge=0;tick();
            put(8'hb7);put(8'h87);repeat(8) ctick();
            assert(!unsupported && dut.enabled && irq_in_service && busrq_n && reads==0)
                else $fatal(1,"B7 released IUS or ENABLE requested before RETI");
            end_service();
            wait(!dut.enabled && busrq_n && busak_n);repeat(8) ctick();
            assert(reads==4 && writes==4 && !irq_pending && !irq_in_service && !irq && ieo)
                else $fatal(1,"Ready held high re-triggered or transfer lost");
            // Ready transitions are real events even after an entire transfer.
            rdy=!polarity;repeat(3) tick();rdy=polarity;repeat(4) tick();
            assert(irq_pending && irq && busrq_n) else $fatal(1,"new Ready edge lost");
            put(8'haf);assert(irq_pending && !irq && dut.ready_interrupts.ior_latched)
                else $fatal(1,"AF erased IOR/IP");
            put(8'ha3);repeat(3) ctick();
            assert(!irq_pending && !irq_in_service && !dut.ready_interrupts.ior_latched && ieo)
                else $fatal(1,"A3 did not clear independent latches");
            cases++;
        end
        // Auto-restart with IRQs is still fail-closed until separately qualified.
        mode=1;polarity=1;fresh();configure(8'hc3,1);put(8'haa);put(8'h87);
        assert(unsupported && !dut.enabled && busrq_n && reads==0 && writes==0)
            else $fatal(1,"Ready IRQ silently accepted unqualified auto restart");
        // Sampled reset with transfer enables physically stopped clears service.
        mode=1;polarity=1;fresh();configure(8'hc3,1);pause_ce=1;rdy=1;repeat(4) tick();
        acknowledge=1;tick();reset=1;tick();reset=0;repeat(4) tick();
        assert(!irq_pending && !irq_in_service && !dut.ready_interrupts.ior_latched && busrq_n)
            else $fatal(1,"stopped-enable reset retained IOR");
        acknowledge=0;
        $display("PASS DMA Ready/IOR register cases=%0d CE=%0d, held ACK, B7/RETI, exact transfers, A3/reset",cases,period);
        $finish;
    end
endmodule
