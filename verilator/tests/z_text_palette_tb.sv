// Original raw six-bit CPU/snapshot fixture; deliberately no RGB intensity oracle.
`timescale 1ps/1ps
module z_text_palette_tb;
    reg cpu_clk=0,video_clk=0,reset=1,enabled=1,rd=0,wr=0,clear_read=0;
    always #15625 cpu_clk=~cpu_clk;
    integer half=11640,hold=1;
    initial begin
        if($value$plusargs("VIDEO_HALF_PS=%d",half)) begin end
        if($value$plusargs("HOLD_EDGES=%d",hold)) begin end
        forever #(half) video_clk=~video_clk;
    end
    reg [15:0] address=0;
    reg [7:0] data=0;
    reg [2:0] video_index=0;
    wire selected,read_hold,video_valid;
    wire [7:0] read_data,held_data;
    wire [5:0] video_bits;
    reg [5:0] expected[0:7];
    x1_z_text_palette dut(.cpu_clk(cpu_clk),.video_clk(video_clk),
        .reset(reset),.video_reset(reset),.enabled(enabled),.io_read(rd),.io_write(wr),
        .clear_read(clear_read),.address(address),.data(data),.selected(selected),
        .read_data(read_data),.read_hold(read_hold),.held_data(held_data),
        .video_index(video_index),.video_bits(video_bits),.video_valid(video_valid));
    task automatic tick;
        @(posedge cpu_clk);#1;@(negedge cpu_clk);
    endtask
    task automatic check_all;
        repeat(40) @(negedge video_clk);
        for(integer c=0;c<8;c=c+1) begin
            video_index=3'(c);#1;
            assert(video_valid && video_bits==expected[c]) else $fatal(1,"torn/wrong raw text entry %0d",c);
            address=16'h1fb8+16'(c);rd=1;tick();
            if(c==0) assert(!selected && read_data==8'hff) else $fatal(1,"entry zero accessible");
            else begin
                assert(selected && read_data[5:0]==expected[c]) else $fatal(1,"CPU text entry %0d failed",c);
                rd=0;tick();
                assert(read_hold && held_data[5:0]==expected[c]) else $fatal(1,"late IN not retained");
            end
            rd=0;clear_read=1;tick();clear_read=0;
            assert(!read_hold) else $fatal(1,"memory/new-I/O tail clear failed");
        end
    endtask
    initial begin
        for(integer c=0;c<8;c=c+1) expected[c]={{2{c[2]}},{2{c[1]}},{2{c[0]}}};
        tick();reset=0;tick();check_all();
        for(integer c=1;c<8;c=c+1) begin
            for(integer value=0;value<64;value=value+1) begin
                address=16'h1fb8+16'(c);data=8'(value)|8'hc0;wr=1;tick();
                expected[c]=6'(value);
                // Every held edge poisons both address and data. No second
                // write may reach another color, including on a mode change.
                address=16'h1fb8+16'((c%7)+1);data=8'hff;
                repeat(hold) tick();wr=0;tick();check_all();
            end
        end
        address=16'h1fb8;data=8'hff;wr=1;tick();wr=0;tick();check_all();
        enabled=0;address=16'h1fb9;wr=1;data=0;tick();enabled=1;
        repeat(hold) tick();wr=0;tick();check_all();
        // A reset-held stale OUT is disarmed until the bus has gone idle.
        reset=1;wr=1;address=16'h1fb9;data=0;repeat(hold) tick();
        assert(!selected && !read_hold && !video_valid && video_bits==0) else $fatal(1,"reset leaked response");
        reset=0;repeat(hold) tick();wr=0;tick();check_all();
        address=16'h1fb9;rd=1;tick();rd=0;tick();
        assert(read_hold) else $fatal(1,"missing pre-pulse response");
        // Between CPU edges: flush the old response without reinitializing
        // storage. This is simulation stress, not a physical pulse-width spec.
        #17;reset=1;#29;
        assert(!read_hold && !video_valid && held_data==8'hff) else $fatal(1,"raw reset pulse failed");
        reset=0;check_all();
        $display("PASS: text cold/zero, seven entries x 64 values, held poisoned OUT, raw snapshot, inactive gate, late IN and retained/disarmed/pulsed reset; half=%0d hold=%0d",half,hold);
        $finish;
    end
endmodule
