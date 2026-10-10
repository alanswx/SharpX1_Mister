`timescale 1ns/1ps
// Original synthetic D88 media. Actual scanner, SD buffer and FDC registers;
// no force, index injection, private bytes, density/rate or busy-change claims.
module fdc_capacity_class_tb;
    parameter CAPACITY_CHECK=1;
    parameter DIVIDER=8;
    localparam VOLUME=1160, TOTAL=2*VOLUME, HEADER=1016, PAYLOAD=128;
    reg clk=0, reset=1, mounted=0, ack=0, host_wr=0, wr=0, rd=0;
    reg drive=0, hd=0, rejecting=0;
    reg [2:0] selected=0;
    reg [1:0] address=0;
    reg [7:0] data=0, host_data=0;
    reg [8:0] host_address=0;
    wire [7:0] dout, host_read_data;
    wire [31:0] lba;
    wire prepare, sd_rd, sd_wr, busy, drq, idle;
    integer ticks=0, requests=0, writes=0, cases=0;
    reg [7:0] media[2][TOTAL];
    reg [7:0] expected_media[2][TOTAL];
    always #5 clk=!clk;
    always @(negedge clk) ticks=ticks+1;
    wire ce=(ticks%DIVIDER)==0;
    always @(negedge clk) if(rejecting)
        assert(!drq && !sd_rd && !sd_wr) else $fatal(1,"mismatch transient payload/SD request");
    wd1793 #(.RWMODE(1), .EDSK(1), .D88_ONLY(1), .PHYSICAL_DRIVES(2),
              .D88_CAPACITY_CHECK(CAPACITY_CHECK)) dut(
        .clk_sys(clk), .ce(ce), .reset(reset), .io_en(1'b1),
        .rd(rd), .wr(wr), .addr(address), .din(data), .dout(dout),
        .drq(drq), .intrq(), .busy(busy), .wp(1'b0), .fmt_wp(),
        .size_code(3'd1), .layout(1'b0), .side(1'b0), .ready(1'b1), .fm_mode(1'b0),
        .drive_select(drive), .drive_connected(1'b1), .transport_idle(idle),
        .img_mounted(mounted), .img_size(20'(TOTAL)), .img_size_id(24'(TOTAL)),
        .disk_index(selected), .prepare(prepare), .sd_lba(lba), .sd_rd(sd_rd), .sd_wr(sd_wr),
        .sd_ack(ack), .sd_buff_addr(host_address), .sd_buff_dout(host_data),
        .sd_buff_din(host_read_data), .sd_buff_wr(host_wr), .input_active(1'b0),
        .input_addr(20'd0), .input_data(8'd0), .input_wr(1'b0),
        .buff_addr(), .buff_read(), .buff_din(8'd0), .hd_selected(hd));

    initial forever begin
        bit writing, owned_drive;
        integer owned_lba, at;
        wait(sd_rd || sd_wr);
        writing=sd_wr; owned_lba=int'(lba); owned_drive=drive;
        assert(!(sd_rd && sd_wr)) else $fatal(1,"both SD requests");
        requests++; if(writing) writes++;
        @(negedge clk); ack=1;
        for(int i=0;i<512;i++) begin
            host_address=9'(i); at=owned_lba*512+i;
            if(writing) begin
                repeat(2) @(negedge clk);
                if(at<TOTAL) media[owned_drive][at]=host_read_data;
                else assert(host_read_data==0) else $fatal(1,"write beyond synthetic extent");
            end else begin
                host_data=(at<TOTAL)?media[owned_drive][at]:8'd0;
                host_wr=1; @(negedge clk);
            end
            assert(lba==32'(owned_lba) && drive==owned_drive)
                else $fatal(1,"host ownership changed during ACK");
        end
        host_wr=0; repeat(10) @(negedge clk); ack=0;
        repeat(12) @(negedge clk);
    end
    task send(input [1:0] port, input [7:0] value);
        @(negedge clk); address=port; data=value; wr=1;
        repeat(3*DIVIDER) @(negedge clk); wr=0;
        repeat(3*DIVIDER) @(negedge clk);
    endtask
    task get_byte(output reg [7:0] value);
        wait(drq || !busy); assert(drq) else $fatal(1,"missing read DRQ");
        @(negedge clk); address=3; rd=1;
        repeat(2*DIVIDER) @(negedge clk); value=dout; rd=0;
        repeat(3*DIVIDER) @(negedge clk);
    endtask
    task settled;
        wait(!prepare && !dut.mount_pending && idle);
        repeat(12*DIVIDER) @(negedge clk);
    endtask
    task mount_drive(input bit d, input [2:0] volume);
        wait(idle && !busy); @(negedge clk); drive=d; selected=volume; mounted=1;
        repeat(4*DIVIDER) @(negedge clk); mounted=0; settled();
    endtask
    task initialize_media(input [7:0] first_class, input [7:0] second_class);
        for(int d=0;d<2;d++) begin
            for(int i=0;i<TOTAL;i++) media[d][i]=0;
            for(int v=0;v<2;v++) begin
                media[d][v*VOLUME+27]=(v==0)?first_class:second_class;
                for(int i=0;i<4;i++) begin
                    media[d][v*VOLUME+28+i]=8'(VOLUME>>(8*i));
                    media[d][v*VOLUME+32+i]=8'(HEADER>>(8*i));
                end
                media[d][v*VOLUME+HEADER+2]=1;
                media[d][v*VOLUME+HEADER+4]=1;
                media[d][v*VOLUME+HEADER+14]=PAYLOAD;
                for(int i=0;i<PAYLOAD;i++) media[d][v*VOLUME+HEADER+16+i]=8'(i*7+3+d*11+v*17);
            end
            for(int i=0;i<TOTAL;i++) expected_media[d][i]=media[d][i];
        end
    endtask
    task type_i;
        send(3,7); send(0,8'h10); wait(!busy); address=1; #1;
        assert(dout==7) else $fatal(1,"SEEK track register");
        address=0; #1;
        assert((dout & 8'h99)==0) else $fatal(1,"SEEK affected by capacity status=%h",dout);
        send(0,0); wait(!busy); address=1; #1;
        assert(dout==0) else $fatal(1,"RESTORE track register");
        address=0; #1;
        assert((dout & 8'h99)==0 && dout[2]) else $fatal(1,"RESTORE affected by capacity status=%h",dout);
    endtask
    function automatic [15:0] crc_byte(input [15:0] crc, input [7:0] value);
        reg [15:0] x;
        x=crc ^ {value,8'd0};
        for(int i=0;i<8;i++) x=x[15] ? (x<<1)^16'h1021 : x<<1;
        return x;
    endfunction
    task accepted_io;
        reg [7:0] value;
        reg [15:0] crc;
        integer before_writes, p;
        p=int'(selected)*VOLUME+HEADER+16;
        send(2,1); send(0,8'h80);
        for(int i=0;i<PAYLOAD;i++) begin
            get_byte(value);
            assert(value==expected_media[drive][p+i]) else $fatal(1,"read payload i=%0d",i);
        end
        wait(!busy); address=0; #1; assert(dout==0) else $fatal(1,"read status=%h",dout);
        crc=16'hffff;
        repeat(3) crc=crc_byte(crc,8'ha1);
        crc=crc_byte(crc,8'hfe);
        crc=crc_byte(crc,0); crc=crc_byte(crc,0); crc=crc_byte(crc,1); crc=crc_byte(crc,0);
        send(0,8'hc0);
        for(int i=0;i<6;i++) begin
            get_byte(value);
            assert(value==((i==2)?8'd1:(i==4)?crc[15:8]:(i==5)?crc[7:0]:8'd0))
                else $fatal(1,"READ ADDRESS byte=%0d got=%h crc=%h",i,value,crc);
        end
        wait(!busy); address=0; #1; assert(dout==0) else $fatal(1,"ID status=%h",dout);
        before_writes=writes;
        send(2,1); send(0,8'ha0);
        for(int i=0;i<PAYLOAD;i++) begin
            wait(drq || !busy); assert(drq) else $fatal(1,"missing write DRQ");
            send(3,8'(i)^8'h5a); expected_media[drive][p+i]=8'(i)^8'h5a;
        end
        wait(!busy && idle); address=0; #1;
        assert(dout==0 && writes>before_writes) else $fatal(1,"write status/host count");
        for(int d=0;d<2;d++) for(int i=0;i<TOTAL;i++)
            assert(media[d][i]==expected_media[d][i]) else $fatal(1,"RMW damaged d=%0d offset=%0d",d,i);
        send(2,1); send(0,8'h80);
        for(int i=0;i<PAYLOAD;i++) begin
            get_byte(value); assert(value==(8'(i)^8'h5a)) else $fatal(1,"write readback");
        end
        wait(!busy); address=0; #1; assert(dout==0) else $fatal(1,"readback status");
    endtask
    task rejected_io;
        integer before_requests, before_writes;
        reg [7:0] command;
        for(int i=0;i<3;i++) begin
            command=(i==0)?8'h80:(i==1)?8'ha0:8'hc0;
            before_requests=requests; before_writes=writes;
            rejecting=1;
            send(2,1); send(0,command);
            while(busy) begin
                assert(!drq) else $fatal(1,"mismatch offered payload DRQ");
                @(negedge clk);
            end
            address=0; #1;
            assert(dout==8'h10 && !drq && writes==before_writes && requests==before_requests)
                else $fatal(1,"mismatch command=%h status=%h req_delta=%0d",command,dout,requests-before_requests);
            rejecting=0;
        end
    endtask
    task check_class(input [7:0] klass, input bit high);
        bit expected_match;
        hd=high;
        expected_match=!CAPACITY_CHECK || (high ? klass==8'h20 : klass==0 || klass==8'h10);
        type_i();
        if(expected_match) accepted_io(); else rejected_io();
        $display("PASS check=%0d divider=%0d drive=%0d volume=%0d class=%h hd=%0d matched=%0d",CAPACITY_CHECK,DIVIDER,drive,selected,klass,high,expected_match);
        cases++;
    endtask
    initial begin
        repeat(10) @(negedge clk); reset=0;
        // Opposite first/selected headers disprove a first-header-only oracle.
        for(int k=0;k<5;k++) begin
            reg [7:0] klass;
            klass=(k==0)?0:(k==1)?8'h10:(k==2)?8'h20:(k==3)?8'h30:8'hff;
            initialize_media(klass==8'h20 ? 8'h00 : 8'h20,klass);
            mount_drive(0,1);
            check_class(klass,0); check_class(klass,1);
            // Controller reset retains scanned metadata; do NOT remount here.
            @(negedge clk); reset=1; repeat(10*DIVIDER) @(negedge clk); reset=0;
            repeat(10*DIVIDER) @(negedge clk); check_class(klass,1);
            // Drive rescans must replace the descriptor, including unknowns.
            media[1][VOLUME+27]=(klass==8'h20)?8'h10:8'h20;
            expected_media[1][VOLUME+27]=media[1][VOLUME+27];
            mount_drive(1,1); check_class(media[1][VOLUME+27],0); check_class(media[1][VOLUME+27],1);
            mount_drive(0,0); check_class(media[0][27],0); check_class(media[0][27],1);
        end
        assert(cases==35) else $fatal(1,"coverage count");
        $display("PASS standalone D88 capacity class cases=%0d SD_requests=%0d SD_writes=%0d",cases,requests,writes);
        $finish;
    end
    initial begin #100000000; $fatal(1,"capacity fixture timeout"); end
endmodule
