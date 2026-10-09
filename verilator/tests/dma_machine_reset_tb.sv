// SPDX-License-Identifier: GPL-2.0-or-later
// Original whole-machine reset/loader diagnostic. Real CPU grants only.
`timescale 1ps/1ps
module dma_machine_reset_tb #(parameter DMA_IRQ = 0, CRTC_TARGET = 0);
    reg clk_sys=0, clk_video=0, sys_running=1, video_running=1, reset=1;
    always begin #15625; if (sys_running) clk_sys=~clk_sys; end
    always begin #17500; if(video_running) clk_video=~clk_video; end
    reg download=0, load_write=0;
    reg [24:0] load_address=0;
    reg [7:0] load_data=0;
    wire load_wait;
    reg [7:0] rom[0:4095];
    integer size=0, reset_kind=0;
    bit video_target=0;
    integer pcg_writes=0;
    integer crtc_writes=0;
    wire crtc_busy;
    generate if(CRTC_TARGET) begin
        assign crtc_busy=dut.machine.x3_crtc.writes.busy;
    end else begin
        assign crtc_busy=0;
    end endgenerate
    reg [15:0] stalled_address, stalled_cpu_address;
    reg [7:0] stalled_data;
    always @(posedge clk_sys) if(CRTC_TARGET && dut.machine.dma_owner && !dut.machine.wr)
        assert(dut.machine.a==16'h1801 && !dut.machine.iorq && dut.machine.m1)
            else $fatal(1,"CRTC DMA bus destination address=%h IORQ=%b M1=%b",dut.machine.a,dut.machine.iorq,dut.machine.m1);
    always @(posedge clk_video)
        if(dut.machine.cg_access_write[0]) pcg_writes++;
    always @(posedge clk_video) if(CRTC_TARGET && dut.machine.dma_owner && dut.machine.crtc_bus_write) begin
        logic [7:0] expected_byte;
        expected_byte=8'h31+8'((crtc_writes==0 ? 0 : crtc_writes-1)*13);
        assert(!dut.machine.cpu_busak_n && dut.machine.crtc_bus_rs &&
               dut.machine.crtc_bus_data==expected_byte)
            else $fatal(1,"owned CRTC packet order/data corrupted");
        crtc_writes++;
        #1;
        assert(dut.machine.display.crtc6845s.mpu_if.R_Nadj==expected_byte[4:0])
            else $fatal(1,"owned CRTC packet missed actual MPU");
    end
    top #(.TURBO(1), .TURBO_DMA(1), .TURBO_DMA_IRQ(DMA_IRQ), .TURBO_VIDEO_MASTER(CRTC_TARGET)) dut (
        .clk_sys(clk_sys), .clk_28636(clk_video), .reset(reset),
        .ioctl_download(download), .ioctl_index(8'd0), .ioctl_wr(load_write),
        .ioctl_addr(load_address), .ioctl_dout(load_data), .ioctl_wait(load_wait),
        .ps2_clk_in(1'b1), .ps2_data_in(1'b1), .joya_n(8'hff), .joyb_n(8'hff),
        .disk_ready(1'b0), .img_mounted(1'b0), .disk_wp(1'b1), .img_size(24'd0),
        .disk_ready_b(1'b0), .img_mounted_b(1'b0), .disk_wp_b(1'b1), .img_size_b(24'd0),
        .sd_ack(1'b0), .sd_buff_addr(9'd0), .sd_buff_dout(8'd0), .sd_buff_wr(1'b0),
        .debug_addr(16'hf100), .rgb12()
    );
    task automatic emit(input reg [7:0] byte_value);
        rom[size]=byte_value; size=size+1;
    endtask
    task automatic out_dma(input reg [7:0] byte_value);
        emit(8'h01); emit(8'h80); emit(8'h1f); // LD BC,1F80
        emit(8'h3e); emit(byte_value); emit(8'hed); emit(8'h79);
    endtask
    task automatic out_port(input reg [15:0] port, input reg [7:0] value);
        emit(8'h01); emit(port[7:0]); emit(port[15:8]);
        emit(8'h3e); emit(value); emit(8'hed); emit(8'h79);
    endtask
    task automatic store(input reg [15:0] address, input reg [7:0] value);
        emit(8'h3e); emit(value); emit(8'h32); emit(address[7:0]); emit(address[15:8]);
    endtask
    initial begin
        if (!$value$plusargs("RESET_KIND=%d",reset_kind)) reset_kind=0;
        video_target=$test$plusargs("pcg");
        assert(reset_kind>=0 && reset_kind<=4 && (reset_kind!=4 || video_target || CRTC_TARGET) && !(video_target && CRTC_TARGET))
            else $fatal(1,"invalid reset profile");
        // Count native restart entries in retained RAM, then program a real
        // continuous Force-Ready 16-byte transfer from high RAM to high RAM.
        emit(8'hf3); emit(8'h21); emit(8'h00); emit(8'hf1); emit(8'h34);
        if(CRTC_TARGET) out_port(16'h1800,5);
        if(video_target) begin
            out_port(16'h1a03,8'h82);
            emit(8'h01); emit(8'h02); emit(8'h1a); emit(8'hed); emit(8'h78); // clear DAM
            out_port(16'h1a02,8'h40);
            for(integer i=0;i<14;i++) begin
                out_port(16'h1800,8'(i));
                case(i)
                    0: out_port(16'h1801,15);
                    1,6,7: out_port(16'h1801,1);
                    2: out_port(16'h1801,2);
                    3: out_port(16'h1801,8'h12);
                    default: out_port(16'h1801,0);
                endcase
            end
            for(integer i=0;i<4;i++) begin
                out_port(16'h3000+(i==0 ? 16'h7ff : i==1 ? 16'h3ff : i==2 ? 16'h5ff : 16'h1ff),8'd60+8'(i));
                out_port(16'h2000+(i==0 ? 16'h7ff : i==1 ? 16'h3ff : i==2 ? 16'h5ff : 16'h1ff),8'h20);
                out_port(16'h3800+(i==0 ? 16'h7ff : i==1 ? 16'h3ff : i==2 ? 16'h5ff : 16'h1ff),8'h10);
            end
            out_port(16'h1fd0,8'h20);
        end
        for (integer i=0;i<16;i=i+1) store(16'h9000+16'(i),8'h31+8'(i*13));
        out_dma(8'hc3); out_dma(8'h7d); out_dma(0); out_dma(8'h90);
        out_dma(15); out_dma(0); out_dma(8'h14); out_dma(CRTC_TARGET ? 8'h28 : video_target ? 8'h18 : 8'h10);
        out_dma(8'had); out_dma(CRTC_TARGET ? 1 : 0); out_dma(CRTC_TARGET ? 8'h18 : video_target ? 8'h15 : 8'h91); out_dma(8'h92);
        if(CRTC_TARGET) begin
            // LOAD loads the source counter only. A fixed B destination must
            // first be temporarily selected as the source and loaded, just
            // like the native-IPL prerequisite in dma_tb's fixed-I/O case.
            out_dma(8'h01); out_dma(8'hcf); out_dma(8'h05);
        end
        out_dma(8'hcf); out_dma(8'hb3); out_dma(8'h87); emit(8'h76);
        repeat(8) @(negedge clk_sys);
        download=1; load_write=1;
        for(integer i=0;i<size;i=i+1) begin
            load_address=25'(i); load_data=rom[i];
            @(negedge clk_sys);
        end
        download=0; load_write=0;
        repeat(8) @(negedge clk_sys); reset=0;
        if (reset_kind==4) begin
            wait(dut.machine.dma_owner && !dut.machine.rd);
            @(negedge clk_video); video_running=0;
            wait(dut.machine.dma_owner && !dut.machine.wr &&
                 (CRTC_TARGET ? (crtc_busy && !dut.machine.crtc_wait_n) :
                  (dut.machine.cg_bus.busy && !dut.machine.cg_wait_n)));
        end else if (reset_kind==1) wait(dut.machine.dma_owner && !dut.machine.wr);
        else wait(dut.machine.dma_owner && !dut.machine.rd);
        @(negedge clk_sys); #2000;
        if(reset_kind==2) sys_running=0;
        // An asset reload pulse must not modify live ROM during drain. The
        // first synthetic byte deliberately differs, so an illegal write is
        // observable before reset. No assertion relies on a patched machine.
        if(reset_kind==3) begin
            download=1; load_write=1; load_address=0; load_data=8'ha5;
        end
        reset=1; #2000;
        if(!dut.machine.dma_draining || dut.machine.core_reset ||
           dut.machine.cpu_busak_n || dut.machine.cpu_ce || !load_wait)
            $fatal(1,"request discarded owned pair");
        reset=0;
        if(reset_kind==4) begin
            stalled_address=dut.machine.a; stalled_cpu_address=dut.machine.cpu_a;
            stalled_data=dut.machine.data_out;
            repeat(80) begin
                @(negedge clk_sys);
                assert(dut.machine.dma_draining && !dut.machine.core_reset &&
                       !dut.machine.cpu_busak_n && !dut.machine.cpu_ce &&
                       !(CRTC_TARGET ? dut.machine.crtc_wait_n : dut.machine.cg_wait_n) &&
                       dut.machine.a==stalled_address && dut.machine.cpu_a==stalled_cpu_address &&
                       dut.machine.data_out==stalled_data && pcg_writes==0 && crtc_writes==0)
                    else $fatal(1,"stopped video lost owned PCG transaction");
            end
            video_running=1;
        end
        if(reset_kind==2) begin
            #1250000;
            if(!dut.machine.dma_draining || dut.machine.core_reset || dut.machine.cpu_busak_n)
                $fatal(1,"stopped SYS lost reset/ACK");
            sys_running=1;
        end
        if(reset_kind==3) begin
            // Keep reload selected through a real blocked SYS edge.
            @(negedge clk_sys);
            if(dut.machine.IPL.mem[0]!==8'hf3) $fatal(1,"loader wrote during drain");
            load_write=0; download=0;
        end
        wait(dut.machine.core_reset);
        if(dut.dma_reads!=1 || dut.dma_writes!=1)
            $fatal(1,"reset did not drain exactly one pair r=%0d w=%0d",dut.dma_reads,dut.dma_writes);
        if(video_target) assert(pcg_writes==1 && dut.machine.pcg_b.mem[11'h1e0]==8'h31)
            else $fatal(1,"owned PCG write cancelled/duplicated");
        if(CRTC_TARGET) assert(crtc_writes==1 && dut.machine.display.crtc6845s.mpu_if.R_Nadj==5'h11)
            else $fatal(1,"owned CRTC write cancelled/duplicated writes=%0d Nadj=%h index=%h dam=%b",crtc_writes,
                        dut.machine.display.crtc6845s.mpu_if.R_Nadj,dut.machine.display.crtc6845s.mpu_if.R_ADR,dut.machine.dam);
        wait(!dut.machine.core_reset);
        // HALT can be reached before the newly enabled request is granted.
        // Completion requires all pairs and the genuine grant to be returned.
        wait(!dut.machine.halt_n && dut.dma_writes==17 &&
             dut.machine.dma_busrq_n && dut.machine.cpu_busak_n);
        repeat(16) @(negedge clk_sys);
        if(dut.machine.RAM.mem[16'hf100]!==2 || dut.dma_grants!=2 ||
           dut.dma_reads!=17 || dut.dma_writes!=17)
            $fatal(1,"native restart/count mismatch entry=%h grant=%0d r=%0d w=%0d",dut.machine.RAM.mem[16'hf100],dut.dma_grants,dut.dma_reads,dut.dma_writes);
        for(integer i=0;i<16;i=i+1)
            if(!CRTC_TARGET && (video_target ? dut.machine.pcg_b.mem[11'h1e0+11'(i)] : dut.machine.RAM.mem[16'h9100+16'(i)]) !== (8'h31+8'(i*13)))
                $fatal(1,"restarted DMA payload mismatch %0d",i);
        if(video_target) assert(pcg_writes==17) else $fatal(1,"PCG writes != DMA accepted pairs");
        if(CRTC_TARGET) assert(crtc_writes==17 && dut.machine.display.crtc6845s.mpu_if.R_Nadj==5'h14)
            else $fatal(1,"restarted CRTC writes != DMA accepted pairs");
        $display("PASS: actual shared-machine reset kind=%0d PCG=%0d CRTC=%0d, owned pair drain, retained ACK, native restart, PCG writes=%0d CRTC writes=%0d",reset_kind,video_target,CRTC_TARGET,pcg_writes,crtc_writes);
        $finish;
    end
    initial begin #10000000000; $fatal(1,"whole-machine reset watchdog"); end
endmodule
