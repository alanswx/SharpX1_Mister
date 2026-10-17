// SPDX-License-Identifier: GPL-2.0-only
// Original public-pin host/DDR test. Real hps_io file decoder; SYS ACK seam
// copied verbatim from sys_top and checked by the Python source-freeze guard.
`timescale 1ns/1ps
module z_font_hps_upload_tb;
    bit clk=0;
    always #15.625 clk=~clk;
    logic io_clk=0,fp_enable=0;
    logic [15:0] io_din=0;
    wire io_wait,io_strobe;
    logic vs_wait=0;
    reg io_ack;
    reg rack;
    assign io_strobe=~rack & io_clk;
    always @(posedge clk) begin
        if(~(io_wait | vs_wait) | io_strobe) begin
            rack <= io_clk;
            io_ack <= rack;
        end
    end
    wire [48:0] bus /* verilator split_var */;
    wire [35:0] extension /* verilator split_var */;
    wire [21:0] gamma;
    assign bus[48:38]=0;
    assign bus[35:33]={fp_enable,1'b0,io_strobe};
    assign bus[31:16]=io_din;
    assign extension[32]=0;
    assign extension[15:0]=0;
    assign gamma[21]=0;
    wire download,wr;
    wire [15:0] index;
    wire [26:0] address;
    wire [7:0] data;
    hps_io #(.CONF_STR("FONT;;"),.CONF_STR_BRAM(0)) hps (
        .clk_sys(clk),.HPS_BUS(bus),.EXT_BUS(extension),.gamma_bus(gamma),
        .ioctl_download(download),.ioctl_wr(wr),.ioctl_index(index),
        .ioctl_addr(address),.ioctl_dout(data),.ioctl_wait(io_wait),
        .ioctl_upload_req(1'b0),.ioctl_upload_index(8'd0),.ioctl_din(8'd0),
        .status_in(128'd0),.status_set(1'b0),.status_menumask(16'd0),
        .info_req(1'b0),.info(8'd0),.new_vmode(1'b0),.video_rotated(1'b0),
        .sd_lba('{32'd0}),.sd_blk_cnt('{6'd0}),.sd_rd(1'b0),.sd_wr(1'b0),
        .sd_buff_din('{8'd0}),.ps2_kbd_clk_in(1'b1),.ps2_kbd_data_in(1'b1),
        .ps2_mouse_clk_in(1'b1),.ps2_mouse_data_in(1'b1),
        .joystick_0_rumble(16'd0),.joystick_1_rumble(16'd0),
        .joystick_2_rumble(16'd0),.joystick_3_rumble(16'd0),
        .joystick_4_rumble(16'd0),.joystick_5_rumble(16'd0)
    );
    wire loaded,error,active;
    wire dclk,rd,we;
    wire [7:0] burst,be;
    wire [28:0] daddr;
    wire [63:0] din;
    logic busy=0;
    x1_z_kanji_frontend front (
        .clk(clk),.cold_reset(1'b0),.consumer_cancel(1'b0),
        .cpu_read(1'b0),.cpu_address(18'd0),.cpu_wait(),.cpu_valid(),.cpu_data(),
        .cpu_response_ack(1'b0),.ioctl_download(download),.ioctl_wr(wr),
        .ioctl_index(index[7:0]),.ioctl_address(address[24:0]),.ioctl_data(data),
        .ioctl_wait(io_wait),.upload_permitted(1'b1),.loaded(loaded),
        .upload_error(error),.upload_active(active),.DDRAM_CLK(dclk),
        .DDRAM_BUSY(busy),.DDRAM_BURSTCNT(burst),.DDRAM_ADDR(daddr),
        .DDRAM_DOUT(64'd0),.DDRAM_DOUT_READY(1'b0),.DDRAM_RD(rd),
        .DDRAM_DIN(din),.DDRAM_BE(be),.DDRAM_WE(we)
    );
    longint unsigned cycles=0,writes=0,host_words=0;
    integer expected_address=0,generation=0,phase=0;
    function automatic [7:0] pattern(input integer a,input integer g);
        return 8'((a*37)^(a>>8)^(a>>17)^(g*91));
    endfunction
    always @(negedge clk) busy=(cycles%11)<3;
    always @(posedge clk) begin
        cycles++;
        assert(!rd && dclk==clk && burst==1) else $fatal(1,"Z_HPS_DDR_SHAPE");
        if(we && !busy) begin
            assert(daddr==29'h06000000+29'(expected_address>>3) &&
                be==(8'd1<<expected_address[2:0]) &&
                din=={8{pattern(expected_address,generation)}})
                else $fatal(1,"Z_HPS_DDR_WRITE_ORACLE");
            expected_address++;writes++;
        end
    end
    task automatic tick;
        @(posedge clk);#1;
    endtask
    task automatic word(input logic [15:0] value);
        integer n;
        @(negedge clk);io_din=value;io_clk=1;
        n=0;
        while(!io_ack) begin tick();n++;assert(n<200) else $fatal(1,"Z_HPS_ACK_RISE");end
        @(negedge clk);io_clk=0;
        n=0;
        while(io_ack) begin
            tick();n++;
            assert(n<200) else $fatal(1,"Z_HPS_ACK_FALL phase=%0d host_words=%0d writes=%0d",phase,host_words,writes);
        end
        host_words++;
    endtask
    task automatic select_file;
        @(negedge clk);fp_enable=1;repeat(3) tick();
    endtask
    task automatic deselect_file;
        @(negedge clk);fp_enable=0;repeat(3) tick();
    endtask
    task automatic begin_upload(input integer g);
        generation=g;expected_address=0;phase=g;
        select_file();word(16'h55);word(5);deselect_file();
        select_file();word(16'h53);word(1);deselect_file();
        assert(!loaded && active && !error) else $fatal(1,"Z_HPS_START");
        select_file();word(16'h54);
    endtask
    task automatic payload(input integer count);
        for(integer a=0;a<count;a++) word({8'd0,pattern(a,generation)});
    endtask
    task automatic end_upload(input bit accepted);
        deselect_file();select_file();word(16'h53);word(0);deselect_file();
        repeat(12) tick();
        assert(!active && loaded==accepted && error!=accepted && !io_wait)
            else $fatal(1,"Z_HPS_END_STATE");
    endtask
    initial begin
        repeat(8) tick();
        begin_upload(0);payload(262144);end_upload(1);
        assert(expected_address==262144) else $fatal(1,"Z_HPS_FULL_LENGTH");
        begin_upload(1);payload(262144);
        word(16'h0099);word(16'h0077);end_upload(0);
        assert(expected_address==262144) else $fatal(1,"Z_HPS_OVERFLOW_WRITE");
        begin_upload(2);payload(262144);end_upload(1);
        begin_upload(3);payload(16);end_upload(0);
        assert(expected_address==16) else $fatal(1,"Z_HPS_SHORT_LENGTH");
        begin_upload(4);payload(4);deselect_file();
        // Seek within an active download, then deliver a gapped/high address.
        select_file();word(16'h53);word(1);word(16'h0000);word(16'h0004);deselect_file();
        select_file();word(16'h54);word(16'h0088);word(16'h0066);deselect_file();
        // A now-valid address must still be discarded after the sticky error.
        select_file();word(16'h53);word(1);word(4);word(0);deselect_file();
        select_file();word(16'h54);word({8'd0,pattern(4,4)});end_upload(0);
        assert(expected_address==4) else $fatal(1,"Z_HPS_GAP_WRITE");
        begin_upload(5);payload(262144);end_upload(1);
        assert(writes==1048596) else $fatal(1,"Z_HPS_WRITE_COUNT");
        $display("PASS Z_HPS_UPLOAD writes=%0d host_words=%0d cycles=%0d full=4 malformed=3 recovered=2",writes,host_words,cycles);
        $finish;
    end
    initial begin #2000000000;$fatal(1,"Z_HPS_GLOBAL_TIMEOUT");end
endmodule
