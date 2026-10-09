// SPDX-License-Identifier: GPL-2.0-or-later
// Original generated-IPL shared CPU/JT51 diagnostic; no private assets/state.
`timescale 1ps/1ps
module machine_fm_tb #(parameter FM_ENABLED=1,SINGLE_CLOCK=0,MASTER_HZ=32000000);
    localparam longint unsigned HALF_PS=64'd500000000000/64'(MASTER_HZ);
    reg clk=0,video_clk=0,reset=1;
    always #(HALF_PS) clk=~clk;
    always #17500 video_clk=~video_clk;
    reg download=0,upload_wr=0;
    reg [24:0] upload_address=0;
    reg [7:0] upload_data=0;
    wire upload_wait;
    sharpx1 #(.TURBO(1),.TURBO_FM_CPU(FM_ENABLED),.TURBO_DMA(1),
        .SINGLE_CLOCK(SINGLE_CLOCK),.MASTER_HZ(MASTER_HZ)) dut(
        .clk_sys(clk),.clk_28636(SINGLE_CLOCK ? clk : video_clk),.reset(reset),
        .pal(1'b0),.scandouble(1'b0),.ioctl_download(download),.ioctl_index(8'd0),
        .ioctl_wr(upload_wr),.ioctl_addr(upload_address),.ioctl_dout(upload_data),.ioctl_wait(upload_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),.sio_rxd(2'b11),
        .sio_cts_n(2'b11),.sio_dcd_n(2'b11),.sio_txd(),.sio_rts_n(),.sio_dtr_n(),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_drive(),.sd_lba(),.sd_rd(),.sd_wr(),.sd_ack(1'b0),.sd_buff_addr(9'd0),
        .sd_buff_dout(8'd0),.sd_buff_din(),.sd_buff_wr(1'b0),.ce_pix(),.HBlank(),
        .HSync(),.VBlank(),.VSync(),.video(),.rgb(),.rgb12(),.audio());
    reg [7:0] program_bytes[0:8191];
    integer pc=0,dispatches=0,busy_reads=0,wait_edges=0,dma_reads=0,dma_writes=0,dam_writes=0,tail_checks=0;
    reg read_old=0,write_old=0,fm_read_old=0;
    reg [7:0] last_status=0;
    wire fm_read=dut.fm_selected && dut.io_read;
    wire dma_read=dut.dma_owner && !dut.mreq && !dut.rd;
    wire dma_write=dut.dma_owner && !dut.mreq && !dut.wr;
    wire observed_dispatch,observed_a0,observed_busy;
    wire [1:0] observed_ct;
    generate if(FM_ENABLED) begin : observe_fm
        assign observed_dispatch=dut.turbo_fm_cpu.bus.device.dispatch;
        assign observed_a0=dut.turbo_fm_cpu.bus.device.saved_a0;
        assign observed_busy=dut.turbo_fm_cpu.bus.device.status[7];
        assign observed_ct={dut.turbo_fm_cpu.bus.device.ct2,dut.turbo_fm_cpu.bus.device.ct1};
    end else begin : observe_absent_fm
        assign observed_dispatch=0;assign observed_a0=0;assign observed_busy=0;assign observed_ct=0;
    end endgenerate
    always @(posedge clk) begin
        if(dut.core_reset) begin
            dispatches=0;busy_reads=0;wait_edges=0;dma_reads=0;dma_writes=0;dam_writes=0;tail_checks=0;
        end else begin
            if(observed_dispatch) begin
                dispatches++;
                if(observed_a0) assert(!observed_busy) else $fatal(1,"shared FM data dispatched while busy");
            end
            if(dut.fm_selected && dut.io_read && dut.fm_data[7]) busy_reads++;
            if(fm_read) last_status<=dut.fm_data;
            if(fm_read_old && !fm_read && dut.mreq && !dut.dma_owner) begin
                assert(dut.fm_read_tail && dut.fm_data==last_status && dut.di==last_status)
                    else $fatal(1,"shared FM trailing read response lost");
                tail_checks++;
            end
            if(!dut.fm_wait_n) wait_edges++;
            if(dma_read && !read_old) dma_reads++;
            if(dma_write && !write_old) dma_writes++;
            if(dut.dam && dut.io_write && dut.a==16'h0700) begin
                dam_writes++;assert(!dut.fm_selected) else $fatal(1,"DAM write reached FM");
            end
            if(dut.dma_owner || (!dut.m1 && !dut.iorq))
                assert(!dut.fm_selected) else $fatal(1,"owned/ACK bus reached FM");
            assert(!dut.fm_protocol_error) else $fatal(1,"shared CPU overran FM queue");
        end
        read_old<=dma_read;write_old<=dma_write;fm_read_old<=fm_read && !dut.core_reset;
    end
    task automatic emit(input [7:0] value);program_bytes[pc]=value;pc++;endtask
    task automatic load(input [7:0] value);emit(8'h3e);emit(value);endtask
    task automatic port(input [15:0] value);emit(8'h01);emit(value[7:0]);emit(value[15:8]);endtask
    task automatic store(input [15:0] value);emit(8'h32);emit(value[7:0]);emit(value[15:8]);endtask
    task automatic out_byte(input [7:0] value);load(value);emit(8'hed);emit(8'h79);endtask
    task automatic mark(input [7:0] value);load(value);store(16'h4000);endtask
    task automatic poll(input [7:0] mask,input bit until_set);
        integer loop_address;loop_address=pc;
        emit(8'hed);emit(8'h78);emit(8'he6);emit(mask);
        emit(until_set ? 8'h28 : 8'h20);emit(8'(loop_address-(pc+1)));
    endtask
    task automatic reg_write(input [7:0] index,value);
        port(16'h0701);poll(8'h80,0);port(16'h0700);out_byte(index);
        port(16'h0701);out_byte(value);poll(8'h80,0);
    endtask
    task automatic tick;@(posedge clk);#1;endtask
    task automatic reboot;
        assert(!dut.dma_owner && dut.dma_busrq_n) else $fatal(1,"FM reset requires drained DMA");
        @(negedge clk);#1;reset=1;
        repeat(256) begin
            tick();assert(dut.core_reset && !dut.cpu_ce && !dut.pe4M4 && dut.fm_wait_n &&
                !dut.fm_read_tail && dut.fm_irq_n && !dut.fm_sample && observed_ct==0)
                else $fatal(1,"shared FM reset retained pending/tail/timer/CT or advanced CPU");
        end
        @(negedge clk);#1;reset=0;
    endtask
    task automatic complete;
        wait(dut.RAM.mem[16'h4000]==8'haa && !dut.halt_n);repeat(512) tick();
        assert(dut.RAM.mem[16'h4100]==0 && dut.RAM.mem[16'h4101]==1 &&
            dut.RAM.mem[16'h4102]==0 && dut.RAM.mem[16'h4103]==8'hff)
            else $fatal(1,"shared FM CPU status readback %h/%h/%h/%h",dut.RAM.mem[16'h4100],
                dut.RAM.mem[16'h4101],dut.RAM.mem[16'h4102],dut.RAM.mem[16'h4103]);
        assert(dispatches==10 && busy_reads>0 && wait_edges>0 && dam_writes>0 && tail_checks>0 &&
            dma_reads==4 && dma_writes==4 && observed_ct==3 && dut.fm_irq_n && !dut.dma_owner)
            else $fatal(1,"shared FM bus/queue/DAM/DMA counts dispatch=%0d busy=%0d wait=%0d dam=%0d DMA=%0d/%0d",dispatches,busy_reads,wait_edges,dam_writes,dma_reads,dma_writes);
        for(integer i=0;i<4;i++) assert(dut.RAM.mem[16'h9000+16'(i)]==8'h31+8'(i))
            else $fatal(1,"shared FM concurrent DMA payload");
        $display("PASS shared IPL CPU/JT51 MASTER=%0d single=%0d busy/status/WAIT/retained tail, DAM and real DMA isolation; warm reboot",MASTER_HZ,SINGLE_CLOCK);
    endtask
    initial begin
        for(integer i=0;i<8192;i++) program_bytes[i]=0;
        emit(8'hf3);emit(8'h31);emit(0);emit(8'hff);mark(0);
        port(16'h0701);emit(8'hed);emit(8'h78);store(16'h4100);mark(1);
        // Actual PPI mode/C5 transition arms DAM for the following OUT only.
        port(16'h1a03);out_byte(8'h80);port(16'h1a02);out_byte(8'h20);out_byte(0);
        port(16'h0700);out_byte(8'h7f);
        port(16'h0702);emit(8'hed);emit(8'h78);store(16'h4103); // IN clears DAM
        reg_write(8'h1b,8'hc0);reg_write(8'h10,8'hfa);reg_write(8'h11,0);
        reg_write(8'h14,5);mark(2); // genuine timer flag/IRQ, not routed to CPU
        for(integer i=0;i<4;i++) begin load(8'h31+8'(i));store(16'h8000+16'(i));end
        port(16'h1f80);out_byte(8'h7d);out_byte(0);out_byte(8'h80);out_byte(3);out_byte(0);
        out_byte(8'h14);out_byte(8'h10);out_byte(8'h80);out_byte(8'h8d);out_byte(0);
        out_byte(8'h90);out_byte(8'h8a);out_byte(8'hcf);out_byte(8'h87);
        port(16'h0701);poll(1,1);store(16'h4101);
        reg_write(8'h14,8'h10);port(16'h0700);emit(8'hed);emit(8'h78);store(16'h4102);
        mark(8'haa);emit(8'h76);
        assert(pc<8192) else $fatal(1,"FM generated IPL overflow");
        for(integer i=0;i<8192;i++) begin
            @(negedge clk);#1;download=1;upload_wr=1;upload_address=25'(i);upload_data=program_bytes[i];
            tick();assert(!upload_wait) else $fatal(1,"unexpected FM IPL upload wait");
        end
        @(negedge clk);#1;download=0;upload_wr=0;repeat(16) tick();reset=0;
        wait(dut.RAM.mem[16'h4000]==1);
        assert(dut.RAM.mem[16'h4100]==0) else $fatal(1,"shared FM programmed decode/read failed");
        complete();reboot();
        wait(!dut.fm_irq_n && !dut.dma_owner && dut.dma_busrq_n);reboot();
        complete();$finish;
    end
    initial begin #10000000000;$fatal(1,"shared FM watchdog stage=%h address=%h dispatch=%0d",dut.RAM.mem[16'h4000],dut.a,dispatches);end
endmodule
