`timescale 1ps/1ps
module loader_tb;
    reg clk = 0;
    always #15625 clk = !clk;
    reg reset = 1, download = 0, wr = 0;
    reg [7:0] index = 0, data = 0;
    reg [24:0] address = 0;
    sharpx1 dut (
        .clk_sys(clk), .clk_28636(clk), .reset(reset),
        .pal(1'b0), .scandouble(1'b0),
        .ioctl_download(download), .ioctl_index(index),
        .ioctl_wr(wr), .ioctl_addr(address), .ioctl_dout(data),
        .ps2_clk_in(1'b1), .ps2_data_in(1'b1), .joya_n(8'hff), .joyb_n(8'hff),
        .rgb(), .audio(),
        .disk_ready(1'b0), .img_mounted(1'b0), .disk_wp(1'b1), .img_size(24'd0),
        .disk_ready_b(1'b0), .img_mounted_b(1'b0), .disk_wp_b(1'b1), .img_size_b(24'd0), .sd_drive(),
        .sd_lba(), .sd_rd(), .sd_wr(), .sd_ack(1'b0), .sd_buff_addr(9'd0),
        .sd_buff_dout(8'd0), .sd_buff_din(), .sd_buff_wr(1'b0),
        .ce_pix(), .HBlank(), .HSync(), .VBlank(), .VSync(), .video()
    );
    task transfer(input [7:0] idx, input [24:0] addr,
                  input [7:0] value, input active);
        @(negedge clk);
        index = idx; address = addr; data = value;
        download = active; wr = 1;
        @(posedge clk); #10;
        @(negedge clk); wr = 0; download = 0;
    endtask
    initial begin
        transfer(0, 42, 8'h55, 1);
        assert(dut.IPL.mem[42] == 8'h55) else $fatal;
        transfer(0, 42, 8'hAA, 0);
        transfer(3, 42, 8'hAA, 1);
        transfer(0, 4138, 8'hAA, 1);
        assert(dut.IPL.mem[42] == 8'h55) else $fatal;
        transfer(2, 42, 8'h66, 1);
        assert(dut.RAM.mem[42] == 8'h66) else $fatal;
        transfer(2, 42, 8'hAA, 0);
        transfer(3, 42, 8'hAA, 1);
        transfer(2, 65578, 8'hAA, 1);
        assert(dut.RAM.mem[42] == 8'h66) else $fatal;
        // Direct RAM download is permitted only while CPU reset is asserted.
        @(negedge clk); reset = 0;
        transfer(2, 42, 8'hAA, 1);
        assert(dut.RAM.mem[42] == 8'h66) else $fatal;
        $display("PASS: download qualification, aperture bounds, no address wrap, RAM reset guard");
        $finish;
    end
endmodule
