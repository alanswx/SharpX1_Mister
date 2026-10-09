// SPDX-License-Identifier: GPL-2.0-or-later
// Original Z80-executed FM bus diagnostic. This is not native board decode,
// IRQ routing or firmware acceptance. No forced CPU/chip state or private assets.
`timescale 1ps/1ps
module fm_cpu_tb #(parameter integer MASTER_HZ=32000000, parameter DECODE_ENABLED=1);
    localparam longint unsigned HALF_PS=64'd500000000000/64'(MASTER_HZ);
    logic clk=0, reset=1, enable=1, ce=0;
    always #(HALF_PS) clk=!clk;
    integer period=8, phase=0, edges=0, pc=0;
    always @(negedge clk) begin phase++; ce=(phase%period)==0; end
    wire [15:0] address;
    wire [7:0] cpu_data, status;
    wire m1_n,mreq_n,iorq_n,rd_n,wr_n,halt_n,rfsh_n,busak_n;
    wire wait_n,irq_n,ct1,ct2,sample,ce4,ce2,fault;
    wire signed [15:0] left,right;
    logic [7:0] memory[0:65535];
    logic [7:0] memory_data=0, io_data=0;
    logic io_active=0;
    // Conservative decode, not an assertion about native ASIC mirrors or IRQ.
    wire selected;
    x1_fm_decode decode(.enabled(1'(DECODE_ENABLED)),.reset(reset),.dam(1'b0),
        .m1_n(m1_n),.mreq_n(mreq_n),.iorq_n(iorq_n),.rd_n(rd_n),.wr_n(wr_n),
        .address(address),.selected(selected),.read_access(),.write_access());
    wire [7:0] response=selected && !rd_n ? status :
        io_active && mreq_n ? io_data : memory_data;
    cpu processor (
        .clock(clk),.cep(ce),.cen(1'b0),.reset_n(!reset),
        .int_n(1'b1),.wait_n(wait_n),.busrq_n(1'b1),.busak_n(busak_n),
        .di(response),.a(address),.data_out(cpu_data),.m1(m1_n),
        .mreq(mreq_n),.iorq(iorq_n),.rd(rd_n),.wr(wr_n),
        .rfsh_n(rfsh_n),.halt_n(halt_n),.dir(16'b0),.dirset(1'b0)
    );
    x1_fm #(.MASTER_HZ(MASTER_HZ)) dut (
        .clk(clk),.reset(reset),.enable(enable),.cpu_cs(selected),
        .cpu_rd_n(rd_n),.cpu_wr_n(wr_n),.cpu_a0(address[0]),
        .cpu_data_in(cpu_data),.cpu_data_out(status),.wait_n(wait_n),
        .irq_n(irq_n),.ct1(ct1),.ct2(ct2),.sample(sample),
        .left(left),.right(right),.cen_chip(ce4),.cen_half(ce2),.protocol_error(fault)
    );
    integer dispatches=0,busy_reads=0,wait_edges=0,irq_edges=0;
    // Preserve clocked I/O response through TV80's trailing automatic I/O wait.
    // Memory writes are real CPU stores, never debugger/test result injection.
    always @(posedge clk or posedge reset) begin
        if(reset) begin memory_data<=0;io_data<=0;io_active<=0; dispatches=0; busy_reads=0; wait_edges=0; irq_edges=0; end
        else begin
            edges++;
            if($test$plusargs("trace") && edges<1500 && ce)
                $display("CPUFM edge=%0d a=%h mreq=%b iorq=%b rd=%b wr=%b di=%h cs=%b status=%h wait=%b writes=%0d",edges,address,mreq_n,iorq_n,rd_n,wr_n,response,selected,dut.status,wait_n,dispatches);
            assert(edges<3000000) else $fatal(1,"CPU FM watchdog PC/bus=%h",address);
            memory_data<=memory[address];
            if(!mreq_n && !rd_n) io_active<=0;
            else if(!iorq_n && !rd_n && m1_n) begin
                io_active<=1;io_data<=selected ? status : 8'hff;
            end
            if(!mreq_n && !wr_n) memory[address]<=cpu_data;
            if(dut.dispatch) begin
                dispatches++;
                if(dut.saved_a0) assert(!dut.status[7])
                    else $fatal(1,"CPU data write while busy");
            end
            if(selected && !rd_n && status[7]) busy_reads++;
            if(ce && !wait_n) wait_edges++;
            if(!irq_n) irq_edges++;
            assert(!fault) else $fatal(1,"CPU overran FM write queue");
            assert(busak_n) else $fatal(1,"unexpected CPU bus relinquish");
            if(!enable) assert(!ce4 && !ce2 && !sample)
                else $fatal(1,"FM advanced with stopped enable");
        end
    end
    task automatic emit(input logic [7:0] value); memory[pc]=value; pc++; endtask
    task automatic port(input logic [15:0] value);
        emit(8'h01);emit(value[7:0]);emit(value[15:8]); // LD BC,nn
    endtask
    task automatic load(input logic [7:0] value);emit(8'h3e);emit(value);endtask
    task automatic store(input logic [15:0] value);
        emit(8'h32);emit(value[7:0]);emit(value[15:8]);
    endtask
    task automatic output_byte(input logic [7:0] value);
        load(value);emit(8'hed);emit(8'h79); // OUT (C),A
    endtask
    task automatic poll(input logic [7:0] mask,input logic until_set);
        integer loop_address;
        loop_address=pc;
        emit(8'hed);emit(8'h78); // IN A,(C)
        emit(8'he6);emit(mask); // AND mask
        emit(until_set ? 8'h28 : 8'h20); // JR Z/NZ,loop
        emit(8'(loop_address-(pc+1)));
    endtask
    task automatic reg_write(input logic [7:0] index,value);
        port(16'h0701);poll(8'h80,0);
        port(16'h0700);output_byte(index);
        port(16'h0701);output_byte(value);poll(8'h80,0);
    endtask
    task automatic ticks(input integer count);repeat(count) @(negedge clk);endtask
    task automatic complete;
        wait(!halt_n);ticks(10);
        assert(memory[16'h4000]==8'h5a && memory[16'h4001]==1 &&
               memory[16'h4002]==0 && memory[16'h4003]==8'hff)
            else $fatal(1,"CPU FM results marker/timer/cleared/unselected=%h/%h/%h/%h",
                memory[16'h4000],memory[16'h4001],memory[16'h4002],memory[16'h4003]);
        assert(dispatches==10 && busy_reads>0 && wait_edges>0 && irq_edges>0 &&
               irq_n && ct1 && ct2 && !fault)
            else $fatal(1,"CPU FM bus/status mismatch writes=%0d busy=%0d waits=%0d irq=%0d",
                dispatches,busy_reads,wait_edges,irq_edges);
        assert(memory[16'h4004]==0) else $fatal(1,"CPU FM programmed decode/read failed");
        for(integer i=0;i<10;i++) assert(memory[16'h4100+16'(i)]==8'hff)
            else $fatal(1,"CPU neighboring port selected FM index=%0d value=%h",i,memory[16'h4100+16'(i)]);
        $display("PASS CPU FM MASTER=%0d CE=%0d writes=%0d busy_reads=%0d waits=%0d irq_edges=%0d",
                 MASTER_HZ,period,dispatches,busy_reads,wait_edges,irq_edges);
    endtask
    initial begin
        if($value$plusargs("CE_PERIOD=%d",period)) begin end
        assert(period>0) else $fatal(1,"invalid CPU CE period");
        for(integer i=0;i<65536;i++) memory[i]=0;
        emit(8'hf3);emit(8'h31);emit(8'h00);emit(8'hf0); // DI; LD SP,F000
        load(0);store(16'h4000);
        port(16'h0701);emit(8'hed);emit(8'h78);store(16'h4004);
        load(8'h91);store(16'h4005);
        for(integer i=0;i<10;i++) begin
            case(i)
                0:port(16'h0600);1:port(16'h06ff);2:port(16'h0702);
                3:port(16'h0703);4:port(16'h0704);5:port(16'h0707);
                6:port(16'h07ff);7:port(16'h0800);8:port(16'h1f90);
                default:port(16'h1fa0);
            endcase
            output_byte(8'h7f);emit(8'hed);emit(8'h78);store(16'h4100+16'(i));
        end
        reg_write(8'h1b,8'hc0); // CT pins, no invented board use
        reg_write(8'h10,8'hfa);reg_write(8'h11,8'h00); // timer A=1000
        reg_write(8'h14,8'h05); // start timer A, enable its flag IRQ
        port(16'h0701);poll(8'h01,1);store(16'h4001);
        reg_write(8'h14,8'h10); // stop and clear A
        port(16'h0700);emit(8'hed);emit(8'h78);store(16'h4002);
        port(16'h0702);emit(8'hed);emit(8'h78);store(16'h4003);
        load(8'h5a);store(16'h4000);emit(8'h76);
        ticks(40);reset=0;
        wait(memory[16'h4005]==8'h91);
        assert(memory[16'h4004]==0) else $fatal(1,"CPU FM programmed decode/read failed");
        // Pause the FM engine at the first data write. CPU continues running
        // and must wait without changing its transaction or repeating it.
        wait(dut.pending && dut.saved_a0);@(negedge clk);enable=0;
        ticks(200);
        assert(dut.pending && !wait_n && address==16'h0701 && !wr_n)
            else $fatal(1,"CPU did not hold queued stopped-enable write");
        enable=1;complete();
        // Warm restart through the real reset pin, with RAM/program retained.
        @(negedge clk);#2;reset=1;#2;reset=0;
        ticks(40);complete();
        // Interrupt-flag reset, not CPU IRQ service: board routing is unproven.
        // Restart once more, let genuine timer IRQ assert, then pulse reset
        // while the FM enable is stopped. CPU must boot and queue a new write.
        @(negedge clk);#2;reset=1;#2;reset=0;
        ticks(40);wait(!irq_n);
        @(negedge clk);enable=0;#2;reset=1;#2;reset=0;
        wait(dut.pending); // CPU instruction duration scales with its CE period.
        ticks(200);
        assert(irq_n && !ct1 && !ct2 && !fault && dut.pending && !wait_n)
            else $fatal(1,"FM IRQ reset/CPU stopped-enable restart failed");
        enable=1;complete();
        $display("PASS CPU FM retained-program raw/HALT/IRQ-flag reset and stopped-enable WAIT");
        $finish;
    end
endmodule
