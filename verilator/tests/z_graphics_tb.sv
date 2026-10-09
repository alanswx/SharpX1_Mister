// Original shifter-level fixture; synchronous source model, not native CRTC.
`timescale 1ps/1ps
module z_graphics_tb;
    reg clk=0,reset=1,enabled=0,start=0,load=0,step=0;
    reg [13:0] base=0;
    reg [2:0] mode=0;
    reg screen=0,odd=0;
    wire read_enable,valid,internal_palette,paired_screens;
    wire [14:0] address;
    wire [11:0] index,second_index;
    reg [7:0] b=0,r=0,g=0;
    reg pair_fixture=0;
    reg [5:0] bank0_color=0,bank1_color=0;
    integer half=11640;
    initial begin
        if($value$plusargs("video_half=%d",half)) begin end
        forever #(half) clk=~clk;
    end
    function automatic [7:0] source(input [14:0] a,input integer c);
        reg [5:0] color;
        color=a[14] ? bank1_color : bank0_color;
        if(pair_fixture) source={8{color[c*2+(a[10] ? 0 : 1)]}};
        else source=8'((int'(a)*37) ^ (int'(a)>>7) ^ (c*83) ^ (a[14] ? 32'hD3 : 32'h29));
    endfunction
    function automatic [11:0] expanded_color(input [5:0] color);
        expanded_color={color[5:4],color[5:4],color[3:2],color[3:2],color[1:0],color[1:0]};
    endfunction
    always @(posedge clk) begin
        b<=source(address,0);r<=source(address,1);g<=source(address,2);
    end
    x1_z_graphics dut(.clk(clk),.reset(reset),.enabled(enabled),
        .character_start(start),.character_load(load),.pixel_step(step),
        .base_address(base),.read_enable(read_enable),.read_address(address),
        .mode(mode),.screen(screen),.raster_odd(odd),
        .blue_q(b),.red_q(r),.green_q(g),.palette_index(index),.index_valid(valid),.internal_palette(internal_palette),
        .paired_screens(paired_screens),.second_palette_index(second_index));
    task automatic tick;
        @(posedge clk);#1;@(negedge clk);
    endtask
    task automatic character(input [13:0] a,input bit disturb=0);
        reg [11:0] expected,expected_second;
        reg [7:0] byte_value;
        reg [13:0] q;
        reg [14:0] lane_address;
        reg [2:0] accepted_mode;
        reg accepted_screen,accepted_odd;
        accepted_mode=mode;accepted_screen=screen;accepted_odd=odd;
        base=a;start=1;tick();start=0;
        repeat(6) begin
            if(disturb) begin
                mode=mode==4 ? 0 : mode+3'd1;
                screen=~screen;odd=~odd;base=base+14'h719;
            end
            tick();
        end
        load=1;step=1;tick();load=0;step=0;
        assert(valid) else $fatal(1,"missing complete character");
        assert(internal_palette==(accepted_mode==4)) else $fatal(1,"wrong captured palette store");
        assert(paired_screens==(accepted_mode==5)) else $fatal(1,"wrong captured screen count");
        for(integer pixel=0;pixel<8;pixel=pixel+1) begin
            expected=0;expected_second=0;
            for(integer lane=0;lane<4;lane=lane+1) begin
                q=a+((accepted_mode==0 || accepted_mode==1 || accepted_mode==3 || accepted_mode==5) && lane[0] ? 14'h400 : 14'd0);
                lane_address={(accepted_mode==0 || accepted_mode==5) ? lane[1] : accepted_mode==2 ? lane[0] : accepted_mode==1 ? accepted_screen : accepted_odd,q};
                for(integer component=0;component<3;component=component+1) begin
                    byte_value=source(lane_address,component);
                    // Independent CPU/PA table oracle: PA[c*4+lane]
                    // corresponds to logical CPU index[c*4+3-lane].
                    if(accepted_mode==0) expected[component*4+3-lane]=byte_value[7-pixel];
                    else if(accepted_mode==4 && lane==0) expected[component*4+3]=byte_value[7-pixel];
                    else if(accepted_mode!=4 && lane<2) begin
                        expected[component*4+3-lane]=byte_value[7-pixel];
                        expected[component*4+1-lane]=byte_value[7-pixel];
                    end
                    if(accepted_mode==5 && lane>=2) begin
                        expected_second[component*4+3-(lane%2)]=byte_value[7-pixel];
                        expected_second[component*4+1-(lane%2)]=byte_value[7-pixel];
                    end
                end
            end
            assert(index==expected) else $fatal(1,"index %h != %h at base %h pixel %0d",index,expected,a,pixel);
            assert(second_index==expected_second) else $fatal(1,"second screen %h != %h at base %h pixel %0d",second_index,expected_second,a,pixel);
            if(pair_fixture) begin
                assert(index==expanded_color(bank0_color) && second_index==expanded_color(bank1_color))
                    else $fatal(1,"independent six-bit color-pair oracle");
            end
            assert(paired_screens==(accepted_mode==5)) else $fatal(1,"live mode redirected paired screens");
            assert(internal_palette==(accepted_mode==4)) else $fatal(1,"live mode redirected palette store");
            if(disturb) begin
                mode=mode==4 ? 0 : mode+3'd1;
                screen=~screen;odd=~odd;base=base+14'h719;
            end
            // Held physical edges must not shift without a pixel enable.
            repeat(2) tick();
            assert(index==expected) else $fatal(1,"shift without enable");
            assert(second_index==expected_second) else $fatal(1,"second-screen shift without enable");
            step=1;tick();step=0;
        end
        mode=accepted_mode;screen=accepted_screen;odd=accepted_odd;
    endtask
    initial begin
        tick();reset=0;enabled=1;
        for(integer m=0;m<6;m=m+1) begin
            mode=3'(m);
            for(integer page=0;page<(m==1 || m==3 || m==4 || m==5 ? 2 : 1);page=page+1) begin
                screen=page[0];odd=page[0];
                for(integer a=0;a<16384;a=a+1) character(14'(a));
            end
        end
        // Every independent six-bit screen-color pair. Constant per-screen
        // bytes deliberately distinguish a swapped/ORed/aliased second bank.
        pair_fixture=1;mode=5;
        for(integer first=0;first<64;first=first+1) begin
            for(integer second=0;second<64;second=second+1) begin
                bank0_color=6'(first);bank1_color=6'(second);
                screen=first[0];odd=second[0];character(14'd0,1);
            end
        end
        pair_fixture=0;
        // Change every live fetch control after acceptance, during RAM reads,
        // before load and between pixels. Only the captured request may win.
        for(integer m=0;m<6;m=m+1) begin
            for(integer page=0;page<2;page=page+1) begin
                mode=3'(m);screen=page[0];odd=page[0];
                character(14'h3f93,1);
            end
        end
        // Incomplete mode-entry load must never reuse a previous character.
        enabled=0;tick();enabled=1;load=1;tick();load=0;
        assert(!valid && index==0 && !paired_screens && second_index==0) else $fatal(1,"stale character after mode exit");
        base=14'h3fff;start=1;tick();start=0;tick();
        reset=1;tick();reset=0;
        assert(!valid && !read_enable && index==0 && !paired_screens && second_index==0) else $fatal(1,"pending reset failed");
        character(14'h3fff);
        $display("PASS: six layouts x all 16384 bases x 8 pixels, all 64x64 independent paired colors, selected pages/parity, live-control mutation, held enables, mode exit, pending reset");
        $finish;
    end
endmodule
