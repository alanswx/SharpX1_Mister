`timescale 1ns/1ps
// Original direct-host fixture: deliberately bypasses C++ media preflight.
module d88_scanner_tb;
    reg clk=0, reset=1, mounted=0, ack=0, host_wr=0, service=1;
    reg [23:0] size=976;
    reg [8:0] host_addr=0;
    reg [7:0] host_data=0;
    reg [7:0] image[400000];
    wire prepare, sd_rd, sd_wr;
    wire [31:0] lba;
    reg [1:0] addr=0;
    reg [7:0] din=0;
    reg wr=0;
    wire [7:0] status;
    always #5 clk=!clk;
    wd1793 #(.RWMODE(1), .EDSK(1), .D88_ONLY(1)) dut(
        .drive_select(1'b0), .drive_connected(1'b1), .transport_idle(),
        .clk_sys(clk), .ce(!reset), .reset(reset), .io_en(1'b1),
        .rd(1'b0), .wr(wr), .addr(addr), .din(din), .dout(status),
        .drq(), .intrq(), .busy(), .wp(1'b1), .fmt_wp(),
        .size_code(3'd1), .layout(1'b0), .side(1'b0), .ready(1'b1), .fm_mode(1'b0),
        .img_mounted(mounted), .img_size(size[19:0]), .img_size_id(size),
        .disk_index(3'd0), .prepare(prepare), .sd_lba(lba), .sd_rd(sd_rd), .sd_wr(sd_wr),
        .sd_ack(ack), .sd_buff_addr(host_addr), .sd_buff_dout(host_data),
        .sd_buff_din(), .sd_buff_wr(host_wr), .input_active(1'b0),
        .input_addr(20'd0), .input_data(8'd0), .input_wr(1'b0),
        .buff_addr(), .buff_read(), .buff_din(8'd0));
    // One request at a time; host completes even if CE is stopped by reset.
    initial forever begin
        wait(sd_rd && service);
        @(negedge clk); ack=1;
        for(int i=0; i<512; i++) begin
            host_addr=9'(i);
            host_data=(lba*512+32'(i)<400000) ? image[lba*512+32'(i)] : 0;
            host_wr=1;
            @(negedge clk);
        end
        host_wr=0;
        repeat(10) @(negedge clk);
        ack=0;
        repeat(10) @(negedge clk);
    end
    reg last_request=0;
    always @(negedge clk) begin
        assert(!sd_wr) else $fatal(1,"scanner wrote media");
        // Size changes at eject can coincide with sampling the previous
        // request. Pending-eject assertions below check it is only drained.
        if(sd_rd && !last_request && size != 0 && !mounted && !dut.mount_pending)
            assert(lba*512<size) else $fatal(1,"out-of-image read lba=%d size=%d addr=%d pending=%b",lba,size,dut.scan_addr,dut.mount_pending);
        last_request=sd_rd;
    end
    task le32(input int at, input int value);
        for(int i=0;i<4;i++) image[at+i]=8'(value>>(8*i));
    endtask
    task valid_image;
        for(int i=0;i<400000;i++) image[i]=0;
        size=976;
        le32(28,976); le32(32,688);
        for(int j=0;j<2;j++) begin
            image[688+j*144+2]=8'(j+1);
            image[688+j*144+4]=2;
            image[688+j*144+14]=128;
            for(int i=0;i<128;i++) image[704+j*144+i]=8'(i+j);
        end
    endtask
    task mount_image;
        @(negedge clk); mounted=1;
        repeat(3) @(negedge clk); mounted=0;
    endtask
    task send(input [1:0] port, input [7:0] value);
        @(negedge clk); addr=port; din=value; wr=1;
        @(negedge clk); wr=0;
    endtask
    task finish_scan(input bit good, input string label_text);
        repeat(20) @(negedge clk);
        wait(!prepare && !dut.mount_pending && !dut.transport_active);
        repeat(10) @(negedge clk);
        assert(dut.media_ready==good) else $fatal(1,"%s valid=%b bad=%b end=%d addr=%d",label_text,dut.d88_valid,dut.d88_bad,dut.d88_end,dut.scan_addr);
        assert(status[7]==!good) else $fatal(1,"%s not-ready status",label_text);
        $display("PASS direct mount: %s", label_text);
    endtask
    initial begin
        repeat(3) @(negedge clk); reset=0;
        for(int c=0;c<17;c++) begin
            valid_image();
            case(c)
              1: size=687;
              2: le32(28,687);
              3: size=975;
              4: le32(32,687);
              5: le32(32,976);
              6: le32(32,32'h1002b0);
              7: le32(36,688);
              8: image[692]=0;
              9: begin image[692]=0; image[693]=1; end
             10: image[836]=1;
             11: begin image[702]=255; image[703]=255; end
             12: image[691]=4;
             13: image[702]=127;
             14: le32(36,840);
             15: begin le32(32,968); image[972]=1; end
             16: size=24'h100000;
            endcase
            mount_image(); finish_scan(c==0,$sformatf("case %0d",c));
        end
        // First volume's boundary, not the concatenated container's boundary.
        valid_image(); size=1952; mount_image(); finish_scan(1,"concatenated first volume");
        // Counts above the inherited FM-7 cap of 32 must not truncate silently.
        valid_image(); size=688+33*144; le32(28,int'(size));
        for(int j=0;j<33;j++) begin
            image[688+j*144+2]=8'(j+1);
            image[688+j*144+4]=33;
            image[688+j*144+14]=128;
        end
        mount_image(); finish_scan(1,"33 sectors, no inherited clamp");
        assert(dut.edsk_size==33) else $fatal(1,"sector count truncated");
        valid_image(); size=688+9*255*144; le32(28,int'(size));
        for(int t=0;t<9;t++) begin
            le32(32+t*4,688+t*255*144);
            for(int j=0;j<255;j++) begin
                image[688+(t*255+j)*144+2]=8'(j+1);
                image[688+(t*255+j)*144+4]=255;
                image[688+(t*255+j)*144+14]=128;
            end
        end
        mount_image(); finish_scan(0,"index overflow rejected");
        assert(dut.edsk_size==1992) else $fatal(1,"index overflow/wrap");
        // Ejection while scanner is stalled before ACK. New mount must not
        // steal the old request; eventual completion permits recovery.
        valid_image(); service=0; mount_image(); wait(sd_rd);
        $display("stalled request lba=%d time=%t",lba,$time);
        @(negedge clk); size=0; mount_image();
        repeat(100) @(negedge clk);
        assert(sd_rd && lba==0 && !dut.media_ready && dut.mount_pending) else $fatal(1,"stalled eject aliased host request");
        size=976; service=1;
        $display("release stalled request time=%t",$time);
        finish_scan(1,"replacement after stalled-host drain");
        // CE stopped through a mid-scan ACK, preserving the mounted medium.
        valid_image(); mount_image(); wait(ack);
        @(negedge clk); reset=1;
        repeat(600) @(negedge clk); reset=0;
        finish_scan(1,"reset while scanner ACK drains");
        size=0; mount_image(); finish_scan(0,"eject");
        valid_image(); mount_image(); finish_scan(1,"remount after eject");
        // Stop CE at byte replay points across header, table, sector header
        // and payload. A held scan_wr must not consume the byte twice.
        for(int phase=0;phase<9;phase++) begin
            int target;
            case(phase)
              0: target=0; 1: target=31; 2: target=32; 3: target=687;
              4: target=688; 5: target=692; 6: target=703; 7: target=704;
              default: target=975;
            endcase
            valid_image(); mount_image();
            wait(dut.scan_addr==target && dut.scan_wr);
            @(negedge clk); reset=1;
            repeat(11) @(negedge clk); reset=0;
            finish_scan(1,$sformatf("reset at parser byte %0d",target));
            assert(dut.edsk_size==2) else $fatal(1,"reset duplicated/dropped indexed record");
        end
        // Media changes during a controller (not scanner) SD read also drain
        // the old published LBA before indexing or exposing the new disk.
        service=0; send(2,1); send(0,8'h80); wait(sd_rd);
        @(negedge clk); mount_image();
        repeat(50) @(negedge clk);
        assert(sd_rd && lba==1 && !dut.media_ready && dut.mount_pending && !dut.s_drq && !dut.s_busy)
            else $fatal(1,"controller media replacement did not quarantine/drain");
        reset=1; service=1;
        repeat(600) @(negedge clk); reset=0;
        finish_scan(1,"replacement during controller SD read and reset");
        $display("PASS: direct D88 RTL bounds, not-ready, replacement, stalled ACK, scanner reset and recovery");
        $finish;
    end
    initial begin #50000000; $fatal(1,"D88 scanner timeout active=%b pending=%b sd_rd=%b busy=%b ack=%b addr=%d",prepare,dut.mount_pending,sd_rd,dut.sd_busy,ack,dut.scan_addr); end
endmodule
