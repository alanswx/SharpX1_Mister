// Original shifter-level fixture; synchronous source model, not native CRTC.
`timescale 1ps/1ps
module z_graphics_tb;
    reg clk=0,reset=1,enabled=0,start=0,load=0,step=0;
    reg [13:0] base=0;
    wire read_enable,valid;
    wire [14:0] address;
    wire [11:0] index;
    reg [7:0] b=0,r=0,g=0;
    integer half=11640;
    initial begin
        if($value$plusargs("video_half=%d",half)) begin end
        forever #(half) clk=~clk;
    end
    function automatic [7:0] source(input [14:0] a,input integer c);
        source=8'((int'(a)*37) ^ (int'(a)>>7) ^ (c*83) ^ (a[14] ? 32'hD3 : 32'h29));
    endfunction
    always @(posedge clk) begin
        b<=source(address,0);r<=source(address,1);g<=source(address,2);
    end
    x1_z_graphics dut(.clk(clk),.reset(reset),.enabled(enabled),
        .character_start(start),.character_load(load),.pixel_step(step),
        .base_address(base),.read_enable(read_enable),.read_address(address),
        .blue_q(b),.red_q(r),.green_q(g),.palette_index(index),.index_valid(valid));
    task automatic tick;
        @(posedge clk);#1;@(negedge clk);
    endtask
    task automatic character(input [13:0] a);
        reg [11:0] expected;
        reg [7:0] byte_value;
        reg [13:0] q;
        reg [14:0] lane_address;
        base=a;start=1;tick();start=0;
        repeat(6) tick();
        load=1;step=1;tick();load=0;step=0;
        assert(valid) else $fatal(1,"missing complete character");
        for(integer pixel=0;pixel<8;pixel=pixel+1) begin
            expected=0;
            for(integer lane=0;lane<4;lane=lane+1) begin
                q=a+(lane[0] ? 14'h400 : 14'd0);
                lane_address={lane[1],q};
                for(integer component=0;component<3;component=component+1) begin
                    byte_value=source(lane_address,component);
                    // Independent CPU/PA table oracle: PA[c*4+lane]
                    // corresponds to logical CPU index[c*4+3-lane].
                    expected[component*4+3-lane]=byte_value[7-pixel];
                end
            end
            assert(index==expected) else $fatal(1,"index %h != %h at base %h pixel %0d",index,expected,a,pixel);
            // Held physical edges must not shift without a pixel enable.
            repeat(2) tick();
            assert(index==expected) else $fatal(1,"shift without enable");
            step=1;tick();step=0;
        end
    endtask
    initial begin
        tick();reset=0;enabled=1;
        for(integer a=0;a<16384;a=a+1) character(14'(a));
        // Incomplete mode-entry load must never reuse a previous character.
        enabled=0;tick();enabled=1;load=1;tick();load=0;
        assert(!valid && index==0) else $fatal(1,"stale character after mode exit");
        base=14'h3fff;start=1;tick();start=0;tick();
        reset=1;tick();reset=0;
        assert(!valid && !read_enable && index==0) else $fatal(1,"pending reset failed");
        character(14'h3fff);
        $display("PASS: all 16384 bases x 8 pixels x 12 bits, held enables, mode exit, pending reset");
        $finish;
    end
endmodule
