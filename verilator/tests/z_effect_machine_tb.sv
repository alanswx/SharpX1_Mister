// SPDX-License-Identifier: GPL-2.0-only
// Actual ioctl-loaded Z80, read-only result observations, no injected state.
`timescale 1ps/1ps
module z_effect_machine_tb #(parameter EFFECT_ENABLED=1);
    bit clk=0,video_clk=0,reset=1,download=0,upload_wr=0;
    always #15625 clk=~clk;
    always #17500 video_clk=~video_clk;
    logic [7:0] upload_data=0;
    logic [24:0] upload_address=0;
    wire upload_wait;
    logic [7:0] ipl[8192];
    string ipl_path;
    integer dam_writes=0;
    sharpx1 #(.TURBO(1),.TURBO_Z_PALETTE_CPU(1),.TURBO_Z_EFFECT_CPU(EFFECT_ENABLED)) dut(
        .clk_sys(clk),.clk_28636(video_clk),.reset(reset),.pal(1'b0),.scandouble(1'b0),
        .ioctl_download(download),.ioctl_index(8'd0),.ioctl_wr(upload_wr),
        .ioctl_addr(upload_address),.ioctl_dout(upload_data),.ioctl_wait(upload_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),.sio_rxd(2'b11),
        .sio_cts_n(2'b11),.sio_dcd_n(2'b11),.sio_txd(),.sio_rts_n(),.sio_dtr_n(),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_drive(),.sd_lba(),.sd_rd(),.sd_wr(),.sd_ack(1'b0),
        .sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_din(),.sd_buff_wr(1'b0),
        .ce_pix(),.HBlank(),.HSync(),.VBlank(),.VSync(),.video(),.rgb(),.rgb12(),
        .audio(),.audio_left(),.audio_right(),.audio_mono(),.audio_sample());
    always @(posedge clk) if(!dut.core_reset && dut.io_write && dut.dam && dut.a>=16'h1fc1 && dut.a<=16'h1fc4) begin
        dam_writes++;
        assert(!dut.z_effect_selected) else $fatal(1,"effect register selected during real DAM write");
    end
    task automatic tick;@(posedge clk);#1;endtask
    task automatic intact;
        for(integer a=0;a<8192;a++) assert(dut.IPL.mem[a]==ipl[a]) else $fatal(1,"effect retained IPL changed");
    endtask
    function automatic [7:0] distinct(input integer slot);
        case(slot) 0:return 8'h11;1:return 8'h22;2:return 8'h44;default:return 8'h88;endcase
    endfunction
    initial begin
        assert($value$plusargs("IPL=%s",ipl_path)) else $fatal(1,"missing original effect IPL");
        $readmemh(ipl_path,ipl);repeat(8) tick();
        for(integer a=0;a<8192;a++) begin
            @(negedge clk);download=1;upload_wr=1;upload_address=25'(a);upload_data=ipl[a];
            assert(!upload_wait) else $fatal(1,"unexpected effect loader wait");tick();
        end
        @(negedge clk);download=0;upload_wr=0;reset=0;
        for(integer i=0;i<2000000 && dut.halt_n;i++) tick();
        assert(!dut.halt_n && dut.RAM.mem['hf800]==8'ha5)
            else $fatal(1,"effect actual CPU cold program did not halt pc=%h halt=%b marker=%h first=%h last=%h mode=%h DAM=%b",dut.cpu_a,dut.halt_n,dut.RAM.mem['hf800],dut.RAM.mem['hf000],dut.RAM.mem['hf3ff],dut.z_palette_cpu.mode,dut.dam);
        for(integer slot=0;slot<4;slot++) begin
            for(integer d=0;d<256;d++) assert(dut.RAM.mem['hf000+slot*256+d]==8'(d))
                else $fatal(1,"effect actual CPU readback mismatch slot=%0d byte=%0d got=%h enabled=%0d",slot,d,dut.RAM.mem['hf000+slot*256+d],EFFECT_ENABLED);
            assert(dut.RAM.mem['hf810+slot]==0) else $fatal(1,"effect inactive AEN write changed reset storage");
            assert(dut.RAM.mem['hf814+slot]==distinct(slot)) else $fatal(1,"effect alias/DAM isolation failed");
            assert(dut.RAM.mem['hf818+slot]==distinct(slot)) else $fatal(1,"effect AEN exit discarded storage");
        end
        intact();@(negedge clk);reset=1;repeat(16) tick();@(negedge clk);reset=0;repeat(32) tick();
        for(integer i=0;i<2000000 && dut.halt_n;i++) tick();
        assert(!dut.halt_n && dut.RAM.mem['hf800]==8'h5a) else $fatal(1,"effect actual CPU warm program did not halt");
        for(integer slot=0;slot<4;slot++) assert(dut.RAM.mem['hf820+slot]==0)
            else $fatal(1,"effect warm reset did not clear control %0d",slot);
        intact();
        assert(dam_writes>0) else $fatal(1,"effect fixture never exercised actual DAM writes");
        $display("PASS: effect actual CPU 1024 byte roundtrips, AEN/inactive/DAM/neighbor controls, retained-IPL warm reset, %0d DAM write SYS events; no capture/effects pixels/native ASIC acceptance",dam_writes);
        $finish;
    end
endmodule
