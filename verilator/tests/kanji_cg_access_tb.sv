// SPDX-License-Identifier: GPL-2.0-only
// Original connected ROM/CG WAIT fixture; all font bytes are synthetic.
`timescale 1ps/1ps
module kanji_cg_access_tb;
    logic cpu_clk=0,video_clk=0,reset=1,video_run=1;
    integer video_half_ps=17500,checks=0,write_count=0;
    always #15625 cpu_clk=!cpu_clk;
    always #(video_half_ps) if(video_run) video_clk=!video_clk;
    wire video_reset;
    x1_reset_release reset_release(video_clk,reset,video_reset);
    logic cpu_select=0,cpu_write=0,high_speed=1,selected_kanji=1;
    logic selected_unsupported=0,gate_valid=1,video_window=1;
    logic [1:0] cpu_plane=0;
    logic [7:0] cpu_data=0;
    logic [16:0] selected_kanji_addr=0;
    wire [16:0] kanji_cpu_addr;
    wire kanji_cpu_read,kanji_cpu_valid,loaded,load_error,wait_n,cpu_read_hold;
    wire [7:0] kanji_cpu_q,cpu_q;
    wire [2:0] access_write;
    x1_pcg_access #(.SEPARATE_VIDEO_RESET(1),.KANJI_SUPPORT(1)) dut(
        .reset(reset),.cpu_clk(cpu_clk),.video_clk(video_clk),.video_reset(video_reset),
        .cpu_select(cpu_select),.cpu_write(cpu_write),.cpu_plane(cpu_plane),.cpu_data(cpu_data),
        .wait_n(wait_n),.cpu_q(cpu_q),.beam_addr(11'd0),.access_addr(),.access_data(),
        .access_write(access_write),.rom_q(8'h32),.blue_q(8'h43),.red_q(8'h54),.green_q(8'h65),
        .high_speed(high_speed),.selected_addr(11'd0),.selected_font16(1'b0),
        .selected_unsupported(selected_unsupported),.selected_font_addr(12'd0),
        .video_window(video_window),.font_cpu_addr(),.font_cpu_q(8'd0),
        .cpu_read_hold(cpu_read_hold),.selected_kanji(selected_kanji),
        .selected_kanji_addr(selected_kanji_addr),.kanji_available(loaded),
        .kanji_cpu_valid(kanji_cpu_valid && gate_valid),.kanji_cpu_q(kanji_cpu_q),
        .kanji_cpu_addr(kanji_cpu_addr),.kanji_cpu_read(kanji_cpu_read)
    );
    logic upload=0,load=0;
    logic [24:0] load_address=0;
    logic [7:0] load_data=0;
    wire [7:0] display_data;
    wire display_valid;
    wire [16:0] display_address=~kanji_cpu_addr;
    x1_kanji_rom rom(
        .cpu_clk(cpu_clk),.video_clk(video_clk),.cpu_reset(reset),.video_reset(video_reset),
        .upload(upload),.load(load),.load_address(load_address),.load_data(load_data),
        .cpu_read(kanji_cpu_read),.cpu_address(kanji_cpu_addr),.cpu_data(kanji_cpu_q),
        .cpu_valid(kanji_cpu_valid),.display_select(1'b1),.display_address(display_address),
        .display_data(display_data),.display_valid(display_valid),.loaded(loaded),.load_error(load_error)
    );
    always @(posedge video_clk) if(access_write!=0) write_count++;
    function automatic logic [7:0] pattern(input integer address);
        return 8'(address*37+(address>>8)*13+(address>>16)*211+19);
    endfunction
    task automatic tick;@(negedge cpu_clk);#1;endtask
    task automatic begin_read(input integer address,input bit write_rom=0,input bit unsupported=0);
        tick();cpu_select=1;cpu_write=write_rom;cpu_plane=0;high_speed=1;
        selected_kanji=1;selected_kanji_addr=17'(address);selected_unsupported=unsupported;
        tick();
        assert(!wait_n && kanji_cpu_addr==17'(address)) else $fatal(1,"acceptance/frozen address");
        // Every live field changes after acceptance. Only the captured
        // request may choose its backend/address/read versus write policy.
        selected_kanji_addr=~17'(address);selected_kanji=0;selected_unsupported=!unsupported;
        high_speed=0;cpu_write=!write_rom;cpu_plane=3;cpu_data=8'hff;
    endtask
    task automatic finish_read(input logic [7:0] expected,input bit write_rom=0);
        integer elapsed;
        elapsed=0;
        while(!wait_n) begin tick();elapsed++;
            assert(elapsed<200) else $fatal(1,"read completion timeout");
        end
        assert(cpu_q==expected && cpu_read_hold==!write_rom && !kanji_cpu_read)
            else $fatal(1,"backend response got %x expected %x",cpu_q,expected);
        repeat(8) begin tick();
            assert(wait_n && cpu_q==expected && !kanji_cpu_read && access_write==0)
                else $fatal(1,"held bus duplicated request or altered response");
        end
        cpu_select=0;repeat(3) tick();
        assert(cpu_q==expected && cpu_read_hold==!write_rom) else $fatal(1,"read-tail retention");
        checks++;
    endtask
    initial begin
        if($value$plusargs("VIDEO_HALF_PS=%d",video_half_ps)) begin end
        #1000000000000;$fatal(1,"global timeout");
    end
    initial begin
        repeat(5) tick();reset=0;repeat(5) tick();
        begin_read(0);finish_read(8'hff); // absent ROM must terminate, not wait forever
        assert(!loaded && !kanji_cpu_read) else $fatal(1,"unloaded backend selected");
        tick();reset=1;repeat(5) tick();upload=1;
        for(integer address=0;address<131072;address++) begin
            tick();load=1;load_address=25'(address);load_data=pattern(address);
        end
        tick();load=0;upload=0;tick();
        assert(loaded && !load_error) else $fatal(1,"synthetic image upload");
        reset=0;repeat(5) tick();
        for(integer address=0;address<131072;address++) begin
            begin_read(address);finish_read(pattern(address));
            assert(display_valid && display_data==pattern(131071-address))
                else $fatal(1,"CPU transaction disturbed display ROM");
        end
        begin_read(37,1);finish_read(8'hff,1);
        begin_read(37);finish_read(pattern(37)); // ROM write ignored
        begin_read(37,0,1);finish_read(8'hff); // absent level/unsupported selector
        // Video ACK alone is insufficient while the CPU backend is delayed.
        gate_valid=0;begin_read(65551);
        repeat(40) tick();
        assert(!wait_n && dut.busy && dut.ack_sync==dut.request && kanji_cpu_read &&
               kanji_cpu_addr==65551) else $fatal(1,"WAIT released without backend validity");
        gate_valid=1;finish_read(pattern(65551));
        // Backend data cannot bypass the provisional video-window contract.
        video_window=0;begin_read(131071);repeat(30) tick();
        assert(!wait_n && dut.stage==0 && kanji_cpu_valid) else $fatal(1,"window bypass");
        video_window=1;finish_read(pattern(131071));
        @(negedge video_clk);video_run=0;
        begin_read(32768);repeat(30) tick();
        assert(!wait_n && kanji_cpu_valid) else $fatal(1,"stopped video bypass");
        video_run=1;finish_read(pattern(32768));
        // Reset while delayed valid and while waiting for a window. Retain
        // ROM, discard ACK/read tail and do not turn a read into a PCG write.
        for(integer kind=0;kind<3;kind++) begin
            gate_valid=kind!=0;video_window=kind==0;begin_read(100+kind);repeat(40) tick();
            assert(!wait_n) else $fatal(1,"reset fixture not pending");
            reset=1;cpu_select=0;#1;
            assert(!kanji_cpu_read && !cpu_read_hold && cpu_q==8'hff && loaded)
                else $fatal(1,"pending reset did not flush response");
            // Third case pulses reset entirely between CPU edges.
            if(kind==2) #100; else repeat(5) tick();
            reset=0;gate_valid=1;video_window=1;repeat(12) tick();
            assert(wait_n && !cpu_read_hold && cpu_q==8'hff && loaded && write_count==0)
                else $fatal(1,"stale post-reset completion/write");
            begin_read(100+kind);finish_read(pattern(100+kind));
        end
        assert(write_count==0) else $fatal(1,"ROM request wrote PCG");
        $display("PASS connected Kanji ROM/WAIT: %0d transactions, every physical byte, concurrent display, frozen requests, absent/protected ROM, delayed valid, window/clock/reset",checks);
        $finish;
    end
endmodule
