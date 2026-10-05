`timescale 1ns/1ps
module turbo_pcg_access_tb;
    reg cpu_clk=0,video_clk=0,reset=1;
    integer video_half=7,window_width=3;
    initial if($value$plusargs("VIDEO_HALF=%d",video_half))
        assert(video_half>0 && video_half<100) else $fatal(1,"bad clock ratio");
    initial if($value$plusargs("WINDOW_WIDTH=%d",window_width))
        assert(window_width>0 && window_width<16) else $fatal(1,"bad window width");
    reg video_run=1;
    always #5 cpu_clk=!cpu_clk;
    always #(video_half) if(video_run) video_clk=!video_clk;
    reg select=0,write_enable=0,high_speed=1,font16_select=0,unsupported=0;
    reg [1:0] plane=0;
    reg [7:0] data=0;
    reg [10:0] beam=0,selected_addr=0;
    reg [11:0] selected_font_addr=0;
    wire [11:0] font_cpu_addr;
    wire [7:0] font_cpu_q,q,access_data,blue,red,green;
    wire [10:0] address;
    wire [2:0] writes;
    wire wait_n;
    wire read_hold;
    reg [7:0] rom_q;
    integer ticks=0,window_mode=2,write_count=0,checks=0;
    wire window_open=window_mode==1 || (window_mode==2 && (ticks%32)>=16 && (ticks%32)<16+window_width);
    always @(posedge video_clk) begin
        if(reset) ticks<=0; else ticks<=ticks+1;
        rom_q<=address[7:0]^8'h5a;
        if(writes!=0) write_count<=write_count+1;
        if(dut.stage==0 && dut.request_sync!=dut.seen && dut.high_speed_request && !window_open)
            assert(writes==0) else $fatal(1,"write before window");
    end
    wire video_reset;
    x1_reset_release release_reset(video_clk,reset,video_reset);
    x1_pcg_access #(.SEPARATE_VIDEO_RESET(1)) dut(reset,cpu_clk,video_clk,select,write_enable,plane,data,
        wait_n,q,beam,address,access_data,writes,rom_q,blue,red,green,
        high_speed,selected_addr,font16_select,unsupported,selected_font_addr,window_open,
        font_cpu_addr,font_cpu_q,read_hold,video_reset);
    x1_video_ram #(11) b(video_clk,address,access_data,writes[0],blue,video_clk,beam,);
    x1_video_ram #(11) r(video_clk,address,access_data,writes[1],red,video_clk,beam,);
    x1_video_ram #(11) g(video_clk,address,access_data,writes[2],green,video_clk,beam,);
    reg load=0;
    reg [24:0] load_address=0;
    reg [7:0] load_data=0;
    wire loaded;
    wire [7:0] display_data;
    x1_font16 font(cpu_clk,video_clk,load,load_address,load_data,12'd0,display_data,loaded,
                   font_cpu_addr,font_cpu_q);
    task transaction(input [10:0] a,input [1:0] p,input w,input [7:0] d,
                     input f,input u,input [11:0] fa,input [7:0] expected);
        integer before_count,elapsed;
        @(negedge cpu_clk);
        high_speed=1; selected_addr=a; plane=p; write_enable=w; data=d;
        font16_select=f; unsupported=u; selected_font_addr=fa; select=1;
        before_count=write_count; elapsed=0;
        #1; assert(!wait_n) else $fatal(1,"missing WAIT");
        @(negedge cpu_clk);
        // All live request fields and beam change after CPU acceptance.
        selected_addr=~a; plane=~p; write_enable=!w; data=~d;
        high_speed=0; font16_select=!f; unsupported=!u; selected_font_addr=~fa; beam=~a;
        while(!wait_n) begin
            @(negedge cpu_clk); elapsed++;
            assert(elapsed<1000) else $fatal(1,"bounded recurring window timeout");
        end
        if(!w) assert(q==expected) else $fatal(1,"read a %x p %d f %d u %d got %x expected %x",a,p,f,u,q,expected);
        assert(read_hold==!w) else $fatal(1,"high-speed CPU response hold qualifier");
        repeat(12) @(negedge cpu_clk);
        assert(wait_n && write_count==before_count+int'(w && p!=0 && !u))
            else $fatal(1,"duplicate/lost/unsupported write");
        select=0;
        repeat(3) @(negedge cpu_clk);
        if(!w) assert(read_hold && q==expected) else $fatal(1,"inactive-strobe read tail lost");
        checks++;
    endtask
    initial begin
        #100000000; $fatal(1,"global timeout");
    end
    initial begin
        repeat(4) @(negedge cpu_clk); reset=0;
        transaction(0,0,0,0,1,0,0,0); // unloaded ANK16 is blank
        for(integer a=0;a<4096;a++) begin
            @(negedge cpu_clk); load=1; load_address=25'(a); load_data=8'(a^(a>>8)^8'ha6);
        end
        @(negedge cpu_clk); load=0;
        repeat(4) @(negedge cpu_clk);
        assert(loaded) else $fatal(1,"font load");
        repeat(4) @(negedge video_clk);
        assert(display_data==8'ha6) else $fatal(1,"display/CPU font ports conflict");
        // Exhaust each physical plane, proving single writes and address isolation.
        for(integer p=1;p<4;p++) begin
            for(integer a=0;a<2048;a++) transaction(11'(a),2'(p),1,8'(a^(a>>8)^(p*37)),0,0,0,0);
            for(integer a=0;a<2048;a++) transaction(11'(a),2'(p),0,0,0,0,0,8'(a^(a>>8)^(p*37)));
        end
        for(integer a=0;a<4096;a++) transaction(0,0,0,0,1,0,12'(a),8'(a^(a>>8)^8'ha6));
        transaction(11'h7ff,0,0,0,0,0,0,8'ha5);
        transaction(11'h7ff,0,1,255,0,0,0,0);
        transaction(11'h7ff,0,0,0,0,0,0,8'ha5);
        transaction(0,0,1,255,1,0,12'hfff,0);
        transaction(0,0,0,0,1,0,12'hfff,8'h56);
        transaction(0,0,0,0,0,1,0,255);
        transaction(0,1,1,255,0,1,0,0);
        transaction(0,1,0,0,0,0,0,37);
        assert(display_data==8'ha6) else $fatal(1,"CPU reads disturbed display port");
        // Stop the destination clock before it can observe a new request.
        @(negedge video_clk); video_run=0;
        @(negedge cpu_clk); high_speed=1; select=1; write_enable=0; plane=1;
        selected_addr=0; unsupported=0;
        repeat(30) @(negedge cpu_clk);
        assert(!wait_n) else $fatal(1,"completion with stopped destination clock");
        video_run=1;
        wait(wait_n);
        @(negedge cpu_clk);
        assert(q==37) else $fatal(1,"clock-resume response");
        select=0;
        repeat(3) @(negedge cpu_clk);
        // No HSYNC: cannot complete or write. Reset cancels waiting requests.
        window_mode=0;
        @(negedge cpu_clk); high_speed=1; select=1; write_enable=1; plane=1; unsupported=0;
        repeat(30) @(negedge cpu_clk);
        assert(!wait_n && dut.stage==0) else $fatal(1,"completion outside window");
        reset=1; select=0;
        repeat(4) @(negedge cpu_clk); reset=0; window_mode=1;
        begin
            integer before_count;
            before_count=write_count;
            repeat(20) @(negedge cpu_clk);
            assert(wait_n && write_count==before_count && loaded) else $fatal(1,"stale write or font lost on reset");
        end
        transaction(0,0,0,0,1,0,12'hfff,8'h56);
        // Reset each RAM/response staging state; allow already completed writes.
        for(integer s=1;s<=2;s++) begin
            @(negedge cpu_clk); high_speed=1; select=1; write_enable=1; plane=2;
            data=8'h55; selected_addr=11'h321; unsupported=0;
            wait(dut.stage==2'(s));
            @(negedge video_clk); reset=1; select=0;
            repeat(4) @(negedge cpu_clk); reset=0;
            begin
                integer before_count;
                before_count=write_count;
                repeat(20) @(negedge cpu_clk);
                assert(wait_n && write_count==before_count) else $fatal(1,"stale staged write");
            end
        end
        // Reset after the video ACK but before its CPU synchronizers consume it.
        @(negedge cpu_clk); high_speed=1; select=1; write_enable=0; plane=1;
        selected_addr=0; unsupported=0;
        @(negedge cpu_clk);
        wait(dut.busy && dut.ack==dut.request);
        reset=1; select=0;
        repeat(4) @(negedge cpu_clk); reset=0;
        repeat(20) @(negedge cpu_clk);
        assert(wait_n && !read_hold && q==255 && loaded)
            else $fatal(1,"stale ACK/response after reset");
        transaction(0,1,0,0,0,0,0,37);
        $display("PASS: %0d high-speed CDC transactions, all PCG/font bytes, frozen bundle/window/held bus/reset",checks);
        $finish;
    end
endmodule
