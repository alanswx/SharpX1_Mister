// SPDX-License-Identifier: GPL-2.0-or-later
// Original generated-IPL diagnostic for the default-off FM-board CTC
// (0704-0707) and its interrupt chain (FM CTC > main CTC > keyboard).
// Real Z80 IM2: FM ch0 timer, FM ch3 cascaded from ZC0, main CTC ch1 timer
// whose ISR re-enables interrupts so FM interrupts nest inside it.
// No private assets/state. Not native CZ-8BS1 timing or chain-order proof.
`timescale 1ps/1ps
module machine_fm_ctc_tb #(parameter FM_CTC=1, SINGLE_CLOCK=0, MASTER_HZ=32000000);
    localparam longint unsigned HALF_PS=64'd500000000000/64'(MASTER_HZ);
    reg clk=0,video_clk=0,reset=1;
    always #(HALF_PS) clk=~clk;
    always #17500 video_clk=~video_clk;
    reg download=0,upload_wr=0;
    reg [24:0] upload_address=0;
    reg [7:0] upload_data=0;
    wire upload_wait;
    sharpx1 #(.TURBO(1),.TURBO_FM_CPU(1),.TURBO_FM_CTC(FM_CTC),
        .SINGLE_CLOCK(SINGLE_CLOCK),.MASTER_HZ(MASTER_HZ)) dut(
        .clk_sys(clk),.clk_28636(SINGLE_CLOCK ? clk : video_clk),.reset(reset),
        .pal(1'b0),.scandouble(1'b0),.ioctl_download(download),.ioctl_index(8'd0),
        .ioctl_wr(upload_wr),.ioctl_addr(upload_address),.ioctl_dout(upload_data),.ioctl_wait(upload_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .tape_mount(1'b0),.tape_present(1'b0),.tape_empty(1'b0),
        .tape_sample_valid(1'b0),.tape_sample_level(1'b0),.tape_sample_last(1'b0),.tape_sample_hz(18'd0),
        .tape_sample_ready(),.tape_underflow(),.tape_mode(),.tape_sensor(),
        .sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),.sio_rxd(2'b11),
        .sio_cts_n(2'b11),.sio_dcd_n(2'b11),.sio_txd(),.sio_rts_n(),.sio_dtr_n(),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),.disk_raw(1'b0),.disk_raw_b(1'b0),
        .sd_drive(),.sd_lba(),.sd_rd(),.sd_wr(),.sd_ack(1'b0),.sd_buff_addr(9'd0),
        .sd_buff_dout(8'd0),.sd_buff_din(),.sd_buff_wr(1'b0),.ce_pix(),.HBlank(),
        .HSync(),.VBlank(),.VSync(),.video(),.rgb(),.rgb12(),.audio(),
        .audio_left(),.audio_right(),.audio_mono(),.audio_sample());
    reg [7:0] program_bytes[0:8191];
    integer pc=0;
    task automatic emit(input [7:0] value);program_bytes[pc]=value;pc++;endtask
    task automatic emit16(input [15:0] value);emit(value[7:0]);emit(value[15:8]);endtask
    task automatic load(input [7:0] value);emit(8'h3e);emit(value);endtask
    task automatic port(input [15:0] value);emit(8'h01);emit16(value);endtask
    task automatic store(input [15:0] value);emit(8'h32);emit16(value);endtask
    task automatic out_byte(input [7:0] value);load(value);emit(8'hed);emit(8'h79);endtask
    task automatic out_to(input [15:0] address,input [7:0] value);port(address);out_byte(value);endtask
    task automatic in_store(input [15:0] address,input [15:0] destination);
        port(address);emit(8'hed);emit(8'h78);store(destination);
    endtask
    task automatic mark(input [7:0] value);load(value);store(16'h4000);endtask
    task automatic delay(input [7:0] count);emit(8'h06);emit(count);emit(8'h10);emit(8'hfe);endtask
    // Counting ISR: PUSH AF/HL, INC (counter), POP, EI, RETI.
    task automatic counting_isr(input [15:0] counter);
        emit(8'hf5);emit(8'he5);emit(8'h21);emit16(counter);emit(8'h34);
        emit(8'he1);emit(8'hf1);emit(8'hfb);emit(8'hed);emit(8'h4d);
    endtask
    task automatic tick;@(posedge clk);#1;endtask

    // Bus observers: count RETIs routed per CTC, check the vector on each ACK.
    integer fm_acks=0,main_acks=0,fm_retis=0,main_retis=0,max_depth=0;
    bit fm_idle=0;
    generate if (FM_CTC) begin : observe
        always @(posedge clk) fm_idle<=dut.fm_board_ctc.fm_ctc.in_service==0 &&
            dut.fm_irq_chain.irq_bridge.fm_depth==0;
        always @(posedge clk) if(!dut.core_reset) begin
            if(dut.fm_ctc_ack) fm_acks++;
            if(dut.ctc_ack) main_acks++;
            if(dut.fm_ctc_reti) fm_retis++;
            if(dut.ctc_reti) main_retis++;
            if(int'(dut.fm_irq_chain.irq_bridge.fm_depth) > max_depth)
                max_depth=int'(dut.fm_irq_chain.irq_bridge.fm_depth);
            if(dut.fm_ctc_ack) assert(dut.irq_vector[7:3]==5'h04)
                else $fatal(1,"FM CTC acknowledge vector %h",dut.irq_vector);
            if(dut.ctc_ack) assert(dut.irq_vector==8'h42)
                else $fatal(1,"main CTC acknowledge vector %h",dut.irq_vector);
        end
    end endgenerate

    initial begin
        for(integer i=0;i<8192;i++) program_bytes[i]=8'h00;
        // Vector table at 1020 (FM CTC ch0..3) and 1040 (main CTC ch0..3).
        program_bytes[16'h1020]=8'h00;program_bytes[16'h1021]=8'h08; // FM ch0 -> 0800
        program_bytes[16'h1026]=8'h20;program_bytes[16'h1027]=8'h08; // FM ch3 -> 0820
        program_bytes[16'h1042]=8'h40;program_bytes[16'h1043]=8'h08; // main ch1 -> 0840
        pc=16'h0800;counting_isr(16'h9000);
        pc=16'h0820;counting_isr(16'h9001);
        // Main CTC ISR: EI early, spin ~640 us so FM interrupts nest, count
        // nested FM ch0 interrupts seen during the spin, RETI.
        pc=16'h0840;
        emit(8'hf5);emit(8'he5);emit(8'hc5);emit(8'hfb);          // PUSH AF/HL/BC; EI
        emit(8'h3a);emit16(16'h9000);emit(8'h4f);                 // LD A,(9000); LD C,A
        delay(0);                                                // ~2560 T
        emit(8'h3a);emit16(16'h9000);emit(8'hb9);                 // LD A,(9000); CP C
        emit(8'h28);emit(8'h04);                                  // JR Z,+4
        emit(8'h21);emit16(16'h9003);emit(8'h34);                 // LD HL,9003; INC (HL)
        emit(8'h21);emit16(16'h9002);emit(8'h34);                 // LD HL,9002; INC (HL)
        emit(8'hc1);emit(8'he1);emit(8'hf1);emit(8'hfb);emit(8'hed);emit(8'h4d);
        pc=0;
        emit(8'hf3);emit(8'h31);emit16(16'hff00);mark(0);          // DI; LD SP,FF00
        emit(8'haf);for(integer i=0;i<4;i++) store(16'h9000+16'(i)); // clear counters
        emit(8'hed);emit(8'h5e);load(8'h10);emit(8'hed);emit(8'h47); // IM 2; I=10
        // FM board detection-style probe: ch2 timer without interrupt, read twice.
        out_to(16'h0706,8'h05);out_to(16'h0706,8'hff);
        delay(8'h20);in_store(16'h0706,16'h4110);
        delay(8'h20);in_store(16'h0706,16'h4111);
        mark(1);
        out_to(16'h0704,8'h20);                                  // FM vector base 20
        out_to(16'h0704,8'h87);out_to(16'h0704,8'h40);            // ch0 timer /16, TC 64, int
        out_to(16'h0707,8'hc7);out_to(16'h0707,8'h04);            // ch3 counter, TC 4, int
        out_to(16'h1fa0,8'h40);                                  // main vector base 40
        out_to(16'h1fa1,8'ha7);out_to(16'h1fa1,8'h40);            // ch1 timer /256, TC 64, int (~4.1 ms)
        mark(2);emit(8'hfb);                                     // EI
        // Wait for >=60 FM ch0 interrupts and >=2 main CTC interrupts.
        begin
            integer loop1,loop2;
            loop1=pc;emit(8'h3a);emit16(16'h9000);emit(8'hfe);emit(8'd60);
            emit(8'h38);emit(8'(loop1-(pc+1)));
            loop2=pc;emit(8'h3a);emit16(16'h9002);emit(8'hfe);emit(8'd2);
            emit(8'h38);emit(8'(loop2-(pc+1)));
        end
        emit(8'hf3);                                             // DI
        out_to(16'h0704,8'h03);out_to(16'h0707,8'h03);out_to(16'h1fa1,8'h03); // stop channels
        for(integer i=0;i<4;i++) begin emit(8'h3a);emit16(16'h9000+16'(i));store(16'h4120+16'(i));end
        mark(8'haa);emit(8'h76);
        assert(pc<16'h0800) else $fatal(1,"FM CTC generated IPL overflow");

        for(integer i=0;i<8192;i++) begin
            @(negedge clk);#1;download=1;upload_wr=1;upload_address=25'(i);upload_data=program_bytes[i];
            tick();
        end
        @(negedge clk);#1;download=0;upload_wr=0;repeat(16) tick();reset=0;
        wait(dut.RAM.mem[16'h4000]==1);
        assert(dut.RAM.mem[16'h4110]!=8'hff && dut.RAM.mem[16'h4111]!=8'hff &&
               dut.RAM.mem[16'h4110]!=dut.RAM.mem[16'h4111])
            else $fatal(1,"FM CTC probe absent %h/%h",dut.RAM.mem[16'h4110],dut.RAM.mem[16'h4111]);
        wait(dut.RAM.mem[16'h4000]==8'haa && !dut.halt_n);
        repeat(256) tick();
        begin
            integer ch0,ch3,main,nested;
            ch0=int'(dut.RAM.mem[16'h4120]);ch3=int'(dut.RAM.mem[16'h4121]);
            main=int'(dut.RAM.mem[16'h4122]);nested=int'(dut.RAM.mem[16'h4123]);
            assert(ch0>=60 && main>=2 && nested>=1 && (ch3*4-ch0)<=4 && (ch0-ch3*4)<=4)
                else $fatal(1,"FM CTC interrupt counts ch0=%0d ch3=%0d main=%0d nested=%0d",ch0,ch3,main,nested);
            assert(fm_acks==ch0+ch3 && main_acks==main && fm_retis==fm_acks && main_retis==main_acks && max_depth>=1)
                else $fatal(1,"FM chain ACK/RETI routing fm=%0d/%0d main=%0d/%0d depth=%0d",
                    fm_acks,fm_retis,main_acks,main_retis,max_depth);
            assert(fm_idle && dut.ctc.in_service==0)
                else $fatal(1,"FM chain left a channel in service");
            $display("PASS FM-board CTC MASTER=%0d single=%0d: probe %h/%h, IM2 ch0=%0d ch3=%0d main=%0d nested=%0d, ACK/RETI routed exactly",
                MASTER_HZ,SINGLE_CLOCK,dut.RAM.mem[16'h4110],dut.RAM.mem[16'h4111],ch0,ch3,main,nested);
        end
        $finish;
    end
    initial begin #60000000000;$fatal(1,"FM CTC watchdog stage=%h",dut.RAM.mem[16'h4000]);end
endmodule
