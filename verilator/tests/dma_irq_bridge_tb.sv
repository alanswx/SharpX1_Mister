// SPDX-License-Identifier: GPL-2.0-or-later
// Original real DMA/CTC connected arbitration fixture; no forced chip state.
`timescale 1ns/1ps
module dma_irq_bridge_tb #(parameter SIO_CHAIN=0);
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
    wire sio_irq,sio_ieo,sio_service,sio_ack,sio_iei,sio_reti;
    wire [7:0] sio_vector,sio_dout;
    wire [1:0] sio_txd,sio_rts,sio_dtr;
    wire sio_bad;
    logic sio_cs=0,sio_rd_n=1,sio_wr_n=1;
    logic [1:0] sio_address=0,sio_rxd=3;
    logic [7:0] sio_din=0;
    integer sio_acks=0,sio_returns=0;
    x1_dma #(.COMPLETION_IRQ(1)) dma(.iei(dma_iei),.acknowledge(dma_ack),.reti(dma_reti),
        .irq(dma_irq),.ieo(dma_ieo),.ack_vector(dma_vector),.*);
    x1_ctc ctc(.clk(clk),.reset(reset),.ce(ce),.wr(cwr),.channel(channel),.din(cdin),
        .dout(),.trigger(trigger),.iei(ctc_iei),.irq(ctc_irq),.ieo(ctc_ieo),
        .ack(ctc_ack),.reti(ctc_reti),.vector(ctc_vector),.zc());
    generate if(SIO_CHAIN) begin : serial_chain
        x1_sio_interrupt sio(.clk(clk),.ce(ce),.reset(reset),
            .cpu_cs(sio_cs),.cpu_rd_n(sio_rd_n),.cpu_wr_n(sio_wr_n),
            .address(sio_address),.cpu_din(sio_din),.cpu_dout(sio_dout),
            .rx_tick(2'b11),.tx_tick(2'b11),.rxd(sio_rxd),.cts_n(2'b11),.dcd_n(2'b11),
            .txd(sio_txd),.rts_n(sio_rts),.dtr_n(sio_dtr),.unsupported(sio_bad),
            .iei(sio_iei),.acknowledge(sio_ack),.reti(sio_reti),
            .irq(sio_irq),.ieo(sio_ieo),.service_active(sio_service),
            .ack_vector(sio_vector),.wait_n(),.ready_n());
        x1_sio_irq_bridge bridge(.clk(clk),.reset(reset),.m1_n(bm1),.mreq_n(bmem),
            .iorq_n(bio),.rd_n(brd),.data(bdata),.upstream_iei(upstream_iei),
            .sio_in_service(sio_service),.dma_in_service(irq_in_service),.*);
    end else begin : original_chain
        assign sio_irq=0;assign sio_ieo=upstream_iei;assign sio_service=0;
        assign sio_ack=0;assign sio_iei=upstream_iei;assign sio_reti=0;
        assign sio_vector=8'hff;assign sio_dout=8'hff;
        assign sio_txd=3;assign sio_rts=3;assign sio_dtr=3;assign sio_bad=0;
        x1_dma_irq_bridge bridge(.clk(clk),.reset(reset),.m1_n(bm1),.mreq_n(bmem),
        .iorq_n(bio),.rd_n(brd),.data(bdata),.upstream_iei(upstream_iei),
        .dma_in_service(irq_in_service),.dma_vector(dma_vector),.*);
    end endgenerate
    always @(negedge clk) begin edges++;ce=!pause_ce && edges%period==0;if(ce) busak_n=busrq_n;end
    always @(posedge clk) if(!reset) begin
        if(dma_ack) dma_acks++;
        if(ctc_ack) ctc_acks++;
        if(keyboard_ack && !old_keyboard_ack) kbd_cycles++;
        old_keyboard_ack<=keyboard_ack;
        if(dma_reti) dr++;
        if(ctc_reti) cr++;
        if(sio_ack) sio_acks++;
        if(sio_reti) sio_returns++;
        assert(int'(sio_ack)+int'(dma_ack)+int'(ctc_ack)+int'(keyboard_ack)<=1)
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
               keyboard_ack==(device==2) && sio_ack==(device==3)) else $fatal(1,"wrong first ACK owner/vector");
        tick();pause_ce=1;
        repeat(40) begin
            tick();assert(ack_vector==expected && !dma_ack && !ctc_ack && !sio_ack &&
                          keyboard_ack==(device==2)) else $fatal(1,"held ACK changed owner/vector");
        end
        pause_ce=0;bm1=1;bio=1;tick();
    endtask
    task automatic opcode(input logic [7:0] op);
        bm1=0;bmem=0;brd=0;bdata=op;repeat(5) tick();
        bm1=1;bmem=1;brd=1;tick();tick();
    endtask
    task automatic return_interrupt;opcode(8'hed);opcode(8'h4d);endtask
    task automatic serial_put(input logic [1:0] port,input logic [7:0] value);
        @(negedge clk);#1;sio_address=port;sio_din=value;sio_cs=1;sio_wr_n=0;
        repeat(3) ctick();@(negedge clk);#1;sio_cs=0;sio_wr_n=1;ctick();
        assert(!sio_bad) else $fatal(1,"unsupported serial configuration");
    endtask
    task automatic serial_reg(input logic ch,input logic [7:0] index,value);
        serial_put({ch,1'b1},index);serial_put({ch,1'b1},value);
    endtask
    task automatic configure_serial;
        for(integer ch=0;ch<2;ch++) begin
            serial_reg(1'(ch),4,8'h44);serial_reg(1'(ch),3,8'hc1);
            serial_reg(1'(ch),1,ch==1 ? 8'h14 : 8'h10);
        end
        serial_reg(1,2,8'he0);
    endtask
    task automatic receive_serial(input logic ch,input logic [7:0] value);
        @(negedge clk);#1;sio_rxd[ch]=0;repeat(16) ctick();
        for(integer bitno=0;bitno<8;bitno++) begin
            sio_rxd[ch]=value[bitno];repeat(16) ctick();
        end
        sio_rxd[ch]=1;repeat(20) ctick();
    endtask
    task automatic read_serial(input logic ch,input logic [7:0] expected);
        @(negedge clk);#1;sio_address={ch,1'b0};sio_cs=1;sio_rd_n=0;
        repeat(3) begin ctick();assert(sio_dout==expected)
            else $fatal(1,"serial FIFO byte %h expected %h",sio_dout,expected);end
        @(negedge clk);#1;sio_cs=0;sio_rd_n=1;ctick();
    endtask
    task automatic connected_serial_matrix;
        integer before_dr,before_cr,before_sa,before_sr;
        keyboard_irq=1;keyboard_vector=8'hb0;
        reset=1;repeat(4) ctick();reset=0;repeat(4) ctick();
        configure_serial();cw(0,8'ha0);cw(0,8'hd5);cw(0,1);
        before_dr=dr;before_cr=cr;before_sa=sio_acks;before_sr=sio_returns;
        // Actual counter, completion IRQ and serial FIFO sources, no forced IUS.
        trigger_ctc(0);ack(8'ha0,1);
        configure_dma();put(8'h87);wait(dma_irq);ack(8'hc4,0);put(8'h8b);
        receive_serial(1,8'hb6);ack(8'he4,3);read_serial(1,8'hb6);
        receive_serial(0,8'ha5);ack(8'hec,3);read_serial(0,8'ha5);
        assert(sio_service && irq_in_service && ctc.in_service[0] && !irq)
            else $fatal(1,"real four-level service stack missing");
        upstream_iei=0;return_interrupt();
        assert(sio_service && irq_in_service && ctc.in_service[0] &&
            sio_returns==before_sr+1 && dr==before_dr && cr==before_cr)
            else $fatal(1,"real A RETI released lower service");
        return_interrupt();
        assert(!sio_service && irq_in_service && ctc.in_service[0] &&
            sio_returns==before_sr+2 && dr==before_dr && cr==before_cr)
            else $fatal(1,"real B RETI released lower service");
        // Unacknowledged real FIFO pending cannot impersonate SIO IUS.
        receive_serial(0,8'h3c);return_interrupt();
        assert(!irq_in_service && ctc.in_service[0] && dr==before_dr+1 && cr==before_cr)
            else $fatal(1,"real pending SIO stole DMA return");
        read_serial(0,8'h3c);return_interrupt();
        assert(ctc.in_service==0 && cr==before_cr+1 && sio_acks==before_sa+2)
            else $fatal(1,"real downstream CTC return/count");
        upstream_iei=1;tick();ack(8'hb0,2);keyboard_irq=0;
        // Real B service held across stopped enables and global reset.
        receive_serial(1,8'h69);bm1=0;bio=0;tick();
        assert(sio_service && ack_vector==8'he4) else $fatal(1,"real B reset ACK entry");
        pause_ce=1;keyboard_irq=1;reset=1;tick();reset=0;
        repeat(20) begin
            tick();assert(!sio_service && !irq_in_service && ctc.in_service==0 &&
                !sio_ack && !dma_ack && !ctc_ack && !keyboard_ack)
                else $fatal(1,"real stopped-CE reset replay/service");
        end
        bm1=1;bio=1;tick();ack(8'hb0,2);keyboard_irq=0;pause_ce=0;
        configure_serial();receive_serial(0,8'h96);ack(8'hec,3);read_serial(0,8'h96);
        return_interrupt();assert(!sio_service && !irq && !sio_bad)
            else $fatal(1,"real fresh serial recovery");
        $display("PASS real SIO/DMA/CTC chain CE=%0d: nested FIFO/completion/counter service, isolated RETI, pending-vs-IUS, stopped-CE reset quarantine and fresh bytes",period);
    endtask
    task automatic reset_service_matrix;
        integer before_ctc;
        // Raw reset forgets service, but an already-held CPU ACK is not a
        // new mailbox transaction after reset. Keep a downstream level high
        // to exercise the transport contract, not a reset MR16 firmware model.
        bm1=1;bio=1;keyboard_irq=0;reset=1;tick();reset=0;tick();
        configure_dma();put(8'h87);wait(dma_irq);
        bm1=0;bio=0;tick();
        assert(irq_in_service) else $fatal(1,"reset matrix DMA ACK entry");
        pause_ce=1;keyboard_irq=1;reset=1;tick();reset=0;
        repeat(20) begin
            tick();assert(!dma_ack && !ctc_ack && !keyboard_ack)
                else $fatal(1,"reset reselected downstream during old ACK");
        end
        bm1=1;bio=1;tick();ack(8'hb7,2);keyboard_irq=0;pause_ce=0;tick();
        // A3/C3 clear DMA IP/IUS while the acknowledged vector remains
        // latched. Neither command may redirect this held cycle to CTC.
        for(integer command_case=0;command_case<2;command_case++) begin
            reset=1;tick();reset=0;tick();
            cw(0,8'ha0);cw(0,8'hd5);cw(0,1);
            configure_dma();put(8'h87);wait(dma_irq);trigger_ctc(0);
            bm1=0;bio=0;tick();before_ctc=ctc_acks;
            put(command_case==0 ? 8'ha3 : 8'hc3);
            repeat(8) begin
                tick();assert(ack_vector==8'hc4 && !dma_ack && !ctc_ack && !keyboard_ack)
                    else $fatal(1,"command reset reselected held DMA vector");
            end
            assert(!irq_pending && !irq_in_service && ctc.pending[0] && ctc_acks==before_ctc)
                else $fatal(1,"command reset erased/consumed downstream pending");
            bm1=1;bio=1;tick();ack(8'ha0,1);
            // RETI must release CTC even with upstream IEI withdrawn.
            upstream_iei=0;return_interrupt();
            assert(ctc.in_service==0 && !irq)
                else $fatal(1,"upstream-low RETI lost downstream release");
            upstream_iei=1;tick();
        end
        reset=1;tick();reset=0;tick();
    endtask
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
        reset_service_matrix();
        if(SIO_CHAIN) connected_serial_matrix();
        $display("PASS connected DMA/CTC bridge CE=%0d: priority/retained pending/held ACK/AF/nested isolated RETI/CTC internal nesting/keyboard/invalid ACK/reset quarantine/A3/C3/upstream-low RETI",period);
        $finish;
    end
endmodule
