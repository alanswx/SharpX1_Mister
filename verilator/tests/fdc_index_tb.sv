`timescale 1ns/1ps
module fdc_index_tb;
    reg clk = 0, reset = 1, wr = 0;
    always #5 clk = !clk;
    wire [7:0] status;
    wd1793 #(.RWMODE(0),.EDSK(0),.HEADLOAD_STATUS(1),.INDEX_CYCLES(800000)) dut (
        .drive_select(1'b0), .drive_connected(1'b1), .transport_idle(),
        .clk_sys(clk),.ce(1'b1),.reset(reset),.io_en(1'b1),.rd(1'b0),.wr(wr),
        .addr(2'd0),.din(8'h08),.dout(status),.drq(),.intrq(),.busy(),.wp(1'b0),.fmt_wp(),
        .size_code(3'd1),.layout(1'b0),.side(1'b0),.ready(1'b1),.fm_mode(1'b0),
        .img_mounted(1'b0),.img_size(20'd0),.img_size_id(24'd0),.disk_index(3'd0),.prepare(),
        .sd_lba(),.sd_rd(),.sd_wr(),.sd_ack(1'b0),.sd_buff_addr(9'd0),.sd_buff_dout(8'd0),
        .sd_buff_din(),.sd_buff_wr(1'b0),.input_active(1'b0),.input_addr(20'd0),
        .input_data(8'd0),.input_wr(1'b0),.buff_addr(),.buff_read(),.buff_din(8'd0)
    );
    integer tick = 0, last_rise = 0, rises = 0, pulse_start = 0;
    reg previous = 0;
    initial begin
        repeat (3) @(negedge clk); reset = 0;
        @(negedge clk); wr = 1;
        @(negedge clk); wr = 0;
        assert (status[5]) else $fatal(1, "X1 head-load status absent");
        while (rises < 3) begin
            @(negedge clk); tick = tick + 1;
            if (status[1] && !previous) begin
                if (last_rise != 0)
                    assert (tick - last_rise == 800000) else $fatal(1, "index period %d",tick-last_rise);
                last_rise = tick; pulse_start = tick; rises = rises + 1;
            end
            if (!status[1] && previous)
                assert (tick - pulse_start == 8000) else $fatal(1, "index width %d",tick-pulse_start);
            previous = status[1];
        end
        $display("PASS: X1 head-load status and deterministic 300 rpm / 2 ms index at 4 MHz enable");
        $finish;
    end
    initial begin #30000000; $fatal(1, "index timeout"); end
endmodule
