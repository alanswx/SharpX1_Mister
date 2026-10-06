// SPDX-License-Identifier: GPL-2.0-only
// Original shared-machine CPU pending-read reset diagnostic. Synthetic ROM.
`timescale 1ps/1ps
module kanji_machine_reset_tb;
    logic clk=0,video_clk=0,sys_run=1,video_run=1,reset=1;
    always #15625 if(sys_run) clk=!clk;
    always #11640 if(video_run) video_clk=!video_clk;
    logic download=0,load=0;
    logic [7:0] index=0,data=0;
    logic [24:0] address=0;
    logic [7:0] program_bytes[0:4095];
    integer size=0,kind=0,writes=0;
    wire load_wait;
    top #(.TURBO(1),.TURBO_KANJI(1),.TURBO_VIDEO_MASTER(1)) dut (
        .clk_sys(clk),.clk_28636(video_clk),.reset(reset),
        .ioctl_download(download),.ioctl_index(index),.ioctl_wr(load),
        .ioctl_addr(address),.ioctl_dout(data),.ioctl_wait(load_wait),
        .ps2_clk_in(1'b1),.ps2_data_in(1'b1),.joya_n(8'hff),.joyb_n(8'hff),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_ack(1'b0),.sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_wr(1'b0),
        .debug_addr(16'hf100),
        .sd_drive(),.debug_disk_control(),.debug_disk_motor(),.debug_disk_ready(),
        .sd_lba(),.sd_rd(),.sd_wr(),.sd_buff_din(),
        .debug_ram(),.debug_text(),.debug_attr(),.sub_pc(),.sub_address(),.sub_control(),
        .sub_wait(),.sub_tx(),.sub_rx(),.cpu_address(),.cpu_in(),.cpu_out(),
        .cpu_mreq_n(),.cpu_iorq_n(),.cpu_rd_n(),.cpu_wr_n(),.cpu_halt_n(),
        .video(),.rgb(),.rgb12(),.audio(),.ce_pix(),.HSync(),.VSync(),.HBlank(),.VBlank(),
        .sys_edges(),.video_edges(),.reset_edges(),.cpu_enables(),.delayed_sys_edges(),
        .dma_grants(),.dma_reads(),.dma_writes(),.cpu_fdc_data_reads(),.cpu_fdc_data_writes()
    );
    always @(posedge video_clk) if(dut.machine.cg_access_write!=0) writes++;
    function automatic logic [7:0] pattern(input integer a);
        return 8'(a*37+(a>>8)*13+(a>>16)*211+19);
    endfunction
    task automatic emit(input logic [7:0] value);
        program_bytes[size]=value;size++;
    endtask
    task automatic word(input logic [7:0] opcode,input logic [15:0] value);
        emit(opcode);emit(value[7:0]);emit(value[15:8]);
    endtask
    task automatic output_port(input logic [15:0] port,input logic [7:0] value);
        word(8'h01,port);emit(8'h3e);emit(value);emit(8'hed);emit(8'h79);
    endtask
    task automatic tick;@(negedge clk);#1;endtask
    integer patch[0:15],fail_address;
    initial begin
        #1000000000000;$fatal(1,"shared-machine reset timeout kind=%0d",kind);
    end
    initial begin
        if($value$plusargs("RESET_KIND=%d",kind)) begin end
        assert(kind>=0 && kind<=4) else $fatal(1,"invalid reset profile");
        emit(8'hf3);word(8'h31,16'hffff);
        word(8'h21,16'hf100);emit(8'h34); // CPU increments retained boot count.
        output_port(16'h1a03,8'h82);
        word(8'h01,16'h1a02);emit(8'hed);emit(8'h78); // Read clears DAM.
        output_port(16'h1a02,8'h40);
        for(integer r=0;r<14;r++) begin
            output_port(16'h1800,8'(r));
            case(r)
                0:output_port(16'h1801,15);
                1,6,7:output_port(16'h1801,1);
                2: begin
                    // Place first-boot HSYNC beyond the 16-character total;
                    // zero width is NOT a reliable closed-window setting.
                    if(kind==4) begin
                        word(8'h01,16'h1801);
                        word(8'h3a,16'hf100);emit(8'hfe);emit(1);
                        emit(8'h20);emit(6); // JR NZ over OUT/JR.
                        emit(8'h3e);emit(255);emit(8'hed);emit(8'h79);
                        emit(8'h18);emit(4); // JR over normal OUT.
                        emit(8'h3e);emit(2);emit(8'hed);emit(8'h79);
                    end else output_port(16'h1801,2);
                end
                3:output_port(16'h1801,8'h12);
                default:output_port(16'h1801,0);
            endcase
        end
        for(integer n=0;n<4;n++) begin
            output_port(16'h2000+(n==0 ? 16'h7ff : n==1 ? 16'h3ff : n==2 ? 16'h5ff : 16'h1ff),7);
            output_port(16'h3000+(n==0 ? 16'h7ff : n==1 ? 16'h3ff : n==2 ? 16'h5ff : 16'h1ff),255);
            output_port(16'h3800+(n==0 ? 16'h7ff : n==1 ? 16'h3ff : n==2 ? 16'h5ff : 16'h1ff),8'hcf);
        end
        output_port(16'h1fd0,8'h60);
        word(8'h01,16'h1400);word(8'h21,16'hd000);
        for(integer row=0;row<16;row++) begin
            emit(8'hed);emit(8'ha2);emit(8'h04);emit(8'h0c);
        end
        for(integer row=0;row<16;row++) begin
            word(8'h3a,16'hd000+16'(row));emit(8'hfe);emit(pattern(131056+row));
            emit(8'hc2);patch[row]=size;emit(0);emit(0);
        end
        emit(8'h3e);emit(8'h5a);word(8'h32,16'hf101);emit(8'h76);
        fail_address=size;
        emit(8'h3e);emit(8'hee);word(8'h32,16'hf101);emit(8'h76);
        for(integer row=0;row<16;row++) begin
            program_bytes[patch[row]]=8'(fail_address);
            program_bytes[patch[row]+1]=8'(fail_address>>8);
        end
        repeat(8) tick();download=1;load=1;index=5;
        for(integer a=0;a<131072;a++) begin address=25'(a);data=pattern(a);tick();end
        load=0;download=0;tick();
        assert(dut.machine.kanji_loaded && !dut.machine.kanji_load_error) else $fatal(1,"initial physical upload");
        download=1;load=1;index=2;address=25'hf100;data=0;tick();address=25'hf101;tick();
        index=0;
        for(integer a=0;a<size;a++) begin address=25'(a);data=program_bytes[a];tick();end
        download=0;load=0;repeat(8) tick();reset=0;
        if(kind==2) begin
            wait(dut.machine.cg_access && dut.machine.io_read);
            video_run=0;
        end
        wait(dut.machine.cg_bus.busy && dut.machine.cg_bus.kanji_request && !dut.machine.cg_wait_n);
        if(kind==4) begin
            repeat(128) begin tick();
                assert(!dut.HSync && dut.machine.cg_bus.busy && !dut.machine.cg_wait_n)
                    else $fatal(1,"native closed window did not hold pending read");
            end
        end
        // Keep all stops/resets outside a clock edge, including 100 ps pulses
        // that no CPU clock can sample. No forced state/bus/result injection.
        #1000;
        if(kind==3) sys_run=0;
        reset=1;#10;
        assert(!dut.machine.cg_bus.busy && !dut.machine.kanji_cpu_read &&
               !dut.machine.kanji_cpu_valid && dut.machine.cg_wait_n && dut.machine.video_reset)
            else $fatal(1,"pending transaction did not cancel asynchronously");
        if(kind==1 || kind==2 || kind==3) #90;else #1000000;
        reset=0;
        if(kind==2) begin
            #1000000;
            assert(dut.machine.video_reset) else $fatal(1,"stopped video released reset");
            video_run=1;
        end
        if(kind==3) begin #1000000;sys_run=1;end
        wait(!dut.machine.video_reset);
        wait(!dut.cpu_halt_n);
        tick();
        assert(dut.machine.RAM.mem[16'hf100]==2 && dut.machine.RAM.mem[16'hf101]==8'h5a)
            else $fatal(1,"native restart/INI failed count=%x result=%x",dut.machine.RAM.mem[16'hf100],dut.machine.RAM.mem[16'hf101]);
        assert(dut.machine.kanji_loaded && !dut.machine.kanji_load_error && writes==0)
            else $fatal(1,"reset changed retained ROM or emitted a PCG write");
        $display("PASS shared X3 Kanji pending reset kind=%0d: async cancellation, retained ROM, real CPU restart/16 INI, zero PCG writes",kind);
        $finish;
    end
endmodule
