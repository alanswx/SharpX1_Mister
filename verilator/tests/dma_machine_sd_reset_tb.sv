// SPDX-License-Identifier: GPL-2.0-or-later
// Original CPU program and generated D88, through real loader/SD interfaces.
// No private assets, forced ownership, register edits or injected Ready.
`timescale 1ps/1ps
module dma_machine_sd_reset_tb;
    reg clk_sys=0, clk_video=0, reset=1, mounted=0;
    always #15625 clk_sys=~clk_sys;
    always #17500 clk_video=~clk_video;
    reg download=0, load_write=0;
    reg [24:0] load_address=0;
    reg [7:0] load_data=0;
    reg ack=0, host_wr=0;
    reg [8:0] host_address=0;
    reg [7:0] host_data=0;
    wire host_drive, sd_rd, sd_wr;
    wire [31:0] lba;
    wire [7:0] host_read;
    reg [7:0] rom[0:8191], image_a[0:1023], image_b[0:1023];
    reg [7:0] original_a[0:1023], original_b[0:1023];
    integer size=0, writing_arg=0, phase_arg=0, drive_arg=0, poll_at;
    bit writing=0, phase=0, drive_b=0;
    reg captured=0, release_host=0, drained=0;
    reg [31:0] saved_lba;
    reg saved_drive, saved_write;
    integer reads_before, writes_before;
    top #(.TURBO(1), .TURBO_DMA(1)) dut (
        .clk_sys(clk_sys), .clk_28636(clk_video), .reset(reset),
        .ioctl_download(download), .ioctl_index(8'd0), .ioctl_wr(load_write),
        .ioctl_addr(load_address), .ioctl_dout(load_data), .ioctl_wait(),
        .ps2_clk_in(1'b1), .ps2_data_in(1'b1), .joya_n(8'hff), .joyb_n(8'hff),
        .disk_ready(1'b1), .img_mounted(mounted), .disk_wp(1'b0), .img_size(24'd960),
        .disk_ready_b(1'b1), .img_mounted_b(mounted), .disk_wp_b(1'b0), .img_size_b(24'd960),
        .sd_drive(host_drive), .sd_lba(lba), .sd_rd(sd_rd), .sd_wr(sd_wr),
        .sd_ack(ack), .sd_buff_addr(host_address), .sd_buff_dout(host_data),
        .sd_buff_din(host_read), .sd_buff_wr(host_wr), .debug_addr(16'hf100),
        .debug_disk_control(), .debug_disk_motor(), .debug_disk_ready(),
        .debug_ram(), .debug_text(), .debug_attr(), .sub_pc(), .sub_address(),
        .sub_control(), .sub_wait(), .sub_tx(), .sub_rx(), .cpu_address(),
        .cpu_in(), .cpu_out(), .cpu_mreq_n(), .cpu_iorq_n(), .cpu_rd_n(),
        .cpu_wr_n(), .cpu_halt_n(), .video(), .rgb(), .audio(), .ce_pix(),
        .HSync(), .VSync(), .HBlank(), .VBlank(), .sys_edges(), .video_edges(),
        .reset_edges(), .cpu_enables(), .delayed_sys_edges(), .dma_grants(),
        .dma_reads(), .dma_writes(), .cpu_fdc_data_reads(), .cpu_fdc_data_writes()
    );
    task automatic emit(input reg [7:0] value);
        rom[size]=value; size++;
    endtask
    task automatic out_port(input reg [15:0] port, input reg [7:0] value);
        emit(8'h01); emit(port[7:0]); emit(port[15:8]);
        emit(8'h3e); emit(value); emit(8'hed); emit(8'h79);
    endtask
    task automatic dma_byte(input reg [7:0] value);
        out_port(16'h1f80,value);
    endtask
    task automatic store(input reg [15:0] address, input reg [7:0] value);
        emit(8'h3e); emit(value); emit(8'h32); emit(address[7:0]); emit(address[15:8]);
    endtask
    task automatic poll_fdc(input reg [7:0] mask);
        emit(8'h01); emit(8'hf8); emit(8'h0f);
        poll_at=size;
        emit(8'hed); emit(8'h78); emit(8'he6); emit(mask);
        emit(8'hc2); emit(8'(poll_at)); emit(8'(poll_at>>8));
    endtask
    task automatic check_port(input reg [15:0] port, input reg [7:0] mask,
                              input reg [7:0] expected);
        emit(8'h01); emit(port[7:0]); emit(port[15:8]);
        emit(8'hed); emit(8'h78); emit(8'he6); emit(mask); emit(8'hfe); emit(expected);
        emit(8'h28); emit(6); store(16'hf101,8'hee); emit(8'h76);
    endtask
    task automatic verify_media;
        reg [7:0] expected_a, expected_b;
        for(integer i=0;i<1024;i++) begin
            expected_a=original_a[i]; expected_b=original_b[i];
            if(writing && i>=704 && i<960) begin
                if(drive_b) expected_b=expected_b^8'h5c;
                else expected_a=expected_a^8'h5c;
            end
            assert(image_a[i]==expected_a && image_b[i]==expected_b)
                else $fatal(1,"whole-image mismatch byte=%0d A=%h/%h B=%h/%h",
                    i,image_a[i],expected_a,image_b[i],expected_b);
        end
    endtask
    function automatic [7:0] payload(input integer i);
        return 8'((drive_b ? 32'h93 : 32'h21)+i*7);
    endfunction

    // Independent host. Reset freezes CPU/FDC enables, not the SD ACK clock.
    initial forever begin : host
        reg this_capture, request_write, request_drive;
        integer request_lba;
        wait(sd_rd || sd_wr);
        @(negedge clk_sys);
        request_write=sd_wr; request_drive=host_drive; request_lba=int'(lba);
        assert(request_lba<=1) else $fatal(1,"out-of-image LBA");
        this_capture=!captured && !dut.machine.fdc.prepare &&
            dut.machine.fdc.s_busy && (request_write==1'(writing));
        if(this_capture) begin
            saved_lba=lba; saved_drive=host_drive; saved_write=request_write;
            if(phase==0) begin captured=1; wait(release_host); end
        end
        ack=1;
        for(integer i=0;i<512;i++) begin
            host_address=9'(i);
            host_data=request_drive ? image_b[request_lba*512+i] : image_a[request_lba*512+i];
            host_wr=!request_write;
            // RAM host read port is synchronous; do not sample on address change.
            @(negedge clk_sys);
            if(request_write) begin
                if(request_drive) image_b[request_lba*512+i]=host_read;
                else image_a[request_lba*512+i]=host_read;
            end
            if(this_capture && phase==1 && i==127) begin
                captured=1; wait(release_host);
            end
        end
        host_wr=0;
        repeat(12) @(negedge clk_sys);
        assert(!sd_rd && !sd_wr) else $fatal(1,"ACK did not release request");
        ack=0;
        repeat(16) @(negedge clk_sys);
        if(this_capture) drained=1;
    end

    initial begin
        if(!$value$plusargs("WRITING=%d",writing_arg)) writing_arg=0;
        if(!$value$plusargs("PHASE=%d",phase_arg)) phase_arg=0;
        if(!$value$plusargs("DRIVE_B=%d",drive_arg)) drive_arg=0;
        assert((writing_arg==0 || writing_arg==1) && (phase_arg==0 || phase_arg==1) &&
               (drive_arg==0 || drive_arg==1)) else $fatal(1,"invalid profile");
        writing=1'(writing_arg); phase=1'(phase_arg); drive_b=1'(drive_arg);
        for(integer i=0;i<1024;i++) begin image_a[i]=0; image_b[i]=0; end
        // 688-byte D88 header, one 16-byte sector header, 256-byte payload.
        image_a[28]=8'hc0; image_a[29]=3; image_a[32]=8'hb0; image_a[33]=2;
        image_a[690]=1; image_a[691]=1; image_a[692]=1; image_a[703]=1;
        for(integer i=0;i<704;i++) image_b[i]=image_a[i];
        for(integer i=0;i<256;i++) begin
            image_a[704+i]=8'(32'h21+i*7); image_b[704+i]=8'(32'h93+i*7);
        end
        for(integer i=0;i<1024;i++) begin original_a[i]=image_a[i]; original_b[i]=image_b[i]; end
        emit(8'hf3); emit(8'h31); emit(8'hff); emit(8'hff);
        emit(8'h21); emit(0); emit(8'hf1); emit(8'h34); // INC retained entry count
        store(16'hf101,0);
        for(integer i=0;i<256;i++) store(16'h9000+16'(i),payload(i)^8'h5c);
        // Real CPU mount delay, identical on cold and warm entry.
        emit(8'h11); emit(8'h80); emit(8'h3e); poll_at=size;
        emit(8'h1b); emit(8'h7a); emit(8'hb3); emit(8'hc2);
        emit(8'(poll_at)); emit(8'(poll_at>>8));
        out_port(16'h0ffc,8'h80|8'(drive_b)); poll_fdc(8'h80);
        dma_byte(8'hc3); dma_byte(writing ? 8'h79 : 8'h7d);
        dma_byte(writing ? 0 : 8'hfb); dma_byte(writing ? 8'h90 : 8'h0f);
        dma_byte(8'hff); dma_byte(0);
        dma_byte(writing ? 8'h14 : 8'h2c); dma_byte(writing ? 8'h28 : 8'h10);
        dma_byte(8'h8d); dma_byte(writing ? 8'hfb : 0); dma_byte(writing ? 8'h0f : 8'h91);
        dma_byte(8'h92); dma_byte(8'hcf);
        if(writing) begin dma_byte(8'h05); dma_byte(8'hcf); end
        out_port(16'h0ffa,1); out_port(16'h0ff8,writing ? 8'ha0 : 8'h80);
        dma_byte(8'h87); poll_fdc(1);
        check_port(16'h0ff8,8'h9c,0); check_port(16'h1f80,8'h20,0);
        dma_byte(8'hbb); dma_byte(8'h7e); dma_byte(8'ha7);
        check_port(16'h1f80,8'hff,8'hff); check_port(16'h1f80,8'hff,0);
        check_port(16'h1f80,8'hff,writing ? 0 : 8'hfb);
        check_port(16'h1f80,8'hff,writing ? 8'h91 : 8'h0f);
        check_port(16'h1f80,8'hff,writing ? 8'hfb : 8'hff);
        check_port(16'h1f80,8'hff,writing ? 8'h0f : 8'h91);
        // Native read validation. Failure halts with EE, never patched away.
        if(!writing) for(integer i=0;i<256;i++) begin
            emit(8'h3a); emit(8'(i)); emit(8'h91); emit(8'hfe); emit(payload(i));
            emit(8'h28); emit(6);
            store(16'hf101,8'hee); emit(8'h76);
        end
        store(16'hf101,8'ha5); emit(8'h76);
        assert(size<8192) else $fatal(1,"diagnostic exceeds Turbo ROM aperture");
        repeat(8) @(negedge clk_sys); download=1; load_write=1;
        for(integer i=0;i<size;i++) begin
            load_address=25'(i); load_data=rom[i]; @(negedge clk_sys);
        end
        download=0; load_write=0; mounted=1;
        repeat(8) @(negedge clk_sys); mounted=0; reset=0;
        wait(captured);
        @(negedge clk_sys); reset=1; #2000;
        reads_before=int'(dut.dma_reads); writes_before=int'(dut.dma_writes);
        assert(!dut.machine.dma_owner && dut.machine.core_reset)
            else $fatal(1,"unexpected owned bus at SD wait");
        repeat(80) begin
            @(negedge clk_sys);
            assert(!dut.machine.cpu_ce && !dut.machine.fdc.ce &&
                   lba==saved_lba && host_drive==saved_drive &&
                   (phase==0 ? (saved_write ? sd_wr : sd_rd) : ack))
                else $fatal(1,"pending SD/reset instability");
            assert(dut.dma_reads==64'(reads_before) && dut.dma_writes==64'(writes_before))
                else $fatal(1,"DMA progressed through held reset");
        end
        release_host=1; wait(drained);
        repeat(80) @(negedge clk_sys);
        assert(!dut.machine.fdc.transport_active && !sd_rd && !sd_wr &&
               !dut.machine.cpu_ce && !dut.machine.fdc.ce)
            else $fatal(1,"SD transport failed to drain with enables stopped");
        assert(reads_before==(writing ? 256 : 0) && writes_before==reads_before)
            else $fatal(1,"unexpected pre-reset pair count");
        // A published write may commit during reset. Check it before reboot
        // so a later identical write cannot conceal a corrupted old buffer.
        verify_media();
        reset=0;
        wait(!dut.machine.halt_n);
        assert(dut.machine.RAM.mem[16'hf100]==2 && dut.machine.RAM.mem[16'hf101]==8'ha5 &&
               dut.dma_reads==64'(reads_before+256) && dut.dma_writes==64'(writes_before+256) &&
               dut.dma_grants==64'(reads_before+256) &&
               dut.cpu_fdc_data_reads==0 && dut.cpu_fdc_data_writes==0)
            else $fatal(1,"native reboot/count/payload failure entry=%h result=%h pairs=%0d/%0d",
                dut.machine.RAM.mem[16'hf100],dut.machine.RAM.mem[16'hf101],dut.dma_reads,dut.dma_writes);
        verify_media();
        $display("PASS: shared-machine DMA SD reset drive=%0d write=%0d phase=%0d, stopped-CE ACK drain, retained native reboot, exact 256 fresh pairs",drive_b,writing,phase);
        $finish;
    end
    initial begin #1000000000000; $fatal(1,"whole-machine SD reset watchdog"); end
endmodule
