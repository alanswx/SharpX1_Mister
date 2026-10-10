// SPDX-License-Identifier: GPL-2.0-only
// Original ioctl IPL / real CPU capacity-selection diagnostic, no private ROM.
`timescale 1ps/1ps
module hd_capacity_machine_tb #(parameter ENABLE_SELECT=1);
    logic clk=0,video_clk=0,reset=1,download=0,upload=0;
    always #15625 clk=!clk;
    always #17500 video_clk=!video_clk;
    logic [24:0] address=0;
    logic [7:0] data=0,program_bytes[0:8191];
    wire load_wait;
    integer size=0,marker_total=0,markers=0,reads=0,dam_reads=0;
    logic old_marker=0,old_read=0,old_select=0;
    wire select_read=dut.io_read && !dut.dam && dut.a[15:1]==15'h07ff;
    sharpx1 #(.TURBO(1),.TURBO_HD_SELECT(ENABLE_SELECT)) dut(
        .clk_sys(clk),.clk_28636(video_clk),.reset(reset),.pal(1'b0),.scandouble(1'b0),
        .ioctl_download(download),.ioctl_index(8'd0),.ioctl_wr(upload),
        .ioctl_addr(address),.ioctl_dout(data),.ioctl_wait(load_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),
        .sio_rxd(2'b11),.sio_cts_n(2'b11),.sio_dcd_n(2'b11),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_ack(1'b0),.sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_wr(1'b0));
    task automatic emit(input logic [7:0] value);
        assert(size<8192);program_bytes[size++]=value;
    endtask
    task automatic out_port(input logic [15:0] port,input logic [7:0] value);
        emit(8'h01);emit(port[7:0]);emit(port[15:8]);
        emit(8'h3e);emit(value);emit(8'hed);emit(8'h79);
    endtask
    task automatic in_port(input logic [15:0] port);
        emit(8'h01);emit(port[7:0]);emit(port[15:8]);emit(8'hed);emit(8'h78);
    endtask
    task automatic marker(input bit expected);
        emit(8'h3e);emit({7'b1010000,expected});
        emit(8'h32);emit(8'h00);emit(8'hf0);marker_total++;
    endtask
    task automatic tick; @(negedge clk); #1; endtask
    always @(posedge clk) begin
        old_marker <= dut.mem_write && dut.a==16'hf000;
        old_read <= dut.io_read;
        old_select <= select_read;
        if(!dut.core_reset) begin
            if(dut.io_read && !old_read && dut.a==16'h0fff && dut.dam) dam_reads++;
            if(select_read && !old_select) reads++;
            // Expected state is an explicit original-IPL marker, not a second
            // copy of the latch's address-decoding equation or forced input.
            if(dut.mem_write && dut.a==16'hf000 && !old_marker) begin
                assert(dut.data_out[7:1]==7'b1010000 &&
                       dut.disk_hd_selected==dut.data_out[0])
                    else $fatal(1,"CPU-selected capacity mismatch step=%0d marker=%h state=%b",
                                markers,dut.data_out,dut.disk_hd_selected);
                markers++;
            end
        end
    end
    initial begin #3000000000; $fatal(1,"HD capacity CPU timeout"); end
    initial begin
        for(integer i=0;i<8192;i++) program_bytes[i]=0;
        emit(8'hf3);emit(8'h31);emit(8'hff);emit(8'hff);
        in_port(16'h1234);marker(0); // Clear initial DAM using a real IN.
        in_port(16'h0ffe);marker(1);
        in_port(16'h1fff);marker(1); // Full address, no low-byte alias.
        out_port(16'h0fff,8'h55);marker(1); // OUT is not selection.
        in_port(16'h0ffc);marker(1); // FM independent of capacity class.
        in_port(16'h0ffd);marker(1);
        out_port(16'h0ffc,8'h91);marker(1); // B/side/motor independent.
        in_port(16'h0fff);marker(0);
        in_port(16'h1ffe);marker(0);
        out_port(16'h0ffe,8'haa);marker(0);
        in_port(16'h0ffe);marker(1);
        out_port(16'h1a03,8'h82);in_port(16'h1234);
        out_port(16'h1a02,8'h20);out_port(16'h1a02,8'h00);
        // Inherited DAM clears on the first SYS edge of the held CPU IN;
        // subsequent edges of that same IN become device-eligible. This
        // qualifies current machine behavior, not native ASIC edge ordering.
        in_port(16'h0fff);marker(0);
        in_port(16'h0fff);marker(0); // Subsequent eligible IN selects low.
        in_port(16'h0ffe);marker(1);emit(8'h76);
        repeat(8) tick();download=1;
        for(integer i=0;i<8192;i++) begin
            tick();while(load_wait) tick();address=i;data=program_bytes[i];upload=1;
            tick();upload=0;
        end
        tick();download=0;repeat(8) tick();reset=0;
        for(integer pass=0;pass<2;pass++) begin
            wait(!dut.halt_n);tick();
            assert(markers==marker_total && reads==6 && dam_reads==1 && dut.disk_hd_selected)
                else $fatal(1,"capacity CPU coverage markers=%0d/%0d reads=%0d DAM=%0d",
                            markers,marker_total,reads,dam_reads);
            $display("PASS capacity CPU pass=%0d markers=%0d selects=%0d DAM-read=%0d",
                     pass,markers,reads,dam_reads);
            if(pass==0) begin
                reset=1;repeat(64) tick();
                assert(!dut.disk_hd_selected) else $fatal(1,"capacity warm reset did not clear");
                markers=0;reads=0;dam_reads=0;reset=0;
            end
        end
        $display("PASS real CPU HD/low class, full decode, IN/OUT/FM/drive independence, DAM and retained-IPL reset; no density/rate acceptance");
        $finish;
    end
endmodule
