// SPDX-License-Identifier: GPL-2.0-or-later
// Original CPU-executed diagnostic and functional single-owner bus fixture.
// No machine, BIOS/game bytes, register/PC forcing or debug RAM injection.
`timescale 1ns/1ps
module dma_cpu_tb;
    logic clk=0, cpu_ce=0, dma_ce=0, reset_n=0, dma_reset=1, cold_reset=1;
    wire cpu_m1_n,cpu_mreq_n,cpu_iorq_n,cpu_rd_n,cpu_wr_n,cpu_rfsh_n,cpu_halt_n;
    wire busrq_n,busak_n;
    wire [15:0] cpu_address,dma_address;
    wire [7:0] cpu_dout,dma_dout,dma_cpu_dout;
    wire dma_mreq_n,dma_iorq_n,dma_rd_n,dma_wr_n,dma_unsupported;
    wire cpu_wait_n,dma_wait_n,dma_cpu_cs;
    logic hold_dma_wait=0;
    bit direct_register_read=0;
    logic [7:0] memory[0:65535];
    logic [7:0] response_q;
    wire dma_owner = !busak_n;
    wire [15:0] bus_address = dma_owner ? dma_address : cpu_address;
    wire [7:0] bus_dout = dma_owner ? dma_dout : cpu_dout;
    wire bus_mreq_n = dma_owner ? dma_mreq_n : cpu_mreq_n;
    wire bus_iorq_n = dma_owner ? dma_iorq_n : cpu_iorq_n;
    wire bus_rd_n = dma_owner ? dma_rd_n : cpu_rd_n;
    wire bus_wr_n = dma_owner ? dma_wr_n : cpu_wr_n;
    wire bus_active = (!bus_mreq_n || !bus_iorq_n) && (!bus_rd_n || !bus_wr_n);
    wire bus_ce = dma_owner ? dma_ce : cpu_ce;
    logic pending=0,accepted=0;
    logic [3:0] target_age=0;
    logic [15:0] latched_address;
    logic [7:0] latched_data;
    logic latched_owner,latched_io,latched_read;
    wire target_ready = pending && target_age>=4;
    wire cpu_dma_port = (cpu_address & 16'hfff0)==16'h1f80;
    wire direct_read_selected = direct_register_read && !dma_owner &&
                               !cpu_iorq_n && !cpu_rd_n && cpu_dma_port;
    wire [7:0] cpu_di = direct_read_selected ? dma_cpu_dout : response_q;
    assign cpu_wait_n = !bus_active || dma_owner || direct_read_selected || target_ready;
    assign dma_wait_n = target_ready && !hold_dma_wait;
    wire selected_wait_n = dma_owner ? dma_wait_n : cpu_wait_n;
    // Reads prepare the DMA's latched response during WAIT. Test both writes
    // at accepted target edges and raw chip-select throughout a stretched OUT.
    // Raw selection deliberately allows BUSRQ before that CPU OUT completes;
    // actual CPU ACK must still wait for its own cycle boundary.
    integer register_write_mode=0;
    assign dma_cpu_cs = reset_n && !dma_owner && !cpu_iorq_n && cpu_dma_port &&
                       (!cpu_rd_n || (!cpu_wr_n && (register_write_mode!=0 || target_ready)));
    integer enable_period=1,phase=0,reset_profile=0;
    integer master_edges=0,cpu_writes=0,cpu_io_reads=0,dma_reads=0,dma_writes=0;
    integer grants=0,wait_blocked_grants=0,stretched_cpu_cycles=0;
    integer tx_count=0,rx_count=0,tx_read_index=0,reset_io_count=0;
    logic [7:0] tx_fifo[0:7],reset_payload=0,result=0,stage=0;
    integer ready_gap=0;
    wire input_stage = stage==8'h13 || stage==8'h14;
    wire reset_stage = stage==8'h15;
    wire [31:0] progress = reset_stage ? 32'(reset_io_count) :
                          input_stage ? 32'(rx_count) : 32'(tx_count);
    wire [31:0] quota = reset_stage ? 32'd1 :
                       (stage==8'h12 || stage==8'h14) ? 32'd8 : 32'd4;
    wire drq = stage!=0 && progress<quota && ready_gap==0;
    wire rdy = input_stage ? !drq : drq;
    cpu processor(
        .clock(clk),.cep(cpu_ce),.cen(1'b0),.reset_n(reset_n),
        .wait_n(cpu_wait_n),.busrq_n(busrq_n),.busak_n(busak_n),
        .int_n(1'b1),.dir(16'b0),.dirset(1'b0),
        .di(cpu_di),.a(cpu_address),.data_out(cpu_dout),
        .m1(cpu_m1_n),.mreq(cpu_mreq_n),.iorq(cpu_iorq_n),
        .rd(cpu_rd_n),.wr(cpu_wr_n),.rfsh_n(cpu_rfsh_n),.halt_n(cpu_halt_n)
    );
    x1_dma dma(
        .clk(clk),.ce(dma_ce),.reset(dma_reset),
        .cpu_cs(dma_cpu_cs),.cpu_rd_n(cpu_rd_n),.cpu_wr_n(cpu_wr_n),
        .cpu_data_in(cpu_dout),.cpu_data_out(dma_cpu_dout),
        .busrq_n(busrq_n),.busak_n(busak_n),
        .mreq_n(dma_mreq_n),.iorq_n(dma_iorq_n),.rd_n(dma_rd_n),.wr_n(dma_wr_n),
        .address(dma_address),.data_out(dma_dout),.data_in(response_q),
        .wait_n(dma_wait_n),.rdy(rdy),.unsupported(dma_unsupported)
    );

    function automatic logic [7:0] sent_byte(input integer index);
        return 8'h31 + 8'(index*13);
    endfunction
    function automatic logic [7:0] received_byte(input integer index);
        return 8'hb0 + 8'(index*7);
    endfunction
    function automatic logic [7:0] io_response(input logic [15:0] addr);
        if ((addr & 16'hfff0)==16'h1f80) return dma_cpu_dout;
        case(addr[7:0])
            8'h22: return input_stage ? 8'(rx_count) : 8'(tx_count);
            8'h23: return tx_read_index<8 ? tx_fifo[tx_read_index] : 8'hff;
            8'h24: return 8'(reset_profile);
            8'h25: return 8'(reset_io_count);
            8'h26: return reset_payload;
            8'h40: return received_byte(rx_count);
            default: return 8'hff;
        endcase
    endfunction

    // Clocked memory/functional I/O response. Responses stay latched through
    // the read; consuming the FIFO cannot change the sampled byte. WAIT adds
    // four enabled intervals to *both* CPU and DMA accesses. Every target
    // operation has one accepted edge even when strobes remain stretched.
    always @(posedge clk) begin
        if(cold_reset) begin
            pending<=0; accepted<=0; target_age<=0; response_q<=0;
            cpu_writes<=0; cpu_io_reads<=0; dma_reads<=0; dma_writes<=0;
            tx_count<=0; rx_count<=0; tx_read_index<=0;
            reset_io_count<=0; reset_payload<=0; result<=0; stage<=0; ready_gap<=0;
        end else begin
            if ((cpu_ce || dma_ce) && ready_gap>0) ready_gap<=ready_gap-1;
            if(!bus_active) begin pending<=0; accepted<=0; target_age<=0; end
            else if(!pending) begin
                pending<=1; accepted<=0; target_age<=0;
                latched_address<=bus_address; latched_data<=bus_dout;
                latched_owner<=dma_owner; latched_io<=!bus_iorq_n;
                latched_read<=!bus_rd_n;
                response_q<=!bus_iorq_n ? io_response(bus_address) : memory[bus_address];
            end else begin
                if (bus_address!=latched_address || dma_owner!=latched_owner ||
                    !bus_iorq_n!=latched_io || !bus_rd_n!=latched_read ||
                    (!bus_wr_n && bus_dout!=latched_data))
                    $fatal(1,"target changed pending transaction addr=%h/%h owner=%b/%b",bus_address,latched_address,dma_owner,latched_owner);
                // DMA control read is itself a latched synchronous peripheral;
                // let its response settle during the inserted CPU WAIT.
                if(!dma_owner && !bus_rd_n && !bus_iorq_n && cpu_dma_port && !accepted)
                    response_q<=dma_cpu_dout;
                if(bus_ce && target_age<4) target_age<=target_age+4'd1;
                if(bus_ce && selected_wait_n && !accepted) begin
                    accepted<=1;
                    if(dma_owner) begin
                        if(dma_unsupported) $fatal(1,"unsupported DMA operation reached target");
                        if(!bus_rd_n) dma_reads<=dma_reads+1;
                        else dma_writes<=dma_writes+1;
                    end else begin
                        if(!bus_wr_n) cpu_writes<=cpu_writes+1;
                        else if(!bus_iorq_n) cpu_io_reads<=cpu_io_reads+1;
                    end
                    if(!bus_wr_n && !bus_mreq_n) begin
                        if(bus_address<16'h8000) $fatal(1,"write into original ROM");
                        memory[bus_address]<=bus_dout;
                    end
                    if(!bus_iorq_n) begin
                        if(!bus_wr_n) begin
                            case(bus_address[7:0])
                                8'h20: begin
                                    if(dma_owner) $fatal(1,"DMA wrote CPU control target");
                                    stage<=bus_dout; ready_gap<=12;
                                end
                                8'h21: begin
                                    if(dma_owner) $fatal(1,"DMA emitted CPU result");
                                    result<=bus_dout;
                                    if(bus_dout!=8'ha5)
                                        $fatal(1,"native ROM failed PC=%h response=%h stage=%h tx=%0d rx=%0d",processor.Z80CPU.i_tv80_core.PC,response_q,stage,tx_count,rx_count);
                                end
                                8'h41: begin
                                    if(!dma_owner) $fatal(1,"CPU performed DMA payload write");
                                    if(reset_stage) begin
                                        reset_io_count<=reset_io_count+1; reset_payload<=bus_dout;
                                    end else begin
                                        if(tx_count>=8 || bus_dout!=sent_byte(tx_count))
                                            $fatal(1,"DMA TX payload/index error");
                                        tx_fifo[tx_count]<=bus_dout; tx_count<=tx_count+1;
                                    end
                                    ready_gap<=22;
                                end
                                default: if((bus_address & 16'hfff0)!=16'h1f80)
                                    $fatal(1,"unknown write target %h",bus_address);
                            endcase
                        end else begin
                            case(bus_address[7:0])
                                8'h40: begin
                                    if(!dma_owner || !input_stage) $fatal(1,"wrong FIFO reader");
                                    rx_count<=rx_count+1; ready_gap<=22;
                                end
                                8'h23: begin
                                    if(dma_owner) $fatal(1,"DMA inspected CPU TX log");
                                    tx_read_index<=tx_read_index+1;
                                end
                                default: ;
                            endcase
                        end
                    end
                end
            end
        end
    end

    task automatic tick(input bit cpu_enabled,input bit dma_enabled);
        bit old_ack,blocked_wait;
        integer old_cpu_writes,old_cpu_reads;
        logic [15:0] owned_pc;
        cpu_ce=cpu_enabled; dma_ce=dma_enabled;
        #5;
        old_ack=busak_n;
        old_cpu_writes=cpu_writes; old_cpu_reads=cpu_io_reads;
        owned_pc=processor.Z80CPU.i_tv80_core.PC;
        blocked_wait=reset_n && cpu_enabled && !busrq_n && busak_n &&
                     !cpu_wait_n && bus_active;
        if(blocked_wait) wait_blocked_grants++;
        if(reset_n && cpu_enabled && bus_active && !dma_owner && !cpu_wait_n)
            stretched_cpu_cycles++;
        clk=1; #2; // Keep inherited TV80 1ps assignments (--timing).
        master_edges++;
        if(master_edges>2000000) $fatal(1,"CPU/DMA fixture watchdog");
        if(blocked_wait && !busak_n) $fatal(1,"CPU granted DMA before WAIT cycle finished");
        if(!dma_rd_n || !dma_wr_n) begin
            if(busak_n || busrq_n) $fatal(1,"DMA strobes before real ownership");
            if(dma_mreq_n==dma_iorq_n) $fatal(1,"DMA memory/I/O selection invalid");
        end
        if(reset_n && !busak_n) begin
            if({cpu_m1_n,cpu_mreq_n,cpu_iorq_n,cpu_rd_n,cpu_wr_n,cpu_rfsh_n}!=6'b111111)
                $fatal(1,"CPU strobe while DMA owns bus");
            if(!old_ack && (processor.Z80CPU.i_tv80_core.PC!=owned_pc ||
                cpu_writes!=old_cpu_writes || cpu_io_reads!=old_cpu_reads))
                $fatal(1,"CPU execution/side effect during DMA ownership");
            if(old_ack) grants++;
        end
        #3; clk=0;
    endtask
    task automatic step;
        bit enabled;
        enabled=(phase % enable_period)==0;
        tick(enabled,enabled); phase++;
    endtask

    // Small original ROM emitter, not an assembler or firmware-derived table.
    integer rom_size,alias_sequence,fail_count;
    integer fail_fixups[0:255];
    task automatic emit(input logic [7:0] byte_value);
        if(rom_size>=16'h2000) $fatal(1,"original ROM exceeds fixture aperture");
        memory[rom_size]=byte_value; rom_size++;
    endtask
    task automatic word_value(input logic [15:0] value);
        emit(value[7:0]); emit(value[15:8]);
    endtask
    task automatic load_a(input logic [7:0] value); emit(8'h3e); emit(value); endtask
    task automatic store_a(input logic [15:0] addr); emit(8'h32); word_value(addr); endtask
    task automatic load_memory(input logic [15:0] addr); emit(8'h3a); word_value(addr); endtask
    task automatic out_port(input logic [7:0] port_number); emit(8'hd3); emit(port_number); endtask
    task automatic in_port(input logic [7:0] port_number); emit(8'hdb); emit(port_number); endtask
    task automatic assert_a(input logic [7:0] expected_value);
        emit(8'hfe); emit(expected_value); emit(8'hc2); // CP; JP NZ,fail
        fail_fixups[fail_count]=rom_size; fail_count++;
        word_value(0);
    endtask
    task automatic dma_byte(input logic [7:0] value);
        emit(8'h0e); emit(alias_sequence[0]?8'h8f:8'h80); alias_sequence++;
        load_a(value); emit(8'hed); emit(8'h79); // OUT (C),A; BC=1F8x
    endtask
    task automatic arm(input logic [7:0] value); load_a(value); out_port(8'h20); endtask
    task automatic poll_count(input logic [7:0] expected_count);
        integer loop_address;
        loop_address=rom_size;
        in_port(8'h22); emit(8'hfe); emit(expected_count);
        emit(8'hc2); word_value(16'(loop_address));
    endtask
    task automatic stream(input logic [15:0] a,b,input bit a_source,input logic [7:0] ready_config);
        dma_byte(8'h83);
        dma_byte(a_source?8'h7d:8'h79);
        dma_byte(a[7:0]); dma_byte(a[15:8]); dma_byte(3); dma_byte(0);
        dma_byte(8'h14); dma_byte(8'h28); dma_byte(8'h80);
        dma_byte(8'h8d); dma_byte(b[7:0]); dma_byte(b[15:8]); dma_byte(ready_config);
        if(a_source) begin dma_byte(8'h01); dma_byte(8'hcf); dma_byte(8'h05); end
        dma_byte(8'hcf);
    endtask
    task automatic check_registers(input logic [15:0] a,b,input logic [7:0] n,input logic [15:0] save_addr);
        logic [7:0] expected_bytes[0:5];
        expected_bytes[0]=n; expected_bytes[1]=0;
        expected_bytes[2]=a[7:0]; expected_bytes[3]=a[15:8];
        expected_bytes[4]=b[7:0]; expected_bytes[5]=b[15:8];
        dma_byte(8'hbb); dma_byte(8'h7e); dma_byte(8'ha7);
        for(integer i=0;i<6;i++) begin
            emit(8'hed); emit(8'h78); // IN A,(C)
            store_a(save_addr+16'(i)); assert_a(expected_bytes[i]);
        end
    endtask
    task automatic install_rom;
        integer warm_fixup,warm_entry,normal_fixup,done_entry,fail_entry;
        for(integer i=0;i<65536;i++) memory[i]=0;
        rom_size=0; fail_count=0; alias_sequence=0;
        emit(8'hf3); emit(8'h31); word_value(16'hc000); // DI; LD SP,C000
        emit(8'h01); word_value(16'h1f80); // LD BC,DMA stream
        load_memory(16'h8ff0); emit(8'hfe); emit(1); emit(8'hca);
        warm_fixup=rom_size; word_value(0); // JP Z,warm-entry
        for(integer i=0;i<8;i++) begin
            load_a(sent_byte(i)); store_a(16'h8000+16'(i));
            load_a(8'he7); store_a(16'h8200+16'(i));
        end
        stream(16'h8000,16'h0041,1,8'h9a);
        arm(8'h11); dma_byte(8'h87); poll_count(4);
        check_registers(16'h8004,16'h0041,3,16'h9000);
        dma_byte(8'hd3); arm(8'h12); dma_byte(8'h87); poll_count(8);
        check_registers(16'h8008,16'h0041,3,16'h9010);
        for(integer i=0;i<8;i++) begin in_port(8'h23); assert_a(sent_byte(i)); end
        stream(16'h8200,16'h0040,0,8'h92);
        arm(8'h13); dma_byte(8'h87); poll_count(4);
        check_registers(16'h8203,16'h0040,3,16'h9020);
        dma_byte(8'hd3); arm(8'h14); dma_byte(8'h87); poll_count(8);
        check_registers(16'h8207,16'h0040,3,16'h9030);
        for(integer i=0;i<8;i++) begin load_memory(16'h8200+16'(i)); assert_a(received_byte(i)); end
        dma_byte(8'hbf); emit(8'hed); emit(8'h78); emit(8'he6); emit(8'h3b); assert_a(8'h19);
        in_port(8'h24); emit(8'hfe); emit(0); emit(8'hca);
        normal_fixup=rom_size; word_value(0); // JP Z,done
        load_a(1); store_a(16'h8ff0); // Z80-written retained reset marker
        stream(16'h8000,16'h0041,1,8'h9a);
        arm(8'h15); dma_byte(8'h87);
        emit(8'hc3); word_value(16'(rom_size-1)); // wait for external reset
        warm_entry=rom_size;
        in_port(8'h25); assert_a(1); in_port(8'h26); assert_a(sent_byte(0));
        check_registers(0,0,0,16'h9040); // hardware reset clears DMA counters
        done_entry=rom_size;
        load_a(8'ha5); out_port(8'h21); emit(8'h76);
        fail_entry=rom_size;
        load_a(8'he1); out_port(8'h21); emit(8'h76);
        memory[warm_fixup]=8'(warm_entry); memory[warm_fixup+1]=8'(warm_entry>>8);
        memory[normal_fixup]=8'(done_entry); memory[normal_fixup+1]=8'(done_entry>>8);
        for(integer i=0;i<fail_count;i++) begin
            memory[fail_fixups[i]]=8'(fail_entry); memory[fail_fixups[i]+1]=8'(fail_entry>>8);
        end
    endtask

    task automatic drain_reset;
        logic [28:0] saved_bus;
        logic [72:0] saved_dma_state;
        integer saved_cpu_writes,saved_cpu_reads,saved_dma_writes,saved_dma_reads;
        logic [15:0] saved_pc;
        hold_dma_wait=1;
        saved_bus={dma_address,dma_dout,dma_mreq_n,dma_iorq_n,dma_rd_n,dma_wr_n,busrq_n};
        saved_cpu_writes=cpu_writes; saved_cpu_reads=cpu_io_reads;
        saved_dma_writes=dma_writes; saved_dma_reads=dma_reads;
        saved_pc=processor.Z80CPU.i_tv80_core.PC;
        saved_dma_state={dma.counter_a,dma.counter_b,dma.byte_counter,dma.remaining,
                         dma.cycle_left,dma.state,dma.enabled};
        repeat(20) begin
            tick(0,0);
            if(saved_bus!={dma_address,dma_dout,dma_mreq_n,dma_iorq_n,dma_rd_n,dma_wr_n,busrq_n} ||
               busak_n || processor.Z80CPU.i_tv80_core.PC!=saved_pc ||
               saved_dma_state!={dma.counter_a,dma.counter_b,dma.byte_counter,dma.remaining,
                                  dma.cycle_left,dma.state,dma.enabled})
                $fatal(1,"stopped enable changed owner/bus/CPU");
        end
        dma_reset=1; // CPU remains granted: resetting TV80 now would revoke ACK.
        repeat(8) tick(0,0);
        if(saved_dma_state!={dma.counter_a,dma.counter_b,dma.byte_counter,dma.remaining,
                             dma.cycle_left,dma.state,dma.enabled})
            $fatal(1,"stopped reset changed DMA transfer state before drain");
        repeat(12) tick(0,1); // DMA clock alone runs, WAIT still blocks completion.
        if(saved_bus!={dma_address,dma_dout,dma_mreq_n,dma_iorq_n,dma_rd_n,dma_wr_n,busrq_n} ||
           busak_n || dma_writes!=saved_dma_writes || dma_reads!=saved_dma_reads)
            $fatal(1,"reset truncated WAIT-stalled transaction");
        hold_dma_wait=0;
        for(integer i=0;i<1000 && !busrq_n;i++) tick(0,1);
        if(!busrq_n || !dma_rd_n || !dma_wr_n || reset_io_count!=1 ||
           dma_writes!=17 || dma_reads!=17 ||
           cpu_writes!=saved_cpu_writes || cpu_io_reads!=saved_cpu_reads)
            $fatal(1,"reset drain failed reads=%0d writes=%0d resetIO=%0d",dma_reads,dma_writes,reset_io_count);
        reset_n=0; // Only now may the CPU revoke ACK; memory/target log retained.
        repeat(4) tick(0,0);
        dma_reset=0; reset_n=1;
    endtask

    task automatic exercise(input integer period,input integer reset_kind);
        bit reset_injected;
        enable_period=period; reset_profile=reset_kind; phase=0;
        grants=0; wait_blocked_grants=0; stretched_cpu_cycles=0;
        cold_reset=1; reset_n=0; dma_reset=1; hold_dma_wait=0;
        install_rom(); repeat(4) tick(0,0);
        cold_reset=0; dma_reset=0; reset_n=1; reset_injected=0;
        for(integer i=0;i<200000;i++) begin
            step();
            if(reset_kind!=0 && !reset_injected && reset_stage && !busak_n &&
               (reset_kind==1 ? !dma_rd_n : !dma_wr_n)) begin
                drain_reset(); reset_injected=1;
            end
            if(!cpu_halt_n) break;
        end
        if(cpu_halt_n || result!=8'ha5 || tx_count!=8 || rx_count!=8 ||
           tx_read_index!=8 || dma_reads!=(reset_kind==0?16:17) ||
           dma_writes!=(reset_kind==0?16:17) || reset_io_count!=(reset_kind==0?0:1) ||
           grants!=(reset_kind==0?16:17) || wait_blocked_grants==0 || stretched_cpu_cycles==0)
            $fatal(1,"qualification failed period=%0d reset=%0d PC=%h R/W=%0d/%0d grants=%0d waitgrant=%0d result=%h",
                period,reset_kind,processor.Z80CPU.i_tv80_core.PC,dma_reads,dma_writes,grants,wait_blocked_grants,result);
        for(integer i=0;i<8;i++)
            if(memory[16'h8000+16'(i)]!=sent_byte(i) || memory[16'h8200+16'(i)]!=received_byte(i))
                $fatal(1,"RAM/source payload corrupted");
        $display("PASS CPU/DMA CE=%0d reset=%0d rawCS=%0d pairs=%0d grants=%0d cpuwrites=%0d waitgrant=%0d stretched=%0d",
            period,reset_kind,register_write_mode,dma_writes,grants,cpu_writes,wait_blocked_grants,stretched_cpu_cycles);
    endtask

    initial begin
        direct_register_read=$test$plusargs("direct-register-read");
        if(direct_register_read) begin
            exercise(1,0);
            $display("PASS: raw read CS settles before TV80 sampling with CE=1; no added register-read WAIT in this bounded case");
        end
        else begin
            for(integer write_mode=0;write_mode<2;write_mode++) begin
                register_write_mode=write_mode;
                for(integer rate=0;rate<3;rate++)
                    for(integer kind=0;kind<3;kind++) exercise(rate==0?1:rate==1?4:7,kind);
            end
            $display("CPU/DMA PASS: 18 CPU-executed original-ROM cases, single-owner mux, no machine integration");
        end
        $finish;
    end
endmodule
