// Original eight-entry palette alias/retention fixture; no native assets.
`timescale 1ps/1ps
module z_internal_palette_tb;
    reg cpu_clk=0,video_clk=0,reset=1,access=0,write_enable=0,display_read=0;
    always #15625 cpu_clk=~cpu_clk;
    integer half=11640,rate=1;
    initial begin
        if($value$plusargs("VIDEO_HALF_PS=%d",half)) begin end
        if($value$plusargs("CE_PERIOD=%d",rate)) begin end
        forever #(half) video_clk=~video_clk;
    end
    reg [11:0] address=0,display_address=0;
    reg [1:0] component=0;
    reg [3:0] nibble=0;
    wire [3:0] data;
    wire valid,display_valid,external_valid;
    wire [11:0] rgb,external_rgb;
    reg [3:0] expected[0:7][0:2];
    x1_z_palette_ram #(.INTERNAL8(1)) dut(
        .cpu_clk(cpu_clk),.video_clk(video_clk),.cpu_reset(reset),.video_reset(reset),
        .cpu_access(access),.cpu_write(write_enable),.cpu_address(address),
        .cpu_component(component),.cpu_nibble(nibble),.cpu_data(data),.cpu_valid(valid),
        .display_read(display_read),.display_address(display_address),
        .display_rgb12(rgb),.display_valid(display_valid));
    x1_z_palette_ram external_store(
        .cpu_clk(cpu_clk),.video_clk(video_clk),.cpu_reset(reset),.video_reset(reset),
        .cpu_access(1'b0),.cpu_write(1'b0),.cpu_address(12'd0),
        .cpu_component(2'd0),.cpu_nibble(4'd0),.cpu_data(),.cpu_valid(),
        .display_read(display_read),.display_address(display_address),
        .display_rgb12(external_rgb),.display_valid(external_valid));
    function automatic [11:0] packed_address(input integer color);
        packed_address=12'(((color&4)<<9)|((color&2)<<6)|((color&1)<<3));
    endfunction
    task automatic cpu_tick;
        @(posedge cpu_clk);#1;@(negedge cpu_clk);
    endtask
    task automatic display_check(input integer color);
        display_address=packed_address(color)^12'h777;
        display_read=1;
        @(posedge video_clk);#1;
        assert(display_valid && rgb=={expected[color][1],expected[color][2],expected[color][0]})
            else $fatal(1,"internal color %0d returned %h",color,rgb);
        assert(external_valid && external_rgb=={display_address[7:4],display_address[11:8],display_address[3:0]})
            else $fatal(1,"internal writes affected external memory");
        @(negedge video_clk);display_read=0;
    endtask
    initial begin
        integer color;
        assert($size(dut.blue)==8 && $size(dut.red)==8 && $size(dut.green)==8)
            else $fatal(1,"internal palette capacity is not eight");
        for(integer c=0;c<8;c=c+1)
            for(integer k=0;k<3;k=k+1) expected[c][k]=(c&(1<<k))!=0 ? 4'd15 : 4'd0;
        cpu_tick();reset=0;
        for(integer c=0;c<8;c=c+1) display_check(c);
        // All ignored physical address combinations and all four-bit values.
        for(integer a=0;a<4096;a=a+1) begin
            color=((a>>9)&4)|((a>>6)&2)|((a>>3)&1);
            for(integer c=0;c<3;c=c+1) begin
                for(integer v=0;v<16;v=v+1) begin
                    address=12'(a);component=2'(c);nibble=4'(v);access=1;write_enable=1;
                    cpu_tick();
                    assert(valid && data==4'(v)) else $fatal(1,"CPU forwarding failed");
                    expected[color][c]=4'(v);access=0;write_enable=0;
                    repeat(rate) cpu_tick();
                    display_check(color);
                end
            end
        end
        // Invalid component and reset-held writes must never modify storage.
        address=12'h888;component=3;access=1;write_enable=1;nibble=0;
        cpu_tick();assert(!valid && data==0) else $fatal(1,"invalid component accepted");
        reset=1;component=0;repeat(4) cpu_tick();
        assert(!valid && !display_valid && data==0 && rgb==0) else $fatal(1,"reset response leaked");
        access=0;write_enable=0;reset=0;
        for(integer c=0;c<8;c=c+1) begin
            for(integer k=0;k<3;k=k+1) begin
                address=packed_address(c);component=2'(k);access=1;cpu_tick();
                assert(valid && data==expected[c][k]) else $fatal(1,"retained CPU data failed");
                access=0;cpu_tick();
            end
            display_check(c);
        end
        $display("PASS: internal eight colors, all 4096 address aliases x three components x 16 nibbles, external isolation, retained reset; half=%0d rate=%0d",half,rate);
        $finish;
    end
endmodule
