`timescale 1ns/1ps
// Original generated-media, register/SD-path CRC fixture. No firmware/game data.
module d88_crc_tb;
    reg clk=0, reset=1, mounted=0, ack=0, host_wr=0, wr=0, rd=0;
    reg [1:0] address=0;
    reg [7:0] data=0, host_data=0;
    reg [8:0] host_address=0;
    reg [7:0] image[1120];
    wire [7:0] dout;
    wire [31:0] lba;
    wire prepare, sd_rd, sd_wr, busy, drq, irq;
    integer divider=8, phase=0, requests=0;
    reg [23:0] size=1120;
    wire ce=!reset && phase==0;
    always #5 clk=!clk;
    always @(negedge clk) phase=(phase+1)%divider;
    wd1793 #(.RWMODE(1), .EDSK(1), .D88_ONLY(1)) dut(
        .drive_select(1'b0), .drive_connected(1'b1), .transport_idle(),
        .clk_sys(clk), .ce(ce), .reset(reset), .io_en(1'b1),
        .rd(rd), .wr(wr), .addr(address), .din(data), .dout(dout),
        .drq(drq), .intrq(irq), .busy(busy), .wp(1'b0), .fmt_wp(),
        .size_code(3'd1), .layout(1'b0), .side(1'b0), .ready(1'b1), .fm_mode(1'b0),
        .img_mounted(mounted), .img_size(size[19:0]), .img_size_id(size),
        .disk_index(3'd0), .prepare(prepare), .sd_lba(lba), .sd_rd(sd_rd), .sd_wr(sd_wr),
        .sd_ack(ack), .sd_buff_addr(host_address), .sd_buff_dout(host_data),
        .sd_buff_din(), .sd_buff_wr(host_wr), .input_active(1'b0),
        .input_addr(20'd0), .input_data(8'd0), .input_wr(1'b0),
        .buff_addr(), .buff_read(), .buff_din(8'd0));
    initial forever begin
        wait(sd_rd);
        @(negedge clk); ack=1; requests++;
        for(int i=0;i<512;i++) begin
            host_address=9'(i);
            host_data=(lba*512+32'(i)<1120) ? image[lba*512+32'(i)] : 0;
            host_wr=1; @(negedge clk);
        end
        host_wr=0;
        repeat(10) @(negedge clk); ack=0;
        repeat(10) @(negedge clk);
    end
    always @(negedge clk) assert(!sd_wr) else $fatal(1,"unexpected host write");
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
    task check_status(input [7:0] value);
        @(negedge clk); address=0; #1;
        assert(dout==value) else $fatal(1,"status got=%02x expected=%02x",dout,value);
        assert(irq && !busy && !drq) else $fatal(1,"completion pins");
        rd=1; repeat(divider*3) @(negedge clk);
        rd=0; repeat(divider*3) @(negedge clk);
        assert(!irq) else $fatal(1,"status read failed to acknowledge");
    endtask
    task mount(input [7:0] error, input bit duplicate, input integer count=3,
               input integer error_at=0);
        for(int i=0;i<1120;i++) image[i]=0;
        size=24'(688+count*144);
        for(int i=0;i<4;i++) image[28+i]=8'(size>>(8*i));
        image[32]=8'hb0; image[33]=2; // first track at 688.
        for(int j=0;j<count;j++) begin
            image[688+j*144+2]=(duplicate && j==2) ? 1 : 8'(j+1);
            image[688+j*144+4]=8'(count);
            image[688+j*144+8]=(j==error_at) ? error : 0;
            image[688+j*144+14]=128;
            for(int i=0;i<128;i++) image[704+j*144+i]=8'(i+j*31);
        end
        @(negedge clk); mounted=1;
        repeat(divider*3) @(negedge clk); mounted=0;
        repeat(divider*3) @(negedge clk);
        wait(!prepare && !dut.mount_pending && !dut.transport_active);
        repeat(divider*3) @(negedge clk);
        assert(dut.media_ready && int'(dut.edsk_size)==count) else $fatal(1,"mount failed");
    endtask
    task start(input [7:0] cmd, input [7:0] sector);
        send(2,sector); send(0,cmd);
    endtask
    task no_data(input [7:0] cmd, input [7:0] sector=1);
        integer before_requests;
        before_requests=requests;
        start(cmd,sector);
        while(busy) begin
            @(negedge clk);
            assert(!drq) else $fatal(1,"bad ID exposed payload DRQ cmd=%02x",cmd);
        end
        assert(requests==before_requests) else $fatal(1,"bad ID fetched payload");
        check_status(8'h18); // bad ID CRC + record not found; no lost-data.
    endtask
    task payload(input integer count, input integer first_pattern);
        reg [7:0] value;
        for(int i=0;i<count;i++) begin
            wait(drq || !busy);
            assert(drq) else $fatal(1,"missing DRQ byte=%0d",i);
            read_byte(value);
            assert(value==8'(i%128+(first_pattern+i/128)*31))
                else $fatal(1,"payload byte=%0d got=%02x",i,value);
        end
        wait(!busy);
    endtask
    task address_record(input bit bad, input bit skip_first=0);
        reg [7:0] value;
        reg [15:0] crc, received_crc;
        start(8'hc0,1);
        crc=16'hb230; received_crc=0;
        for(int i=0;i<6;i++) begin
            wait(drq || !busy); assert(drq) else $fatal(1,"READ ADDRESS truncated");
            assert(!dut.s_crcerr) else $fatal(1,"READ ADDRESS CRC reported before completion");
            if(i==0 && skip_first) begin
                // Deliberately miss byte C. It must still be copied into SCR
                // when presented, and later bytes must not repair/erase it.
                assert(dut.wdreg_sector==0) else $fatal(1,"C absent before first DRQ consumption");
                wait(!drq); value=0;
            end else read_byte(value);
            if(i<4) begin
                assert(value==((i==2) ? 8'd1 : 8'd0)) else $fatal(1,"CHRN mismatch");
                crc=crc^{value,8'd0};
                for(int b=0;b<8;b++) crc=crc[15] ? (crc<<1)^16'h1021 : crc<<1;
            end else received_crc={received_crc[7:0],value};
        end
        wait(!busy);
        assert(dut.wdreg_sector==0) else $fatal(1,"READ ADDRESS did not copy C to sector register");
        assert(received_crc==(crc^(bad ? 16'hffff : 16'h0000))) else $fatal(1,"ID CRC convention");
        check_status((bad ? 8'h08 : 8'h00) | (skip_first ? 8'h04 : 8'h00));
    endtask
    initial begin
        if($value$plusargs("divider=%d",divider)) begin end
        assert(divider==1 || divider==8) else $fatal(1,"unsupported divider");
        repeat(3) @(negedge clk); reset=0;
        mount(8'ha0,0);
        no_data(8'h80); // Read and write must both locate a usable ID.
        no_data(8'ha0);
        // Last failed search ends at entry 2; READ ADDRESS rotates to entry 0.
        address_record(1);
        mount(8'ha0,0); no_data(8'h80); address_record(1,1);
        mount(8'hb0,0); start(8'h80,17); wait(!busy); check_status(8'h10);
        address_record(0); // data CRC must not poison READ ADDRESS.
        // Data CRC does not poison the address field or suppress payload.
        mount(8'hb0,0); start(8'h80,1); wait(drq);
        assert(!dut.s_crcerr) else $fatal(1,"data CRC reported before completion");
        payload(128,0); check_status(8'h08);
        start(8'h80,2); payload(128,1); check_status(8'h00);
        // Matching duplicate ID after a corrupt one remains accessible.
        mount(8'ha0,1); start(8'h80,1); payload(128,2); check_status(8'h08);
        mount(8'ha0,1,3,2); start(8'h80,1); payload(128,0); check_status(8'h00);
        // Nonmatching bad ID does not attribute its CRC to a good read.
        mount(8'ha0,0); start(8'h80,2); payload(128,1); check_status(8'h00);
        mount(8'ha0,0,1); no_data(8'h80);
        mount(8'ha0,0,3,2); no_data(8'h80,3);
        // Multi-sector stops at an unusable ID, without exposing that or
        // subsequent payload; the earlier good sector remains exact.
        mount(8'ha0,0,3,1); start(8'h90,1); payload(128,0); check_status(8'h18);
        // Multi-sector continues after data CRC, ends with missing R=4 and
        // sticky CRC; no lost-data and no extra byte or host write.
        mount(8'hb0,0,3,1); start(8'h90,1); payload(384,0); check_status(8'h18);
        send(0,8'h00); wait(!busy); // Clear actual CRC+RNF, not already-clean status.
        assert(!dut.s_crcerr && !dut.s_seekerr) else $fatal(1,"stale CRC/RNF");
        // Abort/reset pending CRC must not leak into the next good read.
        mount(8'hb0,0); start(8'h80,1); wait(drq); send(0,8'hd0); wait(!busy);
        assert(!dut.s_crcerr && !dut.pending_read_crc && !irq && !drq) else $fatal(1,"abort leaked CRC/pins");
        start(8'h80,2); payload(128,1); check_status(8'h00);
        start(8'h80,1); wait(drq);
        @(negedge clk); reset=1; repeat(divider*3) @(negedge clk); reset=0;
        repeat(divider*3) @(negedge clk);
        assert(!dut.s_crcerr && !dut.pending_read_crc && !irq && !drq) else $fatal(1,"reset leaked CRC/pins");
        start(8'h80,2); payload(128,1); check_status(8'h00);
        $display("PASS: D88 ID/data CRC, duplicate ID, READ ADDRESS, multi-sector and recovery divider=%0d",divider);
        $finish;
    end
    initial begin #100000000; $fatal(1,"D88 CRC fixture timeout state=%0d",dut.state); end
endmodule
