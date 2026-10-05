`timescale 1ns/1ps
// Original register/CDC seam diagnostic. Forced internal measurements isolate
// transport from the inherited counter algorithms; this is not native video
// or physical CDC acceptance. The standalone snapshot unit checks live data.
module hps_video_cdc_case #(
    parameter VIDEO_HALF = 7, SYS_HALF = 5, TIMING_HALF = 3,
    parameter COHERENT = 1
) (output reg done = 0);
    reg clk_vid = 0, clk_sys = 0, clk_100 = 0;
    reg video_running = 1, timing_running = 1;
    always #(VIDEO_HALF) if(video_running) clk_vid = !clk_vid;
    always #(SYS_HALF) clk_sys = !clk_sys;
    always #(TIMING_HALF) if(timing_running) clk_100 = !clk_100;
    reg [3:0] selector = 0;
    wire [15:0] result;
    reg mode = 0;
    video_calc #(.COHERENT_SNAPSHOTS(COHERENT)) dut (
        .clk_100(clk_100), .clk_vid(clk_vid), .clk_sys(clk_sys),
        .ce_pix(1'b0), .de(1'b0), .hs(1'b0), .vs(1'b0),
        .vs_hdmi(1'b0), .f1(1'b0), .new_vmode(mode),
        .video_rotated(1'b1), .par_num(selector), .dout(result)
    );

    task automatic read_field(input [3:0] number, input [15:0] expected);
        @(negedge clk_sys); selector = number;
        @(negedge clk_sys);
        assert(result == expected)
            else $fatal(1,"mode %0d selector %0d got %h expected %h",COHERENT,number,result,expected);
    endtask

    initial begin
        // Distinct high/low words expose field ordering/width mistakes.
        force dut.vid_hcnt = 32'h1234abcd;
        force dut.vid_vcnt = 32'h5678ef90;
        force dut.vid_nres = 8'hd5;
        force dut.vid_int = 2'b10;
        force dut.vid_htime = 32'h13572468;
        force dut.vid_vtime = 32'h369c58ad;
        force dut.vid_pix = 32'ha5a55a5a;
        force dut.vid_vtime_hdmi = 32'h76543210;
        repeat(50) @(negedge clk_sys);
        read_field(0,0);
        read_field(1,16'h03d5);
        read_field(2,16'habcd); read_field(3,16'h1234);
        read_field(4,16'hef90); read_field(5,16'h5678);
        read_field(6,16'h2468); read_field(7,16'h1357);
        read_field(8,16'h58ad); read_field(9,16'h369c);
        read_field(10,16'h5a5a); read_field(11,16'ha5a5);
        read_field(12,16'h3210); read_field(13,16'h7654);
        read_field(14,0); read_field(15,0);
        mode = 1;
        repeat(5) @(negedge clk_vid);
        assert(dut.measured_new_vmode) else $fatal(1,"mode input did not propagate");
        if(COHERENT) begin
            @(negedge clk_vid); video_running = 0;
            @(negedge clk_100); timing_running = 0;
            repeat(20) @(negedge clk_sys);
            force dut.vid_hcnt = 32'hfedc9876;
            force dut.vid_htime = 32'h89abcdef;
            repeat(20) @(negedge clk_sys);
            read_field(2,16'habcd); read_field(3,16'h1234);
            read_field(6,16'h2468); read_field(7,16'h1357);
            video_running = 1; timing_running = 1;
            repeat(50) @(negedge clk_sys);
            read_field(2,16'h9876); read_field(3,16'hfedc);
            read_field(6,16'hcdef); read_field(7,16'h89ab);
        end
        done = 1;
    end
endmodule

module hps_video_cdc_tb;
    wire [4:0] done;
    hps_video_cdc_case #(7,5,3,1) a(done[0]);
    hps_video_cdc_case #(3,11,7,1) b(done[1]);
    hps_video_cdc_case #(17,3,13,1) c(done[2]);
    hps_video_cdc_case #(5,5,5,1) d(done[3]);
    hps_video_cdc_case #(7,5,3,0) legacy(done[4]);
    initial begin
        wait(&done);
        $display("PASS: HPS 16-register mapping, four CDC clock ratios, mode sync and stopped-source retention/recovery; legacy mapping retained");
        $finish;
    end
    initial begin #100000; $fatal(1,"HPS measurement test timeout"); end
endmodule
