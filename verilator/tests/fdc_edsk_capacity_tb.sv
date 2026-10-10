`timescale 1ns/1ps
// Original addressed-stream EDSK fixture. Uses the public RWMODE=0 upload
// interface, not force or parser state injection. Gaps in this monotonic stream
// deliberately isolate offset arithmetic; this is not an SD/full-image test.
module fdc_edsk_capacity_tb;
    parameter ADDRESS_BITS=24;
    parameter CAPACITY_TEST=1;
    reg clk=0, reset=1, active=0, input_wr=0;
    reg [ADDRESS_BITS-1:0] input_addr=0;
    reg [7:0] input_data=0;
    reg [23:0] size=0;
    wire prepare;
    wire [127:0] signature="EXTENDED CPC DSK";
    always #5 clk=!clk;
    wd1793 #(.RWMODE(0), .ADDRESS_BITS(ADDRESS_BITS)) dut(
        .clk_sys(clk), .ce(!reset), .reset(reset), .io_en(1'b0), .rd(1'b0), .wr(1'b0),
        .addr(2'd0), .din(8'd0), .dout(), .drq(), .intrq(), .busy(), .wp(1'b0), .fmt_wp(),
        .size_code(3'd1), .layout(1'b0), .side(1'b0), .ready(1'b1), .fm_mode(1'b0),
        .drive_select(1'b0), .drive_connected(1'b1), .transport_idle(),
        .img_mounted(1'b0), .img_size(size[ADDRESS_BITS-1:0]), .img_size_id(size),
        .disk_index(3'd0), .prepare(prepare), .sd_lba(), .sd_rd(), .sd_wr(), .sd_ack(1'b0),
        .sd_buff_addr(9'd0), .sd_buff_dout(8'd0), .sd_buff_din(), .sd_buff_wr(1'b0),
        .input_active(active), .input_addr(input_addr), .input_data(input_data), .input_wr(input_wr),
        .buff_addr(), .buff_read(), .buff_din(8'd0));
    task push(input integer a, input [7:0] v);
        @(negedge clk); input_addr=ADDRESS_BITS'(a); input_data=v; input_wr=1;
        repeat(3) @(negedge clk); input_wr=0; repeat(3) @(negedge clk);
    endtask
    task capacity_overflow;
        integer remaining, start, tracks, count;
        start=1<<(ADDRESS_BITS-1); tracks=69; remaining=1993;
        @(negedge clk); size=24'(start+tracks*4096); active=1;
        repeat(180) @(negedge clk);
        for(int i=0;i<256;i++) begin
            reg [7:0] v;
            v=0;
            if(i<16) v=8'(signature>>(120-i*8));
            if(i==48) v=8'(tracks);
            if(i==49) v=1;
            if(i>=52 && i<52+tracks) v=16;
            push(i,v);
        end
        for(int track=0;track<tracks;track++) begin
            count=(remaining>29)?29:remaining;
            for(int i=0;i<4096;i++) begin
                reg [7:0] v;
                v=0;
                if(i==16) v=8'(track);
                if(i==21) v=8'(count);
                if(i>=24 && i<24+count*8) begin
                    case((i-24)%8)
                        0: v=8'(track);
                        2: v=8'((i-24)/8+1);
                        6: v=128;
                        default: v=0;
                    endcase
                end
                push(start+track*4096+i,v);
            end
            remaining-=count;
        end
        @(negedge clk); active=0; repeat(8) @(negedge clk);
        assert(!dut.media_ready && dut.d88_bad && dut.edsk_size==0)
            else $fatal(1,"wide EDSK default capacity overflow admitted count=%0d",dut.edsk_size);
        $display("PASS wide EDSK 1993-entry capacity overflow rejected");
    endtask
    task image(input integer start, input integer bound, input integer length,
               input bit accepted, input string label_text);
        @(negedge clk); size=24'(bound); active=1;
        repeat(180) @(negedge clk);
        for(int i=0;i<53;i++) begin
            reg [7:0] v;
            v=0;
            if(i<16) v=8'(signature>>(120-i*8));
            if(i==48 || i==49) v=1;
            if(i==52) v=2;
            push(i,v);
        end
        for(int i=0;i<32;i++) begin
            reg [7:0] v;
            v=0;
            if(i==21 || i==26) v=1;
            if(i==30) v=8'(length);
            if(i==31) v=8'(length>>8);
            push(start+i,v);
        end
        @(negedge clk); active=0; repeat(8) @(negedge clk);
        assert(!prepare && dut.media_ready==accepted) else $fatal(1,"EDSK %s admission=%b",label_text,dut.media_ready);
        if(accepted) begin
            assert(dut.edsk_size==1 && dut.var_size && dut.image_index.edsk_ram.ram[0]==
                   {7'd0,1'b0,8'd0,8'd0,8'd1,2'd0,2'b00,1'b0,ADDRESS_BITS'(start+256)})
                else $fatal(1,"EDSK wide offset/index mismatch");
        end else assert(dut.edsk_size==0 && !dut.var_size && dut.d88_bad)
            else $fatal(1,"EDSK overflow silently truncated");
        $display("PASS EDSK addressed stream width=%0d %s",ADDRESS_BITS,label_text);
    endtask
    initial begin
        repeat(10) @(negedge clk); reset=0;
        if(CAPACITY_TEST) capacity_overflow();
        else begin
            image(256,1024,128,1,"low offset");
            image((1<<(ADDRESS_BITS-1))+256,(1<<(ADDRESS_BITS-1))+1024,128,1,"highest address bit offset");
            image((1<<ADDRESS_BITS)-128,(1<<ADDRESS_BITS)-1,128,0,"track plus 256 carry rejected");
            image((1<<ADDRESS_BITS)-512,(1<<ADDRESS_BITS)-1,512,0,"sector offset plus length carry rejected");
        end
        $display("PASS EDSK width arithmetic (no SD or geometry acceptance)"); $finish;
    end
    initial begin #100000000; $fatal(1,"EDSK stream timeout"); end
endmodule
