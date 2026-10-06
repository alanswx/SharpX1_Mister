// SPDX-License-Identifier: GPL-2.0-or-later
// Original connected Z80/DMA/service diagnostic, not a Sharp machine model.
// Fixture-only F1 enable/F2 result ports are NOT proposed X1 hardware ports.
// Real DMA flags feed service; WR4 IRQ parsing/IOR/auto-repeat remain separate.
`timescale 1ns/1ps
module dma_service_cpu_tb #(parameter bit NATIVE_IRQ=0);
    logic clk=0, reset=1, ce=0, pause_ce=0, iei=0;
    always #5 clk=~clk;
    integer period=1, phase=0, profile=0, pc=0, edges=0;
    always @(negedge clk) begin phase++; ce=!pause_ce && phase%period==0; end
    logic [7:0] memory[0:65535];
    wire [15:0] cpu_address,dma_address;
    wire [7:0] cpu_data,dma_data,dma_status;
    wire m1_n,mreq_n,iorq_n,rd_n,wr_n,halt_n,rfsh_n,busak_n;
    wire dma_mreq_n,dma_iorq_n,dma_rd_n,dma_wr_n,raw_busrq_n,unsupported;
    wire irq,ieo,service_pending,in_service,block_bus_request;
    wire [7:0] ack_vector;
    wire [7:0] candidate_vector;
    logic [7:0] expected_vector;
    wire native_irq,native_ieo,native_pending,native_service;
    wire helper_irq,helper_ieo,helper_pending,helper_service,helper_block;
    wire [7:0] native_vector,helper_vector;
    logic ack_old=0;
    logic reti=0,fetch_seen=0;
    logic [7:0] previous_opcode=0;
    wire owner=!busak_n;
    wire acknowledge=!owner && !m1_n && !iorq_n;
    wire dma_selected=!owner && m1_n && !iorq_n && cpu_address[15:4]==12'h1f8;
    logic irq_enabled=0,io_seen=0,memory_seen=0,dma_read_seen=0,dma_write_seen=0;
    logic io_active=0;
    logic [7:0] io_data=0,result=0;
    integer reads=0,writes=0,acks=0,returns=0,grants=0;
    logic owner_previous=0;
    wire condition=profile==0 ? dma.end_of_block : dma.match_found;
    wire [7:0] response=acknowledge ? ack_vector :
        !mreq_n && !rd_n ? memory[cpu_address] :
        dma_selected && !rd_n ? dma_status : io_active ? io_data : 8'hff;
    // The DMA CPU interface latches its read on an enabled edge. Present that
    // register directly and hold WAIT until accepted, rather than adding a
    // second stale-response register at the TV80 sampling edge.
    wire cpu_wait_n=!(dma_selected && !rd_n && !dma.read_seen);
    x1_dma_vector formation(.base_vector(8'hd6),.status_affects_vector(1'b1),
        .match_found(dma.match_found),.end_of_block(dma.end_of_block),.vector(candidate_vector));

    cpu processor (
        .clock(clk),.cep(ce),.cen(1'b0),.reset_n(!reset),.wait_n(cpu_wait_n),
        .busrq_n(raw_busrq_n || block_bus_request),.busak_n(busak_n),.int_n(!irq),
        .di(response),.a(cpu_address),.data_out(cpu_data),.m1(m1_n),
        .mreq(mreq_n),.iorq(iorq_n),.rd(rd_n),.wr(wr_n),.halt_n(halt_n),
        .rfsh_n(rfsh_n),.dir(16'b0),.dirset(1'b0)
    );
    x1_dma #(.COMPLETION_IRQ(NATIVE_IRQ)) dma (
        .iei(iei),.acknowledge(acknowledge),.reti(reti),
        .irq(native_irq),.ieo(native_ieo),.irq_pending(native_pending),
        .irq_in_service(native_service),.ack_vector(native_vector),
        .clk(clk),.ce(ce),.reset(reset),.cpu_cs(dma_selected),
        .cpu_rd_n(rd_n),.cpu_wr_n(wr_n),.cpu_data_in(cpu_data),.cpu_data_out(dma_status),
        .busrq_n(raw_busrq_n),.busak_n(busak_n),.mreq_n(dma_mreq_n),.iorq_n(dma_iorq_n),
        .rd_n(dma_rd_n),.wr_n(dma_wr_n),.address(dma_address),.data_out(dma_data),
        .data_in(memory[dma_address]),.wait_n(1'b1),.rdy(1'b1),.unsupported(unsupported)
    );
    x1_dma_service service (
        .clk(clk),.reset(reset),.irq_enabled(irq_enabled && !NATIVE_IRQ),.condition(condition),
        .bus_owned(!raw_busrq_n || !busak_n),.iei(iei),.acknowledge(acknowledge),
        .reti(reti),.reset_interrupts(1'b0),.candidate_vector(candidate_vector),
        .pending(helper_pending),.in_service(helper_service),.irq(helper_irq),.ieo(helper_ieo),
        .block_bus_request(helper_block),.ack_vector(helper_vector)
    );
    assign irq=NATIVE_IRQ ? native_irq : helper_irq;
    assign ieo=NATIVE_IRQ ? native_ieo : helper_ieo;
    assign service_pending=NATIVE_IRQ ? native_pending : helper_pending;
    assign in_service=NATIVE_IRQ ? native_service : helper_service;
    assign ack_vector=NATIVE_IRQ ? native_vector : helper_vector;
    // Native DMA inhibits requests internally; do not hide them at the CPU.
    assign block_bus_request=NATIVE_IRQ ? 1'b0 : helper_block;

    always @(posedge clk) begin
        if(reset) begin
            reti<=0; fetch_seen<=0; previous_opcode<=0;
            irq_enabled<=0; io_seen<=0; memory_seen<=0;
            dma_read_seen<=0; dma_write_seen<=0; io_active<=0; io_data<=0;
            ack_old<=0;
        end else begin
            edges++;
            if($test$plusargs("trace") && ce && edges<4000)
                $display("DMASVC a=%h di=%h m1=%b io=%b rd=%b wr=%b out=%h owner=%b rq=%b state=%d loaded=%b enabled=%b rem=%d ready=%b reads=%d writes=%d irqen=%b flags=%b%b ip=%b ius=%b irq=%b",cpu_address,response,m1_n,iorq_n,rd_n,wr_n,cpu_data,owner,raw_busrq_n,dma.state,dma.loaded,dma.enabled,dma.remaining,dma.ready_now,reads,writes,irq_enabled,dma.end_of_block,dma.match_found,service_pending,in_service,irq);
            assert(edges<1000000) else $fatal(1,"CPU service watchdog bus=%h result=%h reads=%d writes=%d irqen=%b EOB=%b IP=%b IUS=%b",cpu_address,result,reads,writes,irq_enabled,dma.end_of_block,service_pending,in_service);
            if(dma.loaded) assert(!unsupported) else $fatal(1,"unsupported loaded DMA stream");
            assert(!(irq && (!raw_busrq_n || owner))) else $fatal(1,"DMA interrupted before bus drain");
            if(owner && !owner_previous) grants++;
            owner_previous<=owner;
            if(acknowledge && !ack_old && irq) acks++;
            ack_old<=acknowledge;
            if(reti) returns++;
            reti<=0;
            if(!owner && !m1_n && !mreq_n && !rd_n) begin
                if(!fetch_seen) begin
                    if(previous_opcode==8'hed && memory[cpu_address]==8'h4d) reti<=1;
                    previous_opcode<=memory[cpu_address];
                end
                fetch_seen<=1;
            end else fetch_seen<=0;
            if(acknowledge) previous_opcode<=0;
            if(!owner && !mreq_n && !wr_n) begin
                if(!memory_seen) memory[cpu_address]<=cpu_data;
                memory_seen<=1;
            end else memory_seen<=0;
            if(!owner && !mreq_n && !rd_n) io_active<=0;
            else if(dma_selected && !rd_n) begin io_active<=1;io_data<=dma_status;end
            if(!owner && m1_n && !iorq_n && !wr_n) begin
                if(!io_seen) case(cpu_address[7:0])
                    8'hf1: irq_enabled<=cpu_data[0];
                    8'hf2: result<=cpu_data;
                    default: ;
                endcase
                io_seen<=1;
            end else io_seen<=0;
            if(owner && !dma_mreq_n && !dma_rd_n) begin
                if(!dma_read_seen) reads++;
                dma_read_seen<=1;
            end else dma_read_seen<=0;
            if(owner && !dma_mreq_n && !dma_wr_n) begin
                if(!dma_write_seen) begin writes++;memory[dma_address]<=dma_data;end
                dma_write_seen<=1;
            end else dma_write_seen<=0;
        end
    end
    task automatic emit(input logic [7:0] value);memory[pc]=value;pc++;endtask
    task automatic load(input logic [7:0] value);emit(8'h3e);emit(value);endtask
    task automatic store(input logic [15:0] address);
        emit(8'h32);emit(address[7:0]);emit(address[15:8]);
    endtask
    task automatic port(input logic [15:0] address);
        emit(8'h01);emit(address[7:0]);emit(address[15:8]);
    endtask
    task automatic put(input logic [7:0] value);load(value);emit(8'hed);emit(8'h79);endtask
    initial begin
        if($value$plusargs("CE_PERIOD=%d",period)) begin end
        if($value$plusargs("PROFILE=%d",profile)) begin end
        assert(period>0 && profile>=0 && profile<4) else $fatal(1,"bad fixture profile");
        expected_vector=profile==0 ? 8'hd4 : profile==3 ? 8'hd6 : 8'hd2;
        for(integer i=0;i<65536;i++) memory[i]=8'hcc;
        emit(8'hf3);emit(8'h31);emit(0);emit(8'hf0);
        // CPU prepares source and destination guards, not a debugger or DMA.
        for(integer i=0;i<6;i++) begin
            load(i==(profile==3 ? 3 : 1) ? 8'ha5 : 8'h31+8'(i));store(16'h8000+16'(i));
            load(8'hcc);store(16'h9000+16'(i));
        end
        load(0);store(16'h6001);
        load(8'h00);store({8'h20,expected_vector});
        load(8'h04);store({8'h20,expected_vector}+16'd1);
        load(8'h20);emit(8'hed);emit(8'h47);emit(8'hed);emit(8'h5e); // I, IM2
        if(!NATIVE_IRQ) begin port(16'h00f1);put(1);end
        port(16'h1f80);
        put(profile==0 ? 8'h7d : profile==2 ? 8'h7f : 8'h7e);
        // Pure continuous uses N reads, sequential uses N+1. Use four
        // programmed operations so the early match is distinct from EOB.
        put(0);put(8'h80);put(profile==1 || profile==3 ? 4 : 3);put(0);
        put(8'h14);put(8'h10);
        if(profile==0) put(8'h80);
        else begin put(8'h9c);put(0);put(8'ha5);end
        put((profile==2 ? 8'h8d : 8'had) | (NATIVE_IRQ ? 8'h10 : 8'h00));
        put(0);put(8'h90);
        if(NATIVE_IRQ) begin
            // Genuine WR4 associated interrupt-control/vector bytes; WR3
            // starts disabled, then real WR6 AB enables the IRQ circuit.
            put(8'h30 | (profile==0 ? 8'h02 : profile==3 ? 8'h03 : 8'h01));
            put(8'hd6);
        end
        put(8'h8a);put(8'hcf);
        if(NATIVE_IRQ) put(8'hab);
        put(8'h87);emit(8'hfb);emit(0);emit(8'h76); // EI; NOP; HALT
        port(16'h00f2);put(8'h5a);emit(8'hf3);emit(8'h76);
        assert(pc<16'h0400) else $fatal(1,"diagnostic overlaps handler");
        pc=1024;
        emit(8'hf5);emit(8'hc5); // PUSH AF,BC
        port(16'h1f80);put(8'h83);
        if(NATIVE_IRQ) begin
            put(8'haf); // AF must not clear IUS; RR0 IP is already ACK-cleared.
            put(8'hbf);emit(8'hed);emit(8'h78);store(16'h6002);
        end
        put(8'h8b); // clear real flags before RETI
        if(NATIVE_IRQ) put(8'hab);
        load(8'ha9);store(16'h6001);
        emit(8'hc1);emit(8'hf1);emit(8'hfb);emit(8'hed);emit(8'h4d);
        repeat(20) @(negedge clk);reset=0;
        // An upstream priority gate withholds service until the actual CPU
        // executes HALT. Avoid assuming whether DMA finishes before EI/HALT.
        wait(!halt_n);@(negedge clk);
        assert(service_pending && acks==0 && !irq && !in_service)
            else $fatal(1,"completion was not retained behind upstream IEI");
        iei=1;
        // Hold the genuine CPU ACK bus cycle for eighty system edges while
        // BOTH enabled engines stop. Service must capture exactly one vector.
        wait(acknowledge);@(negedge clk);pause_ce=1;
        repeat(80) begin
            @(negedge clk);
            assert(acknowledge && in_service && !service_pending && ack_vector==expected_vector &&
                   acks==1 && !owner && (NATIVE_IRQ ? dma.irq_bus_block : block_bus_request))
                else $fatal(1,"stopped-CE held real ACK lost vector/service");
        end
        pause_ce=0;
        wait(result==8'h5a);repeat(30) @(negedge clk);
        assert(memory[16'h6001]==8'ha9 && acks==1 && returns==1 &&
               !in_service && !service_pending && ieo && !irq && raw_busrq_n && busak_n)
            else $fatal(1,"actual IM2 handler/RETI/service result");
        assert(reads==(profile==0 ? 4 : profile==1 ? 3 : profile==2 ? 2 : 5) &&
               writes==(profile==0 ? 4 : profile==2 ? 2 : 0))
            else $fatal(1,"real DMA completion transactions reads=%d writes=%d",reads,writes);
        if(NATIVE_IRQ) assert(memory[16'h6002][3] &&
            memory[16'h6002][5:4]==(profile==0 ? 2'b01 : profile==3 ? 2'b00 : 2'b10))
            else $fatal(1,"CPU native RR0 after ACK/AF %h",memory[16'h6002]);
        for(integer i=0;i<6;i++) begin
            assert(memory[36864+i]==(i<writes ? memory[32768+i] : 8'hcc))
                else $fatal(1,"DMA destination/guard mismatch %d",i);
        end
        $display("PASS connected CPU/DMA service NATIVE_IRQ=%0d CE=%0d profile=%0d reads=%0d writes=%0d grants=%0d: IM2/vector/handler/RETI and 80 stopped-enable ACK edges",NATIVE_IRQ,period,profile,reads,writes,grants);
        $finish;
    end
endmodule
