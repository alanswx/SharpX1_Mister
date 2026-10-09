// SPDX-License-Identifier: GPL-2.0-or-later
// Original actual-CPU, actual-device nested IM2 diagnostic. No private assets.
// FFF0 is a fixture-only host-release input, NOT a proposed Sharp X1 port.
`timescale 1ns/1ps
module sio_chain_cpu_tb;
    reg clk=0,ce=0,reset=1,stop_ce=0,bad_ius=0,reset_nested=0;
    always #5 clk=~clk;
    integer period=1,edges=0,pc=0,acks=0,returns=0,reads=0,writes=0,grants=0;
    always @(negedge clk) begin edges++;ce=!stop_ce && edges%period==0;end
    reg [7:0] memory[0:65535];
    reg [7:0] memory_data=0,host_release=0;
    reg io_active=0;
    reg [15:0] io_port=0;
    wire m1_n,mreq_n,iorq_n,rd_n,wr_n,halt_n,busak_n,rfsh_n,busrq_n;
    wire [15:0] address,dma_address;
    wire [7:0] cpu_data,sio_data,dma_status,dma_data;
    wire owner=!busak_n;
    wire acknowledge=!m1_n && !iorq_n && !owner;
    wire sio_cs;
    x1_sio_decode decode(.enabled(1'b1),.reset(reset || owner),.dam(1'b0),
        .m1_n(m1_n),.iorq_n(iorq_n),.rd_n(rd_n),.wr_n(wr_n),.address(address),
        .selected(sio_cs),.read_access(),.write_access());
    wire dma_cs=!owner && m1_n && !iorq_n && address==16'h1f80;
    wire ctc_cs=!owner && m1_n && !iorq_n && address[15:2]==14'h07e8;
    reg ctc_write_seen=0;
    wire ctc_write=ctc_cs && !wr_n && !ctc_write_seen;
    wire sio_irq,sio_ieo,sio_service,sio_ack,sio_iei,sio_reti,sio_bad;
    wire dma_irq,dma_ieo,dma_pending,dma_service,dma_ack,dma_iei,dma_reti,dma_bad;
    wire ctc_irq,ctc_ieo,ctc_ack,ctc_iei,ctc_reti,irq,keyboard_ack;
    wire [7:0] sio_vector,dma_vector,ctc_vector,ack_vector,ctc_data;
    wire [1:0] txd,rts_n,dtr_n,wait_n;
    reg [1:0] rx_tick=0,rxd=3;
    reg [3:0] trigger=0;
    wire dma_mreq_n,dma_iorq_n,dma_rd_n,dma_wr_n;
    wire [15:0] response_port=(sio_cs || dma_cs || ctc_cs || (!iorq_n && m1_n)) ? address : io_port;
    wire response_io=sio_cs || dma_cs || ctc_cs || (io_active && mreq_n) || (!iorq_n && m1_n);
    wire [7:0] io_response=response_port>=16'h1f90 && response_port<=16'h1f93 ? sio_data :
        response_port==16'h1f80 ? dma_status : response_port==16'hfff0 ? host_release :
        response_port>=16'h1fa0 && response_port<=16'h1fa3 ? ctc_data : 8'hff;
    wire [7:0] cpu_di=acknowledge ? ack_vector : response_io ? io_response : memory_data;
    cpu processor(.clock(clk),.cep(ce),.cen(1'b0),.reset_n(!reset),
        .int_n(!irq),.wait_n(&wait_n),.busrq_n(busrq_n),.busak_n(busak_n),
        .rfsh_n(rfsh_n),.halt_n(halt_n),.mreq(mreq_n),.iorq(iorq_n),
        .wr(wr_n),.rd(rd_n),.m1(m1_n),.di(cpu_di),.data_out(cpu_data),
        .a(address),.dir(16'b0),.dirset(1'b0));
    x1_sio_interrupt #(.FLOW_ENABLE(1)) sio(.clk(clk),.ce(ce),.reset(reset),
        .cpu_cs(sio_cs),.cpu_rd_n(rd_n),.cpu_wr_n(wr_n),.address(address[1:0]),
        .cpu_din(cpu_data),.cpu_dout(sio_data),.rx_tick(rx_tick),.tx_tick(2'b00),
        .rxd(rxd),.cts_n(2'b11),.dcd_n(2'b11),.txd(txd),.rts_n(rts_n),.dtr_n(dtr_n),
        .unsupported(sio_bad),.iei(sio_iei),.acknowledge(sio_ack),.reti(sio_reti),
        .irq(sio_irq),.ieo(sio_ieo),.service_active(sio_service),
        .ack_vector(sio_vector),.wait_n(wait_n),.ready_n());
    x1_dma #(.COMPLETION_IRQ(1)) dma(.clk(clk),.ce(ce),.reset(reset),
        .cpu_cs(dma_cs),.cpu_rd_n(rd_n),.cpu_wr_n(wr_n),.cpu_data_in(cpu_data),
        .cpu_data_out(dma_status),.busrq_n(busrq_n),.busak_n(busak_n),
        .mreq_n(dma_mreq_n),.iorq_n(dma_iorq_n),.rd_n(dma_rd_n),.wr_n(dma_wr_n),
        .address(dma_address),.data_out(dma_data),.data_in(memory[dma_address]),
        .wait_n(1'b1),.rdy(1'b1),.unsupported(dma_bad),.iei(dma_iei),
        .acknowledge(dma_ack),.reti(dma_reti),.irq(dma_irq),.ieo(dma_ieo),
        .irq_pending(dma_pending),.irq_in_service(dma_service),.ack_vector(dma_vector));
    x1_ctc ctc(.clk(clk),.ce(ce),.reset(reset),.wr(ctc_write),.channel(address[1:0]),
        .din(cpu_data),.dout(ctc_data),.trigger(trigger),.iei(ctc_iei),.irq(ctc_irq),
        .ieo(ctc_ieo),.ack(ctc_ack),.reti(ctc_reti),.vector(ctc_vector),.zc());
    x1_sio_irq_bridge bridge(.clk(clk),.reset(reset),.m1_n(m1_n || owner),
        .mreq_n(mreq_n || owner),.iorq_n(iorq_n || owner),.rd_n(rd_n || owner),
        .data(cpu_di),.upstream_iei(1'b1),.sio_in_service(!bad_ius && sio_service),
        .dma_in_service(dma_service),.keyboard_irq(1'b0),.keyboard_vector(8'hff),.*);
    reg ack_old=0,owner_old=0,dma_read_old=0,dma_write_old=0;
    reg [7:0] held_vector=0;
    always @(posedge clk) begin
        memory_data<=memory[address];
        if(reset) begin
            io_active<=0;ctc_write_seen<=0;
            acks=0;returns=0;reads=0;writes=0;grants=0;
        end
        else begin
            ctc_write_seen<=ctc_cs && !wr_n;
            if(!owner && !mreq_n && !rd_n) io_active<=0;
            else if(!owner && m1_n && !iorq_n && !rd_n) begin io_active<=1;io_port<=address;end
            if(!owner && !mreq_n && !wr_n) memory[address]<=cpu_data;
            if(owner && !dma_mreq_n && !dma_wr_n) memory[dma_address]<=dma_data;
            if(owner && !owner_old) grants++;
            if(owner && !dma_mreq_n && !dma_rd_n && !dma_read_old) reads++;
            if(owner && !dma_mreq_n && !dma_wr_n && !dma_write_old) writes++;
            if(acknowledge && !ack_old) begin
                case(acks)
                    0:assert(ack_vector==8'ha0 && ctc_ack) else $fatal(1,"CPU CTC ACK");
                    1:assert(ack_vector==8'hc4 && dma_ack) else $fatal(1,"CPU DMA ACK");
                    2:assert(ack_vector==8'he4 && sio_ack) else $fatal(1,"CPU B RX ACK");
                    3:assert(ack_vector==8'hec && sio_ack) else $fatal(1,"CPU A RX ACK");
                    default:$fatal(1,"extra CPU chain ACK");
                endcase
                acks++;held_vector<=ack_vector;
            end else if(acknowledge) assert(ack_vector==held_vector)
                else $fatal(1,"CPU chain held vector");
            if(sio_reti || dma_reti || ctc_reti) begin
                case(returns)
                    0,1:assert(sio_reti && !dma_reti && !ctc_reti) else $fatal(1,"CPU SIO RETI owner");
                    2:assert(dma_reti && !sio_reti && !ctc_reti) else $fatal(1,"CPU DMA RETI owner");
                    3:assert(ctc_reti && !sio_reti && !dma_reti) else $fatal(1,"CPU CTC RETI owner");
                    default:$fatal(1,"extra CPU chain RETI");
                endcase
                returns++;
            end
            assert(!sio_bad && (!dma.loaded || !dma_bad) && !keyboard_ack)
                else $fatal(1,"CPU unsupported device mode SIO=%b DMA=%b loaded=%b",sio_bad,dma_bad,dma.loaded);
        end
        ack_old<=acknowledge;owner_old<=owner;
        dma_read_old<=owner && !dma_mreq_n && !dma_rd_n;
        dma_write_old<=owner && !dma_mreq_n && !dma_wr_n;
    end
    task automatic emit(input [7:0] value);memory[pc]=value;pc++;endtask
    task automatic load(input [7:0] value);emit(8'h3e);emit(value);endtask
    task automatic port(input [15:0] value);emit(8'h01);emit(value[7:0]);emit(value[15:8]);endtask
    task automatic out_byte(input [7:0] value);load(value);emit(8'hed);emit(8'h79);endtask
    task automatic store(input [15:0] value);emit(8'h32);emit(value[7:0]);emit(value[15:8]);endtask
    task automatic mark(input [7:0] value);load(value);store(16'h4000);endtask
    task automatic serial_reg(input [7:0] index,value);out_byte(index);out_byte(value);endtask
    task automatic vector_entry(input [7:0] vector,input [15:0] handler);
        memory[16'h0200+16'(vector)]=handler[7:0];memory[16'h0201+16'(vector)]=handler[15:8];
    endtask
    task automatic wait_host(input [7:0] mask);
        integer loop_pc;
        emit(8'hfb);emit(0);port(16'hfff0);loop_pc=pc;
        emit(8'hed);emit(8'h78);emit(8'he6);emit(mask); // IN; AND mask
        emit(8'hca);emit(8'(loop_pc));emit(8'(loop_pc>>8)); // JP Z,loop
        emit(8'hf3);emit(8'hc1);emit(8'hf1);emit(8'hed);emit(8'h4d);
    endtask
    task automatic step;do begin @(posedge clk);#1;end while(!ce);endtask
    task automatic receive(input bit ch,input [7:0] value);
        rx_tick=ch ? 2 : 1;rxd[ch]=0;repeat(16) step();
        for(integer i=0;i<8;i++) begin rxd[ch]=value[i];repeat(16) step();end
        rxd[ch]=1;repeat(32) step();rx_tick=0;
    endtask
    task automatic run_chain(input bit interrupt_with_reset);
        wait(memory[16'h4000]==1 && !halt_n);
        trigger[0]=1;step();trigger[0]=0;
        wait(memory[16'h4000]==8'h20);
        assert(dma_service && ctc.in_service[0] && grants>0)
            else $fatal(1,"CPU DMA failed to nest CTC/grant");
        receive(1,8'hb6);wait(memory[16'h4000]==8'h30);
        assert(sio_service && dma_service && ctc.in_service[0]) else $fatal(1,"CPU B service missing");
        receive(0,8'ha5);wait(memory[16'h4000]==8'h40 && returns==1);
        assert(sio_service && dma_service && ctc.in_service[0] && acks==4 &&
            memory[16'h4100]==8'hb6 && memory[16'h4101]==8'ha5)
            else $fatal(1,"CPU actual nested RX bytes/service");
        if(interrupt_with_reset) begin
            // DMA already drained its bus; this is concurrent interrupt
            // service reset, NOT a substitute for the owned-pair drain policy.
            assert(!owner && busrq_n) else $fatal(1,"nested reset requires drained DMA bus");
            stop_ce=1;reset=1;
            repeat(8) begin @(posedge clk);#1;end
            assert(!sio_service && !dma_service && ctc.in_service==0 && !irq)
                else $fatal(1,"nested service survived stopped-CE reset");
            reset=0;
            repeat(20) begin
                @(posedge clk);#1;
                assert(!irq && !sio_ack && !dma_ack && !ctc_ack && acks==0 && returns==0)
                    else $fatal(1,"nested reset replay with CE stopped");
            end
            stop_ce=0;
            $display("PASS actual CPU nested SIO/DMA/CTC stopped-CE reset CE=%0d; retained program reboot follows",period);
        end else begin
            host_release=7;
            wait(memory[16'h4000]==8'haa && !halt_n);repeat(100) step();
            assert(acks==4 && returns==4 && !sio_service && !dma_service && ctc.in_service==0 &&
                !irq && reads==4 && writes==4) else $fatal(1,"CPU chain final counts/service");
            for(integer i=0;i<4;i++) assert(memory[16'h9000+16'(i)]==8'h31+8'(i))
                else $fatal(1,"CPU chain actual DMA payload");
            $display("PASS actual CPU SIO/DMA/CTC nested IM2 CE=%0d: four ACK/RETI, real FIFO bytes, BUSACK ownership and four-byte DMA payload",period);
        end
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        bad_ius=$test$plusargs("BAD_IUS");reset_nested=$test$plusargs("RESET_NESTED");
        for(integer i=0;i<65536;i++) memory[i]=0;
        for(integer i=0;i<4;i++) memory[16'h8000+16'(i)]=8'h31+8'(i);
        emit(8'hf3);emit(8'h31);emit(0);emit(8'hff);
        load(2);emit(8'hed);emit(8'h47);emit(8'hed);emit(8'h5e);
        for(integer ch=0;ch<2;ch++) begin
            port(ch==0 ? 16'h1f91 : 16'h1f93);out_byte(8'h18);
            serial_reg(4,8'h44);serial_reg(3,8'hc1);serial_reg(1,ch==0 ? 8'h10 : 8'h14);
        end
        serial_reg(2,8'he0);
        port(16'h1fa0);out_byte(8'ha0);out_byte(8'hd5);out_byte(1);
        port(16'h1f80);
        out_byte(8'h7d);out_byte(0);out_byte(8'h80);out_byte(3);out_byte(0);
        out_byte(8'h14);out_byte(8'h10);out_byte(8'ha0);out_byte(8'hbd);
        out_byte(0);out_byte(8'h90);out_byte(8'h32);out_byte(8'hc0);out_byte(8'h8a);out_byte(8'hcf);
        mark(1);emit(8'hfb);emit(8'h76);emit(8'hf3);mark(8'haa);emit(8'h76);
        if(pc>=16'h02a0) $fatal(1,"CPU chain program overlaps vectors");
        pc=32'h0400;emit(8'hf5);emit(8'hc5);mark(8'h10);port(16'h1f80);out_byte(8'h87);wait_host(4);
        pc=32'h0480;emit(8'hf5);emit(8'hc5);port(16'h1f80);out_byte(8'h8b);mark(8'h20);wait_host(2);
        pc=32'h0500;emit(8'hf5);emit(8'hc5);port(16'h1f92);emit(8'hed);emit(8'h78);store(16'h4100);mark(8'h30);wait_host(1);
        pc=32'h0580;emit(8'hf5);emit(8'hc5);port(16'h1f90);emit(8'hed);emit(8'h78);store(16'h4101);mark(8'h40);
        emit(8'hf3);emit(8'hc1);emit(8'hf1);emit(8'hed);emit(8'h4d);
        vector_entry(8'ha0,16'h0400);vector_entry(8'hc4,16'h0480);
        vector_entry(8'he4,16'h0500);vector_entry(8'hec,16'h0580);
        repeat(8) step();reset=0;
        if(reset_nested) run_chain(1);
        run_chain(0);
        $finish;
    end
    initial begin #20000000;$fatal(1,"CPU chain watchdog address=%h stage=%h ACK=%0d RETI=%0d",address,memory[16'h4000],acks,returns);end
endmodule
