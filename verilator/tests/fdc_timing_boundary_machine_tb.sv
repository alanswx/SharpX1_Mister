// SPDX-License-Identifier: GPL-2.0-or-later
// Original public-mount consumer-CE/final-store/prefill boundary qualification.
// DUT hierarchy is observation-only. No force, private RAM or CE writes.
`timescale 1ps/1ps
module fdc_timing_boundary_machine_tb #(parameter RATE=1000000, ADDRESS_BITS=20);
    localparam HEADER=1016, PAYLOAD=HEADER+16, LENGTH=256;
    localparam TOTAL=PAYLOAD+LENGTH+16+128;
    logic clk=0,video_clk=0,reset=1,download=0,load=0,mounted=0;
    logic mount_a=0,mount_b=0,ack=0,host_wr=0;
    always #15625 clk=!clk;
    always #17500 video_clk=!video_clk;
    logic [24:0] load_addr=0;
    logic [7:0] load_data=0,rom[32768],image_bytes[2][TOTAL],original[2][TOTAL],ledger[2][TOTAL];
    logic [8:0] host_addr=0;
    logic [7:0] host_data=0;
    wire [7:0] host_read;
    wire [31:0] lba;
    wire sd_rd,sd_wr,owner,load_wait;
    integer scenario=0,drive=0,rom_size=0,stage=0,requests=0,published_writes=0;
    integer recovery_reads=0,recovery_writes=0,preface_arrivals=0,preface_emits=0;
    integer preface_writes=0;
    integer chip_count=0,read_due=0,write_due=0,arm_edge=0;
    integer sys_edges=0,last_chip=0,clock_checks=0;
    bit chip_seen=0,old_marker=0,failed=0,complete=0;
    bit cancel_seen=0,cancel_checked=0,completion_seen=0;
    bit host_owned=0;
    integer preface_stores=0;
    bit consumer_collision=0, final_store_pending=0, prefill_seen=0, control_taken=0;
    string rom_path;
    sharpx1 #(.TURBO(1),.TURBO_DMA(1),.SINGLE_CLOCK(0),
        .TURBO_FDC_TIMING(1),.FDC_CLOCK_HZ(RATE),.D88_ADDRESS_BITS(ADDRESS_BITS)) dut (
        .clk_sys(clk),.clk_28636(video_clk),.reset(reset),.pal(1'b0),.scandouble(1'b0),
        .ioctl_download(download),.ioctl_index(8'd0),.ioctl_wr(load),
        .ioctl_addr(load_addr),.ioctl_dout(load_data),.ioctl_wait(load_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),
        .sio_rxd(2'b11),.sio_cts_n(2'b11),.sio_dcd_n(2'b11),
        .sio_txd(),.sio_rts_n(),.sio_dtr_n(),
        .disk_ready(1'b1),.img_mounted(mounted|mount_a),.disk_wp(1'b0),.img_size(24'(TOTAL)),
        .disk_ready_b(1'b1),.img_mounted_b(mounted|mount_b),.disk_wp_b(1'b0),.img_size_b(24'(TOTAL)),
        .sd_drive(owner),.sd_lba(lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(ack),
        .sd_buff_addr(host_addr),.sd_buff_dout(host_data),.sd_buff_din(host_read),.sd_buff_wr(host_wr),
        .ce_pix(),.HBlank(),.HSync(),.VBlank(),.VSync(),.video(),.rgb(),.rgb12(),
        .audio(),.audio_left(),.audio_right(),.audio_mono(),.audio_sample()
    );
    function automatic [7:0] payload(input integer d,i);
        if(i==LENGTH-1) return d==0 ? 8'hd3 : 8'h6c;
        return 8'(i*37+(i>>8)*53+d*104+19);
    endfunction
    // Prediction comes ONLY from the original image and the planned recovery
    // command. Neither DSR/DR, observed SD output nor DUT metadata supplies it.
    function automatic [7:0] predicted_store(input integer d,at,input bit prelude);
        if(at>=TOTAL) return 0;
        if(at>=PAYLOAD && at<PAYLOAD+LENGTH)
            return original[d][at]^(prelude ? 8'ha7 : 8'h5a);
        return original[d][at];
    endfunction
    task automatic tick; @(negedge clk);#1;endtask
    wire marker=dut.mem_write && !dut.dma_owner && dut.a==16'hf010;
    wire result=dut.mem_write && !dut.dma_owner && dut.a==16'hf000;
    wire data_read=dut.fdc.timing_read_accept && dut.a==16'h0ffb && !dut.dam;
    wire data_write=dut.fdc.timing_write_accept && dut.a==16'h0ffb && !dut.dam;
    always @(posedge clk) begin
        sys_edges++;
        if(marker && !old_marker) stage=int'(dut.data_out);
        if(result && dut.data_out==8'hee) failed=1;
        if(result && dut.data_out==8'h5a) complete=1;
        old_marker=marker;
        if(!dut.core_reset) begin
            if(dut.fdc.fdc_ce) begin
                if(chip_seen) begin
                    assert(sys_edges-last_chip==32000000/RATE) else $fatal(1,"explicit chip rate changed");
                    clock_checks++;
                end
                last_chip=sys_edges;chip_seen=1;chip_count<=chip_count+1;
            end
            if(dut.fdc.strict_timing.begin_read) read_due=chip_count+int'(dut.fdc.fdc_ce)+32;
            if(dut.fdc.strict_timing.arm_write) begin
                arm_edge=chip_count+int'(dut.fdc.fdc_ce);write_due=arm_edge+32;
            end
            if(dut.fdc.timing_read_load) begin
                assert(chip_count+int'(dut.fdc.fdc_ce)==read_due) else $fatal(1,"read cadence rephased");
                read_due+=32;
                if(stage==1) preface_arrivals++;
            end
            if(dut.fdc.strict_timing.launch)
                assert(chip_count+int'(dut.fdc.fdc_ce)-arm_edge==32) else $fatal(1,"initial prefill rephased");
            if(stage>=16 && data_read) recovery_reads++;
            if(stage>=16 && data_write) recovery_writes++;
            if(stage==1 && data_write) preface_writes++;
            assert(!dut.turbo_dma.engine.force_ready) else $fatal(1,"manufactured Ready prohibited");
            if(stage==1 && dut.fdc.timing_buffer_store) begin
                preface_stores++;
                if(dut.fdc.strict_timing.write_index==LENGTH-1)
                    assert(dut.fdc.timing_write_byte==(payload(drive,LENGTH-1)^8'ha7))
                        else $fatal(1,"distinct last prelude byte wrong");
            end
            if(cancel_seen && stage==1)
                assert(!(dut.fdc.timing_read_load || dut.fdc.timing_buffer_store || dut.fdc.timing_taken))
                    else $fatal(1,"cancelled prelude produced late serial/consume event");
        end else chip_seen=0;
    end
    always @(negedge clk) begin
        if(dut.fdc.strict_timing.write_emit && !dut.fdc.timing_cancel) begin
            assert(chip_count==write_due) else $fatal(1,"DSR cadence rephased");
            write_due+=32;if(stage==1) preface_emits++;
        end
    end
    logic [31:0] rng=32'h93268721;
    function automatic integer host_delay;
        rng=(rng<<1)^(rng[31]?32'h04c11db7:32'd0);
        return int'(rng&31)+1;
    endfunction
    initial forever begin
        integer block,at;
        bit disk,writing,prelude;
        wait(sd_rd || sd_wr);block=int'(lba);disk=owner;writing=sd_wr;host_owned=1;requests++;
        prelude=stage==1;
        assert(!(sd_rd && sd_wr)) else $fatal(1,"simultaneous SD directions");
        if(writing) begin
            assert((stage==48 || (scenario==5 && stage==1)) && int'(disk)==drive &&
                   block==PAYLOAD/512 && published_writes==(stage==1 ? 0 : (scenario==5 ? 1 : 0)))
                else $fatal(1,"unpublished prelude payload reached SD");
            published_writes++;
        end
        repeat(host_delay()) begin
            tick();assert(lba==32'(block) && owner==disk) else $fatal(1,"pre-ACK identity changed");
        end
        ack=1;
        for(int i=0;i<512;i++) begin
            host_addr=9'(i);at=block*512+i;
            if(writing) begin
                tick();tick();
                assert(host_read==predicted_store(int'(disk),at,prelude))
                    else $fatal(1,"published block differs from independent ledger offset=%0d",at);
                if(at<TOTAL) image_bytes[disk][at]=host_read;
            end else begin
                host_data=at<TOTAL?image_bytes[disk][at]:8'd0;host_wr=1;tick();
            end
            assert(lba==32'(block) && owner==disk) else $fatal(1,"ACK identity changed");
        end
        host_wr=0;repeat(host_delay()+8) tick();ack=0;
        if(writing) for(int i=0;i<512;i++) begin
            at=block*512+i;
            if(at<TOTAL) ledger[disk][at]=predicted_store(int'(disk),at,prelude);
        end
        repeat(16) tick();host_owned=0;
    end
    task automatic mount_active;
        if(drive==0) mount_a=1; else mount_b=1;
    endtask
    initial begin
        wait(!reset);
        if(scenario==0 || scenario==1 || scenario==4 || scenario==5) begin
            wait(stage==1 && dut.fdc.strict_timing.completion.valid);
            completion_seen=1;
            // Counter changes on negedge; #1 observes settled real CE.
            do tick(); while(!dut.fdc.ce);
            assert(dut.fdc.strict_timing.completion.valid && dut.fdc.ce &&
                   dut.fdc.timing_taken && dut.transport_idle && !host_owned && !ack && !sd_rd && !sd_wr)
                else $fatal(1,"real consumer boundary absent");
            if(scenario<2) begin
                consumer_collision=1;cancel_seen=1;mount_active();#1;
                assert(dut.fdc.strict_timing.completion.valid && dut.fdc.ce && dut.fdc.timing_cancel)
                    else $fatal(1,"mount did not collide with real consumer CE");
                assert(!dut.fdc.timing_taken)
                    else $fatal(1,"consumer collision accepted cancelled lease");
                @(posedge clk);#1;
                assert(!dut.fdc.strict_timing.completion.valid)
                    else $fatal(1,"consumer collision retained cancelled lease");
            end else begin
                assert(dut.fdc.timing_taken) else $fatal(1,"uncancelled completion not taken");
                control_taken=1;
                @(posedge clk);#1;
                assert(!dut.fdc.strict_timing.completion.valid)
                    else $fatal(1,"uncancelled lease retained");
            end
        end else if(scenario==2) begin
            wait(stage==1 && dut.fdc.strict_timing.write_emit &&
                 dut.fdc.strict_timing.write_index==LENGTH-1);
            tick();
            assert(dut.fdc.strict_timing.write_emit &&
                   dut.fdc.strict_timing.write_index==LENGTH-1 &&
                   dut.fdc.timing_buffer_store && preface_stores==LENGTH-1 &&
                   dut.transport_idle && !host_owned && !ack && !sd_rd && !sd_wr)
                else $fatal(1,"pending final store boundary absent");
            final_store_pending=1;cancel_seen=1;mount_active();#1;
            assert(!dut.fdc.timing_buffer_store)
                else $fatal(1,"cancelled final store remained eligible");
            @(posedge clk);#1;
            assert(preface_stores==LENGTH-1 && !dut.fdc.strict_timing.active)
                else $fatal(1,"cancelled final store retired");
        end else begin
            wait(stage==1 && dut.fdc.strict_timing.armed && dut.fdc.timing_drq);
            tick();
            assert(dut.fdc.strict_timing.armed && dut.fdc.timing_drq &&
                   dut.fdc.strict_timing.prefill_left>1 && !dut.fdc.strict_timing.active &&
                   preface_writes==0 && preface_emits==0 &&
                   dut.transport_idle && !host_owned && !ack && !sd_rd && !sd_wr)
                else $fatal(1,"genuine prefill boundary absent");
            prefill_seen=1;cancel_seen=1;mount_active();#1;
            @(posedge clk);#1;
            assert(!dut.fdc.strict_timing.armed && !dut.fdc.strict_timing.active)
                else $fatal(1,"cancelled prefill remained armed");
        end
        if(scenario<4) begin
            repeat(16) tick();
            assert(published_writes==0 && !sd_wr && !dut.fdc.strict_timing.active &&
                   !dut.fdc.strict_timing.armed && !dut.fdc.strict_timing.completion.valid)
                else $fatal(1,"cancelled prelude published or retained work");
            cancel_checked=1;mount_a=0;mount_b=0;
        end
    end
    initial begin
        assert($value$plusargs("ROM=%s",rom_path)) else $fatal(1,"generated IPL required");
        if($value$plusargs("ROM_SIZE=%d",rom_size)) begin end
        if($value$plusargs("CASE=%d",scenario)) begin end
        if($value$plusargs("DRIVE=%d",drive)) begin end
        assert(rom_size>0 && rom_size<=32768 && scenario>=0 && scenario<=5 && drive>=0 && drive<2)
            else $fatal(1,"invalid fixture configuration");
        $readmemh(rom_path,rom,0,rom_size-1);
        for(int d=0;d<2;d++) begin
            for(int i=0;i<TOTAL;i++) image_bytes[d][i]=0;
            for(int i=0;i<4;i++) begin
                image_bytes[d][28+i]=8'(TOTAL>>(i*8));image_bytes[d][32+i]=8'(HEADER>>(i*8));
            end
            image_bytes[d][HEADER+2]=1;image_bytes[d][HEADER+3]=1;
            image_bytes[d][HEADER+4]=2;image_bytes[d][HEADER+15]=1;
            for(int i=0;i<LENGTH;i++) image_bytes[d][PAYLOAD+i]=payload(d,i);
            image_bytes[d][PAYLOAD+LENGTH+2]=2;image_bytes[d][PAYLOAD+LENGTH+4]=2;
            image_bytes[d][PAYLOAD+LENGTH+14]=128;
            for(int i=0;i<128;i++) image_bytes[d][PAYLOAD+LENGTH+16+i]=8'(i*7+d*43+103);
            for(int i=0;i<TOTAL;i++) begin original[d][i]=image_bytes[d][i];ledger[d][i]=image_bytes[d][i];end
        end
        repeat(8) tick();download=1;
        for(int i=0;i<rom_size;i++) begin
            tick();while(load_wait) tick();load_addr=25'(i);load_data=rom[i];load=1;tick();load=0;
        end
        tick();download=0;mounted=1;repeat(32) tick();mounted=0;repeat(32) tick();reset=0;
        wait(complete || failed);repeat(32) tick();
        assert(!failed) else $fatal(1,"CPU recovery payload/status diagnostic failed stage=%0d",stage);
        assert(clock_checks>0) else $fatal(1,"clock coverage absent");
        if(scenario<4) assert(cancel_seen && cancel_checked) else $fatal(1,"cancellation absent");
        if(scenario<2) assert(consumer_collision && completion_seen) else $fatal(1,"consumer collision absent");
        if(scenario==2) assert(final_store_pending && preface_stores==LENGTH-1)
            else $fatal(1,"final store cancellation absent");
        if(scenario==3) assert(prefill_seen && preface_stores==0 && preface_emits==0 && preface_writes==0)
            else $fatal(1,"prefill cancellation absent");
        if(scenario>=4) assert(control_taken && completion_seen) else $fatal(1,"uncancelled control absent");
        if(scenario==1 || scenario==5) assert(preface_stores==LENGTH && preface_emits==LENGTH)
            else $fatal(1,"complete prelude store count wrong");
        if(scenario==0 || scenario==4) assert(preface_arrivals==LENGTH)
            else $fatal(1,"complete prelude read count wrong");
        assert(recovery_reads==3*LENGTH && recovery_writes==LENGTH &&
               published_writes==(scenario==5 ? 2 : 1) && stage==64)
            else $fatal(1,"recovery transfer/publication counts wrong");
        for(int d=0;d<2;d++) for(int i=0;i<TOTAL;i++)
            assert(image_bytes[d][i]==ledger[d][i]) else $fatal(1,"whole medium differs from publication ledger");
        $display("PASS boundary machine rate=%0d width=%0d case=%0d drive=%0d collision=%0d final_pending=%0d prefill=%0d control=%0d prelude=%0d/%0d/%0d recovery=%0d/%0d writes=%0d requests=%0d",RATE,ADDRESS_BITS,scenario,drive,consumer_collision,final_store_pending,prefill_seen,control_taken,preface_arrivals,preface_emits,preface_stores,recovery_reads,recovery_writes,published_writes,requests);
        $finish;
    end
    initial begin
        wait(!reset);
        #(64'd100000000000+64'(LENGTH)*160*64'd1000000000000/64'(RATE));
        $fatal(1,"physical duration budget exhausted stage=%0d case=%0d",stage,scenario);
    end
endmodule
