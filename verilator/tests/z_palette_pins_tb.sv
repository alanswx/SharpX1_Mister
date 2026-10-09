// Independent table-4-22 pin oracle through real component/palette memories.
// Accepted RAM writes are driven directly; actual Z80 is tested separately.
`timescale 1ps/1ps
module z_palette_pins_tb;
    reg cpu_clk=0,video_clk=0,reset=1,enabled=1,start=0,load=0,step=0;
    always #15625 cpu_clk=~cpu_clk;
    integer half=11640;
    initial begin
        if($value$plusargs("video_half=%d",half)) begin end
        forever #(half) video_clk=~video_clk;
    end
    reg [13:0] base=0;
    reg [14:0] cpu_address=0;
    reg cpu_write=0;
    reg [7:0] bdata=0,rdata=0,gdata=0;
    wire [7:0] bq,rq,gq;
    wire read_enable,valid;
    wire [14:0] read_address;
    wire [11:0] index,rgb;
    wire palette_valid;
    x1_video_ram #(15) blue(cpu_clk,cpu_address,bdata,cpu_write,,video_clk,read_address,bq);
    x1_video_ram #(15) red(cpu_clk,cpu_address,rdata,cpu_write,,video_clk,read_address,rq);
    x1_video_ram #(15) green(cpu_clk,cpu_address,gdata,cpu_write,,video_clk,read_address,gq);
    x1_z_graphics graphics(.clk(video_clk),.reset(reset),.enabled(enabled),
        .character_start(start),.character_load(load),.pixel_step(step),
        .base_address(base),.read_enable(read_enable),.read_address(read_address),
        .mode(3'd0),.screen(1'b0),.raster_odd(1'b0),
        .blue_q(bq),.red_q(rq),.green_q(gq),.palette_index(index),.index_valid(valid),.internal_palette(),
        .paired_screens(),.second_palette_index());
    x1_z_palette_ram palette(.cpu_clk(cpu_clk),.video_clk(video_clk),
        .cpu_reset(reset),.video_reset(reset),.cpu_access(1'b0),.cpu_write(1'b0),
        .cpu_address(12'd0),.cpu_component(2'd0),.cpu_nibble(4'd0),.cpu_data(),.cpu_valid(),
        .display_read(valid),.display_address(index),.display_rgb12(rgb),.display_valid(palette_valid));
    task automatic tick;
        @(posedge video_clk);#1;@(negedge video_clk);
    endtask
    initial begin
        tick();reset=0;
        for(integer color=0;color<4096;color=color+1) begin
            base=14'(color);
            for(integer lane=0;lane<4;lane=lane+1) begin
                @(negedge cpu_clk);
                cpu_address={lane[1],14'(color+(lane[0] ? 1024 : 0))};
                // Independent CPU logical bits from the physical PA table:
                // QHA0 comes from first source byte and connects to DB7.
                bdata={8{color[3-lane]}};
                rdata={8{color[7-lane]}};
                gdata={8{color[11-lane]}};
                cpu_write=1;
                @(posedge cpu_clk);#1;
            end
            @(negedge cpu_clk);cpu_write=0;
            @(negedge video_clk);start=1;tick();start=0;
            repeat(6) tick();load=1;step=1;tick();load=0;step=0;
            for(integer pixel=0;pixel<8;pixel=pixel+1) begin
                tick();
                assert(valid && index==12'(color)) else $fatal(1,"CPU/display pin identity color %h index %h",color,index);
                assert(palette_valid && rgb=={color[7:4],color[11:8],color[3:0]})
                    else $fatal(1,"RGB/palette mismatch color %h RGB %h",color,rgb);
                step=1;tick();step=0;
            end
        end
        $display("PASS: 4096 logical CPU indices x eight pixels through real GRAM/fetch/shifter/palette RAM");
        $finish;
    end
endmodule
