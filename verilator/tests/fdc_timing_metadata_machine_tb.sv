// SPDX-License-Identifier: GPL-2.0-or-later
// Original public-machine D88 publication-ledger diagnostic. No force/private
// writes. Header codes are container conventions, NOT native wire encodings.
`timescale 1ps/1ps
module fdc_timing_metadata_machine_tb #(
    parameter RATE=1000000, ADDRESS_BITS=20, HEADER_OFFSET=1016
);
    localparam LENGTH=1024, LOW_HEADER=1016, LOW_PAYLOAD=LOW_HEADER+16;
    localparam PAYLOAD=HEADER_OFFSET+16, TOTAL=PAYLOAD+LENGTH+16+128;
    localparam LOW_TOTAL=LOW_PAYLOAD+LENGTH+16+128;
    localparam REJECT_HIGH=(ADDRESS_BITS==20 && HEADER_OFFSET>=1048576);
    logic clk=0,video_clk=0,reset=1,download=0,load=0,mounted=0;
    logic mount_a=0,mount_b=0,ack=0,host_wr=0,low_media=0;
    always #15625 clk=!clk;
    always #17500 video_clk=!video_clk;
    logic [24:0] load_addr=0;
    logic [7:0] load_data=0,rom[32768];
    byte unsigned image_bytes[2][TOTAL],ledger[2][TOTAL];
    byte unsigned low_bytes[2][LOW_TOTAL],low_ledger[2][LOW_TOTAL];
    logic [8:0] host_addr=0;
    logic [7:0] host_data=0;
    wire [7:0] host_read;
    wire [31:0] lba;
    wire sd_rd,sd_wr,owner,load_wait;
    integer drive=0,rom_size=0,stage=0,requests=0,writes=0;
    integer cancel_block=-1,cancel_point=0,cancel_kind=0;
    integer first_count=0,second_count=0,chip_count=0,read_due=0,write_due=0,arm_edge=0;
    integer accepted_reads=0,accepted_writes=0,sys_edges=0,last_chip=0,clock_checks=0;
    bit old_marker=0,complete=0,failed=0,cancelled=0,host_owned=0,chip_seen=0;
    bit rejected=0,remounted=0,cancel_released=0;
    bit high_scan_seen=0,rejected_status_seen=0;
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
        .img_size(24'(low_media?LOW_TOTAL:TOTAL)),
        .disk_ready_b(1'b1),.img_mounted_b(mounted|mount_b),.disk_wp_b(1'b0),
        .img_size_b(24'(low_media?LOW_TOTAL:TOTAL)),
        .sd_drive(owner),.sd_lba(lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(ack),
        .sd_buff_addr(host_addr),.sd_buff_dout(host_data),.sd_buff_din(host_read),.sd_buff_wr(host_wr),
        .ce_pix(),.HBlank(),.HSync(),.VBlank(),.VSync(),.video(),.rgb(),.rgb12(),
        .audio(),.audio_left(),.audio_right(),.audio_mono(),.audio_sample()
    );
    function automatic [7:0] payload(input integer d,i);
        return 8'(i*37+(i>>8)*53+d*104+19);
    endfunction
    task automatic tick; @(negedge clk);#1;endtask
    function automatic integer header;return low_media?LOW_HEADER:HEADER_OFFSET;endfunction
    function automatic integer medium_size;return low_media?LOW_TOTAL:TOTAL;endfunction
    function automatic [7:0] media_byte(input integer d,at);
        if(at>=medium_size()) return 0;
        return low_media?low_bytes[d][at]:image_bytes[d][at];
    endfunction
    function automatic [7:0] ledger_byte(input integer d,at);
        if(at>=medium_size()) return 0;
        return low_media?low_ledger[d][at]:ledger[d][at];
    endfunction
    // Publication ordinal is the COMMAND plan, not a DUT state/index query.
    // First normal write: 3 payload blocks, mark RMW, then CRC RMW.
    // Second write: deleted if success, normal recovery if cancelled.
    function automatic integer planned_kind(input integer command_stage,ordinal);
        if(ordinal<3) return 0;
        if(command_stage==20 || cancel_block<0) return ordinal==3?1:2;
        if(cancel_block<3) return ordinal==3?1:2;
        return 2;
    endfunction
    function automatic integer planned_count(input integer command_stage);
        if(command_stage==20) return 5;
        if(cancel_block<0) return 4;
        return 3+int'(cancel_block<3)+int'(cancel_block<4);
    endfunction
    function automatic integer planned_lba(input integer kind,ordinal);
        if(kind==0) return (header()+16)/512+ordinal;
        return (header()+7+int'(kind==2))/512;
    endfunction
    function automatic [7:0] predicted_byte(input integer d,at,command_stage,kind);
        if(kind==0 && at>=header()+16 && at<header()+16+LENGTH)
            return payload(d,at-header()-16)^(command_stage==20?8'h5a:8'ha7);
        if(kind==1 && at==header()+7) return command_stage==50 && cancel_block<0?8'h10:8'h00;
        if(kind==2 && at==header()+8) return 0;
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
                assert(first_count==(cancel_block<0?5:cancel_block+1))
                    else $fatal(1,"split metadata publication missing before CPU readback");
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
            if(REJECT_HIGH && !low_media) begin
                assert(!dut.fdc.timing_read_load && !sd_wr) else $fatal(1,"width20 admitted high-address payload");
                if(int'(dut.active_drive)==drive && !dut.media_changing && dut.fdc.scan_active)
                    high_scan_seen=1;
                if(high_scan_seen && !dut.fdc.scan_active && !dut.fdc.mount_pending &&
                   !dut.media_changing && int'(dut.active_drive)==drive && dut.fdc.d88_bad &&
                   !dut.dma_owner && !dut.dam && dut.a==16'h0ff8 && dut.fdc.timing_read_accept) begin
                    assert(dut.fdc.wdreg_status[7]) else $fatal(1,"completed high rejection lacks CPU NOTREADY");
                    rejected_status_seen=1;
                end
            end
        end else chip_seen=0;
    end
    always @(negedge clk) if(dut.fdc.strict_timing.write_emit && !dut.fdc.timing_cancel) begin
        assert(chip_count==write_due) else $fatal(1,"DSR cadence rephased");write_due+=32;
    end
    logic [31:0] rng=32'hb913ace7;
    function automatic integer host_delay;
        rng=(rng<<1)^(rng[31]?32'h04c11db7:32'd0);return int'(rng&31)+1;
    endfunction
    task automatic start_cancel;
        assert(host_owned && stage==20 && !cancelled) else $fatal(1,"cancellation outside planned owned phase");
        cancelled=1;
        if(cancel_kind==0) reset=1;
        else if(drive==0) mount_a=1;
        else mount_b=1;
    endtask
    initial forever begin
        integer block,at,ordinal,kind,command_stage;
        bit disk,writing,target;
        wait(sd_rd || sd_wr);
        block=int'(lba);disk=owner;writing=sd_wr;host_owned=1;requests++;
        command_stage=stage;ordinal=-1;kind=-1;target=0;
        assert(!(sd_rd && sd_wr)) else $fatal(1,"simultaneous SD directions");
        if(writing) begin
            assert(command_stage==20 || command_stage==50) else $fatal(1,"unplanned write stage");
            ordinal=command_stage==20?first_count:second_count;
            assert(ordinal<planned_count(command_stage) && int'(disk)==drive)
                else $fatal(1,"unexpected publication ordinal or owner");
            kind=planned_kind(command_stage,ordinal);
            assert(block==planned_lba(kind,ordinal)) else $fatal(1,"planned publication LBA mismatch");
            assert(!cancelled || command_stage==50) else $fatal(1,"unpublished write escaped cancellation");
            if(command_stage==20) first_count++;else second_count++;
            writes++;target=command_stage==20 && ordinal==cancel_block;
        end
        repeat(host_delay()) begin
            tick();assert(lba==32'(block) && owner==disk) else $fatal(1,"pre-ACK request identity changed");
        end
        if(target && cancel_point==0) start_cancel();
        ack=1;
        for(int i=0;i<512;i++) begin
            host_addr=9'(i);at=block*512+i;
            if(writing) begin
                tick();tick();
                assert(host_read==predicted_byte(int'(disk),at,command_stage,kind))
                    else $fatal(1,"published block differs from planned ledger stage=%0d kind=%0d offset=%0d",command_stage,kind,at);
                if(at<medium_size()) begin
                    if(low_media) low_bytes[disk][at]=host_read;else image_bytes[disk][at]=host_read;
                end
            end else begin host_data=media_byte(int'(disk),at);host_wr=1;tick();end
            assert(lba==32'(block) && owner==disk) else $fatal(1,"owned ACK identity changed");
            if(target && cancel_point==1 && i==127) start_cancel();
        end
        host_wr=0;
        if(target && cancel_point==2) start_cancel();
        repeat(host_delay()+8) begin
            tick();assert(lba==32'(block) && owner==disk) else $fatal(1,"owned ACK tail identity changed");
        end
        ack=0;
        // Only planned edits enter the ledger. Observed SD bytes NEVER do.
        if(writing) for(int i=0;i<512;i++) begin
            at=block*512+i;
            if(at<medium_size()) begin
                if(low_media) low_ledger[disk][at]=predicted_byte(int'(disk),at,command_stage,kind);
                else ledger[disk][at]=predicted_byte(int'(disk),at,command_stage,kind);
            end
        end
        repeat(16) tick();host_owned=0;
        if(target) begin
            assert(!sd_wr) else $fatal(1,"cancelled ACK spawned next write");
            reset=0;mount_a=0;mount_b=0;cancel_released=1;
        end
    end
    initial begin
        wait(!reset);
        if(REJECT_HIGH) begin
            wait(stage==2);
            wait(high_scan_seen && !dut.fdc.scan_active && !dut.fdc.mount_pending &&
                 !dut.media_changing && int'(dut.active_drive)==drive && dut.transport_idle && !host_owned);
            assert(dut.fdc.d88_bad && !dut.fdc.d88_valid && writes==0 && accepted_reads==0 && accepted_writes==0)
                else $fatal(1,"width20 high admission rejection absent");
            wait(rejected_status_seen);
            rejected=1;tick();low_media=1;mounted=1;repeat(32) tick();mounted=0;
        end
        wait(stage==40);wait(dut.transport_idle && !host_owned);tick();
        if(drive==0) mount_a=1;else mount_b=1;
        repeat(32) tick();mount_a=0;mount_b=0;remounted=1;
        if(cancel_block<0) begin
            wait(stage==70);wait(dut.transport_idle && !host_owned);tick();
            if(drive==0) mount_a=1;else mount_b=1;
            repeat(32) tick();mount_a=0;mount_b=0;
        end
    end
    initial begin
        assert($value$plusargs("ROM=%s",rom_path)) else $fatal(1,"generated IPL required");
        if($value$plusargs("ROM_SIZE=%d",rom_size)) begin end
        if($value$plusargs("DRIVE=%d",drive)) begin end
        if($value$plusargs("CANCEL_BLOCK=%d",cancel_block)) begin end
        if($value$plusargs("CANCEL_POINT=%d",cancel_point)) begin end
        if($value$plusargs("CANCEL_KIND=%d",cancel_kind)) begin end
        assert(rom_size>0 && rom_size<=32768 && drive>=0 && drive<2 && cancel_block>=-1 && cancel_block<=4 &&
               cancel_point>=0 && cancel_point<=2 && cancel_kind>=0 && cancel_kind<=1)
            else $fatal(1,"invalid fixture configuration");
        $readmemh(rom_path,rom,0,rom_size-1);
        for(int d=0;d<2;d++) begin
            for(int i=0;i<TOTAL;i++) image_bytes[d][i]=0;
            for(int i=0;i<LOW_TOTAL;i++) low_bytes[d][i]=0;
            for(int j=0;j<2;j++) begin
                integer h,sz;
                h=j==0?HEADER_OFFSET:LOW_HEADER;sz=j==0?TOTAL:LOW_TOTAL;
                for(int i=0;i<4;i++) begin
                    if(j==0) begin image_bytes[d][28+i]=8'(sz>>(i*8));image_bytes[d][32+i]=8'(h>>(i*8));end
                    else begin low_bytes[d][28+i]=8'(sz>>(i*8));low_bytes[d][32+i]=8'(h>>(i*8));end
                end
                if(j==0) begin
                    image_bytes[d][h+2]=1;image_bytes[d][h+3]=3;image_bytes[d][h+4]=2;
                    image_bytes[d][h+7]=8'h10;image_bytes[d][h+8]=8'hb0;image_bytes[d][h+15]=4;
                    image_bytes[d][h+16+LENGTH+2]=2;image_bytes[d][h+16+LENGTH+4]=2;
                    image_bytes[d][h+16+LENGTH+14]=128;
                    for(int i=0;i<LENGTH;i++) image_bytes[d][h+16+i]=payload(d,i);
                    for(int i=0;i<128;i++) image_bytes[d][h+32+LENGTH+i]=8'(i*7+d*43+103);
                end else begin
                    low_bytes[d][h+2]=1;low_bytes[d][h+3]=3;low_bytes[d][h+4]=2;
                    low_bytes[d][h+7]=8'h10;low_bytes[d][h+8]=8'hb0;low_bytes[d][h+15]=4;
                    low_bytes[d][h+16+LENGTH+2]=2;low_bytes[d][h+16+LENGTH+4]=2;
                    low_bytes[d][h+16+LENGTH+14]=128;
                    for(int i=0;i<LENGTH;i++) low_bytes[d][h+16+i]=payload(d,i);
                    for(int i=0;i<128;i++) low_bytes[d][h+32+LENGTH+i]=8'(i*7+d*43+103);
                end
            end
            for(int i=0;i<TOTAL;i++) ledger[d][i]=image_bytes[d][i];
            for(int i=0;i<LOW_TOTAL;i++) low_ledger[d][i]=low_bytes[d][i];
        end
        repeat(8) tick();download=1;
        for(int i=0;i<rom_size;i++) begin
            tick();while(load_wait) tick();load_addr=25'(i);load_data=rom[i];load=1;tick();load=0;
        end
        tick();download=0;mounted=1;repeat(32) tick();mounted=0;repeat(32) tick();reset=0;
        wait(complete || failed);repeat(32) tick();
        assert(!failed) else $fatal(1,"CPU metadata payload/status diagnostic failed stage=%0d",stage);
        assert(remounted && clock_checks>0) else $fatal(1,"required rescan/clock coverage absent");
        if(REJECT_HIGH) assert(rejected && low_media) else $fatal(1,"low remount recovery absent");
        if(cancel_block>=0) assert(cancelled && cancel_released && first_count==cancel_block+1)
            else $fatal(1,"owned cancellation publication count wrong");
        else assert(first_count==5) else $fatal(1,"split metadata publication missing");
        assert(second_count==planned_count(50)) else $fatal(1,"recovery/deleted publication count wrong");
        assert(accepted_reads==(cancel_block<0?5:4)*LENGTH && accepted_writes==2*LENGTH)
            else $fatal(1,"actual DATA acceptance counts wrong");
        for(int d=0;d<2;d++) begin
            for(int i=0;i<TOTAL;i++) assert(image_bytes[d][i]==ledger[d][i]) else $fatal(1,"whole original medium differs from ledger");
            for(int i=0;i<LOW_TOTAL;i++) assert(low_bytes[d][i]==low_ledger[d][i]) else $fatal(1,"whole low medium differs from ledger");
        end
        $display("PASS metadata machine rate=%0d width=%0d header=%0d drive=%0d cancel=%0d/%0d/%0d reject=%0d reads=%0d writes=%0d publications=%0d/%0d requests=%0d",RATE,ADDRESS_BITS,HEADER_OFFSET,drive,cancel_block,cancel_point,cancel_kind,rejected,accepted_reads,accepted_writes,first_count,second_count,requests);
        $finish;
    end
    initial begin
        wait(!reset);
        // Includes actual byte-by-byte scanning of the >1MiB gap, not just
        // transfer cadence. Budget is physical SYS time, never CPU rephase.
        #(64'd1000000000000+64'(TOTAL)*3*64'd2500000);
        $fatal(1,"physical duration budget exhausted stage=%0d",stage);
    end
endmodule
