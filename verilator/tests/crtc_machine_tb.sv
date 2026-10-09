// SPDX-License-Identifier: GPL-2.0-only
// Real CPU/IPL/shared-machine CRTC writes; no forced bus or private firmware.
module crtc_machine_tb;
    timeunit 1ps;
    timeprecision 1ps;
    bit clk=0,video_clk=0,video_run=1,reset=1,download=0,load=0;
    integer video_half=11640;
    always #15625 clk=~clk;
    always begin #(video_half); if(video_run) video_clk=~video_clk; end
    bit [24:0] address=0;
    bit [7:0] data=0,program_bytes[0:4095];
    wire load_wait,halt_n;
    integer size=0,accepted=0,committed=0;
    bit [8:0] packets[$];
    time video_edge=0;
    top #(.TURBO(1),.TURBO_VIDEO_MASTER(1)) dut (
        .clk_sys(clk),.clk_28636(video_clk),.reset(reset),
        .ioctl_download(download),.ioctl_index(8'd0),.ioctl_wr(load),
        .ioctl_addr(address),.ioctl_dout(data),.ioctl_wait(load_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_ack(1'b0),.sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_wr(1'b0),
        .debug_addr(16'd0),.cpu_halt_n(halt_n),
        .sd_drive(),.debug_disk_control(),.debug_disk_motor(),.debug_disk_ready(),
        .sd_lba(),.sd_rd(),.sd_wr(),.sd_buff_din(),
        .debug_ram(),.debug_text(),.debug_attr(),.sub_pc(),.sub_address(),.sub_control(),
        .sub_wait(),.sub_tx(),.sub_rx(),.cpu_address(),.cpu_in(),.cpu_out(),
        .cpu_mreq_n(),.cpu_iorq_n(),.cpu_rd_n(),.cpu_wr_n(),
        .video(),.rgb(),.rgb12(),.audio(),.ce_pix(),.HSync(),.VSync(),.HBlank(),.VBlank(),
        .audio_left(),.audio_right(),.audio_mono(),.audio_sample(),
        .sys_edges(),.video_edges(),.reset_edges(),.cpu_enables(),.delayed_sys_edges(),
        .dma_grants(),.dma_reads(),.dma_writes(),.cpu_fdc_data_reads(),.cpu_fdc_data_writes()
    );
    always @(posedge clk) if(!dut.machine.core_reset) begin
        if(dut.machine.x3_crtc.writes.select && !dut.machine.x3_crtc.writes.busy &&
           !dut.machine.x3_crtc.writes.done) begin
            packets.push_back({dut.machine.a[0],dut.machine.data_out});
            accepted++;
        end
        if(dut.machine.x3_crtc.writes.select && !dut.machine.x3_crtc.writes.done)
            assert(!dut.machine.machine_wait_n) else $fatal(1,"CRTC request bypassed CPU WAIT");
    end
    always @(posedge video_clk) begin
        bit [8:0] packet;
        bit [4:0] index;
        video_edge=$time;
        if(dut.machine.crtc_bus_write) begin
            assert(packets.size()>0 && !dut.machine.video_reset) else $fatal(1,"unrequested/reset CRTC commit");
            packet=packets.pop_front();
            assert(packet=={dut.machine.crtc_bus_rs,dut.machine.crtc_bus_data})
                else $fatal(1,"CPU CRTC packet order/data corrupted");
            index=dut.machine.display.crtc6845s.mpu_if.R_ADR;
            committed++;
            #1;
            if(!packet[8]) assert(dut.machine.display.crtc6845s.mpu_if.R_ADR==packet[4:0]);
            else if(index==5) assert(dut.machine.display.crtc6845s.mpu_if.R_Nadj==packet[4:0]);
            else if(index==9) assert(dut.machine.display.crtc6845s.mpu_if.R_Nr==packet[4:0]);
            else $fatal(1,"unexpected generated CRTC index");
        end
    end
    always @(dut.machine.display.crtc6845s.mpu_if.R_Nadj or
             dut.machine.display.crtc6845s.mpu_if.R_Nr) if($time>1000000)
        assert($time==video_edge) else $fatal(1,"shared CRTC register escaped video edge");
    task automatic emit(input byte value); program_bytes[size++]=value; endtask
    task automatic out_port(input bit [15:0] port,input byte value);
        emit(8'h01);emit(port[7:0]);emit(port[15:8]);
        emit(8'h3e);emit(value);emit(8'hed);emit(8'h79);
    endtask
    task automatic tick; @(negedge clk); #1; endtask
    task automatic check_complete(input integer count);
        wait(!halt_n);repeat(64) tick();
        assert(accepted==count && committed==count && packets.size()==0)
            else $fatal(1,"CPU CRTC sweep incomplete accepted=%0d committed=%0d",accepted,committed);
        assert(dut.machine.display.crtc6845s.mpu_if.R_Nadj==5'd10 &&
               dut.machine.display.crtc6845s.mpu_if.R_Nr==5'd20)
            else $fatal(1,"CPU CRTC final registers incorrect");
    endtask
    initial begin
        bit [8:0] frozen;
        integer previous_commits;
        void'($value$plusargs("VIDEO_HALF=%d",video_half));
        emit(8'hf3);
        out_port(16'h1800,5);out_port(16'h1801,8'h12);
        out_port(16'h1802,9);out_port(16'h1803,8'h0b);
        for(integer k=0;k<32;k++) begin
            out_port(16'h18fe,5);out_port(16'h18ff,byte'(k^21));
            out_port(16'h1804,9);out_port(16'h1805,byte'(k^11));
        end
        emit(8'h76);
        repeat(8) tick();download=1;
        for(integer k=0;k<size;k++) begin
            while(load_wait) tick();address=25'(k);data=program_bytes[k];load=1;tick();
        end
        load=0;download=0;repeat(8) tick();reset=0;
        wait(dut.machine.x3_crtc.writes.busy && dut.machine.x3_crtc.writes.held_packet==9'h112);
        video_run=0;frozen=dut.machine.x3_crtc.writes.held_packet;previous_commits=committed;
        repeat(64) begin
            tick();
            assert(dut.machine.x3_crtc.writes.busy && !dut.machine.machine_wait_n &&
                   dut.machine.x3_crtc.writes.held_packet==frozen && committed==previous_commits)
                else $fatal(1,"stopped video lost CPU WAIT/held CRTC packet");
        end
        video_run=1;check_complete(132);
        // Retained IPL and target registers; no second upload.
        reset=1;repeat(32) tick();
        assert(dut.machine.display.crtc6845s.mpu_if.R_Nadj==5'd10 &&
               dut.machine.display.crtc6845s.mpu_if.R_Nr==5'd20)
            else $fatal(1,"warm reset cleared retained CRTC registers");
        reset=0;check_complete(264);
        $display("PASS: real CPU/IPL 132 mirrored CRTC writes plus retained warm reboot, coherent target values, stopped-video WAIT and exact 264 commits");
        $finish;
    end
    initial begin #100000000000; $fatal(1,"CPU CRTC fixture timeout"); end
endmodule
