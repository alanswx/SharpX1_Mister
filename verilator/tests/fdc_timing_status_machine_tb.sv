// SPDX-License-Identifier: GPL-2.0-or-later
// Original diagnostic, derived from this project's original metadata fixture.
// Real CPU/DMA, public ioctl/SD pins only; hierarchical probes observe only.
// D88 byte-8 status 10 is a CONTAINER policy, not a native pin encoding.
`timescale 1ps/1ps
module fdc_timing_status_machine_tb #(
    parameter RATE=1000000, ADDRESS_BITS=20, HEADER_OFFSET=1008
);
    localparam LENGTH=1024, PAYLOAD=HEADER_OFFSET+16;
    localparam TOTAL=PAYLOAD+LENGTH+16+128;
    localparam PAYLOAD_BLOCKS=((PAYLOAD%512)+LENGTH+511)/512;
    localparam SPLIT=((HEADER_OFFSET+7)%512==511);
    localparam PUBLICATIONS=PAYLOAD_BLOCKS+1;
    localparam WRITE_READS=PAYLOAD_BLOCKS+1+int'(SPLIT);
    logic clk=0,video_clk=0,reset=1,download=0,load=0,mounted=0;
    logic mount_a=0,mount_b=0,ack=0,host_wr=0;
    always #15625 clk=!clk;
    always #17500 video_clk=!video_clk;
    logic [24:0] load_addr=0;
    logic [7:0] load_data=0,rom[32768];
    byte unsigned image_bytes[2][TOTAL],ledger[2][TOTAL];
    logic [8:0] host_addr=0;
    logic [7:0] host_data=0;
    wire [7:0] host_read;
    wire [31:0] lba;
    wire sd_rd,sd_wr,owner,load_wait;
    integer drive=0,rom_size=0,stage=0,requests=0,writes=0;
    integer first_count=0,second_count=0,first_reads=0,second_reads=0;
    integer chip_count=0,read_due=0,write_due=0,arm_edge=0;
    integer accepted_reads=0,accepted_writes=0,sys_edges=0,last_chip=0,clock_checks=0;
    bit old_marker=0,complete=0,failed=0,host_owned=0,chip_seen=0;
    bit remounted_normal=0,remounted_deleted=0;
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
        .disk_ready(1'b1),.img_mounted(mounted|mount_a),.disk_wp(1'b0),
        .img_size(24'(TOTAL)),
        .disk_ready_b(1'b1),.img_mounted_b(mounted|mount_b),.disk_wp_b(1'b0),
        .img_size_b(24'(TOTAL)),
        .sd_drive(owner),.sd_lba(lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(ack),
        .sd_buff_addr(host_addr),.sd_buff_dout(host_data),.sd_buff_din(host_read),.sd_buff_wr(host_wr),
        .ce_pix(),.HBlank(),.HSync(),.VBlank(),.VSync(),.video(),.rgb(),.rgb12(),
        .audio(),.audio_left(),.audio_right(),.audio_mono(),.audio_sample()
    );

    function automatic [7:0] payload(input integer d,i);
        return 8'(i*37+(i>>8)*53+d*104+19);
    endfunction
    task automatic tick; @(negedge clk);#1;endtask
    function automatic [7:0] media_byte(input integer d,at);
        return at<TOTAL?image_bytes[d][at]:8'd0;
    endfunction
    function automatic [7:0] ledger_byte(input integer d,at);
        return at<TOTAL?ledger[d][at]:8'd0;
    endfunction
    // Plans depend ONLY on original layout and the CPU command schedule.
    // Each write flushes all payload blocks and one changed-mark block.
    // Split status 10 is read but never dirty: no status-only publication.
    function automatic integer planned_lba(input integer ordinal);
        return ordinal<PAYLOAD_BLOCKS?PAYLOAD/512+ordinal:(HEADER_OFFSET+7)/512;
    endfunction
    function automatic integer planned_read_lba(input integer ordinal);
        if(ordinal<PAYLOAD_BLOCKS) return PAYLOAD/512+ordinal;
        return ordinal==PAYLOAD_BLOCKS?(HEADER_OFFSET+7)/512:(HEADER_OFFSET+8)/512;
    endfunction
    function automatic [7:0] predicted_byte(input integer d,at,command_stage,ordinal);
        if(ordinal<PAYLOAD_BLOCKS && at>=PAYLOAD && at<PAYLOAD+LENGTH)
            return payload(d,at-PAYLOAD)^(command_stage==20?8'h5a:8'ha7);
        if(ordinal==PAYLOAD_BLOCKS && at==HEADER_OFFSET+7)
            return command_stage==20?8'h00:8'h10;
        return ledger_byte(d,at);
    endfunction
    wire marker=dut.mem_write && !dut.dma_owner && dut.a==16'hf010;
    wire result=dut.mem_write && !dut.dma_owner && dut.a==16'hf000;
    always @(posedge clk) begin
        sys_edges++;
        if(marker && !old_marker) begin
            stage=int'(dut.data_out);
            $display("EVENT CPU stage=%0d publications=%0d/%0d",stage,first_count,second_count);$fflush();
            if(stage==30)
                assert(first_count==PUBLICATIONS && first_reads==WRITE_READS)
                    else $fatal(1,"normal write publication/read plan incomplete");
            if(stage==60)
                assert(second_count==PUBLICATIONS && second_reads==WRITE_READS)
                    else $fatal(1,"deleted write publication/read plan incomplete");
        end
        if(result && dut.data_out==8'hee) failed=1;
        if(result && dut.data_out==8'h5a) complete=1;
        old_marker=marker;
        if(dut.fdc.metadata_commit)
            assert(!ack) else $fatal(1,"metadata cache committed before owned ACK drain");
        if(!dut.core_reset) begin
            if(dut.fdc.fdc_ce) begin
                if(chip_seen) begin
                    assert(sys_edges-last_chip==32000000/RATE) else $fatal(1,"explicit chip rate changed");
                    clock_checks++;
                end
                chip_seen=1;last_chip=sys_edges;chip_count<=chip_count+1;
            end
            if(dut.fdc.strict_timing.begin_read) read_due=chip_count+int'(dut.fdc.fdc_ce)+32;
            if(dut.fdc.strict_timing.arm_write) begin
                arm_edge=chip_count+int'(dut.fdc.fdc_ce);write_due=arm_edge+32;
            end
            if(dut.fdc.timing_read_load) begin
                assert(chip_count+int'(dut.fdc.fdc_ce)==read_due) else $fatal(1,"read cadence rephased");
                read_due+=32;
            end
            if(dut.fdc.strict_timing.launch)
                assert(chip_count+int'(dut.fdc.fdc_ce)-arm_edge==32) else $fatal(1,"initial prefill rephased");
            if(dut.fdc.timing_read_accept && dut.a==16'h0ffb && !dut.dam) accepted_reads++;
            if(dut.fdc.timing_write_accept && dut.a==16'h0ffb && !dut.dam) accepted_writes++;
            assert(!dut.turbo_dma.engine.force_ready) else $fatal(1,"manufactured Ready prohibited");
        end else chip_seen=0;
    end
    always @(negedge clk) if(dut.fdc.strict_timing.write_emit && !dut.fdc.timing_cancel) begin
        assert(chip_count==write_due) else $fatal(1,"DSR cadence rephased");write_due+=32;
    end

    logic [31:0] rng=32'hb913ace7;
    function automatic integer host_delay;
        rng=(rng<<1)^(rng[31]?32'h04c11db7:32'd0);return int'(rng&31)+1;
    endfunction
    initial forever begin
        integer block,at,ordinal,command_stage,read_ordinal;
        bit disk,writing;
        wait(sd_rd || sd_wr);
        block=int'(lba);disk=owner;writing=sd_wr;host_owned=1;requests++;
        command_stage=stage;ordinal=-1;
        assert(!(sd_rd && sd_wr)) else $fatal(1,"simultaneous SD directions");
        if(writing) begin
            assert(command_stage==20 || command_stage==50) else $fatal(1,"unplanned write stage");
            ordinal=command_stage==20?first_count:second_count;
            assert(ordinal<PUBLICATIONS && int'(disk)==drive)
                else $fatal(1,"unexpected publication ordinal or owner");
            assert(block==planned_lba(ordinal)) else $fatal(1,"planned publication LBA mismatch");
            if(command_stage==20) first_count++;else second_count++;
            writes++;
        end else if(command_stage==20 || command_stage==50) begin
            read_ordinal=command_stage==20?first_reads:second_reads;
            assert(read_ordinal<WRITE_READS && int'(disk)==drive && block==planned_read_lba(read_ordinal))
                else $fatal(1,"write prefetch/metadata read plan mismatch");
            if(command_stage==20) first_reads++;else second_reads++;
        end
        repeat(host_delay()) begin
            tick();assert(lba==32'(block) && owner==disk) else $fatal(1,"pre-ACK request identity changed");
        end
        ack=1;
        for(int i=0;i<512;i++) begin
            host_addr=9'(i);at=block*512+i;
            if(writing) begin
                tick();tick();
                if(at==HEADER_OFFSET+8)
                    assert(host_read==8'h10)
                        else $fatal(1,"active nonB0 status changed in publication stage=%0d offset=%0d",command_stage,at);
                assert(host_read==predicted_byte(int'(disk),at,command_stage,ordinal))
                    else $fatal(1,"published block differs from independent ledger stage=%0d ordinal=%0d offset=%0d",command_stage,ordinal,at);
                if(at<TOTAL) image_bytes[disk][at]=host_read;
            end else begin host_data=media_byte(int'(disk),at);host_wr=1;tick();end
            assert(lba==32'(block) && owner==disk) else $fatal(1,"owned ACK identity changed");
        end
        host_wr=0;
        repeat(host_delay()+8) begin
            tick();assert(lba==32'(block) && owner==disk) else $fatal(1,"owned ACK tail identity changed");
        end
        ack=0;
        // NEVER copy observed SD output into the independent ledger.
        if(writing) for(int i=0;i<512;i++) begin
            at=block*512+i;
            if(at<TOTAL) ledger[disk][at]=predicted_byte(int'(disk),at,command_stage,ordinal);
        end
        repeat(16) tick();host_owned=0;
    end
    initial begin
        wait(!reset);
        wait(stage==40);wait(dut.transport_idle && !host_owned);tick();
        if(drive==0) mount_a=1;else mount_b=1;
        repeat(32) tick();mount_a=0;mount_b=0;remounted_normal=1;
        wait(stage==70);wait(dut.transport_idle && !host_owned);tick();
        if(drive==0) mount_a=1;else mount_b=1;
        repeat(32) tick();mount_a=0;mount_b=0;remounted_deleted=1;
    end
    initial begin
        assert($value$plusargs("ROM=%s",rom_path)) else $fatal(1,"generated IPL required");
        if($value$plusargs("ROM_SIZE=%d",rom_size)) begin end
        if($value$plusargs("DRIVE=%d",drive)) begin end
        assert(rom_size>0 && rom_size<=32768 && drive>=0 && drive<2 &&
               (HEADER_OFFSET==1008 || HEADER_OFFSET==1016) &&
               (RATE==1000000 || RATE==2000000) && (ADDRESS_BITS==20 || ADDRESS_BITS==24))
            else $fatal(1,"invalid fixture configuration");
        $readmemh(rom_path,rom,0,rom_size-1);
        for(int d=0;d<2;d++) begin
            for(int i=0;i<TOTAL;i++) image_bytes[d][i]=0;
            for(int i=0;i<4;i++) begin
                image_bytes[d][28+i]=8'(TOTAL>>(i*8));
                image_bytes[d][32+i]=8'(HEADER_OFFSET>>(i*8));
            end
            image_bytes[d][HEADER_OFFSET+2]=1;image_bytes[d][HEADER_OFFSET+3]=3;
            image_bytes[d][HEADER_OFFSET+4]=2;
            image_bytes[d][HEADER_OFFSET+7]=8'h10;image_bytes[d][HEADER_OFFSET+8]=8'h10;
            image_bytes[d][HEADER_OFFSET+15]=4;
            image_bytes[d][PAYLOAD+LENGTH+2]=2;image_bytes[d][PAYLOAD+LENGTH+4]=2;
            image_bytes[d][PAYLOAD+LENGTH+14]=128;
            for(int i=0;i<LENGTH;i++) image_bytes[d][PAYLOAD+i]=payload(d,i);
            for(int i=0;i<128;i++) image_bytes[d][PAYLOAD+LENGTH+16+i]=8'(i*7+d*43+103);
            for(int i=0;i<TOTAL;i++) ledger[d][i]=image_bytes[d][i];
        end
        repeat(8) tick();download=1;
        for(int i=0;i<rom_size;i++) begin
            tick();while(load_wait) tick();load_addr=25'(i);load_data=rom[i];load=1;tick();load=0;
        end
        tick();download=0;mounted=1;repeat(32) tick();mounted=0;repeat(32) tick();reset=0;
        wait(complete || failed);repeat(32) tick();
        assert(!failed) else $fatal(1,"CPU status-container payload/status diagnostic failed stage=%0d",stage);
        assert(remounted_normal && remounted_deleted && clock_checks>0)
            else $fatal(1,"required rescan/clock coverage absent");
        assert(first_count==PUBLICATIONS && second_count==PUBLICATIONS &&
               first_reads==WRITE_READS && second_reads==WRITE_READS)
            else $fatal(1,"final publication/read count wrong");
        assert(accepted_reads==5*LENGTH && accepted_writes==2*LENGTH)
            else $fatal(1,"actual DATA acceptance counts wrong");
        for(int d=0;d<2;d++) begin
            assert(image_bytes[d][HEADER_OFFSET+8]==8'h10)
                else $fatal(1,"active nonB0 status changed in whole medium");
            for(int i=0;i<TOTAL;i++)
                assert(image_bytes[d][i]==ledger[d][i])
                    else $fatal(1,"whole medium differs from independent ledger drive=%0d offset=%0d",d,i);
        end
        $display("PASS status machine rate=%0d width=%0d header=%0d drive=%0d split=%0d reads=%0d writes=%0d publications=%0d/%0d write_reads=%0d/%0d requests=%0d",
                 RATE,ADDRESS_BITS,HEADER_OFFSET,drive,SPLIT,accepted_reads,accepted_writes,first_count,second_count,first_reads,second_reads,requests);
        $finish;
    end
    initial begin
        wait(!reset);#(64'd1000000000000);
        $fatal(1,"physical duration budget exhausted stage=%0d",stage);
    end
endmodule
