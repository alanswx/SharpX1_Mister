// SPDX-License-Identifier: GPL-2.0-only
// Original CPU-written priority/control crossing diagnostic. No private ROM.
`timescale 1ps/1ps
module z_priority_machine_cdc_tb #(parameter PRIORITY_CPU=1);
    logic clk=0,video_clk=0,sys_run=1,video_run=1,reset=1;
    integer video_half=11640;
    always #15625 if(sys_run) clk=!clk;
    always begin #(video_half); if(video_run) video_clk=!video_clk; end
    logic download=0,load=0;
    logic [24:0] address=0;
    logic [7:0] data=0,program_bytes[0:4095];
    wire load_wait,halt_n;
    integer size=0;
    top #(.TURBO(1),.TURBO_VIDEO_MASTER(1),.TURBO_Z_PALETTE_CPU(1),
          .TURBO_Z_VIDEO(1),.TURBO_Z_MULTIMODE(1),.TURBO_Z_TEXT_CPU(PRIORITY_CPU)) dut (
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
        .sys_edges(),.video_edges(),.reset_edges(),.cpu_enables(),.delayed_sys_edges(),
        .dma_grants(),.dma_reads(),.dma_writes(),.cpu_fdc_data_reads(),.cpu_fdc_data_writes()
    );
    wire [31:0] controls=dut.machine.z_palette_cpu.controls_crossing.multimode.controls;
    wire valid=dut.machine.z_palette_cpu.controls_crossing.multimode.controls_valid;
    bit [255:0] seen=0;
    always @(negedge video_clk) if(valid && !reset && controls[23:16]==8'h90) begin
        assert(controls[15:0]==16'h0001)
            else $fatal(1,"mode/bank/width payload corrupted %h",controls);
        seen[controls[31:24]]=1;
    end
    task automatic emit(input logic [7:0] value);
        assert(size<4096);program_bytes[size++]=value;
    endtask
    task automatic out_port(input logic [15:0] port,input logic [7:0] value);
        emit(8'h01);emit(port[7:0]);emit(port[15:8]);
        emit(8'h3e);emit(value);emit(8'hed);emit(8'h79);
    endtask
    task automatic tick; @(negedge clk); #1; endtask
    task automatic await_cpu;
        wait(!halt_n); repeat(64) tick();
        assert(&seen && controls==32'hff900001)
            else $fatal(1,"CPU sweep incomplete seen=%h controls=%h",seen,controls);
    endtask
    initial begin #100000000000; $fatal(1,"CPU/control CDC timeout"); end
    initial begin
        logic [31:0] frozen;
        logic request_before;
        if($value$plusargs("VIDEO_HALF_PS=%d",video_half)) begin end
        emit(8'hf3);
        out_port(16'h1a03,8'h82);
        emit(8'h01);emit(8'h02);emit(8'h1a);emit(8'hed);emit(8'h78); // Clear DAM.
        out_port(16'h1a02,8'h40);
        out_port(16'h1fb0,8'h90);
        for(integer n=0;n<256;n++) begin
            out_port(16'h1fc0,8'(n));
            // Real CPU delay permits each independently written byte to cross.
            emit(8'h06);emit(32);emit(8'h10);emit(8'hfe); // LD B,32 / DJNZ.
        end
        emit(8'h76);
        repeat(8) tick();download=1;
        for(integer n=0;n<size;n++) begin
            while(load_wait) tick();
            load=1;address=25'(n);data=program_bytes[n];tick();
        end
        load=0;download=0;repeat(8) tick();reset=0;
        await_cpu();
        // Physically stop SYS; destination must hold after in-flight ACK drain.
        tick();sys_run=0;
        repeat(12) @(negedge video_clk);frozen=controls;
        repeat(32) begin @(negedge video_clk);assert(controls==frozen);end
        sys_run=1;repeat(32) tick();
        // Physically stop VID; SYS must not overwrite an unconsumed payload.
        @(negedge video_clk);video_run=0;
        repeat(12) tick();
        frozen=dut.machine.z_palette_cpu.controls_crossing.multimode.snapshot.held_data;
        request_before=dut.machine.z_palette_cpu.controls_crossing.multimode.snapshot.request;
        repeat(32) begin
            tick();
            assert(dut.machine.z_palette_cpu.controls_crossing.multimode.snapshot.held_data==frozen &&
                   dut.machine.z_palette_cpu.controls_crossing.multimode.snapshot.request==request_before)
                else $fatal(1,"unconsumed video payload overwritten");
        end
        // Warm reset with VID still stopped; source reset does not erase the
        // held handshake. Restart under reset: mode/priority/black reset,
        // while the inherited PPI width latch remains at 40 columns.
        reset=1;repeat(32) tick();
        assert(dut.machine.z_palette_cpu.priority_control==0);
        video_run=1;
        repeat(64) @(negedge video_clk);
        assert(valid && controls==32'h00000001) else $fatal(1,"reset controls failed to cross %h",controls);
        seen=0;tick();reset=0;
        await_cpu();
        $display("PASS real CPU priority CDC: 256 cold/warm values, held payload, both stopped clocks, retained IPL; video half=%0d ps",video_half);
        $finish;
    end
endmodule
