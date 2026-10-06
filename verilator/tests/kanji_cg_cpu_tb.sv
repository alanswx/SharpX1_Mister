// SPDX-License-Identifier: GPL-2.0-only
// Original Z80-executed high-speed Kanji CG diagnostic. Synthetic ROM only;
// no monitor code, forced CPU/chip state or test-injected result stores.
`timescale 1ps/1ps
module kanji_cg_cpu_tb;
    logic clk=0,video_clk=0,reset=1,ce=0;
    integer period=4,phase=0,video_half_ps=17500,pc=0,edges=0,wait_edges=0,completed=0;
    always #15625 clk=!clk;
    always #(video_half_ps) video_clk=!video_clk;
    always @(negedge clk) begin phase++;ce=!reset && phase%period==0;end
    wire video_reset;
    x1_reset_release release_reset(video_clk,reset,video_reset);
    wire [15:0] a;
    wire [7:0] data_out;
    wire mreq,iorq,rd,wr,m1,halt_n,busak_n,rfsh_n;
    logic [7:0] memory[0:65535];
    logic [7:0] memory_data=0,io_data=0;
    logic io_active=0;
    wire [7:0] cg_q;
    wire wait_n,read_hold;
    wire io_write=!reset && !iorq && !wr && m1;
    wire io_read=!reset && !iorq && !rd && m1;
    wire cg_access=(io_read || io_write) && a[15:10]==6'b000101;
    wire [7:0] response=cg_access && !rd ? cg_q : io_active && mreq ? io_data : memory_data;
    cpu processor(
        .clock(clk),.cep(ce),.cen(1'b0),.reset_n(!reset),.int_n(1'b1),
        .wait_n(wait_n),.busrq_n(1'b1),.busak_n(busak_n),.di(response),.a(a),
        .data_out(data_out),.mreq(mreq),.iorq(iorq),.rd(rd),.wr(wr),.m1(m1),
        .halt_n(halt_n),.rfsh_n(rfsh_n),.dir(16'd0),.dirset(1'b0)
    );
    wire [10:0] selected_addr;
    wire [11:0] selected_font_addr;
    wire selected_font16,selected_unsupported,selected_kanji;
    wire [16:0] selected_kanji_addr,kanji_cpu_addr;
    x1_pcg_selector #(.KANJI_SUPPORT(1)) selector(
        .clk(clk),.text_write(io_write && a[15:12]==4'h3 && !a[11]),
        .attr_write(io_write && a[15:12]==4'h2),.kan_write(io_write && a[15:11]==5'b00111),
        .address(a[10:0]),.data(data_out),.nibble(a[3:0]),.plane(a[9:8]),
        .font16_mode(1'b1),.byte_address(selected_addr),.font_address(selected_font_addr),
        .font16_select(selected_font16),.unsupported(selected_unsupported),
        .kanji_select(selected_kanji),.kanji_address(selected_kanji_addr)
    );
    wire loaded,load_error,kanji_cpu_read,kanji_cpu_valid;
    wire [7:0] kanji_cpu_q;
    wire [2:0] access_write;
    integer video_ticks=0;
    always @(posedge video_clk) if(video_reset) video_ticks<=0;else video_ticks++;
    wire video_window=video_ticks%32>=16 && video_ticks%32<19;
    x1_pcg_access #(.KANJI_SUPPORT(1),.SEPARATE_VIDEO_RESET(1)) adapter(
        .reset(reset),.cpu_clk(clk),.video_clk(video_clk),.video_reset(video_reset),
        .cpu_select(cg_access),.cpu_write(io_write),.cpu_plane(a[9:8]),.cpu_data(data_out),
        .wait_n(wait_n),.cpu_q(cg_q),.beam_addr(11'd0),.access_addr(),.access_data(),
        .access_write(access_write),.rom_q(8'h32),.blue_q(8'h43),.red_q(8'h54),.green_q(8'h65),
        .high_speed(1'b1),.selected_addr(selected_addr),.selected_font16(selected_font16),
        .selected_unsupported(selected_unsupported),.selected_font_addr(selected_font_addr),
        .video_window(video_window),.font_cpu_addr(),.font_cpu_q(8'ha6),.cpu_read_hold(read_hold),
        .selected_kanji(selected_kanji),.selected_kanji_addr(selected_kanji_addr),
        .kanji_available(loaded),.kanji_cpu_valid(kanji_cpu_valid),.kanji_cpu_q(kanji_cpu_q),
        .kanji_cpu_addr(kanji_cpu_addr),.kanji_cpu_read(kanji_cpu_read)
    );
    logic upload=0,load=0;
    logic [24:0] load_address=0;
    logic [7:0] load_data=0;
    x1_kanji_rom rom(
        .cpu_clk(clk),.video_clk(video_clk),.cpu_reset(reset),.video_reset(video_reset),
        .upload(upload),.load(load),.load_address(load_address),.load_data(load_data),
        .cpu_read(kanji_cpu_read),.cpu_address(kanji_cpu_addr),.cpu_data(kanji_cpu_q),
        .cpu_valid(kanji_cpu_valid),.display_select(1'b0),.display_address(17'd0),
        .display_data(),.display_valid(),.loaded(loaded),.load_error(load_error)
    );
    always @(posedge clk) begin
        memory_data<=memory[a];
        if(reset) begin io_active<=0;io_data<=0;end
        else begin
            edges++;
            assert(edges<8000000) else $fatal(1,"CPU watchdog a=%h marker=%h",a,memory[16'hf000]);
            if(!mreq && !rd) io_active<=0;
            else if(io_read) begin io_active<=1;io_data<=cg_q;end
            if(!mreq && !wr) memory[a]<=data_out;
            if(ce && !wait_n) wait_edges++;
            assert(busak_n && access_write==0) else $fatal(1,"unexpected grant or PCG write");
            if(adapter.busy && adapter.ack_sync==adapter.request &&
               (!adapter.kanji_request || adapter.kanji_absent || adapter.write_request || kanji_cpu_valid))
                completed++;
        end
    end
    function automatic logic [7:0] pattern(input integer address);
        return 8'(address*37+(address>>8)*13+(address>>16)*211+19);
    endfunction
    function automatic logic [10:0] cell_address(input integer index);
        return index==0 ? 11'h7ff : index==1 ? 11'h3ff : index==2 ? 11'h5ff : 11'h1ff;
    endfunction
    task automatic emit(input logic [7:0] value);memory[pc]=value;pc++;endtask
    task automatic port(input logic [15:0] value);emit(8'h01);emit(value[7:0]);emit(value[15:8]);endtask
    task automatic output_byte(input logic [15:0] target,input logic [7:0] value);
        port(target);emit(8'h3e);emit(value);emit(8'hed);emit(8'h79);
    endtask
    task automatic equal(input logic [15:0] target,input logic [7:0] value);
        port(target);emit(8'hed);emit(8'h78);emit(8'hfe);emit(value);
        emit(8'hc2);emit(8'h00);emit(8'hf1); // JP NZ,F100 (original failure handler)
    endtask
    task automatic tick;@(negedge clk);#1;endtask
    integer glyph,physical,expected_reads=0,before_completed;
    initial begin
        if($value$plusargs("CE_PERIOD=%d",period)) begin end
        if($value$plusargs("VIDEO_HALF_PS=%d",video_half_ps)) begin end
        for(integer index=0;index<65536;index++) memory[index]=0;
        emit(8'hf3);emit(8'h31);emit(8'hff);emit(8'hff);
        // Populate all bounded candidates by actual CPU OUT instructions.
        for(integer index=0;index<4;index++) begin
            output_byte(16'(16'h3000+int'(cell_address(index))),0);
            output_byte(16'(16'h3800+int'(cell_address(index))),0);
            output_byte(16'(16'h2000+int'(cell_address(index))),7);
        end
        for(integer half=0;half<2;half++)
        for(integer bank=0;bank<16;bank++)
        for(integer g=0;g<5;g++) begin
            glyph=g==0 ? 0 : g==1 ? 1 : g==2 ? 127 : g==3 ? 128 : 255;
            output_byte(16'h3fff,8'(128+half*64+bank));
            output_byte(16'h37ff,8'(glyph));output_byte(16'h27ff,7);
            for(integer row=0;row<16;row++) begin
                physical=half*65536+bank*4096+glyph*16+row;
                equal(16'(16'h1400+row),pattern(physical));expected_reads++;
            end
        end
        // Level 2 stays unsupported; ANK exit dispatches to the ANK backend.
        output_byte(16'h3fff,8'h90);equal(16'h1400,8'hff);expected_reads++;
        output_byte(16'h3fff,0);equal(16'h1403,8'ha6);expected_reads++;
        // Return to first-level Kanji after mode exit without reloading ROM.
        output_byte(16'h3fff,8'hcf);equal(16'h140f,pattern(131071));expected_reads++;
        // Monitor-style INI stores real bytes into RAM, with B decrement
        // compensated before the next row. This exercises block-I/O timing,
        // not just isolated IN A,(C) instructions or host-side readback.
        port(16'h1400);emit(8'h21);emit(8'h00);emit(8'hd0);
        for(integer row=0;row<16;row++) begin
            emit(8'hed);emit(8'ha2);emit(8'h04);emit(8'h0c);expected_reads++;
        end
        for(integer row=0;row<16;row++) begin
            emit(8'h3a);emit(8'(row));emit(8'hd0);
            emit(8'hfe);emit(pattern(131056+row));emit(8'hc2);emit(8'h00);emit(8'hf1);
        end
        assert(pc<16'hd000) else $fatal(1,"diagnostic overlaps block-I/O result RAM");
        emit(8'h3e);emit(8'ha5);emit(8'h32);emit(8'h00);emit(8'hf0);emit(8'h76);
        pc=32'hf100;emit(8'h3e);emit(8'hee);emit(8'h32);emit(8'h00);emit(8'hf0);emit(8'h76);
        repeat(5) tick();upload=1;
        for(integer address=0;address<131072;address++) begin
            tick();load=1;load_address=25'(address);load_data=pattern(address);
        end
        tick();load=0;upload=0;tick();
        assert(loaded && !load_error) else $fatal(1,"CPU diagnostic ROM upload");
        // Two native CPU runs, including retained ROM/selector warm reset.
        for(integer run=0;run<2;run++) begin
            before_completed=completed;reset=0;
            wait(!halt_n);tick();
            assert(memory[16'hf000]==8'ha5 && completed-before_completed==expected_reads && wait_edges>0)
                else $fatal(1,"CPU assertions failed run=%0d marker=%h transfers=%0d/%0d a=%h",
                            run,memory[16'hf000],completed-before_completed,expected_reads,a);
            reset=1;repeat(5) tick();
            assert(loaded && !kanji_cpu_read && !read_hold && cg_q==8'hff)
                else $fatal(1,"warm reset lost ROM or retained CPU response");
        end
        $display("PASS actual Z80 Kanji CG: CE=%0d video half=%0d ps, %0d native IN/INI assertions per cold/warm run, all banks/halves/rows, level2 rejection and ANK exit",period,video_half_ps,expected_reads);
        $finish;
    end
endmodule
