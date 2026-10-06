// SPDX-License-Identifier: GPL-2.0-or-later
// Original CPU-executed IM2 diagnostic. No BIOS, snapshots, state forcing or
// emulator imports. Synthetic RAM holds only this test's generated program.
`timescale 1ns/1ps
module sio_cpu_tb;
    reg clk=0, ce=0, reset=1;
    always #5 clk=~clk;
    integer period=1,edges=0,pc=0,ack_count=0,reti_count=0;
    always @(negedge clk) begin edges=edges+1; ce=(edges%period)==0; end
    wire m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,halt_n,busak_n;
    wire [15:0] address;
    wire [7:0] cpu_data,sio_data,ack_vector;
    reg [7:0] memory[0:65535];
    reg [7:0] memory_data=0;
    wire cpu_cs=!iorq_n && m1_n && address[15:2]==14'(16'h1f90>>2);
    wire acknowledge=!iorq_n && !m1_n;
    wire [7:0] cpu_di=acknowledge ? ack_vector : cpu_cs ? sio_data : memory_data;
    reg [1:0] rx_tick=0,tx_tick=0,rxd=3,cts_n=3,dcd_n=3;
    wire [1:0] txd,rts_n,dtr_n;
    wire unsupported,irq,ieo,reti;
    reg ack_old=0;
    reg [7:0] observed_vector;
    cpu processor (
        .clock(clk), .cep(ce), .cen(1'b0), .reset_n(!reset),
        .int_n(!irq), .wait_n(1'b1), .busrq_n(1'b1), .busak_n(busak_n),
        .rfsh_n(rfsh_n), .halt_n(halt_n), .mreq(mreq_n), .iorq(iorq_n),
        .wr(wr_n), .rd(rd_n), .m1(m1_n), .di(cpu_di), .data_out(cpu_data),
        .a(address), .dir(16'b0), .dirset(1'b0)
    );
    x1_sio_interrupt sio (
        .clk(clk), .ce(ce), .reset(reset), .cpu_cs(cpu_cs),
        .cpu_rd_n(rd_n), .cpu_wr_n(wr_n), .address(address[1:0]),
        .cpu_din(cpu_data), .cpu_dout(sio_data), .rx_tick(rx_tick), .tx_tick(tx_tick),
        .rxd(rxd), .cts_n(cts_n), .dcd_n(dcd_n), .txd(txd), .rts_n(rts_n), .dtr_n(dtr_n),
        .unsupported(unsupported), .iei(1'b1), .acknowledge(acknowledge),
        .reti(reti), .irq(irq), .ieo(ieo), .ack_vector(ack_vector)
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
        memory_data<=memory[address];
        if(!reset && !mreq_n && !wr_n) memory[address]<=cpu_data;
        if(reset) begin ack_old<=0; ack_count<=0; reti_count<=0; end
        else begin
            ack_old<=acknowledge;
            if(acknowledge && !ack_old) begin
                case(ack_count)
                    0: if(ack_vector!==8'he4) $fatal(1,"CPU first vector not B RX");
                    1: if(ack_vector!==8'hee) $fatal(1,"CPU second vector not A special RX");
                    2: if(ack_vector!==8'he8) $fatal(1,"CPU third vector not A TX");
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
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        for(integer i=0;i<65536;i=i+1) memory[i]=0;
        emit(8'hf3); emit(8'h31); emit(8'h00); emit(8'hff); // DI; LD SP,ff00
        load_a(2); emit(8'hed); emit(8'h47); emit(8'hed); emit(8'h5e); // LD I,A; IM 2
        for(integer ch=0;ch<2;ch=ch+1) begin
            port(ch==0 ? 16'h1f91 : 16'h1f93); out_byte(8'h18);
            reg_write(4,8'h44); reg_write(3,8'hc1); reg_write(5,8'hea);
            reg_write(1,ch==0 ? 8'h12 : 8'h16);
        end
        reg_write(2,8'he0); // B vector only
        mark(1); emit(8'hfb); emit(8'h76); emit(8'hf3); // EI; HALT; DI after ISR
        mark(2); emit(8'hfb); emit(8'h76); emit(8'hf3);
        port(16'h1f90); out_byte(8'h69);
        mark(3); emit(8'hfb); emit(8'h76); emit(8'hf3);
        mark(8'haa); emit(8'h76);
        pc=32'h0400; port(16'h1f92); emit(8'hed); emit(8'h78); store(16'h4100);
        load_a(8'he4); store(16'h4102); emit(8'hfb); emit(8'hed); emit(8'h4d);
        pc=32'h0440; port(16'h1f90); emit(8'hed); emit(8'h78); store(16'h4101);
        load_a(8'hee); store(16'h4102); emit(8'hfb); emit(8'hed); emit(8'h4d);
        pc=32'h0480; port(16'h1f91); out_byte(8'h28);
        load_a(8'he8); store(16'h4102); emit(8'hfb); emit(8'hed); emit(8'h4d);
        vector_entry(8'he4,16'h0400); vector_entry(8'hee,16'h0440); vector_entry(8'he8,16'h0480);
        repeat(8) step(); reset=0;
        stage(1); if(irq) $fatal(1,"IRQ before serial traffic");
        receive(1,8'hb6,0);
        stage(2);
        if(memory[16'h4100]!==8'hb6 || memory[16'h4102]!==8'he4 || reti_count!=1)
            $fatal(1,"CPU B RX ISR/read/RETI failed");
        receive(0,8'h37,1);
        stage(3);
        if(memory[16'h4101]!==8'h37 || memory[16'h4102]!==8'hee || reti_count!=2)
            $fatal(1,"CPU A special RX ISR/read/RETI failed");
        tx_tick=1; step(); tx_tick=0;
        if(txd[0]!==0) $fatal(1,"CPU TX data did not enter shifter");
        stage(8'haa);
        if(memory[16'h4102]!==8'he8 || ack_count!=3 || reti_count!=3 || irq || !ieo)
            $fatal(1,"CPU TX pending reset/final RETI failed");
        // Verify the actual transmitted character loaded by CPU, not merely
        // the interrupt handler marker. Advance each bit exactly 16 ticks.
        tx_tick=1;
        for(integer i=0;i<10;i=i+1) begin
            reg [9:0] frame;
            frame={1'b1,8'h69,1'b0};
            repeat(16) begin
                if(txd[0]!==frame[i]) $fatal(1,"CPU TX pin bit %0d mismatch",i);
                step();
            end
        end
        tx_tick=0;
        repeat(100) step();
        if(ack_count!=3 || reti_count!=3 || irq || unsupported || txd!==3)
            $fatal(1,"CPU IRQ reasserted without new traffic");
        $display("PASS: actual Z80 IM2 B RX/A framing-special/TX vectors E4/EE/E8, ISR bytes, three ACK/decoded RETI, real TX pins CE=%0d",period);
        $finish;
    end
    initial begin #20000000; $fatal(1,"CPU SIO watchdog PC=%h stage=%h ACKs=%0d RETIs=%0d",address,memory[16'h4000],ack_count,reti_count); end
endmodule
