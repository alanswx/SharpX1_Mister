// SPDX-License-Identifier: GPL-2.0-or-later
// Original shared-machine/public ioctl + SD fixture. Hierarchy is READ-ONLY
// observation of genuine CPU/DMA bus, DRQ, chip CE and reset ownership.
// No force, index injection, private memory reads/writes or external CPU bus.
`timescale 1ps/1ps
module fdc_timing_machine_tb #(
    parameter RATE=1000000, ADDRESS_BITS=20, TIMING_ENABLED=1
);
    localparam SYS_HZ=32000000, HEADER=1016, MAX_MEDIUM=HEADER+16+1024+16+128;
    logic clk=0, vid=0, reset=1, download=0, load=0, mounted=0,mount_a=0,mount_b=0;
    always #15625 clk=!clk;
    always #17500 vid=!vid;
    logic [24:0] load_address=0;
    logic [7:0] load_data=0, rom[32768];
    logic ack=0, host_wr=0;
    logic [8:0] host_address=0;
    logic [7:0] host_data=0;
    wire load_wait, owner, sd_rd, sd_wr;
    wire [31:0] lba;
    wire [7:0] host_read;
    integer length=128, drive=0, mode=-1, rom_size=0, total=0;
    integer sys_edges=0, requests=0, host_writes=0, markers=0, phase=0;
    integer dma_reads=0, dma_writes=0, cpu_reads=0, cpu_writes=0;
    integer dma_bus_reads=0,dma_bus_writes=0;
    bit old_dma_read=0,old_dma_write=0;
    integer arrivals=0, dsr_loads=0, chip_edges=0, assembly_start=0, initial_start=0;
    integer clock_previous=0, clock_checks=0, next_read_edge=0, next_write_edge=0;
    integer ready_drops=0, grant_returns=0,request_entries=0,ack_entries=0;
    integer cancel_kind=0,cancel_write=0,host_byte=0,miss_arrivals=0;
    integer accepted_reads=0,accepted_writes=0,drain_retirements=0;
    bit observe_drain=0;
    time drq_observed_time=0,read_accept_max_ps=0,write_accept_max_ps=0;
    bit cancel_fired=0,cancel_observed=0,host_owned=0,host_direction=0;
    bit host_disk=0;
    bit old_request=0;
    bit old_pair=0;
    bit clock_seen=0, old_drq=0, old_owner=0, old_read=0, old_write=0;
    bit old_marker=0, failed=0, completed=0;
    logic [7:0] image_bytes[2][MAX_MEDIUM], expected[2][MAX_MEDIUM];
    string rom_path;
    sharpx1 #(.TURBO(1), .TURBO_DMA(1), .SINGLE_CLOCK(0),
        .TURBO_FDC_TIMING(TIMING_ENABLED), .FDC_CLOCK_HZ(RATE),
        .D88_ADDRESS_BITS(ADDRESS_BITS)) dut (
        .clk_sys(clk), .clk_28636(vid), .reset(reset), .pal(1'b0), .scandouble(1'b0),
        .ioctl_download(download), .ioctl_index(8'd0), .ioctl_wr(load),
        .ioctl_addr(load_address), .ioctl_dout(load_data), .ioctl_wait(load_wait),
        .ps2_clk_in(1'b1), .ps2_data_in(1'b1), .joya_n(8'hff), .joyb_n(8'hff),
        .sio_external_rx_clock(1'b0), .sio_external_tx_clock(1'b0),
        .sio_rxd(2'b11), .sio_cts_n(2'b11), .sio_dcd_n(2'b11),
        .sio_txd(), .sio_rts_n(), .sio_dtr_n(),
        .disk_ready(1'b1), .img_mounted(mounted|mount_a), .disk_wp(1'b0), .img_size(24'(total)),
        .disk_ready_b(1'b1), .img_mounted_b(mounted|mount_b), .disk_wp_b(1'b0), .img_size_b(24'(total)),
        .sd_drive(owner), .sd_lba(lba), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(ack),
        .sd_buff_addr(host_address), .sd_buff_dout(host_data), .sd_buff_din(host_read), .sd_buff_wr(host_wr),
        .ce_pix(), .HBlank(), .HSync(), .VBlank(), .VSync(), .video(), .rgb(), .rgb12(),
        .audio(), .audio_left(), .audio_right(), .audio_mono(), .audio_sample()
    );
    function automatic [7:0] payload(input integer d, i);
        return 8'(i*37+(i>>8)*53+d*104+19);
    endfunction
    task automatic tick; @(negedge clk); #1; endtask
    // Observe register/bus transactions without writing any DUT state.
    wire data_read=dut.io_read && !dut.dam && dut.a==16'h0ffb;
    wire data_write=dut.io_write && !dut.dam && dut.a==16'h0ffb;
    wire ram_marker=dut.mem_write && dut.a==16'hf010 && !dut.dma_owner;
    wire result_marker=dut.mem_write && dut.a==16'hf000 && !dut.dma_owner;
    wire dma_bus_read=dut.dma_owner && !dut.rd && (!dut.mreq || !dut.iorq);
    wire dma_bus_write=dut.dma_owner && !dut.wr && (!dut.mreq || !dut.iorq);
    always @(posedge clk) begin
        sys_edges++;
        if(!dut.core_reset) begin
            if(dma_bus_read && !old_dma_read) dma_bus_reads++;
            if(dma_bus_write && !old_dma_write) dma_bus_writes++;
            if(data_read && !old_read) begin
                if(dut.dma_owner) dma_reads++; else cpu_reads++;
            end
            if(data_write && !old_write) begin
                if(dut.dma_owner) dma_writes++; else cpu_writes++;
            end
            if(ram_marker && !old_marker) begin
                phase=int'(dut.data_out);
                if(phase==16) begin
                    // The cancellation prelude has its own genuine traffic.
                    // Count the independently self-checked R/W/R gate only.
                    markers=0;arrivals=0;dsr_loads=0;
                    dma_reads=0;dma_writes=0;cpu_reads=0;cpu_writes=0;
                    dma_bus_reads=0;dma_bus_writes=0;ready_drops=0;
                    grant_returns=0;request_entries=0;ack_entries=0;
                    accepted_reads=0;accepted_writes=0;read_accept_max_ps=0;write_accept_max_ps=0;
                end
                if(phase>=16) markers++;
                if(phase==32) for(int i=0;i<length;i++) expected[drive][HEADER+16+i]=payload(drive,i)^8'h5a;
            end
            if(cancel_kind==3 && !cancel_fired && phase==(cancel_write!=0 ? 2 : 1) && int'(dut.disk_control.drive)!=drive) begin
                assert(host_owned && ack && host_disk==1'(drive) &&
                       host_direction==1'(cancel_write))
                    else $fatal(1,"CPU reselection missed owned ACK phase");
                cancel_fired=1;cancel_observed=1;
            end
            if(result_marker) begin
                if(dut.data_out==8'hee) failed=1;
                if(dut.data_out==8'h5a) completed=1;
            end
            if(old_drq && !dut.fdc_drq) ready_drops++;
            if(dut.fdc_drq && !old_drq) drq_observed_time=$time;
            if(TIMING_ENABLED && phase>=16 && data_read && dut.fdc.timing_read_accept) begin
                accepted_reads++;
                if($time-drq_observed_time>read_accept_max_ps) read_accept_max_ps=$time-drq_observed_time;
            end
            if(TIMING_ENABLED && phase>=16 && data_write && dut.fdc.timing_write_accept) begin
                accepted_writes++;
                if($time-drq_observed_time>write_accept_max_ps) write_accept_max_ps=$time-drq_observed_time;
            end
            if(observe_drain && dut.turbo_dma.engine.ce && dma_bus_write &&
               dut.turbo_dma.engine.cycle_left==1) drain_retirements++;
            if(old_owner && !dut.dma_owner) grant_returns++;
            if(!dut.dma_busrq_n && !old_request) request_entries++;
            if(dut.dma_owner && !old_owner) ack_entries++;
            // ACK, not BUSRQ, owns the mux. A requested active pair must
            // retain its request, but the idle ACK-release tail is legal.
            if(dma_bus_read || dma_bus_write)
                assert(!dut.cpu_busak_n && !dut.dma_busrq_n)
                    else $fatal(1,"DMA active transfer without retained request/grant");
            if(mode!=-1)
                assert(!dut.turbo_dma.engine.force_ready)
                    else $fatal(1,"fixture must not manufacture DMA Ready");
            if(mode!=-1 && dut.turbo_dma.engine.pair_active && !old_pair)
                assert(dut.fdc_drq)
                    else $fatal(1,"DMA pair began without FDC DRQ");
            if(TIMING_ENABLED && dut.fdc.fdc_ce) begin
                if(clock_seen) begin
                    assert(sys_edges-clock_previous==SYS_HZ/RATE) else $fatal(1,"explicit nominal FDC clock period");
                    clock_checks++;
                end
                clock_seen=1;clock_previous=sys_edges;chip_edges<=chip_edges+1;
            end
        end else clock_seen=0;
        old_read=data_read;old_write=data_write;old_marker=ram_marker;
        old_drq=dut.fdc_drq;old_owner=dut.dma_owner;
        old_dma_read=dma_bus_read;old_dma_write=dma_bus_write;
        old_request=!dut.dma_busrq_n;
        old_pair=dut.turbo_dma.engine.pair_active;
    end
    generate if(TIMING_ENABLED) begin : timing_observation
        integer in_read=0,in_write=0;
        always @(posedge clk) if(!dut.core_reset) begin
            // Counter is NBA-updated: both observers see the same pre-edge
            // count, independent of process scheduling. Include this CE.
            if(dut.fdc.strict_timing.begin_read) begin
                assembly_start=chip_edges+int'(dut.fdc.fdc_ce); next_read_edge=assembly_start+32;in_read=0;
            end
            if(dut.fdc.strict_timing.arm_write) begin
                initial_start=chip_edges+int'(dut.fdc.fdc_ce);next_write_edge=initial_start+32;in_write=0;
            end
            if(dut.fdc.timing_read_load) begin
                assert(chip_edges+int'(dut.fdc.fdc_ce)==next_read_edge) else $fatal(1,"CPU/DMA service rephased read arrival");
                next_read_edge+=32;in_read++;arrivals++;
                if(phase==3) miss_arrivals++;
            end
            if(dut.fdc.strict_timing.launch)
                assert(chip_edges+int'(dut.fdc.fdc_ce)-initial_start==32) else $fatal(1,"CPU/DMA initial prefill window");
        end
        always @(negedge clk) if(dut.fdc.strict_timing.write_emit) begin
            assert(chip_edges==next_write_edge) else $fatal(1,"CPU/DMA service rephased DSR load");
            next_write_edge+=32;in_write++;dsr_loads++;
        end
    end endgenerate
    logic [31:0] random_state=32'h34572103;
    function automatic integer delay_sys;
        random_state=(random_state<<1)^(random_state[31] ? 32'h04c11db7 : 32'd0);
        return int'(random_state & 31)+1;
    endfunction
    initial forever begin
        integer saved_lba, at;
        bit saved_owner, writing;
        wait(sd_rd || sd_wr);saved_lba=int'(lba);saved_owner=owner;writing=sd_wr;
        host_owned=1;host_disk=saved_owner;host_direction=writing;host_byte=0;
        requests++;if(writing) host_writes++;
        assert(!(sd_rd && sd_wr)) else $fatal(1,"both host directions");
        repeat(delay_sys()) begin
            tick();assert(lba==32'(saved_lba) && owner==saved_owner) else $fatal(1,"pre-ACK owner/LBA changed");
        end
        ack=1;
        for(int i=0;i<512;i++) begin
            host_address=9'(i);at=saved_lba*512+i;host_byte=i;
            if(writing) begin
                tick();tick();
                if(at<total) begin
                    assert(host_read==expected[saved_owner][at]) else $fatal(1,"SD write payload/neighbor oracle offset=%0d",at);
                    image_bytes[saved_owner][at]=host_read;
                end else assert(host_read==0) else $fatal(1,"write outside synthetic medium");
            end else begin
                host_data=(at<total)?image_bytes[saved_owner][at]:8'd0;host_wr=1;tick();
            end
            assert(lba==32'(saved_lba) && owner==saved_owner) else $fatal(1,"ACK owner/LBA changed");
            // Lengthen only the host handshake in cancellation cases; the
            // independent physical serial cadence remains unchanged.
            if(cancel_kind!=0 && phase<16) repeat(16) tick();
        end
        host_wr=0;repeat(8+delay_sys()) tick();ack=0;repeat(12) tick();
        host_owned=0;
    end
    initial begin
        assert($value$plusargs("ROM=%s",rom_path)) else $fatal(1,"missing generated IPL");
        if($value$plusargs("ROM_SIZE=%d",rom_size)) begin end
        if($value$plusargs("LENGTH=%d",length)) begin end
        if($value$plusargs("DRIVE=%d",drive)) begin end
        if($value$plusargs("MODE=%d",mode)) begin end
        if($value$plusargs("CANCEL=%d",cancel_kind)) begin end
        if($value$plusargs("CANCEL_WRITE=%d",cancel_write)) begin end
        assert(rom_size>0 && rom_size<=32768 && (length==128 || length==256 || length==512 || length==1024))
            else $fatal(1,"fixture arguments");
        total=HEADER+16+length+16+128;
        $readmemh(rom_path,rom,0,rom_size-1);
        for(int d=0;d<2;d++) begin
            for(int i=0;i<MAX_MEDIUM;i++) image_bytes[d][i]=0;
            for(int b=0;b<4;b++) begin
                image_bytes[d][28+b]=8'(total>>(8*b));image_bytes[d][32+b]=8'(HEADER>>(8*b));
            end
            image_bytes[d][HEADER+2]=1;image_bytes[d][HEADER+4]=2;
            image_bytes[d][HEADER+3]=length==128 ? 0 : length==256 ? 1 : length==512 ? 2 : 3;
            image_bytes[d][HEADER+14]=8'(length);image_bytes[d][HEADER+15]=8'(length>>8);
            for(int i=0;i<length;i++) image_bytes[d][HEADER+16+i]=payload(d,i);
            image_bytes[d][HEADER+16+length+2]=2;image_bytes[d][HEADER+16+length+4]=2;
            image_bytes[d][HEADER+16+length+14]=128;
            for(int i=0;i<128;i++) image_bytes[d][HEADER+32+length+i]=8'(i*7+d*43+103);
            for(int i=0;i<MAX_MEDIUM;i++) expected[d][i]=image_bytes[d][i];
        end
        repeat(8) tick();download=1;
        for(int i=0;i<rom_size;i++) begin
            tick();while(load_wait) tick();load_address=25'(i);load_data=rom[i];load=1;
            tick();load=0;
        end
        tick();download=0;mounted=1;repeat(32) tick();mounted=0;
        repeat(32) tick();reset=0;
        wait(completed || failed);repeat(32) tick();
        assert(!failed) else $fatal(1,"actual CPU diagnostic failure phase=%0d CPU_bus=%h DATA=%0d/%0d",phase,dut.cpu_a,accepted_reads,accepted_writes);
        if(cancel_kind!=0) assert(cancel_fired && cancel_observed)
            else $fatal(1,"requested cancellation not actually exercised");
        assert(markers==3 && phase==48 && host_writes>0) else $fatal(1,"CPU read/write/readback coverage");
        assert(arrivals==2*length && dsr_loads==length && clock_checks>0)
            else $fatal(1,"connected timed arrivals/loads absent or wrong");
        assert(accepted_reads==2*length && accepted_writes==length)
            else $fatal(1,"actual accepted DATA events differ from byte count");
        if(mode==-2) assert(miss_arrivals==length)
            else $fatal(1,"CPU2M deliberate loss stream not exercised");
        if(mode==-1) begin
            assert(cpu_reads==2*length && cpu_writes==length && dma_reads==0 && dma_writes==0)
                else $fatal(1,"CPU transfer counts");
        end else begin
            assert(dma_reads==2*length && dma_writes==length &&
                   dma_bus_reads==3*length && dma_bus_writes==3*length && cpu_reads==0 && cpu_writes==0)
                else $fatal(1,"genuine DMA transfer counts");
            assert(ready_drops>=3*length && grant_returns>0 && request_entries>0 && ack_entries>0 && dut.cpu_busak_n && dut.dma_busrq_n && !dut.dma_owner)
                else $fatal(1,"DMA Ready deassert/ownership release absent");
        end
        for(int d=0;d<2;d++) for(int i=0;i<total;i++)
            assert(image_bytes[d][i]==expected[d][i]) else $fatal(1,"whole A/B medium changed unexpectedly");
        $display("PASS actual CPU/DMA fixed FDC rate=%0d width=%0d drive=%0d length=%0d mode=%0d arrivals=%0d loads=%0d dma=%0d/%0d cpu=%0d/%0d ready_drops=%0d returns=%0d SD=%0d/%0d",RATE,ADDRESS_BITS,drive,length,mode,arrivals,dsr_loads,dma_reads,dma_writes,cpu_reads,cpu_writes,ready_drops,grant_returns,requests,host_writes);
        $display("OBSERVED DATA accepts=%0d/%0d max_DRQ_observed_to_accept_ps=%0t/%0t cancellation=%0d write=%0d drain_retirements=%0d",accepted_reads,accepted_writes,read_accept_max_ps,write_accept_max_ps,cancel_kind,cancel_write,drain_retirements);
        $finish;
    end
    initial begin
        wait(!reset);
        // Fixed startup/CPU bookkeeping allowance plus THREE full streams,
        // derived from explicit physical chip rate, not CPU service cadence.
        #(64'd100000000000 + 64'(length)*96*64'd1000000000000/64'(RATE));
        $fatal(1,"bounded CPU fixture timeout pc=%h address=%h phase=%0d dma=%0d/%0d requests=%0d",dut.cpu_a,dut.a,phase,dma_reads,dma_writes,requests);
    end
    generate if(TIMING_ENABLED) begin : cancellation_observation
    initial begin
        wait(!reset);
        if(cancel_kind==1 || cancel_kind==2) begin
            wait(phase==(cancel_write!=0 ? 2 : 1) && host_owned && ack &&
                 host_disk==1'(drive) && host_direction==1'(cancel_write) && host_byte>=8);
            tick();cancel_fired=1;
            if(cancel_kind==1) begin
                reset=1;
                repeat(16) tick();
                assert(dut.core_reset && !dut.cpu_ce && !dut.fdc.ce)
                    else $fatal(1,"ACK reset did not stop controller/CPU enables");
                wait(!ack && !dut.fdc.sd_busy);
                repeat(32) tick();cancel_observed=1;reset=0;
            end else begin
                if(drive==0) mount_a=1;else mount_b=1;
                repeat(8) tick();
                assert(!dut.fdc.strict_timing.active && !dut.fdc.timing_buffer_store && !dut.fdc.timing_read_load)
                    else $fatal(1,"mounted media failed to cancel stream");
                mount_a=0;mount_b=0;cancel_observed=1;
            end
        end else if(cancel_kind==4) begin
            wait(phase==1 && dut.dma_owner && !dut.mreq && !dut.wr);
            tick();cancel_fired=1;observe_drain=1;reset=1;#1;
            assert(dut.dma_draining && !dut.core_reset && !dut.cpu_run && load_wait)
                else $fatal(1,"owned DMA reset lacked real retained grant/drain");
            wait(dut.core_reset);repeat(32) tick();
            assert(drain_retirements==1)
                else $fatal(1,"owned reset must retire exactly the already-started DMA pair");
            observe_drain=0;
            assert(!dut.dma_owner && dut.cpu_busak_n && dut.dma_busrq_n)
                else $fatal(1,"owned DMA reset failed to release");
            cancel_observed=1;reset=0;
        end
    end
    end endgenerate
endmodule
