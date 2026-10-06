// SPDX-License-Identifier: GPL-2.0-or-later
// Original real DMA/CTC connected arbitration fixture; no forced chip state.
`timescale 1ns/1ps
module dma_irq_bridge_tb;
    logic clk=0,ce=0,reset=1,pause_ce=0;
    always #5 clk=!clk;
    integer period=1,edges=0,dma_acks=0,ctc_acks=0,kbd_cycles=0,dr=0,cr=0;
    logic cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
    logic [7:0] cpu_data_in=0;
    wire [7:0] cpu_data_out;
    wire busrq_n,mreq_n,iorq_n,rd_n,wr_n,unsupported;
    logic busak_n=1,wait_n=1,rdy=1;
    wire [15:0] address;
    wire [7:0] data_out;
    wire [7:0] data_in=address[7:0];
    wire dma_irq,dma_ieo,irq_pending,irq_in_service;
    wire [7:0] dma_vector;
    wire dma_ack,dma_iei,dma_reti,ctc_ack,ctc_iei,ctc_reti,keyboard_ack,irq;
    wire [7:0] ack_vector,ctc_vector;
    logic bm1=1,bmem=1,bio=1,brd=1,upstream_iei=1,keyboard_irq=0;
    logic [7:0] bdata=0,keyboard_vector=8'hb0;
    logic cwr=0;
    logic [1:0] channel=0;
    logic [7:0] cdin=0;
    logic [3:0] trigger=0;
    wire ctc_irq,ctc_ieo;
    logic old_keyboard_ack=0;
    x1_dma #(.COMPLETION_IRQ(1)) dma(.iei(dma_iei),.acknowledge(dma_ack),.reti(dma_reti),
        .irq(dma_irq),.ieo(dma_ieo),.ack_vector(dma_vector),.*);
    x1_ctc ctc(.clk(clk),.reset(reset),.ce(ce),.wr(cwr),.channel(channel),.din(cdin),
        .dout(),.trigger(trigger),.iei(ctc_iei),.irq(ctc_irq),.ieo(ctc_ieo),
        .ack(ctc_ack),.reti(ctc_reti),.vector(ctc_vector),.zc());
    x1_dma_irq_bridge bridge(.clk(clk),.reset(reset),.m1_n(bm1),.mreq_n(bmem),
        .iorq_n(bio),.rd_n(brd),.data(bdata),.upstream_iei(upstream_iei),
        .dma_in_service(irq_in_service),.dma_vector(dma_vector),.*);
    always @(negedge clk) begin edges++;ce=!pause_ce && edges%period==0;if(ce) busak_n=busrq_n;end
    always @(posedge clk) if(!reset) begin
        if(dma_ack) dma_acks++;
        if(ctc_ack) ctc_acks++;
        if(keyboard_ack && !old_keyboard_ack) kbd_cycles++;
        old_keyboard_ack<=keyboard_ack;
        if(dma_reti) dr++;
        if(ctc_reti) cr++;
        assert(!(dma_ack && (ctc_ack || keyboard_ack)) && !(ctc_ack && keyboard_ack))
            else $fatal(1,"multiple ACK consumers");
        assert(edges<200000) else $fatal(1,"connected bridge watchdog");
    end
    task automatic tick;@(posedge clk);#1;endtask
    task automatic ctick;do begin tick();end while(!ce);endtask
    task automatic put(input logic [7:0] value);
        @(negedge clk);#1;cpu_cs=1;cpu_wr_n=0;cpu_data_in=value;
        repeat(3) ctick();@(negedge clk);#1;cpu_cs=0;cpu_wr_n=1;ctick();
    endtask
    task automatic cw(input logic [1:0] ch,input logic [7:0] value);
        @(negedge clk);#1;channel=ch;cdin=value;cwr=1;tick();cwr=0;tick();
    endtask
    task automatic trigger_ctc(input integer ch);
        trigger[ch]=0;tick();trigger[ch]=1;tick();trigger[ch]=0;tick();
    endtask
    task automatic configure_dma;
        put(8'h7d);put(0);put(8'h10);put(3);put(0);put(8'h14);put(8'h10);
        put(8'ha0);put(8'hbd);put(0);put(8'h20);put(8'h32);put(8'hc0);
        put(8'h8a);put(8'hcf);
    endtask
    task automatic ack(input logic [7:0] expected,input integer device);
        assert(irq) else $fatal(1,"no pending IRQ for %h",expected);
        bm1=0;bio=0;#1;
        assert(ack_vector==expected && dma_ack==(device==0) && ctc_ack==(device==1) &&
               keyboard_ack==(device==2)) else $fatal(1,"wrong first ACK owner/vector");
        tick();pause_ce=1;
        repeat(40) begin
            tick();assert(ack_vector==expected && !dma_ack && !ctc_ack &&
                          keyboard_ack==(device==2)) else $fatal(1,"held ACK changed owner/vector");
        end
        pause_ce=0;bm1=1;bio=1;tick();
    endtask
    task automatic opcode(input logic [7:0] op);
        bm1=0;bmem=0;brd=0;bdata=op;repeat(5) tick();
        bm1=1;bmem=1;brd=1;tick();tick();
    endtask
    task automatic return_interrupt;opcode(8'hed);opcode(8'h4d);endtask
    initial begin
        if($value$plusargs("CE_PERIOD=%d",period)) begin end
        repeat(4) ctick();reset=0;repeat(4) ctick();
        cw(0,8'ha0);cw(0,8'hd5);cw(0,1);
        cw(1,8'hd5);cw(1,1);
        configure_dma();upstream_iei=0;keyboard_irq=1;put(8'h87);
        wait(!busak_n);trigger_ctc(0);
        assert(!irq && !ctc_iei) else $fatal(1,"upstream priority leaked IRQ");
        wait(irq_pending && busrq_n && busak_n);repeat(4) tick();upstream_iei=1;tick();
        assert(dma_irq && !ctc_irq && !keyboard_ack && ctc.pending[0])
            else $fatal(1,"DMA/CTC/keyboard pending priority");
        ack(8'hc4,0);
        assert(irq_in_service && ctc.pending[0] && !ctc_iei && dma_acks==1 && ctc_acks==0)
            else $fatal(1,"DMA service erased downstream pending");
        put(8'haf);put(8'h8b);
        assert(!irq && !ctc_iei) else $fatal(1,"AF incorrectly cleared service block");
        return_interrupt();
        assert(!irq_in_service && ctc_irq && dr==1 && cr==0)
            else $fatal(1,"DMA RETI not isolated");
        ack(8'ha0,1);
        assert(ctc.in_service[0] && !ctc.pending[0] && !irq)
            else $fatal(1,"CTC service/keyboard block");
        // A second real DMA block preempts active CTC channel 0 service.
        put(8'hd3);put(8'hab);put(8'h87);wait(dma_irq);
        ack(8'hc4,0);
        assert(irq_in_service && ctc.in_service[0]) else $fatal(1,"nested service lost CTC");
        put(8'h8b);return_interrupt();
        assert(!irq_in_service && ctc.in_service[0] && !irq && dr==2 && cr==0)
            else $fatal(1,"nested DMA RETI broadcast into CTC");
        // CTC's own higher channel nesting must remain intact too.
        trigger_ctc(0); // Same channel cannot interrupt its own service.
        assert(!ctc_irq) else $fatal(1,"CTC self nesting");
        return_interrupt();
        assert(ctc_irq && cr==1) else $fatal(1,"CTC queued condition lost after RETI");
        cw(0,8'h03); // control word: disable pending and stop before keyboard
        assert(irq && ctc_ieo) else $fatal(1,"keyboard not exposed");
        ack(8'hb0,2);
        keyboard_vector=8'hb7;keyboard_irq=0;tick();
        // Invalid ACK cannot consume a new device appearing mid-cycle.
        bm1=0;bio=0;tick();trigger_ctc(1);repeat(12) tick();
        assert(ack_vector==8'hff && ctc_acks==1 && !keyboard_ack && !dma_ack && !ctc_ack)
            else $fatal(1,"invalid held ACK stole new CTC event");
        bm1=1;bio=1;tick();ack(8'ha2,1);
        assert(ctc.in_service[1]) else $fatal(1,"CTC channel 1 service missing");
        cw(0,8'hd5);cw(0,1);trigger_ctc(0);ack(8'ha0,1);
        assert(ctc.in_service[0] && ctc.in_service[1]) else $fatal(1,"CTC internal nesting missing");
        return_interrupt();assert(!ctc.in_service[0] && ctc.in_service[1])
            else $fatal(1,"CTC internal RETI priority");
        return_interrupt();assert(ctc.in_service==0) else $fatal(1,"CTC remaining service not released");
        assert(dma_acks==2 && ctc_acks==3 && kbd_cycles==1 && dr==2 && cr==3)
            else $fatal(1,"connected dispatch counts %d/%d/%d RETI %d/%d",dma_acks,ctc_acks,kbd_cycles,dr,cr);
        reset=1;tick();reset=0;tick();
        assert(!irq && !irq_pending && !irq_in_service && ctc.in_service==0)
            else $fatal(1,"bridge/device reset service");
        $display("PASS connected DMA/CTC bridge CE=%0d: priority/retained pending/held ACK/AF/nested isolated RETI/CTC internal nesting/keyboard/invalid ACK/reset",period);
        $finish;
    end
endmodule
