`timescale 1ns/1ps
// Original generated D88 fixture. Register/real SD path only; no private assets.
module d88_metadata_tb;
    reg clk=0, reset=1, mounted=0, ack=0, host_wr=0, wr=0, rd=0;
    reg [1:0] address=0;
    reg [7:0] data=0, host_data=0;
    reg [8:0] host_address=0;
    reg [7:0] image[8192], original[8192], expected[8192];
    wire [7:0] dout, host_read_data;
    wire [31:0] lba;
    wire prepare, sd_rd, sd_wr, busy, drq, irq, idle;
    reg protected_media=0, service=1, hold_ack=0, ready=1;
    integer divider=8, phase=0, writes=0, requests=0, pause_write=0;
    integer header=1016, length=128, count=3, target=0, groups=0;
    reg audit_index=0;
    reg [56:0] committed_index[3];
    reg pause_metadata_read=0, pause_second_read=0;
    reg [23:0] size=0;
    wire ce=!reset && phase==0;
    always #5 clk=!clk;
    always @(negedge clk) phase=(phase+1)%divider;
    // Observe index storage without injecting it. Every entire entry must
    // stay unchanged except at an actual owned metadata ACK drain.
    always @(posedge clk) begin
        if(mounted || dut.mount_pending || prepare) audit_index=0;
        else if(audit_index && dut.metadata_commit) begin
            assert(int'(dut.metadata_index)<count) else $fatal(1,"bad metadata index");
            if(dut.metadata_commit_mark) committed_index[int'(dut.metadata_index)][20]=dut.metadata_deleted;
            if(dut.metadata_commit_crc) committed_index[int'(dut.metadata_index)][21]=0;
        end
    end
    always @(negedge clk) if(audit_index && !mounted && !dut.mount_pending && !prepare)
        for(int j=0;j<count;j++) assert(dut.image_index.edsk_ram.ram[j]==committed_index[j])
            else $fatal(1,"index changed outside corresponding ACK commit entry=%0d",j);
    wd1793 #(.RWMODE(1), .EDSK(1), .D88_ONLY(1)) dut(
        .drive_select(1'b0), .drive_connected(1'b1), .transport_idle(idle),
        .clk_sys(clk), .ce(ce), .reset(reset), .io_en(1'b1),
        .rd(rd), .wr(wr), .addr(address), .din(data), .dout(dout),
        .drq(drq), .intrq(irq), .busy(busy), .wp(protected_media), .fmt_wp(),
        .size_code(3'd1), .layout(1'b0), .side(1'b0), .ready(ready), .fm_mode(1'b0),
        .img_mounted(mounted), .img_size(size[19:0]), .img_size_id(size),
        .disk_index(3'd0), .prepare(prepare), .sd_lba(lba), .sd_rd(sd_rd), .sd_wr(sd_wr),
        .sd_ack(ack), .sd_buff_addr(host_address), .sd_buff_dout(host_data),
        .sd_buff_din(host_read_data), .sd_buff_wr(host_wr), .input_active(1'b0),
        .input_addr(20'd0), .input_data(8'd0), .input_wr(1'b0),
        .buff_addr(), .buff_read(), .buff_din(8'd0));

    initial forever begin
        bit writing;
        reg [31:0] owned_lba;
        reg [1:0] owned_bank;
        wait(sd_rd || sd_wr);
        writing=sd_wr; owned_lba=lba; owned_bank=dut.sd_block;
        assert(!(sd_rd && sd_wr)) else $fatal(1,"simultaneous host requests");
        if(writing && writes+1==pause_write) service=0;
        if(!writing && dut.metadata_busy && pause_metadata_read &&
           dut.metadata_second==pause_second_read) service=0;
        wait(service);
        @(negedge clk); ack=1; requests++;
        if(writing) writes++;
        for(int i=0;i<512;i++) begin
            host_address=9'(i);
            if(writing) begin
                repeat(2) @(negedge clk);
                if(owned_lba*512+32'(i)<8192) image[owned_lba*512+32'(i)]=host_read_data;
            end else begin
                host_data=(owned_lba*512+32'(i)<8192) ? image[owned_lba*512+32'(i)] : 0;
                host_wr=1; @(negedge clk);
            end
            assert(lba==owned_lba && dut.sd_block==owned_bank)
                else $fatal(1,"owned LBA/bank changed during ACK");
        end
        host_wr=0;
        wait(!hold_ack);
        repeat(10) @(negedge clk); ack=0;
        repeat(12) @(negedge clk);
    end
    task send(input [1:0] port, input [7:0] value);
        @(negedge clk); address=port; data=value; wr=1;
        repeat(divider*3) @(negedge clk);
        wr=0; repeat(divider*3) @(negedge clk);
    endtask
    task read_byte(output reg [7:0] value);
        @(negedge clk); address=3; rd=1;
        repeat(divider*2) @(negedge clk); value=dout;
        rd=0; repeat(divider*3) @(negedge clk);
    endtask
    task finish_scan;
        repeat(divider*4) @(negedge clk);
        wait(!prepare && !dut.mount_pending && idle);
        repeat(divider*4) @(negedge clk);
        assert(dut.media_ready && int'(dut.edsk_size)==count) else $fatal(1,"mount failed");
        for(int j=0;j<count;j++) committed_index[j]=dut.image_index.edsk_ram.ram[j];
        audit_index=1;
    endtask
    task remount;
        @(negedge clk); mounted=1;
        repeat(divider*3) @(negedge clk); mounted=0;
        finish_scan();
    endtask
    task mount(input integer n=0, input integer start_header=1016,
               input [7:0] mark=0, input [7:0] status=8'hb0,
               input bit duplicate=0, input bit image_wp=0);
        pause_write=0; pause_metadata_read=0; service=1; hold_ack=0; protected_media=0; ready=1;
        length=128<<n; header=start_header; target=duplicate ? 2 : 0;
        size=24'(header+count*(16+length));
        for(int i=0;i<8192;i++) image[i]=8'(i*13+7);
        for(int i=0;i<688;i++) image[i]=0;
        image[26]=image_wp ? 8'h10 : 0;
        for(int i=0;i<4;i++) begin
            image[28+i]=8'(size>>(8*i)); image[32+i]=8'(header>>(8*i));
        end
        for(int j=0;j<count;j++) begin
            int h;
            h=header+j*(16+length);
            for(int i=0;i<16;i++) image[h+i]=8'(8'h80+i);
            image[h]=0; image[h+1]=5; // Exercise existing H-LSB comparison.
            image[h+2]=(duplicate && j==2) ? 1 : 8'(j+1);
            image[h+3]=8'(n); image[h+4]=8'(count); image[h+5]=0;
            image[h+6]=0; image[h+7]=mark;
            image[h+8]=(duplicate && j==0) ? 8'ha0 : status;
            image[h+14]=8'(length); image[h+15]=8'(length>>8);
            for(int i=0;i<length;i++) image[h+16+i]=8'(i+j*31);
        end
        remount();
        for(int i=0;i<8192;i++) begin original[i]=image[i]; expected[i]=image[i]; end
    endtask
    task start(input [7:0] command, input [7:0] sector=1);
        send(2,sector); send(0,command);
    endtask
    task compare_media;
        for(int i=0;i<8192;i++) assert(image[i]==expected[i])
            else $fatal(1,"media mismatch offset=%0d got=%02x expected=%02x",i,image[i],expected[i]);
    endtask
    task status_check(input [7:0] status);
        address=0; #1;
        assert(dout==status && !busy && !drq && irq)
            else $fatal(1,"status got=%02x expected=%02x pins=%b%b%b",dout,status,busy,drq,irq);
        rd=1; repeat(divider*3) @(negedge clk);
        rd=0; repeat(divider*3) @(negedge clk);
    endtask
    task write_payload(input integer sectors=1, input integer skip=-1,
                       input bit watchdog_race=0);
        for(int i=0;i<length*sectors;i++) begin
            int h;
            h=header+(target+i/length)*(16+length);
            wait(drq || !busy); assert(drq) else $fatal(1,"write truncated byte=%0d",i);
            if(i==skip) begin
                wait(!drq); expected[h+16+i%length]=0;
            end else if(watchdog_race && i==1) begin
                // Accept CPU data just before expiry, hold WR past expiry.
                wait(dut.wd_timer<=2);
                @(negedge clk); address=3; data=8'(i)^8'ha5; wr=1;
                repeat(divider*8) @(negedge clk);
                assert(drq && dut.write_byte_seen) else $fatal(1,"watchdog replaced accepted CPU byte");
                wr=0; repeat(divider*3) @(negedge clk);
                expected[h+16+i%length]=8'(i)^8'ha5;
            end else begin
                send(3,8'(i)^8'ha5); expected[h+16+i%length]=8'(i)^8'ha5;
            end
        end
    endtask
    task expect_metadata(input integer entry, input bit deleted);
        int h;
        h=header+entry*(16+length);
        expected[h+7]=deleted ? 8'h10 : 0;
        if(expected[h+8]==8'hb0) expected[h+8]=0;
    endtask
    task readback(input integer entry, input [7:0] status);
        reg [7:0] value;
        int h;
        h=header+entry*(16+length);
        start(8'h8a,8'(entry+1));
        for(int i=0;i<length;i++) begin
            wait(drq || !busy); assert(drq) else $fatal(1,"readback truncated");
            read_byte(value);
            assert(value==expected[h+16+i]) else $fatal(1,"readback mismatch byte=%0d",i);
        end
        wait(!busy); status_check(status);
    endtask
    task normal_case(input integer n, input integer at, input bit deleted,
                     input [7:0] initial_mark, input [7:0] initial_status=8'hb0);
        mount(n,at,initial_mark,initial_status);
        start(deleted ? 8'hab : 8'haa);
        write_payload(); expect_metadata(0,deleted);
        wait(!busy); status_check(0); compare_media();
        readback(0,deleted ? 8'h20 : 0);
        remount(); readback(0,deleted ? 8'h20 : 0); compare_media(); groups++;
    endtask
    task cancel_command(input integer kind);
        if(kind==0) send(0,8'hd0);
        else if(kind==1 || kind==3) begin
            reset=1; repeat(divider*4) @(negedge clk);
            if(kind==3) reset=0; // Pulse ends BEFORE the owned ACK drains.
        end
        else begin mounted=1; ready=0; repeat(divider*4) @(negedge clk); mounted=0; end
    endtask
    task recover(input integer kind);
        wait(!dut.transport_active);
        repeat(divider*6) @(negedge clk);
        assert(!drq && !irq) else $fatal(1,"cancel completion raised pins");
        reset=0; ready=1;
        if(kind==2) finish_scan();
        else begin
            for(int edge_count=0;edge_count<1000*divider && !(idle && !busy);edge_count++) @(negedge clk);
            assert(idle && !busy) else $fatal(1,"cancel did not release metadata ownership kind=%0d",kind);
            repeat(divider*4) @(negedge clk);
        end
    endtask
    // Abort/reset/eject an already published payload/metadata request, before
    // ACK or while ACK-high. The host retains old-media bytes through drain.
    task abort_case(input integer stage, input integer kind, input bit high_ack,
                    input integer at=1016);
        integer base, blocks, ordinal, h;
        mount(2,at,0,8'hb0);
        base=writes; h=header;
        blocks=((h+16)%512+length+511)/512;
        ordinal=base+blocks+stage;
        pause_write=ordinal;
        start(8'hab); write_payload();
        wait(sd_wr && !service); @(negedge clk);
        // Before any metadata publication, CRC and deleted field stay old.
        assert(image[h+7]==(stage==2 ? 8'h10 : 0) && image[h+8]==8'hb0)
            else $fatal(1,"early metadata publication");
        if(stage!=0) begin
            for(int i=0;i<length;i++) assert(image[h+16+i]==expected[h+16+i])
                else $fatal(1,"metadata precedes payload commit");
        end
        if(high_ack) begin hold_ack=1; service=1; wait(ack); repeat(20) @(negedge clk); end
        cancel_command(kind);
        // Publication freezes buffer/owner even while reset stops CE.
        pause_write=0; service=1; hold_ack=0;
        if(stage!=0) expected[h+7]=8'h10;
        if(stage==2 || (stage==1 && (h+7)/512==(h+8)/512)) expected[h+8]=0;
        recover(kind);
        assert(image[h+8]==expected[h+8]) else $fatal(1,"wrong CRC commit on cancel");
        // The payload's final already-published block may commit after cancel.
        compare_media();
        if(kind!=2) readback(0,(stage!=0 ? 8'h20 : 0) | (expected[h+8]==8'hb0 ? 8'h08 : 0));
        remount(); readback(0,(stage!=0 ? 8'h20 : 0) | (expected[h+8]==8'hb0 ? 8'h08 : 0)); groups++;
    endtask
    task abort_header_read(input integer kind, input bit second, input bit high_ack);
        mount(); pause_metadata_read=1; pause_second_read=second;
        start(8'hab); write_payload();
        wait(sd_rd && !service); @(negedge clk);
        assert(image[header+7]==(second ? 8'h10 : 0) && image[header+8]==8'hb0) else $fatal;
        if(high_ack) begin hold_ack=1; service=1; wait(ack); repeat(20) @(negedge clk); end
        cancel_command(kind);
        pause_metadata_read=0; service=1; hold_ack=0;
        if(second) expected[header+7]=8'h10;
        recover(kind); compare_media();
        if(kind!=2) readback(0,(second ? 8'h20 : 0)|8'h08);
        remount(); readback(0,(second ? 8'h20 : 0)|8'h08); groups++;
    endtask
    initial begin
        if($value$plusargs("divider=%d",divider)) begin end
        assert(divider==1 || divider==8) else $fatal(1,"bad divider");
        repeat(3) @(negedge clk); reset=0;
        // A D88 sector container cannot represent raw track tokens/gaps.
        // Unsupported track commands must not masquerade as sector transfers
        // or pretend a no-op format completed successfully.
        for(int command=0;command<2;command++) begin
            int base;
            mount(); base=writes;
            start(command==0 ? 8'he0 : 8'hf0);
            while(busy) begin
                @(negedge clk);
                assert(!drq) else $fatal(1,"unsupported track command offered sector data");
            end
            status_check(command==0 ? 8'h10 : 8'h20);
            assert(writes==base) else $fatal(1,"unsupported format changed host media");
            compare_media(); groups++;
        end
        for(int n=0;n<4;n++) begin
            normal_case(n,1008,0,8'h10); // Header in previous payload block.
            normal_case(n,1016,1,0); // Byte 7/8 straddle host blocks.
            normal_case(n,1031,1,8'h01); // Unaligned payload, noncanonical mark.
        end
        normal_case(0,1008,0,8'h10,8'h10); // Preserve byte-8 non-B0 status.
        // Correct duplicate is the only writable record; bad-ID neighbors stay exact.
        mount(1,1016,0,8'hb0,1); start(8'hab); write_payload(); expect_metadata(2,1);
        wait(!busy); status_check(8'h08); compare_media();
        start(8'h8a);
        for(int i=0;i<length;i++) begin
            reg [7:0] value;
            wait(drq); read_byte(value); assert(value==expected[header+2*(16+length)+16+i]) else $fatal;
        end
        wait(!busy); status_check(8'h28); groups++;
        // Protected host and protected container never request CPU data/write.
        for(int p=0;p<2;p++) begin
            int base;
            mount(0,1016,0,8'hb0,0,p==1); protected_media=(p==0); base=writes;
            // Machine combines fmt_wp with host policy; do so explicitly here.
            protected_media=protected_media || dut.fmt_wp;
            start(8'hab);
            while(busy) begin @(negedge clk); assert(!drq) else $fatal; end
            address=0; #1; assert((dout&8'h40)!=0 && writes==base) else $fatal;
            compare_media(); groups++;
        end
        // All matching IDs damaged: no payload DRQ or writes.
        mount(0,1016,0,8'ha0);
        begin int base; base=writes; start(8'hab);
            while(busy) begin @(negedge clk); assert(!drq) else $fatal; end
            status_check(8'h18); assert(writes==base) else $fatal; compare_media(); groups++;
        end
        // Multi-sector commits each selected record before searching the next.
        mount(0,1016,0,8'hb0); start(8'hbb); write_payload(3);
        for(int j=0;j<3;j++) expect_metadata(j,1);
        wait(!busy); status_check(8'h10); compare_media();
        for(int j=0;j<3;j++) readback(j,8'h20);
        remount(); for(int j=0;j<3;j++) readback(j,8'h20); groups++;
        // Initial timeout must leave the entire image and metadata untouched.
        mount(); begin int base; base=writes; start(8'hab); wait(drq); wait(!busy);
            status_check(8'h04); assert(writes==base) else $fatal; compare_media(); groups++;
        end
        mount(); start(8'hab); write_payload(1,17); expect_metadata(0,1);
        wait(!busy); status_check(8'h04); compare_media(); readback(0,8'h20);
        remount(); readback(0,8'h20); groups++;
        mount(); start(8'hab); write_payload(1,-1,1); expect_metadata(0,1);
        wait(!busy); status_check(0); compare_media(); groups++;
        // Interrupted CPU collection never flushes the partial buffered sector.
        for(int kind=0;kind<4;kind++) begin
            int base;
            mount(); base=writes; start(8'hab); wait(drq); send(3,8'h55); wait(drq);
            cancel_command(kind); service=1; recover(kind);
            assert(writes==base) else $fatal(1,"interrupted CPU collection flushed");
            compare_media(); groups++;
        end
        for(int stage=0;stage<3;stage++)
            for(int kind=0;kind<4;kind++)
                for(int high=0;high<2;high++) abort_case(stage,kind,1'(high));
        for(int kind=0;kind<4;kind++)
            for(int high=0;high<2;high++) begin
                abort_case(1,kind,1'(high),1008); // Both fields share one commit.
                abort_header_read(kind,0,1'(high));
                abort_header_read(kind,1,1'(high));
            end
        $display("PASS: D88 payload-before-metadata, per-block index commit, sizes/unaligned/split header, deleted/CRC, protection, duplicates, multi, lost-data/race and abort/reset/eject groups=%0d divider=%0d",groups,divider);
        $finish;
    end
    initial begin #1000000000; $fatal(1,"metadata timeout state=%0d groups=%0d",dut.state,groups); end
endmodule
