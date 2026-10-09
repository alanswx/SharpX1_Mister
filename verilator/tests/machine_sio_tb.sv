// SPDX-License-Identifier: GPL-2.0-or-later
// Original IPL-driven shared-machine diagnostic. No private media/state.
`timescale 1ps/1ps
module machine_sio_tb #(parameter SIO_ENABLED=1, DMA_ENABLED=1, SERIAL_X1=0);
    reg clk=0,video_clk=0,reset=1,external_clock=0;
    always #15625 clk=~clk; // 32 MHz SYS
    always #17500 video_clk=~video_clk; // checked-in nominal board PLL
    // x1 uses 500 kHz: the 4 MHz device CE exceeds 4.5x its data rate.
    always #(SERIAL_X1 ? 1000000 : 500000) external_clock=~external_clock;
    reg download=0,upload_wr=0;
    reg [24:0] upload_address=0;
    reg [7:0] upload_data=0;
    reg [1:0] rxd=3,cts_n=3;
    wire [1:0] txd,rts_n,dtr_n;
    wire upload_wait;
    sharpx1 #(.TURBO(1),.TURBO_SIO(SIO_ENABLED),.TURBO_DMA(DMA_ENABLED),
        .TURBO_DMA_IRQ(DMA_ENABLED)) dut(
        .clk_sys(clk),.clk_28636(video_clk),.reset(reset),.pal(1'b0),.scandouble(1'b0),
        .ioctl_download(download),.ioctl_index(8'd0),.ioctl_wr(upload_wr),
        .ioctl_addr(upload_address),.ioctl_dout(upload_data),.ioctl_wait(upload_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .sio_external_rx_clock(external_clock),.sio_external_tx_clock(external_clock),
        .sio_rxd(rxd),.sio_cts_n(cts_n),.sio_dcd_n(2'b11),
        .sio_txd(txd),.sio_rts_n(rts_n),.sio_dtr_n(dtr_n),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_drive(),.sd_lba(),.sd_rd(),.sd_wr(),.sd_ack(1'b0),
        .sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_din(),.sd_buff_wr(1'b0),
        .ce_pix(),.HBlank(),.HSync(),.VBlank(),.VSync(),.video(),.rgb(),.rgb12(),.audio());
    reg [7:0] program_bytes[0:8191];
    integer pc=0,acks=0,returns=0,reads=0,writes=0,grants=0;
    reg ack_old=0,owner_old=0,read_old=0,write_old=0;
    reg [7:0] held_vector=0;
    wire ack=!dut.m1 && !dut.iorq;
    wire dma_read=dut.dma_owner && !dut.mreq && !dut.rd;
    wire dma_write=dut.dma_owner && !dut.mreq && !dut.wr;
    wire [1:0] observed_rx_tick;
    wire [1:0] observed_rx_clock;
    wire observed_rx_busy;
    generate if(SIO_ENABLED) begin : serial_observation
        assign observed_rx_tick=dut.turbo_sio.rx_tick;
        assign observed_rx_clock=dut.turbo_sio.rx_clock;
        assign observed_rx_busy=dut.turbo_sio.device.channels[0].unit.rx_busy;
    end else begin : absent_serial_observation
        assign observed_rx_tick=0;
        assign observed_rx_clock=0;
        assign observed_rx_busy=0;
    end endgenerate
    always @(posedge clk) begin
        if(dut.core_reset) begin acks=0;returns=0;reads=0;writes=0;grants=0;end
        else begin
            if(ack && !ack_old) begin
                case(acks)
                    0:assert(dut.irq_vector==8'ha0 && dut.ctc_ack) else $fatal(1,"machine CTC ACK");
                    1:assert(dut.irq_vector==(DMA_ENABLED ? 8'hc4 : 8'he4) &&
                        (DMA_ENABLED ? dut.dma_ack : dut.sio_ack)) else $fatal(1,"machine second ACK");
                    2:assert(dut.irq_vector==(DMA_ENABLED ? 8'he4 : 8'hec) && dut.sio_ack)
                        else $fatal(1,"machine third ACK");
                    3:assert(DMA_ENABLED && dut.irq_vector==8'hec && dut.sio_ack) else $fatal(1,"machine A RX ACK");
                    default:$fatal(1,"extra machine ACK");
                endcase
                acks++;held_vector<=dut.irq_vector;
            end else if(ack) assert(dut.irq_vector==held_vector) else $fatal(1,"machine held ACK changed");
            if(dut.sio_reti || dut.dma_reti || dut.ctc_reti) begin
                if(returns<2) assert(dut.sio_reti && !dut.dma_reti && !dut.ctc_reti)
                    else $fatal(1,"machine SIO RETI owner");
                else if(returns==2 && DMA_ENABLED) assert(dut.dma_reti && !dut.ctc_reti)
                    else $fatal(1,"machine DMA RETI owner");
                else assert(dut.ctc_reti && !dut.sio_reti && !dut.dma_reti)
                    else $fatal(1,"machine CTC RETI owner");
                returns++;
            end
            if(dut.dma_owner && !owner_old) grants++;
            if(dma_read && !read_old) reads++;
            if(dma_write && !write_old) writes++;
            assert(!dut.sio_unsupported && dut.sio_rx_overflow==0 && dut.sio_tx_overflow==0)
                else $fatal(1,"machine serial unsupported/clock overflow");
        end
        ack_old<=ack;owner_old<=dut.dma_owner;read_old<=dma_read;write_old<=dma_write;
    end
    task automatic emit(input [7:0] value);program_bytes[pc]=value;pc++;endtask
    task automatic load(input [7:0] value);emit(8'h3e);emit(value);endtask
    task automatic port(input [15:0] value);emit(8'h01);emit(value[7:0]);emit(value[15:8]);endtask
    task automatic out_byte(input [7:0] value);load(value);emit(8'hed);emit(8'h79);endtask
    task automatic store(input [15:0] value);emit(8'h32);emit(value[7:0]);emit(value[15:8]);endtask
    task automatic mark(input [7:0] value);load(value);store(16'h4000);endtask
    task automatic serial_reg(input [7:0] index,value);out_byte(index);out_byte(value);endtask
    task automatic vector_entry(input [7:0] vector,input [15:0] handler);
        load(handler[7:0]);store(16'h8000+16'(vector));
        load(handler[15:8]);store(16'h8001+16'(vector));
    endtask
    task automatic wait_cts;
        integer loop_pc;
        emit(8'hfb);emit(0);port(16'h1f91);loop_pc=pc;
        emit(8'hed);emit(8'h78);emit(8'he6);emit(8'h20); // actual RR0 CTS
        emit(8'hca);emit(8'(loop_pc));emit(8'(loop_pc>>8));
        emit(8'hf3);emit(8'hc1);emit(8'hf1);emit(8'hed);emit(8'h4d);
    endtask
    task automatic tick;@(posedge clk);#1;endtask
    task automatic serial_events(input bit ch,input integer count);
        integer n;bit accepted;
        n=0;
        while(n<count) begin
            @(posedge clk);
            accepted=dut.pe4M4 && observed_rx_tick[ch];
            #1;if(accepted) n++;
        end
    endtask
    task automatic receive(input bit ch,input [7:0] value);
        // Externally synchronize the x1 start to a fresh pin-clock cycle;
        // don't count an already queued idle edge as a start-bit sample.
        if(SERIAL_X1) begin
            @(negedge observed_rx_clock[ch]);repeat(16) tick();
        end
        @(negedge clk);#1;rxd[ch]=0;serial_events(ch,SERIAL_X1 ? 1 : 16);
        for(integer i=0;i<8;i++) begin rxd[ch]=value[i];serial_events(ch,SERIAL_X1 ? 1 : 16);end
        rxd[ch]=1;serial_events(ch,SERIAL_X1 ? 2 : 32);
    endtask
    task automatic reset_and_reboot;
        assert(!dut.dma_owner && dut.dma_busrq_n)
            else $fatal(1,"machine reset requires drained bus");
        @(negedge clk);#1;reset=1;rxd=3;cts_n=3;
        repeat(256) begin
            tick();
            assert(dut.core_reset && !dut.cpu_ce && !dut.pe4M4 &&
                dut.sio_wait_n && !dut.sio_read_tail && !observed_rx_busy && !dut.sio_in_service &&
                !dut.dma_in_service && dut.ctc.in_service==0)
                else $fatal(1,"machine warm reset retained WAIT/tail/service or advanced CPU");
        end
        @(negedge clk);#1;reset=0;
    endtask
    task automatic run_native(input bit reset_nested,input bit reset_wait);
        wait(dut.RAM.mem[16'h4000]==1 && !dut.halt_n);
        assert(dut.RAM.mem[16'h4102]==4) else $fatal(1,"machine SIO programmed status/read failed");
        wait(dut.RAM.mem[16'h4000]==(DMA_ENABLED ? 8'h20 : 8'h10));
        assert(dut.ctc.in_service[0] && (!DMA_ENABLED || dut.dma_in_service))
            else $fatal(1,"machine native lower service missing");
        receive(1,8'hb6);wait(dut.RAM.mem[16'h4000]==8'h30);
        assert(dut.sio_in_service && dut.ctc.in_service[0] && !dut.ctc_iei)
            else $fatal(1,"machine SIO service failed to block CTC");
        receive(0,8'ha5);wait(dut.RAM.mem[16'h4000]==8'h40 && returns==1);
        assert(dut.sio_in_service && dut.ctc.in_service[0] &&
            dut.RAM.mem[16'h4100]==8'hb6 && dut.RAM.mem[16'h4101]==8'ha5)
            else $fatal(1,"machine actual serial reads/nesting B=%h A=%h",dut.RAM.mem[16'h4100],dut.RAM.mem[16'h4101]);
        if(reset_nested) begin
            reset_and_reboot();
            $display("PASS shared machine serial nested warm reset; unchanged IPL reboot follows DMA=%0d",DMA_ENABLED);
        end else begin
            cts_n[0]=0;
            wait(dut.RAM.mem[16'h4000]==8'h50 && !dut.sio_wait_n && dut.io_read);
            repeat(256) begin
                tick();assert(dut.a==16'h1f90 && !dut.rd && !dut.sio_wait_n &&
                    dut.RAM.mem[16'h4000]==8'h50)
                    else $fatal(1,"shared serial RX WAIT failed to hold actual CPU read");
            end
            if(reset_wait) begin
                // Start a real partial frame while the CPU is stalled, then
                // abort it through machine reset, not internal-state forcing.
                @(negedge clk);#1;rxd[0]=0;serial_events(0,4);
                assert(acks==(DMA_ENABLED ? 4 : 3) && returns==acks &&
                    observed_rx_busy && !dut.sio_wait_n &&
                    dut.RAM.mem[16'h4103]==8'h99)
                    else $fatal(1,"machine stalled read committed before reset");
                reset_and_reboot();
                $display("PASS shared serial warm reset aborts CPU RX WAIT with stopped CE; retained IPL reboot DMA=%0d",DMA_ENABLED);
                return;
            end
            receive(0,8'h53);
            wait(dut.RAM.mem[16'h4000]==8'haa && !dut.halt_n);repeat(1000) tick();
            assert(acks==(DMA_ENABLED ? 4 : 3) && returns==acks && !dut.sio_in_service &&
                !dut.dma_in_service && dut.ctc.in_service==0 && !dut.machine_irq &&
                reads==(DMA_ENABLED ? 4 : 0) && writes==reads)
                else $fatal(1,"machine final dispatch/service/payload counts ACK=%0d RETI=%0d RD=%0d WR=%0d",acks,returns,reads,writes);
            if(DMA_ENABLED) for(integer i=0;i<4;i++) assert(dut.RAM.mem[16'h9000+16'(i)]==8'h31+8'(i))
                else $fatal(1,"machine DMA payload");
            assert(dtr_n[1]==0 && txd==3) else $fatal(1,"machine DTR selector/TX idle");
            assert(dut.RAM.mem[16'h4103]==8'h53 && dut.sio_wait_n)
                else $fatal(1,"shared serial WAIT release/read byte");
            $display("PASS IPL-driven shared SIO/CTC/DMA=%0d x1=%0d: real RX reads/WAIT, clock queues, nested IM2/RETI, absent-DMA IEI pass-through and retained warm reset",DMA_ENABLED,SERIAL_X1);
        end
    endtask
    initial begin
        for(integer i=0;i<8192;i++) program_bytes[i]=0;
        emit(8'hf3);emit(8'h31);emit(0);emit(8'hff);
        load(8'h80);emit(8'hed);emit(8'h47);emit(8'hed);emit(8'h5e);
        load(8'h99);store(16'h4103); // actual CPU sentinel for aborted WAIT read
        vector_entry(8'ha0,16'h0400);vector_entry(8'hc4,16'h0480);
        vector_entry(8'he4,16'h0500);vector_entry(8'hec,16'h0580);
        for(integer i=0;i<4;i++) begin load(8'h31+8'(i));store(16'h8000+16'(i));end
        for(integer ch=0;ch<2;ch++) begin
            port(ch==0 ? 16'h1f91 : 16'h1f93);out_byte(8'h18);
            serial_reg(4,SERIAL_X1 ? 8'h04 : 8'h44);serial_reg(3,8'hc1);serial_reg(5,8'hea);
            serial_reg(1,ch==0 ? 8'h10 : 8'h14);
        end
        serial_reg(2,8'he0);
        port(16'h1f91);emit(8'hed);emit(8'h78);store(16'h4102);
        port(16'h1fa2);out_byte(7);out_byte(1); // real B clock, no CTC2 IRQ
        if(DMA_ENABLED) begin
            port(16'h1f80);out_byte(8'h7d);out_byte(0);out_byte(8'h80);out_byte(3);out_byte(0);
            out_byte(8'h14);out_byte(8'h10);out_byte(8'ha0);out_byte(8'hbd);
            out_byte(0);out_byte(8'h90);out_byte(8'h32);out_byte(8'hc0);out_byte(8'h8a);out_byte(8'hcf);
        end
        port(16'h1fa0);out_byte(8'ha0);out_byte(8'h87);out_byte(32);
        mark(1);emit(8'hfb);emit(8'h76);emit(8'hf3);
        port(16'h1f91);serial_reg(1,8'ha0);mark(8'h50);
        port(16'h1f90);emit(8'hed);emit(8'h78);store(16'h4103);
        port(16'h1f91);serial_reg(1,8'h10);mark(8'haa);emit(8'h76);
        assert(pc<32'h0400) else $fatal(1,"generated IPL overlaps handlers");
        pc=32'h0400;emit(8'hf5);emit(8'hc5);port(16'h1fa0);out_byte(3);mark(8'h10);
        if(DMA_ENABLED) begin port(16'h1f80);out_byte(8'h87);end
        wait_cts();
        pc=32'h0480;emit(8'hf5);emit(8'hc5);port(16'h1f80);out_byte(8'h8b);mark(8'h20);wait_cts();
        pc=32'h0500;emit(8'hf5);emit(8'hc5);port(16'h1f92);emit(8'hed);emit(8'h78);store(16'h4100);mark(8'h30);wait_cts();
        pc=32'h0580;emit(8'hf5);emit(8'hc5);port(16'h1f90);emit(8'hed);emit(8'h78);store(16'h4101);mark(8'h40);
        emit(8'hf3);emit(8'hc1);emit(8'hf1);emit(8'hed);emit(8'h4d);
        for(integer i=0;i<8192;i++) begin
            @(negedge clk);#1;download=1;upload_wr=1;upload_address=25'(i);upload_data=program_bytes[i];
            tick();assert(!upload_wait) else $fatal(1,"unexpected IPL upload wait");
        end
        @(negedge clk);#1;download=0;upload_wr=0;repeat(16) tick();reset=0;
        run_native(1,0);run_native(0,1);run_native(0,0);$finish;
    end
    initial begin #10000000000;$fatal(1,"machine SIO watchdog stage=%h ACK=%0d RETI=%0d",dut.RAM.mem[16'h4000],acks,returns);end
endmodule
