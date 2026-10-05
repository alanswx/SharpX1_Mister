`timescale 1ns/1ps
// Original two-image/FDC transport bench, bypassing host preflight. Exercises
// real ACK history and buffers, not a mocked controller completion signal.
module dual_fdc_tb #(parameter EJECT_WRITE = 0);
    reg clk=0, reset=1, service=0, ack=0, host_wr=0;
    always #5 clk=!clk;
    reg [1:0] selected=0, mounted=3;
    reg [1:0] present=3;
    reg [23:0] size_a=976, size_b=976;
    wire [1:0] active;
    wire changing, selected_ready, wp, transport_idle;
    wire [23:0] size;
    x1_disk_media media(clk,selected,mounted,present,2'b10,size_a,size_b,
                        transport_idle,active,changing,selected_ready,wp,size);
    wire prepare, sd_rd, sd_wr, drq;
    wire [31:0] lba;
    reg [8:0] host_addr=0;
    reg [7:0] host_data=0;
    wire [7:0] host_out, status;
    reg [1:0] addr=0;
    reg [7:0] din=0;
    reg wr=0;
    reg [7:0] images[0:1][0:975];
    wd1793 #(.RWMODE(1),.EDSK(1),.D88_ONLY(1),.PHYSICAL_DRIVES(2)) fdc(
        .clk_sys(clk),.ce(!reset),.reset(reset),.io_en(1'b1),.rd(1'b0),.wr(wr),
        .addr(addr),.din(din),.dout(status),.drq(drq),.intrq(),.busy(),
        .wp(wp),.fmt_wp(),.size_code(3'd1),.layout(1'b0),.side(1'b0),
        .ready(selected_ready && !prepare),.fm_mode(1'b0),
        .drive_select(active[0]),.transport_idle(transport_idle),
        .drive_connected(active < 2),
        .img_mounted(changing),.img_size(size[19:0]),.img_size_id(size),.disk_index(3'd0),
        .prepare(prepare),.sd_lba(lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(ack),
        .sd_buff_addr(host_addr),.sd_buff_dout(host_data),.sd_buff_din(host_out),.sd_buff_wr(host_wr),
        .input_active(1'b0),.input_addr(20'd0),.input_data(8'd0),.input_wr(1'b0),
        .buff_addr(),.buff_read(),.buff_din(8'd0));
    task le32(input int drive, input int at, input int value);
        for(int i=0;i<4;i++) images[drive][at+i]=8'(value>>(8*i));
    endtask
    task valid_image(input int drive);
        for(int i=0;i<976;i++) images[drive][i]=0;
        le32(drive,28,976); le32(drive,32,688);
        for(int j=0;j<2;j++) begin
            images[drive][688+j*144+2]=8'(j+1);
            images[drive][688+j*144+4]=2;
            images[drive][688+j*144+14]=128;
            for(int i=0;i<128;i++) images[drive][704+j*144+i]=8'(i+drive*128+j);
        end
    endtask
    initial forever begin
        int owner, base;
        bit writing;
        wait((sd_rd || sd_wr) && service);
        @(negedge clk);
        owner=int'(active); base=int'(lba)*512; writing=sd_wr; ack=1;
        for(int i=0;i<512;i++) begin
            assert(int'(active)==owner && int'(lba)*512==base) else $fatal(1,"host owner/LBA changed during ACK");
            host_addr=9'(i);
            host_data=(base+i<976) ? images[owner][base+i] : 0;
            host_wr=!writing;
            @(negedge clk);
            if(writing && base+i<976) images[owner][base+i]=host_out;
        end
        host_wr=0; repeat(10) @(negedge clk); ack=0;
        repeat(12) @(negedge clk);
    end
    task finish_scan(input bit good);
        repeat(20) @(negedge clk);
        wait(!changing && !prepare && !fdc.mount_pending && transport_idle);
        repeat(10) @(negedge clk);
        assert(fdc.media_ready==good) else $fatal(1,"wrong media readiness valid=%b bad=%b active=%d",fdc.d88_valid,fdc.d88_bad,active);
    endtask
    task send(input [1:0] port, input [7:0] value);
        @(negedge clk); addr=port;din=value;wr=1;
        @(negedge clk); wr=0;
    endtask
    initial begin
        valid_image(0); valid_image(1);
        repeat(4) @(negedge clk); reset=0; mounted=0;
        wait(sd_rd); @(negedge clk);
        selected=1; repeat(100) @(negedge clk);
        assert(active==0 && lba==0 && sd_rd && changing && !fdc.media_ready) else $fatal(1,"pending A scan switched owner");
        service=1; finish_scan(1);
        assert(active==1) else $fatal(1,"B rescan owner");
        // An inactive A mount does not invalidate valid B metadata.
        mounted=1; repeat(3) @(negedge clk); mounted=0;
        assert(fdc.media_ready && !changing) else $fatal(1,"inactive mount invalidated B");
        selected=0; finish_scan(1);
        send(2,1); send(0,8'hA0);
        wait(drq); @(negedge clk); service=0;
        for(int i=0;i<128;i++) begin
            wait(drq); send(3,8'(i)^8'h5a); wait(!drq);
        end
        wait(sd_wr); @(negedge clk);
        assert(active==0 && lba==1) else $fatal(1,"A write publication");
        selected=1; reset=1; host_addr=229;
        if(EJECT_WRITE == 1) begin
            mounted=1; present=2; size_a=0;
        end
        repeat(30) @(negedge clk);
        assert(active==0 && sd_wr && lba==1 && host_out==(8'd37^8'h5a)) else $fatal(1,"pending write owner/buffer lost on selection/reset");
        service=1; wait(ack);
        if(EJECT_WRITE == 2) begin
            @(negedge clk); mounted=1; present=2; size_a=0;
            repeat(3) @(negedge clk);
            assert(active==0 && changing && !selected_ready && lba==1)
                else $fatal(1,"ACK-high eject lost owner/quarantine");
        end
        if(EJECT_WRITE != 0) begin
            repeat(3) @(negedge clk); mounted=0;
        end
        wait(!ack); repeat(20) @(negedge clk);
        assert(transport_idle && active==1) else $fatal(1,"ACK failed to drain with CE stopped");
        reset=0; finish_scan(1);
        for(int i=0;i<128;i++) begin
            assert(images[0][704+i]==(8'(i)^8'h5a)) else $fatal(1,"accepted write not associated with A byte=%d",i);
            assert(images[1][704+i]==8'(i+128)) else $fatal(1,"A write changed B");
        end
        // Direct malformed B is rejected without falling back to A/raw media.
        le32(1,32,687); mounted=2;
        repeat(3) @(negedge clk); mounted=0; finish_scan(0);
        valid_image(1); mounted=2;
        repeat(3) @(negedge clk); mounted=0; finish_scan(1);
        present=1; size_b=0; mounted=2;
        repeat(3) @(negedge clk); mounted=0; finish_scan(0);
        if(EJECT_WRITE != 0) begin
            present=3; size_a=976; mounted=1;
            repeat(3) @(negedge clk); mounted=0;
        end
        selected=0; finish_scan(1);
        $display("PASS: real FDC A/B scan ownership, mount isolation, accepted A write/buffer through selection and CE-stopped reset, malformed/ejected B and A recovery");
        if(EJECT_WRITE != 0)
            $display("PASS: active A eject variant %0d drains accepted write to retained old-media host buffer; physical HPS mount epochs are not modeled",EJECT_WRITE);
        $finish;
    end
    initial begin #100000000; $fatal(1,"dual FDC timeout active=%d scan=%b state=%d",active,prepare,fdc.state); end
endmodule
