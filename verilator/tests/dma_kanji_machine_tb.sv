// SPDX-License-Identifier: GPL-2.0-only
// Original ioctl-loaded CPU/DMA/Kanji ownership diagnostic; no private assets.
`timescale 1ps/1ps
module dma_kanji_machine_tb #(parameter QUALIFY = 1);
    logic sys=0,vid=0,sys_run=1,vid_run=1,reset=1;
    always #15625 if(sys_run) sys=!sys;
    // Integer-ps phase accumulator: nominal X3, not a rounded fixed period.
    longint edge_number=0,previous_time=0,next_time;
    always begin
        edge_number++; next_time=edge_number*64'd1000000000000/64'd85909080;
        #(next_time-previous_time); previous_time=next_time;
        if(vid_run) vid=!vid;
    end
    logic download=0,load=0;
    logic [7:0] index=0,data=0,rom[0:4095];
    logic [24:0] address=0;
    wire load_wait;
    integer size=0,kind=0;
    bit absent=0,corrupt_font=0;
    top #(.TURBO(1),.TURBO_DMA(1),.TURBO_KANJI(1),.TURBO_VIDEO_MASTER(1),
          .TURBO_DMA_KANJI_EXPERIMENT(QUALIFY)) dut (
        .clk_sys(sys),.clk_28636(vid),.reset(reset),
        .ioctl_download(download),.ioctl_index(index),.ioctl_wr(load),
        .ioctl_addr(address),.ioctl_dout(data),.ioctl_wait(load_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_ack(1'b0),.sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_wr(1'b0),
        .debug_addr(16'hf100),.rgb12(),
        .sd_drive(),.debug_disk_control(),.debug_disk_motor(),.debug_disk_ready(),
        .sd_lba(),.sd_rd(),.sd_wr(),.sd_buff_din(),
        .debug_ram(),.debug_text(),.debug_attr(),.sub_pc(),.sub_address(),.sub_control(),
        .sub_wait(),.sub_tx(),.sub_rx(),.cpu_address(),.cpu_in(),.cpu_out(),
        .cpu_mreq_n(),.cpu_iorq_n(),.cpu_rd_n(),.cpu_wr_n(),.cpu_halt_n(),
        .video(),.rgb(),.audio(),.audio_left(),.audio_right(),.audio_mono(),.audio_sample(),
        .ce_pix(),.HSync(),.VSync(),.HBlank(),.VBlank(),
        .sys_edges(),.video_edges(),.reset_edges(),.cpu_enables(),.delayed_sys_edges(),
        .dma_grants(),.dma_reads(),.dma_writes(),.cpu_fdc_data_reads(),.cpu_fdc_data_writes()
    );
    task automatic tick; @(negedge sys); #1; endtask
    function automatic logic [7:0] pattern(input integer a);
        return 8'(a*37+(a>>8)*13+(a>>16)*211+19);
    endfunction
    task automatic emit(input logic [7:0] b); rom[size]=b;size++;endtask
    task automatic word(input logic [7:0] op,input logic [15:0] v);
        emit(op);emit(v[7:0]);emit(v[15:8]);
    endtask
    task automatic out_port(input logic [15:0] port,input logic [7:0] v);
        word(8'h01,port);emit(8'h3e);emit(v);emit(8'hed);emit(8'h79);
    endtask
    integer patch[0:15],failure;
    logic [15:0] held_address;
    logic [16:0] held_kanji;
    initial begin #100000000000;
        $display("clock edges SYS=%0d VID=%0d phase=%0d next=%0d crtcwait=%b video_reset=%b",dut.sys_edges,dut.video_edges,edge_number,next_time,dut.machine.crtc_wait_n,dut.machine.video_reset);
        $fatal(1,"DMA/Kanji timeout kind=%0d pc=%h owner=%b a=%h rd=%b cgwait=%b busy=%b req=%b valid=%b hs=%b reads=%0d writes=%0d marker=%h unsupported=%b",kind,dut.machine.cpu_a,dut.machine.dma_owner,dut.machine.a,dut.machine.rd,dut.machine.cg_wait_n,dut.machine.cg_bus.busy,dut.machine.cg_bus.kanji_request,dut.machine.kanji_cpu_valid,dut.machine.HSync,dut.dma_reads,dut.dma_writes,dut.machine.RAM.mem[16'hf101],dut.machine.dma_unsupported);
    end
    initial begin
        if($value$plusargs("RESET_KIND=%d",kind)) begin end
        absent=$test$plusargs("absent");
        corrupt_font=$test$plusargs("corrupt-font");
        assert(kind>=0 && kind<=3) else $fatal(1,"invalid profile");
        assert(!corrupt_font || (!absent && kind==0)) else $fatal(1,"invalid payload negative");
        emit(8'hf3);word(8'h31,16'hffff);word(8'h21,16'hf100);emit(8'h34);
        out_port(16'h1a03,8'h82);word(8'h01,16'h1a02);emit(8'hed);emit(8'h78);
        out_port(16'h1a02,8'h40);
        for(integer r=0;r<14;r++) begin
            out_port(16'h1800,8'(r));
            case(r)
                0:out_port(16'h1801,15);
                1,6,7:out_port(16'h1801,1);
                2:out_port(16'h1801,2);
                3:out_port(16'h1801,8'h12);
                default:out_port(16'h1801,0);
            endcase
        end
        for(integer n=0;n<4;n++) begin
            out_port(16'h2000+(n==0 ? 16'h7ff : n==1 ? 16'h3ff : n==2 ? 16'h5ff : 16'h1ff),7);
            out_port(16'h3000+(n==0 ? 16'h7ff : n==1 ? 16'h3ff : n==2 ? 16'h5ff : 16'h1ff),255);
            out_port(16'h3800+(n==0 ? 16'h7ff : n==1 ? 16'h3ff : n==2 ? 16'h5ff : 16'h1ff),8'hcf);
        end
        out_port(16'h1fd0,8'h60);
        // Incrementing A I/O -> incrementing B RAM, 16 bytes; Force Ready
        // qualifies target WAIT only, not FDC Ready or native DMA IRQ.
        out_port(16'h1f80,8'hc3);out_port(16'h1f80,8'h7d);
        out_port(16'h1f80,0);out_port(16'h1f80,8'h14);
        out_port(16'h1f80,15);out_port(16'h1f80,0);
        out_port(16'h1f80,8'h1c);out_port(16'h1f80,8'h10);
        out_port(16'h1f80,8'had);out_port(16'h1f80,0);out_port(16'h1f80,8'hd0);
        out_port(16'h1f80,8'h92);out_port(16'h1f80,8'hcf);
        out_port(16'h1f80,8'hb3);out_port(16'h1f80,8'h87);
        for(integer row=0;row<16;row++) begin
            word(8'h3a,16'hd000+16'(row));emit(8'hfe);
            emit(absent ? 8'hff : pattern(131056+row));
            emit(8'hc2);patch[row]=size;emit(0);emit(0);
        end
        emit(8'h3e);emit(8'h5a);word(8'h32,16'hf101);emit(8'h76);
        failure=size;emit(8'h3e);emit(8'hee);word(8'h32,16'hf101);emit(8'h76);
        for(integer row=0;row<16;row++) begin rom[patch[row]]=8'(failure);rom[patch[row]+1]=8'(failure>>8);end
        repeat(8) tick();
        if(!absent) begin
            download=1;load=1;index=5;
            for(integer a=0;a<131072;a++) begin
                address=25'(a);data=pattern(a)^(corrupt_font && a==131056 ? 8'h01 : 8'h00);tick();
            end
            load=0;download=0;repeat(8) tick();
            assert(dut.machine.kanji_loaded) else $fatal(1,"font upload failed");
        end
        download=1;load=1;index=0;
        for(integer a=0;a<size;a++) begin address=25'(a);data=rom[a];tick();end
        load=0;download=0;repeat(8) tick();reset=0;
        if(kind!=0) begin
            wait(dut.machine.dma_owner && !dut.machine.rd);
            if(kind==2) begin @(negedge vid);vid_run=0;end
            wait(dut.machine.cg_bus.busy && !dut.machine.cg_wait_n);
            #1;held_address=dut.machine.a;held_kanji=dut.machine.kanji_cpu_addr;
            assert(!dut.machine.cpu_busak_n && dut.machine.cg_bus.kanji_request)
                else $fatal(1,"no genuine Kanji ownership");
            if(kind==1) sys_run=0;
            reset=1;#2000;
            assert(dut.machine.dma_draining && !dut.machine.core_reset && !dut.machine.cpu_ce && load_wait)
                else $fatal(1,"owned read discarded at reset");
            reset=0;
            if(kind==3) begin
                // An inadmissible index-5 upload must not invalidate or alter
                // the live font while its owned response is pending.
                index=5;address=25'd131056;data=8'ha5;download=1;load=1;
                @(posedge sys);#1;
                assert(load_wait && dut.machine.dma_draining)
                    else $fatal(1,"upload probe missed owned drain");
                tick();load=0;download=0;tick();
                assert(dut.machine.kanji_loaded==!absent && !dut.machine.kanji_load_error)
                    else $fatal(1,"blocked upload invalidated owned Kanji font");
            end
            if(kind==1) begin #1250000;
                assert(dut.machine.dma_draining && !dut.machine.core_reset && dut.machine.a==held_address)
                    else $fatal(1,"stopped SYS lost ownership");
                sys_run=1;
            end
            if(kind==2) begin
                repeat(80) begin tick();
                    assert(dut.machine.dma_draining && !dut.machine.core_reset && !dut.machine.cpu_ce &&
                           !dut.machine.cpu_busak_n && !dut.machine.cg_wait_n &&
                           dut.machine.a==held_address && dut.machine.kanji_cpu_addr==held_kanji &&
                           !dut.machine.rd && dut.machine.wr && dut.dma_reads==1 && dut.dma_writes==0)
                        else $fatal(1,"stopped VID changed owned read drain=%b reset=%b ce=%b ack=%b wait=%b address=%h/%h kanji=%h/%h reads=%0d writes=%0d",dut.machine.dma_draining,dut.machine.core_reset,dut.machine.cpu_ce,dut.machine.cpu_busak_n,dut.machine.cg_wait_n,dut.machine.a,held_address,dut.machine.kanji_cpu_addr,held_kanji,dut.dma_reads,dut.dma_writes);
                end
                vid_run=1;
            end
            wait(dut.machine.core_reset);
            assert(dut.dma_reads==1 && dut.dma_writes==1 &&
                   dut.machine.RAM.mem[16'hd000]==(absent ? 8'hff : pattern(131056)))
                else $fatal(1,"owned read/write pair lost or duplicated");
            wait(!dut.machine.core_reset);
        end
        wait(!dut.cpu_halt_n && dut.machine.cpu_busak_n && dut.machine.dma_busrq_n);
        repeat(16) tick();
        assert(dut.machine.RAM.mem[16'hf100]==(kind==0 ? 1 : 2) &&
               dut.machine.RAM.mem[16'hf101]==8'h5a &&
               dut.dma_reads==(kind==0 ? 16 : 17) && dut.dma_writes==dut.dma_reads)
            else $fatal(1,"CPU payload/restart mismatch marker=%h reads=%0d writes=%0d",dut.machine.RAM.mem[16'hf101],dut.dma_reads,dut.dma_writes);
        assert(dut.machine.kanji_loaded==!absent && !dut.machine.kanji_load_error)
            else $fatal(1,"retained font changed");
        if(!absent) begin
            for(integer a=0;a<131072;a++)
                assert(dut.machine.turbo_kanji.rom.memory[a]==pattern(a))
                    else $fatal(1,"protected font byte changed address=%h",a);
        end
        $display("PASS DMA/Kanji real CPU grant, 16 CPU-verified bytes, reset=%0d absent=%0d",kind,absent);
        $finish;
    end
endmodule
