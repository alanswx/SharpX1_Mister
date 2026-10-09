// SPDX-License-Identifier: GPL-2.0-or-later
// Original CPU-executed SIO/DMA diagnostic. Single-owner delayed target;
// no BIOS, native machine, fake RDY/grant or forced processor state.
`timescale 1ns/1ps
module sio_dma_cpu_tb;
    reg clk=0,ce=0,reset=1,pause_ce=0;
    always #5 clk=~clk;
    integer period=1,edges=0,channel=0,pc=0,fail_count=0;
    integer fixups[0:31];
    reg im2_profile=0;
    integer reset_kind=-1,drained_pairs=0;
    reg warm_reset=0;
    wire guard_reset,guard_cpu_run,guard_dma_reset,draining;
    wire reset_profile=reset_kind>=0;
    wire core_reset=reset_profile ? guard_reset : reset;
    wire cpu_ce=ce && (!reset_profile || guard_cpu_run);
    wire dma_reset=reset_profile ? guard_dma_reset : reset;
    always @(negedge clk) begin edges=edges+1; ce=!pause_ce && edges%period==0; end
    wire cpu_m1_n,cpu_mreq_n,cpu_iorq_n,cpu_rd_n,cpu_wr_n,cpu_rfsh_n,halt_n;
    wire busrq_n,busak_n,dma_mreq_n,dma_iorq_n,dma_rd_n,dma_wr_n;
    wire [15:0] cpu_address,dma_address;
    wire [7:0] cpu_dout,dma_dout,dma_cpu_dout,sio_dout;
    wire owner=!busak_n;
    wire [15:0] address=owner ? dma_address : cpu_address;
    wire [7:0] dout=owner ? dma_dout : cpu_dout;
    wire mreq_n=owner ? dma_mreq_n : cpu_mreq_n;
    wire iorq_n=owner ? dma_iorq_n : cpu_iorq_n;
    wire rd_n=owner ? dma_rd_n : cpu_rd_n;
    wire wr_n=owner ? dma_wr_n : cpu_wr_n;
    wire acknowledge=!owner && !cpu_m1_n && !cpu_iorq_n;
    wire active=!acknowledge && (!mreq_n || !iorq_n) && (!rd_n || !wr_n);
    wire sio_cs=!core_reset && !iorq_n && (owner || cpu_m1_n) && address[15:2]==14'(16'h1f90>>2);
    wire dma_cs=!core_reset && !owner && !cpu_iorq_n && cpu_m1_n &&
        cpu_address[15:4]==12'h1f8;
    reg [7:0] memory[0:65535];
    reg [7:0] response=0;
    reg pending=0,accepted=0;
    reg [3:0] age=0;
    reg [15:0] held_address=0;
    reg [7:0] held_data=0;
    reg held_owner=0,held_io=0,held_read=0;
    wire target_ready=pending && age>=4;
    wire cpu_wait_n=owner || !active || target_ready;
    wire dma_wait_n=target_ready;
    wire dma_bad,sio_bad,irq,ieo;
    reg [1:0] rx_tick=0,tx_tick=0,rxd=3;
    wire [1:0] ready_n,flow_wait_n,txd,rts_n,dtr_n;
    wire [7:0] vector;
    wire [7:0] cpu_di=acknowledge ? vector : response;
    wire reti;
    integer ack_count=0,reti_count=0;
    integer paused_ack_edges=0;
    reg ack_old=0;
    reg [7:0] held_vector=0;
    integer grants=0,blocked_grants=0,dma_reads=0,dma_writes=0,io_reads=0,io_writes=0;
    integer cpu_effects=0,owned_edges=0;
    integer error_inspections=0,error_status_reads=0,error_irq_edges=0;
    integer owned_irq_edges=0;
    x1_dma_reset reset_guard(.clk(clk),.reset_request(reset || warm_reset),
        .dma_busak_n(busak_n),.dma_busrq_n(busrq_n),.machine_reset(guard_reset),
        .cpu_run(guard_cpu_run),.dma_reset(guard_dma_reset),.draining(draining));
    cpu processor(.clock(clk),.cep(cpu_ce),.cen(1'b0),.reset_n(!core_reset),
        .int_n(!irq),.wait_n(cpu_wait_n),.busrq_n(busrq_n),.busak_n(busak_n),
        .rfsh_n(cpu_rfsh_n),.halt_n(halt_n),.mreq(cpu_mreq_n),.iorq(cpu_iorq_n),
        .wr(cpu_wr_n),.rd(cpu_rd_n),.m1(cpu_m1_n),.di(cpu_di),
        .data_out(cpu_dout),.a(cpu_address),.dir(16'b0),.dirset(1'b0));
    x1_dma dma(.clk(clk),.ce(ce),.reset(dma_reset),.cpu_cs(dma_cs),
        .iei(1'b1),.acknowledge(1'b0),.reti(1'b0),
        .irq(),.ieo(),.irq_pending(),.irq_in_service(),.ack_vector(),
        .cpu_rd_n(cpu_rd_n),.cpu_wr_n(cpu_wr_n),.cpu_data_in(cpu_dout),
        .cpu_data_out(dma_cpu_dout),.busrq_n(busrq_n),.busak_n(busak_n),
        .mreq_n(dma_mreq_n),.iorq_n(dma_iorq_n),.rd_n(dma_rd_n),.wr_n(dma_wr_n),
        .address(dma_address),.data_out(dma_dout),.data_in(response),
        .wait_n(dma_wait_n),.rdy(ready_n[channel]),.unsupported(dma_bad));
    x1_sio_interrupt #(.FLOW_ENABLE(1)) sio(.clk(clk),.ce(ce),.reset(core_reset),
        .cpu_cs(sio_cs),.cpu_rd_n(rd_n),.cpu_wr_n(wr_n),.address(address[1:0]),
        .cpu_din(dout),.cpu_dout(sio_dout),.rx_tick(rx_tick),.tx_tick(tx_tick),
        .rxd(rxd),.cts_n(2'b11),.dcd_n(2'b11),.txd(txd),.rts_n(rts_n),.dtr_n(dtr_n),
        .unsupported(sio_bad),.iei(1'b1),.acknowledge(acknowledge),.reti(reti),
        .irq(irq),.ieo(ieo),.service_active(),.ack_vector(vector),.wait_n(flow_wait_n),.ready_n(ready_n));
    // Existing fetch decoder, with idle CTC/keyboard. RETI is qualified only
    // to this sole interrupt device; this is not shared daisy-chain wiring.
    x1_irq_bridge opcode_decoder(.clk(clk),.reset(core_reset),.m1_n(cpu_m1_n),
        .mreq_n(cpu_mreq_n),.iorq_n(cpu_iorq_n),.rd_n(cpu_rd_n),.data(cpu_di),
        .keyboard_irq(1'b0),.ctc_irq(1'b0),.ctc_ieo(1'b1),
        .keyboard_vector(8'hff),.ctc_vector(8'hff),.ctc_reti(reti),
        .irq(),.keyboard_ack(),.ctc_ack(),.ctc_iei(),.ctc_selected(),.ack_vector());
    always @(posedge clk) begin
        if(core_reset) begin ack_old<=0; ack_count<=0; reti_count<=0; end
        else begin
            ack_old<=acknowledge;
            if(acknowledge) begin
                if(!im2_profile || owner || !busrq_n || io_reads!=drained_pairs+5 ||
                   memory[16'h9200]!==8'h37)
                    $fatal(1,"IRQ ACK before DMA error pair drained/released");
                if(!ack_old) begin
                    if(ack_count!=0 || vector!==(channel==0 ? 8'hee : 8'he6))
                        $fatal(1,"wrong/repeated DMA-error vector %h",vector);
                    ack_count<=ack_count+1; held_vector<=vector;
                end else if(vector!==held_vector) $fatal(1,"held CPU ACK vector changed");
                if(sio_cs || dma_cs || active) $fatal(1,"ACK decoded as ordinary target");
            end
            if(reti) begin
                if(!im2_profile || owner || ack_count!=1 || reti_count!=0 || ieo)
                    $fatal(1,"RETI without owned SIO service");
                reti_count<=reti_count+1;
            end
            if(im2_profile && memory[16'h8002]==5 && reti_count==0 && ieo)
                $fatal(1,"Error Reset prematurely released SIO IUS before RETI");
        end
    end

    // Clocked response remains valid through idle/release. Read peripherals
    // first latch on their enabled edge, then settle while target WAIT holds.
    // Four enabled target intervals precede one accepted memory side effect.
    always @(posedge clk) begin
        if(core_reset) begin pending<=0; accepted<=0; age<=0; response<=0; end
        else if(!active) begin pending<=0; accepted<=0; age<=0; end
        else if(!pending) begin
            pending<=1; accepted<=0; age<=0;
            held_address<=address; held_data<=dout; held_owner<=owner;
            held_io<=!iorq_n; held_read<=!rd_n;
            response<=!mreq_n ? memory[address] : sio_cs ? sio_dout : dma_cpu_dout;
        end else begin
            if(address!==held_address || owner!==held_owner || !iorq_n!==held_io ||
               !rd_n!==held_read || (!wr_n && dout!==held_data))
                $fatal(1,"pending target changed a=%h/%h owner=%b/%b",address,held_address,owner,held_owner);
            if(!accepted && !rd_n && !iorq_n)
                response<=sio_cs ? sio_dout : dma_cpu_dout;
            if(ce && age<4) age<=age+1'b1;
            if(ce && target_ready && !accepted) begin
                accepted<=1;
                if(owner) begin
                    if(dma_bad) $fatal(1,"unsupported DMA transfer");
                    if(!rd_n) begin dma_reads<=dma_reads+1; if(!iorq_n) io_reads<=io_reads+1; end
                    else begin dma_writes<=dma_writes+1; if(!iorq_n) io_writes<=io_writes+1; end
                    if(!iorq_n && (!sio_cs || address!==(channel==0 ? 16'h1f90 : 16'h1f92)))
                        $fatal(1,"DMA selected non-data SIO target");
                end else begin
                    cpu_effects<=cpu_effects+1;
                    if(sio_cs && !rd_n && memory[16'h8000]==3) begin
                        if(!address[0]) begin
                            if(response!==8'h37 || (im2_profile ? (ieo || ack_count!=1) : !irq))
                                $fatal(1,"CPU locked-error inspection lost word/service");
                            error_inspections<=error_inspections+1;
                        end else begin
                            if(response!==8'h41 || (im2_profile ? (ieo || ack_count!=1) : !irq))
                                $fatal(1,"CPU framing-status inspection lost error/service");
                            error_status_reads<=error_status_reads+1;
                        end
                    end
                end
                if(!wr_n && !mreq_n) begin
                    if(address<16'h8000) $fatal(1,"write to original ROM");
                    memory[address]<=dout;
                    if(address==16'h8001 && dout!==8'ha5 &&
                       !(reset_profile && dout==8'hcc && memory[16'h8000]==0))
                        $fatal(1,"CPU byte/count assertion failed PC=%h",processor.Z80CPU.i_tv80_core.PC);
                end
                if(!iorq_n && !sio_cs && !dma_cs) $fatal(1,"unknown I/O target");
            end
        end
    end
    // Observe pre/post enabled edges; do not synthesize or force ACK. CPU must
    // finish its current WAIT-stretched OUT before entering bus release.
    always @(posedge clk) if(!core_reset) begin : ownership_checks
        reg was_owner,blocked;
        reg [15:0] old_pc;
        integer old_effects;
        was_owner=owner; old_pc=processor.Z80CPU.i_tv80_core.PC; old_effects=cpu_effects;
        blocked=cpu_ce && !busrq_n && !owner && active && !cpu_wait_n;
        if(blocked) blocked_grants=blocked_grants+1;
        #2;
        if(blocked && owner) $fatal(1,"CPU granted before WAIT cycle completed");
        if(!dma_rd_n || !dma_wr_n)
            if(!owner || busrq_n || dma_mreq_n==dma_iorq_n) $fatal(1,"unowned DMA strobes");
        if(owner) begin
            owned_edges=owned_edges+1;
            if({cpu_m1_n,cpu_mreq_n,cpu_iorq_n,cpu_rd_n,cpu_wr_n,cpu_rfsh_n}!==6'b111111)
                $fatal(1,"CPU strobe during DMA ownership");
            if(!was_owner) grants=grants+1;
            else if(processor.Z80CPU.i_tv80_core.PC!==old_pc || cpu_effects!=old_effects)
                $fatal(1,"CPU advanced/side effect while owned");
        end
        if(sio_bad) $fatal(1,"unsupported CPU SIO stream");
        if(irq) error_irq_edges=error_irq_edges+1;
        if(irq && owner) owned_irq_edges=owned_irq_edges+1;
        if(!im2_profile && acknowledge) $fatal(1,"DI diagnostic unexpectedly acknowledged IRQ");
    end
    task automatic emit(input reg [7:0] value); memory[pc]=value; pc=pc+1; endtask
    task automatic word_emit(input reg [15:0] value); emit(value[7:0]); emit(value[15:8]); endtask
    task automatic port(input reg [15:0] value); emit(8'h01); word_emit(value); endtask
    task automatic load_a(input reg [7:0] value); emit(8'h3e); emit(value); endtask
    task automatic store(input reg [15:0] value); emit(8'h32); word_emit(value); endtask
    task automatic out_byte(input reg [7:0] value); load_a(value); emit(8'hed); emit(8'h79); endtask
    task automatic wr_sio(input reg [7:0] index,value); out_byte(index); out_byte(value); endtask
    task automatic assert_a(input reg [7:0] value);
        emit(8'hfe); emit(value); emit(8'hc2); fixups[fail_count]=pc; fail_count=fail_count+1; word_emit(0);
    endtask
    task automatic configure(input reg rx,input reg [7:0] ram_high,count,mode,stage);
        port(16'h1f80); out_byte(8'h7d); out_byte(channel==0 ? 8'h90 : 8'h92); out_byte(8'h1f);
        out_byte(count); out_byte(0); out_byte(8'h2c); out_byte(8'h10); out_byte(8'h80);
        out_byte(8'h8d|mode); out_byte(0); out_byte(ram_high);
        out_byte(8'h92); out_byte(8'hcf); // active-low Ready, WAIT sampled
        if(!rx) begin out_byte(8'h01); out_byte(8'hcf); end
        load_a(stage); store(16'h8000); out_byte(8'h87);
    endtask
    task automatic check_count(input reg [7:0] count);
        port(16'h1f8f); out_byte(8'hbb); out_byte(6); out_byte(8'ha7);
        emit(8'hed); emit(8'h78); assert_a(count);
        emit(8'hed); emit(8'h78); assert_a(0);
    endtask
    task automatic inspect_error;
        port(channel==0 ? 16'h1f91 : 16'h1f93); out_byte(1);
        emit(8'hed); emit(8'h78); assert_a(8'h41);
        port(channel==0 ? 16'h1f90 : 16'h1f92);
        emit(8'hed); emit(8'h78); assert_a(8'h37);
        emit(8'hed); emit(8'h78); assert_a(8'h37);
        port(channel==0 ? 16'h1f91 : 16'h1f93); out_byte(8'h30);
    endtask
    task automatic step;
        do begin @(posedge clk); #3; end while(!ce);
    endtask
    task automatic receive_byte(input reg [7:0] value,input reg bad_stop);
        rx_tick=channel==0 ? 1 : 2; rxd[channel]=0; repeat(16) step();
        for(integer i=0;i<8;i=i+1) begin rxd[channel]=value[i]; repeat(16) step(); end
        rxd[channel]=!bad_stop; repeat(16) step();
        rxd[channel]=1; repeat(32) step(); rx_tick=0;
    endtask
    task automatic transmit_byte(input reg [7:0] value);
        reg [9:0] frame;
        frame={1'b1,value,1'b0}; tx_tick=channel==0 ? 1 : 2; step(); tx_tick=0;
        tx_tick=channel==0 ? 1 : 2;
        for(integer i=0;i<10;i=i+1) repeat(16) begin
            if(txd[channel]!==frame[i]) $fatal(1,"CPU/DMA TX %h bit %0d mismatch",value,i);
            step();
        end
        tx_tick=0;
    endtask
    task automatic pause_ack;
        reg [7:0] saved_vector;
        reg [15:0] saved_pc;
        wait(acknowledge);
        @(negedge clk); #1; pause_ce=1; ce=0;
        saved_vector=vector; saved_pc=processor.Z80CPU.i_tv80_core.PC;
        repeat(80) begin @(posedge clk); #3;
            if(ce || !acknowledge || owner || !busrq_n || vector!==saved_vector ||
               processor.Z80CPU.i_tv80_core.PC!==saved_pc || ack_count!=1 || reti_count!=0 || ieo)
                $fatal(1,"stopped-enable actual ACK lost/duplicated service or vector");
            paused_ack_edges=paused_ack_edges+1;
        end
        @(negedge clk); #1; pause_ce=0;
    endtask
    task automatic request_warm_reset;
        reg [15:0] saved_address,saved_pc;
        reg [7:0] saved_response;
        integer saved_reads,saved_writes;
        if(reset_kind==0) wait(owner && !dma_iorq_n && !dma_rd_n && pending && age>=2);
        else wait(owner && !dma_mreq_n && !dma_wr_n && pending && age>=2);
        // Freeze advancement before requesting reset. The sub-SYS pulse
        // must be retained; neither actual ACK nor the target is revoked.
        @(negedge clk); #1; pause_ce=1; ce=0;
        saved_address=address; saved_pc=processor.Z80CPU.i_tv80_core.PC;
        saved_response=response; saved_reads=dma_reads; saved_writes=dma_writes;
        warm_reset=1; #2; warm_reset=0;
        repeat(80) begin @(posedge clk); #3;
            if(ce || cpu_ce || !draining || core_reset || !dma_reset || !owner || busrq_n ||
               address!==saved_address || processor.Z80CPU.i_tv80_core.PC!==saved_pc ||
               dma_reads!=saved_reads || dma_writes!=saved_writes || response!==saved_response)
                $fatal(1,"reset discarded stopped-enable SIO pair/response/grant");
        end
        @(negedge clk); #1; pause_ce=0;
        wait(core_reset); #3;
        if(dma_reads!=1 || dma_writes!=1 || memory[16'h9000]!==8'h53)
            $fatal(1,"warm reset did not drain exactly one actual serial pair r=%0d w=%0d",dma_reads,dma_writes);
        drained_pairs=1;
        wait(!core_reset);
    endtask
    initial begin : run
        integer loop_pc,fail_pc;
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        if(!$value$plusargs("CHANNEL=%d",channel)) channel=0;
        im2_profile=$test$plusargs("im2");
        if(!$value$plusargs("RESET_KIND=%d",reset_kind)) reset_kind=-1;
        if(reset_kind>1 || (reset_kind>=0 && im2_profile)) $fatal(1,"separate supported reset profiles required");
        for(integer i=0;i<65536;i=i+1) memory[i]=8'hcc;
        emit(8'hf3); emit(8'h31); word_emit(16'hff00); // DI; LD SP,FF00
        if(reset_kind>=0) begin
            // Genuine CPU reboot entry count and sentinel initialization.
            // Retained RAM is never patched by the host after cold reset.
            memory[16'h8003]=0;
            emit(8'h21); word_emit(16'h8003); emit(8'h34); // INC (HL)
            load_a(0); store(16'h8000); load_a(8'hcc); store(16'h8001);
            for(integer i=0;i<4;i=i+1) store(16'h9000+16'(i));
            store(16'h9200); store(16'h9201);
        end
        port(channel==0 ? 16'h1f91 : 16'h1f93);
        out_byte(8'h18); wr_sio(4,8'h44); wr_sio(3,8'hc1); wr_sio(5,8'hea); wr_sio(1,8'he0);
        if(im2_profile) begin
            load_a(8'h70); emit(8'hed); emit(8'h47); emit(8'hed); emit(8'h5e); // I=70, IM2
            port(16'h1f93); wr_sio(2,8'he0); wr_sio(1,4);
            port(channel==0 ? 16'h1f91 : 16'h1f93); wr_sio(1,channel==0 ? 8'he0 : 8'he4);
        end
        configure(1,8'h90,3,8'h20,1);
        loop_pc=pc; emit(8'h3a); word_emit(16'h9003); emit(8'hfe); emit(8'h86);
        emit(8'hc2); word_emit(16'(loop_pc));
        for(integer i=0;i<4;i=i+1) begin
            emit(8'h3a); word_emit(16'h9000+16'(i)); assert_a(8'h53+8'(i*17));
        end
        check_count(3);
        for(integer i=0;i<4;i=i+1) begin load_a(8'h69+8'(i*19)); store(16'h9100+16'(i)); end
        port(channel==0 ? 16'h1f91 : 16'h1f93); wr_sio(1,im2_profile && channel==1 ? 8'hc4 : 8'hc0);
        configure(0,8'h91,3,8'h20,2);
        port(channel==0 ? 16'h1f91 : 16'h1f93);
        loop_pc=pc; out_byte(1); emit(8'hed); emit(8'h78); emit(8'he6); emit(1);
        emit(8'hfe); emit(1); emit(8'hc2); word_emit(16'(loop_pc)); // poll actual RR1 all sent
        check_count(3);
        // Burst release allows intervention after Ready lock. Default stays
        // DI; +im2 enables IRQ only after polling the actual first DMA copy.
        port(channel==0 ? 16'h1f91 : 16'h1f93); wr_sio(1,im2_profile && channel==1 ? 8'hec : 8'he8);
        configure(1,8'h92,1,8'h80,3);
        loop_pc=pc; emit(8'h3a); word_emit(16'h9200); emit(8'hfe); emit(8'h37);
        emit(8'hc2); word_emit(16'(loop_pc));
        if(im2_profile) begin
            emit(8'hfb); emit(8'h76); emit(8'hf3); // EI; HALT; DI after genuine handler return
            emit(8'h3a); word_emit(16'h8002); assert_a(5);
        end else inspect_error();
        loop_pc=pc; emit(8'h3a); word_emit(16'h9201); emit(8'hfe); emit(8'hb6);
        emit(8'hc2); word_emit(16'(loop_pc));
        check_count(1); load_a(8'ha5); store(16'h8001); emit(8'h76);
        fail_pc=pc; load_a(8'hee); store(16'h8001); emit(8'h76);
        if(im2_profile) begin
            if(pc>=16'h1000) $fatal(1,"original ROM overlaps handler");
            pc=32'h1000; emit(8'hf5); emit(8'hc5); // PUSH AF/BC
            inspect_error(); load_a(5); store(16'h8002);
            emit(8'hc1); emit(8'hf1); emit(8'hfb); emit(8'hed); emit(8'h4d); // POP BC/AF; EI; RETI
            memory[channel==0 ? 16'h70ee : 16'h70e6]=0;
            memory[channel==0 ? 16'h70ef : 16'h70e7]=8'h10;
        end
        for(integer i=0;i<fail_count;i=i+1) begin
            memory[fixups[i]]=8'(fail_pc); memory[fixups[i]+1]=8'(fail_pc>>8);
        end
        repeat(8) step(); reset=0;
        wait(memory[16'h8000]==1 && dma.enabled);
        if(reset_profile) begin
            fork
                receive_byte(8'h53,0);
                request_warm_reset();
            join
            rx_tick=0; rxd=3;
            wait(memory[16'h8003]==2 && memory[16'h8000]==1 && dma.enabled);
        end
        repeat(80) begin step(); if(!busrq_n || dma_reads!=drained_pairs || dma_writes!=drained_pairs) $fatal(1,"empty RX DMA request"); end
        for(integer i=0;i<4;i=i+1) begin
            receive_byte(8'h53+8'(i*17),0); wait(dma_writes==drained_pairs+i+1);
            if(i<3) repeat(80) begin step();
                if(!owner || dma_reads!=drained_pairs+i+1 || dma_writes!=drained_pairs+i+1) $fatal(1,"continuous RX ownership/pacing");
            end
        end
        wait(memory[16'h8000]==2 && io_writes==1);
        repeat(80) begin step(); if(!owner || io_writes!=1) $fatal(1,"continuous full TX ownership/pacing"); end
        for(integer i=0;i<4;i=i+1) begin
            transmit_byte(8'h69+8'(i*19)); if(i<3) wait(io_writes==i+2);
        end
        wait(memory[16'h8000]==3 && dma.enabled);
        if(im2_profile) fork
            receive_byte(8'h37,1);
            pause_ack();
        join
        else receive_byte(8'h37,1);
        wait(memory[16'h9200]==8'h37);
        receive_byte(8'hb6,0);
        wait(memory[16'h8001]==8'ha5 && !halt_n); repeat(40) step();
        if(paused_ack_edges!=(im2_profile ? 80 : 0) ||
           ack_count!=(im2_profile ? 1 : 0) || reti_count!=(im2_profile ? 1 : 0) ||
           error_inspections!=2 || error_status_reads!=1 || error_irq_edges==0 || owned_irq_edges==0 ||
           grants!=drained_pairs+4 || blocked_grants==0 || owned_edges==0 ||
           dma_reads!=drained_pairs+10 || dma_writes!=drained_pairs+10 ||
           io_reads!=drained_pairs+6 || io_writes!=4 || owner || !busrq_n || irq || !ieo || sio_bad || dma_bad || txd!==3 ||
           (reset_profile && memory[16'h8003]!==2))
            $fatal(1,"final CPU/DMA result grants=%0d blocked=%0d pairs=%0d/%0d",grants,blocked_grants,dma_reads,dma_writes);
        $display("PASS: actual CPU/SIO/DMA continuous RX/TX + burst error, grants/WAIT/pins/counts CE=%0d channel=%0d blocked=%0d IM2=%0d ACK/RETI=%0d/%0d reset=%0d drained=%0d",period,channel,blocked_grants,im2_profile,ack_count,reti_count,reset_kind,drained_pairs);
        $finish;
    end
    initial begin #20000000; $fatal(1,"CPU SIO DMA watchdog PC=%h stage=%h pairs=%0d/%0d entry=%h reset=%b/%b drained=%0d enabled=%b",processor.Z80CPU.i_tv80_core.PC,memory[16'h8000],dma_reads,dma_writes,memory[16'h8003],core_reset,draining,drained_pairs,dma.enabled); end
endmodule
