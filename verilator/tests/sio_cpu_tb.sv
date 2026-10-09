// SPDX-License-Identifier: GPL-2.0-or-later
// Original CPU-executed IM2 diagnostic. No BIOS, snapshots, state forcing or
// emulator imports. Synthetic RAM holds only this test's generated program.
`timescale 1ns/1ps
module sio_cpu_tb;
    reg clk=0, ce=0, reset=1;
    always #5 clk=~clk;
    integer period=1,edges=0,pc=0,ack_count=0,reti_count=0;
    reg first_status=0,flow_profile=0;
    reg decode_profile=0,sio_enabled=1,dam=0;
    reg bypass_dam=0,bypass_enable=0,wide_decode=0;
    reg stop_ce=0;
    reg abort_reset_sender=0, reset_sender_done=0;
    integer irq_reset_phase=-1;
    integer expected_irqs=3;
    always @(negedge clk) begin edges=edges+1; ce=!stop_ce && (edges%period)==0; end
    wire m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,halt_n,busak_n;
    wire [15:0] address;
    wire [7:0] cpu_data,sio_data,ack_vector;
    reg [7:0] memory[0:65535];
    reg [7:0] memory_data=0;
    reg io_response_active=0;
    wire decoded_cs;
    wire cpu_cs=wide_decode ? (sio_enabled && !reset && !dam && m1_n && !iorq_n &&
        (rd_n != wr_n) && address[15:4]==12'h1f9) : decoded_cs;
    x1_sio_decode decode(.enabled(bypass_enable || sio_enabled),.reset(reset),.dam(!bypass_dam && dam),
        .m1_n(m1_n),.iorq_n(iorq_n),.rd_n(rd_n),.wr_n(wr_n),
        .address(address),.selected(decoded_cs),.read_access(),.write_access());
    reg unmapped_response_active=0;
    wire acknowledge=!iorq_n && !m1_n;
    // Keep a clocked I/O read response through bus release until the next
    // memory read. TV80 can retain T2 for its automatic I/O wait after its
    // external strobes release, so an idle-bus RAM mux is not a valid response.
    wire [7:0] cpu_di=acknowledge ? ack_vector :
        (cpu_cs || (io_response_active && mreq_n)) ? sio_data :
        ((!iorq_n && m1_n) || (unmapped_response_active && mreq_n)) ? 8'hff : memory_data;
    reg [1:0] rx_tick=0,tx_tick=0,rxd=3,cts_n=3,dcd_n=3;
    wire [1:0] txd,rts_n,dtr_n;
    wire unsupported,irq,ieo,reti;
    wire [1:0] flow_wait_n;
    reg ack_old=0;
    reg [7:0] observed_vector;
    cpu processor (
        .clock(clk), .cep(ce), .cen(1'b0), .reset_n(!reset),
        .int_n(!irq), .wait_n(&flow_wait_n), .busrq_n(1'b1), .busak_n(busak_n),
        .rfsh_n(rfsh_n), .halt_n(halt_n), .mreq(mreq_n), .iorq(iorq_n),
        .wr(wr_n), .rd(rd_n), .m1(m1_n), .di(cpu_di), .data_out(cpu_data),
        .a(address), .dir(16'b0), .dirset(1'b0)
    );
    x1_sio_interrupt #(.FLOW_ENABLE(1)) sio (
        .clk(clk), .ce(ce), .reset(reset), .cpu_cs(cpu_cs),
        .cpu_rd_n(rd_n), .cpu_wr_n(wr_n), .address(address[1:0]),
        .cpu_din(cpu_data), .cpu_dout(sio_data), .rx_tick(rx_tick), .tx_tick(tx_tick),
        .rxd(rxd), .cts_n(cts_n), .dcd_n(dcd_n), .txd(txd), .rts_n(rts_n), .dtr_n(dtr_n),
        .unsupported(unsupported), .iei(1'b1), .acknowledge(acknowledge),
        .reti(reti), .irq(irq), .ieo(ieo), .ack_vector(ack_vector), .wait_n(flow_wait_n), .ready_n()
    );
    // Reuse the existing machine's stretched-fetch ED/4D decoder. Its CTC
    // and keyboard inputs are idle: no CTC exists in this standalone fixture.
    x1_irq_bridge opcode_decoder (
        .clk(clk), .reset(reset), .m1_n(m1_n), .mreq_n(mreq_n),
        .iorq_n(iorq_n), .rd_n(rd_n), .data(cpu_di),
        .keyboard_irq(1'b0), .ctc_irq(1'b0), .ctc_ieo(1'b1),
        .keyboard_vector(8'hff), .ctc_vector(8'hff), .ctc_reti(reti),
        .irq(), .keyboard_ack(), .ctc_ack(), .ctc_iei(), .ctc_selected(), .ack_vector()
    );
    always @(posedge clk) begin
        if(flow_profile && $test$plusargs("flow-trace") && ce && memory[16'h4000]==5)
            $display("FLOW t=%0t a=%h rd=%b cs=%b wait=%b di=%h reg=%h data=%h fifo=%d seen=%b event=%b ts=%b",$time,address,rd_n,cpu_cs,flow_wait_n,cpu_di,processor.Z80CPU.di_reg,sio_data,sio.channels[0].unit.fifo_count,sio.channels[0].unit.read_seen,sio.channels[0].unit.read_event,processor.Z80CPU.tstate);
        memory_data<=memory[address];
        if(reset || (!mreq_n && !rd_n)) io_response_active<=0;
        else if(cpu_cs && !rd_n) io_response_active<=1;
        if(reset || (!mreq_n && !rd_n)) unmapped_response_active<=0;
        else if(!iorq_n && m1_n && !rd_n && !cpu_cs) unmapped_response_active<=1;
        if(!reset && !mreq_n && !wr_n) memory[address]<=cpu_data;
        if(reset) begin ack_old<=0; ack_count<=0; reti_count<=0; end
        else begin
            if(cpu_cs && (acknowledge || dam || !sio_enabled))
                $fatal(1,"SIO selected during excluded bus cycle");
            ack_old<=acknowledge;
            if(acknowledge && !ack_old) begin
                case(ack_count)
                    0: if(ack_vector!==8'he4) $fatal(1,"CPU first vector not B RX");
                    1: if(ack_vector!==8'hee) $fatal(1,"CPU second vector not A special RX");
                    2: if(ack_vector!==8'he8) $fatal(1,"CPU third vector not A TX");
                    3: if(!first_status || ack_vector!==8'hea) $fatal(1,"CPU fourth vector not A external");
                    default: $fatal(1,"unexpected CPU interrupt");
                endcase
                observed_vector<=ack_vector; ack_count<=ack_count+1;
            end else if(acknowledge && ack_vector!==observed_vector)
                $fatal(1,"CPU ACK vector changed mid-cycle");
            if(reti) reti_count<=reti_count+1;
            if(unsupported) $fatal(1,"CPU programmed unsupported SIO behavior");
        end
    end
    task automatic emit(input reg [7:0] value);
        memory[pc]=value; pc=pc+1;
    endtask
    task automatic load_a(input reg [7:0] value); emit(8'h3e); emit(value); endtask
    task automatic store(input reg [15:0] addr);
        emit(8'h32); emit(addr[7:0]); emit(addr[15:8]);
    endtask
    task automatic port(input reg [15:0] addr);
        emit(8'h01); emit(addr[7:0]); emit(addr[15:8]); // LD BC,nn
    endtask
    task automatic out_byte(input reg [7:0] value);
        load_a(value); emit(8'hed); emit(8'h79); // OUT (C),A
    endtask
    task automatic reg_write(input reg [7:0] index,value);
        out_byte(index); out_byte(value);
    endtask
    task automatic vector_entry(input reg [7:0] vector,input reg [15:0] handler);
        memory[16'h0200+16'(vector)]=handler[7:0];
        memory[16'h0201+16'(vector)]=handler[15:8];
    endtask
    task automatic mark(input reg [7:0] value); load_a(value); store(16'h4000); endtask
    task automatic step;
        do begin @(posedge clk); #1; end while(!ce);
    endtask
    task automatic receive(input reg channel,input reg [7:0] value,input reg bad_stop);
        rx_tick=channel ? 2 : 1; rxd[channel]=0; repeat(16) step();
        for(integer i=0;i<8;i=i+1) begin rxd[channel]=value[i]; repeat(16) step(); end
        rxd[channel]=!bad_stop; repeat(16) step(); rxd[channel]=1; repeat(16) step(); rx_tick=0;
    endtask
    task automatic stage(input reg [7:0] expected);
        wait(memory[16'h4000]==expected && !halt_n);
        @(negedge clk); #1;
    endtask
    task automatic transmit_a(input reg [7:0] value);
        reg [9:0] frame;
        frame={1'b1,value,1'b0}; tx_tick=1;
        for(integer i=0;i<10;i=i+1) repeat(16) begin
            if(txd[0]!==frame[i]) $fatal(1,"CPU TX byte %h pin bit %0d mismatch",value,i);
            step();
        end
        tx_tick=0;
    endtask
    task automatic reset_arrival;
        reg [9:0] frame;
        frame={1'b1,8'hd3,1'b0};rx_tick=2;
        for(integer bitno=0;bitno<10 && !abort_reset_sender;bitno++) begin
            rxd[1]=frame[bitno];
            for(integer tick=0;tick<16 && !abort_reset_sender;tick++)
                do begin @(posedge clk);#1; end while(!ce && !abort_reset_sender);
        end
        rx_tick=0;rxd=3;reset_sender_done=1;
    endtask
    task automatic reset_during_irq;
        // Observe ACK/service concurrently with stop-bit reception: waiting
        // until the sender finishes can miss the entire fast CPU handler.
        fork reset_arrival(); join_none
        case(irq_reset_phase)
            0: wait(acknowledge && sio.priority_unit.in_service[3]);
            1: wait(sio.priority_unit.in_service[3] && !acknowledge);
            2: wait(memory[16'h4100]==8'hd3 && sio.priority_unit.in_service[3]);
            3: wait(reti);
            default: $fatal(1,"invalid SIO IRQ reset phase");
        endcase
        @(negedge clk); #1; stop_ce=1;abort_reset_sender=1;
        wait(reset_sender_done);
        @(negedge clk); #1;
        if(ce || ack_count!=1) $fatal(1,"IRQ reset phase did not own one actual CPU ACK");
        if(irq_reset_phase<3 && sio.priority_unit.in_service!==6'b001000)
            $fatal(1,"SIO service lost before requested reset phase");
        case(irq_reset_phase)
            0: if(!acknowledge || sio.channels[1].unit.fifo_count!=1 || reti_count!=0)
                   $fatal(1,"reset did not capture held ACK with unread B data");
            1: if(acknowledge || sio.channels[1].unit.fifo_count!=1 || reti_count!=0)
                   $fatal(1,"reset did not capture handler entry with unread B data");
            2: if(sio.channels[1].unit.fifo_count!=0 || memory[16'h4100]!=8'hd3 || reti_count!=0)
                   $fatal(1,"reset did not capture consumed FIFO before RETI");
            3: if(reti_count!=1 || sio.channels[1].unit.fifo_count!=0)
                   $fatal(1,"reset did not follow one actual decoded RETI");
        endcase
        reset=1;rx_tick=0;tx_tick=0;rxd=3;
        repeat(8) begin @(negedge clk); #1;
            if(ce || irq || !ieo || sio.priority_unit.in_service!=0 ||
               sio.priority_unit.ack_seen || txd!==3 || unsupported ||
               ack_vector!==8'hff || flow_wait_n!==3)
                $fatal(1,"stopped-CE SIO IRQ reset left service/source/vector/WAIT");
        end
        reset=0;
        repeat(20) begin @(negedge clk); #1;
            if(ce || irq || !ieo || ack_count!=0 || reti_count!=0)
                $fatal(1,"SIO replayed old IRQ after stopped-CE reset");
        end
        stop_ce=0;stage(1);
        if(irq || ack_count!=0 || reti_count!=0 || !ieo)
            $fatal(1,"retained diagnostic did not reboot cleanly after IRQ reset");
        $display("PASS actual CPU SIO stopped-CE IRQ reset phase=%0d CE=%0d; fresh traffic follows",irq_reset_phase,period);
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        first_status=$test$plusargs("first-status"); expected_irqs=first_status ? 4 : 3;
        flow_profile=$test$plusargs("flow");
        decode_profile=$test$plusargs("decode");
        bypass_dam=$test$plusargs("BYPASS_DAM");
        bypass_enable=$test$plusargs("BYPASS_ENABLE");
        wide_decode=$test$plusargs("WIDE_DECODE");
        if(!decode_profile && (bypass_dam || bypass_enable || wide_decode))
            $fatal(1,"decode negatives require the decode profile");
        if($value$plusargs("IRQ_RESET_PHASE=%d",irq_reset_phase)) begin end
        if(irq_reset_phase>=0 && (first_status || flow_profile))
            $fatal(1,"IRQ reset is a separate fixture profile");
        if(flow_profile && first_status) $fatal(1,"separate fixture profiles required");
        if(decode_profile && irq_reset_phase>=0) $fatal(1,"decode and reset are separate profiles");
        for(integer i=0;i<65536;i=i+1) memory[i]=0;
        emit(8'hf3); emit(8'h31); emit(8'h00); emit(8'hff); // DI; LD SP,ff00
        load_a(2); emit(8'hed); emit(8'h47); emit(8'hed); emit(8'h5e); // LD I,A; IM 2
        if(decode_profile) begin
            // Real OUT/IN at both neighboring ranges. Invalid FF control bytes
            // must not change a SIO pointer, FIFO, diagnostic or modem output.
            for(integer i=0;i<16;i++) begin
                port(i<4 ? 16'h1f8c+16'(i) : 16'h1f90+16'(i));
                out_byte(8'hff);emit(8'hed);emit(8'h78);store(16'h4200+16'(i));
            end
            mark(8'hd0);
            for(integer i=0;i<4;i++) begin
                port(16'h1f90+16'(i));out_byte(8'hff);
                emit(8'hed);emit(8'h78);store(16'h4210+16'(i));
            end
            mark(8'hd1);
            // Restore checks use separate addresses from blocked read results.
            port(16'h1f91);emit(8'hed);emit(8'h78);store(16'h4220);
            port(16'h1f93);emit(8'hed);emit(8'h78);store(16'h4221);
            mark(8'he0);
            for(integer i=0;i<4;i++) begin
                port(16'h1f90+16'(i));out_byte(8'hff);
                emit(8'hed);emit(8'h78);store(16'h4230+16'(i));
            end
            mark(8'he1);
            port(16'h1f91);emit(8'hed);emit(8'h78);store(16'h4240);
            port(16'h1f93);emit(8'hed);emit(8'h78);store(16'h4241);
        end
        for(integer ch=0;ch<2;ch=ch+1) begin
            port(ch==0 ? 16'h1f91 : 16'h1f93); out_byte(8'h18);
            reg_write(4,8'h44); reg_write(3,8'hc1); reg_write(5,8'hea);
            reg_write(1,first_status ? (ch==0 ? 8'h0b : 8'h0c) : (ch==0 ? 8'h12 : 8'h16));
            if(first_status) out_byte(8'h20);
        end
        reg_write(2,8'he0); // B vector only
        mark(1); emit(8'hfb); emit(8'h76); emit(8'hf3); // EI; HALT; DI after ISR
        mark(2); emit(8'hfb); emit(8'h76); emit(8'hf3);
        port(16'h1f90); out_byte(8'h69);
        mark(3); emit(8'hfb); emit(8'h76); emit(8'hf3);
        if(first_status) begin mark(4); emit(8'hfb); emit(8'h76); emit(8'hf3); end
        if(flow_profile) begin
            port(16'h1f91); reg_write(1,8'ha0); mark(5);
            port(16'h1f90); emit(8'hed); emit(8'h78); store(16'h4106);
            port(16'h1f91); reg_write(1,8'h80);
            port(16'h1f90); out_byte(8'h55); mark(6); out_byte(8'h17);
        end
        mark(8'haa); emit(8'h76);
        if(decode_profile && pc>=16'h02e4) $fatal(1,"decode program overlaps IM2 vector entries");
        pc=32'h0400; port(16'h1f92); emit(8'hed); emit(8'h78); store(16'h4100);
        load_a(8'he4); store(16'h4102); emit(8'hfb); emit(8'hed); emit(8'h4d);
        pc=32'h0440; port(16'h1f90); emit(8'hed); emit(8'h78); store(16'h4101);
        if(first_status) begin
            emit(8'hed); emit(8'h78); store(16'h4104); // same locked byte again
            port(16'h1f91); out_byte(8'h30); // Error Reset releases locked FIFO word
            out_byte(1); emit(8'hed); emit(8'h78); store(16'h4105); // RR1 after release
        end
        load_a(8'hee); store(16'h4102); emit(8'hfb); emit(8'hed); emit(8'h4d);
        pc=32'h0480; port(16'h1f91); out_byte(8'h28);
        load_a(8'he8); store(16'h4102); emit(8'hfb); emit(8'hed); emit(8'h4d);
        if(first_status) begin
            pc=32'h04c0; port(16'h1f91); emit(8'hed); emit(8'h78); store(16'h4103);
            out_byte(8'h10); // external source reset is distinct from RETI
            load_a(8'hea); store(16'h4102); emit(8'hfb); emit(8'hed); emit(8'h4d);
            vector_entry(8'hea,16'h04c0);
        end
        vector_entry(8'he4,16'h0400); vector_entry(8'hee,16'h0440); vector_entry(8'he8,16'h0480);
        repeat(8) step(); reset=0;
        if(decode_profile) begin
            wait(memory[16'h4000]==8'hd0);@(negedge clk);#1;dam=1;
            wait(memory[16'h4000]==8'hd1);@(negedge clk);#1;dam=0;
            wait(memory[16'h4000]==8'he0);@(negedge clk);#1;sio_enabled=0;
            wait(memory[16'h4000]==8'he1);@(negedge clk);#1;sio_enabled=1;
        end
        stage(1); if(irq) $fatal(1,"IRQ before serial traffic");
        if(decode_profile) begin
            for(integer i=0;i<16;i++)
                assert(memory[16'h4200+16'(i)]==8'hff) else $fatal(1,"neighbor port did not float FF");
            for(integer i=0;i<4;i++)
                assert(memory[16'h4210+16'(i)]==8'hff && memory[16'h4230+16'(i)]==8'hff)
                    else $fatal(1,"blocked port read did not float FF");
            assert(memory[16'h4220]==4 && memory[16'h4221]==4 &&
                   memory[16'h4240]==4 && memory[16'h4241]==4)
                else $fatal(1,"DAM/disabled access changed SIO or read response");
        end
        if(irq_reset_phase>=0) reset_during_irq();
        receive(1,8'hb6,0);
        stage(2);
        if(memory[16'h4100]!==8'hb6 || memory[16'h4102]!==8'he4 || reti_count!=1)
            $fatal(1,"CPU B RX ISR/read/RETI failed");
        receive(0,8'h37,1);
        stage(3);
        if(memory[16'h4101]!==8'h37 || memory[16'h4102]!==8'hee || reti_count!=2)
            $fatal(1,"CPU A special RX ISR/read/RETI failed");
        if(first_status && (memory[16'h4104]!==8'h37 || memory[16'h4105]!==1))
            $fatal(1,"CPU repeated locked read/Error Reset failed");
        tx_tick=1; step(); tx_tick=0;
        if(txd[0]!==0) $fatal(1,"CPU TX data did not enter shifter");
        if(flow_profile) begin
            wait(cpu_cs && !rd_n && !flow_wait_n[0]);
            repeat(100) begin step();
                if(address!==16'h1f90 || rd_n || flow_wait_n[0] || memory[16'h4000]!==5)
                    $fatal(1,"CPU empty-RX WAIT did not hold its real read");
            end
            receive(0,8'h53,0);
            wait(cpu_cs && !wr_n && !flow_wait_n[0] && memory[16'h4000]==6);
            repeat(100) begin step();
                if(address!==16'h1f90 || wr_n || cpu_data!==8'h17 || flow_wait_n[0] ||
                   memory[16'h4106]!==8'h53 || memory[16'h4000]!==6)
                    $fatal(1,"CPU full-TX WAIT/read response failed addr=%h wr=%b data=%h wait=%b RX=%h stage=%h",address,wr_n,cpu_data,flow_wait_n,memory[16'h4106],memory[16'h4000]);
            end
        end else stage(first_status ? 4 : 8'haa);
        if(memory[16'h4102]!==8'he8 || ack_count!=3 || reti_count!=3 || irq || !ieo)
            $fatal(1,"CPU TX pending reset/final RETI failed");
        if(first_status) begin
            // Pulse CTS long enough for one SYS sample then return high.
            cts_n[0]=0; @(posedge clk); #1; cts_n[0]=1;
            stage(8'haa);
            if(memory[16'h4103]!==8'h26 || memory[16'h4102]!==8'hea ||
               ack_count!=4 || reti_count!=4 || irq || !ieo)
                $fatal(1,"CPU external vector/status/source reset/RETI failed");
        end
        // Verify the actual transmitted character loaded by CPU, not merely
        // the interrupt handler marker. Advance each bit exactly 16 ticks.
        transmit_a(8'h69);
        if(flow_profile) begin
            tx_tick=1; step(); tx_tick=0; // holding 55 enters shifter, admits CPU 17
            stage(8'haa);
            transmit_a(8'h55); tx_tick=1; step(); tx_tick=0; transmit_a(8'h17);
        end
        repeat(100) step();
        if(ack_count!=expected_irqs || reti_count!=expected_irqs || irq || unsupported || txd!==3)
            $fatal(1,"CPU IRQ reasserted without new traffic");
        $display("PASS: actual Z80 IM2/ISR bytes/ACK/RETI=%0d, TX pins CE=%0d first/status=%0d flow=%0d",expected_irqs,period,first_status,flow_profile);
        if(decode_profile) $display("PASS: actual CPU neighboring/DAM/disabled SIO decode isolation");
        $finish;
    end
    initial begin #20000000; $fatal(1,"CPU SIO watchdog PC=%h stage=%h ACKs=%0d RETIs=%0d",address,memory[16'h4000],ack_count,reti_count); end
endmodule
