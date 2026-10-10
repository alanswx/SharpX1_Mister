// SPDX-License-Identifier: GPL-2.0-only
// Actual inherited firmware + source-linked callbacks; replacement bus fixture,
// not x1_sub/shared-machine, FDC/DMA, native IRQ or hardware qualification.
`timescale 1ps/1ps
module rtc_mr16_firmware_tb #(parameter CE_DIVISOR=1);
    bit clk=0,reset=1,power_reset=1,running=1;
    longint unsigned cycles=0;
    wire ce=running && cycles%64'(CE_DIVISOR)==0;
    wire [15:0] address,write_data,p1;
    logic [15:0] memory_data=0;
    wire write_enable,memory_cs,t1,oscillator_ce,hrd_set,hwd_clear;
    wire [39:0] calendar;
    wire valid;
    bit hwd_full=0,hrd_full=0;
    logic [15:0] rom[4096],ram[2048];
    wire rom_cs,ram_cs;
    wire [11:0] rom_address;
    string rom_path;
    bit baseline_control=0;
    byte result_bytes[3];
    x1_mr16_rom_decode #(.EXTENDED(1)) decoder(address,memory_cs,rom_cs,ram_cs,rom_address);
    x1_rtc_clock_enable oscillator(.clk(clk),.power_reset(power_reset),
        .oscillator_ce(oscillator_ce),.phase());
    x1_cz880_rtc rtc(.clk(clk),.power_reset(power_reset),.oscillator_ce(oscillator_ce),
        .cs(1'b1),.mcu_p1(p1[7:0]),.mcu_t1(t1),.data_out_sink(),
        .current_state(calendar),.state_valid(valid),.shift_state(),.register_mode(),
        .divider_phase(),.second_tick(),.calendar_advanced(),.month_wrapped());
    mr16_x1 #(.RETAIN_RESPONSE(1)) controller(.I_RESET(reset),.I_CLK(clk),.I_CLKEN(ce),
        .O_A(address),.O_D(write_data),.I_D(memory_data),.O_WR(write_enable),.O_MEMCS(memory_cs),
        .I_TMRG(1'b0),.O_P0(),.O_P1(),.O_P2(),.O_P3(),.O_P4(),.O_P5(p1),
        .O_P6(),.O_P7(),.O_P8(),.O_P9(),.O_PA(),.O_PB(),
        .I_P0(16'd0),.I_P1({10'd0,t1,3'd0,hwd_full,hrd_full}),
        .I_P2(16'd3),.I_P3(16'd0),.O_I4(hrd_set),.O_I5(hwd_clear),
        .O_I6(),.O_I7(),.O_I8(),.O_I9(),.O_IA(),.O_IB(),.I_INT(4'd0),.O_ACK());
    always @(posedge clk) begin
        if(!reset && ce && cycles<64'(CE_DIVISOR)*100 && $test$plusargs("TRACE_START"))
            $display("TRACE c=%0d pc=%h a=%h di=%h raw=%h held=%h inst=%h sp=%h",cycles,{controller.cpu.reg_pc,1'b0},address,memory_data,controller.raw_d_in,controller.d_in,controller.cpu.inst,{controller.cpu.reg_rh[15],controller.cpu.reg_rl[15]});
        memory_data <= ram_cs ? ram[address[11:1]] : rom_cs ? rom[rom_address] : 16'hffff;
        if(!reset && ram_cs && write_enable) ram[address[11:1]] <= write_data;
        // GPIO acknowledges are SYS-domain transport events, as in x1_sub;
        // gating their delayed pulse with controller CE loses sparse replies.
        if(!reset && hrd_set) hrd_full <= 1;
        if(!reset && hwd_clear) hwd_full <= 0;
    end
    task automatic step;
        clk=0;#5;clk=1;#5;cycles++;
    endtask
    task automatic send(input byte value);
        for(integer i=0;i<2000000 && hwd_full;i++) step();
        assert(!hwd_full) else $fatal(1,"firmware host input full timeout");
        ram[1]={8'd0,value};hwd_full=1;
        for(integer i=0;i<2000000 && hwd_full;i++) step();
        assert(!hwd_full) else $fatal(1,"firmware command receive timeout byte=%h address=%h PC=%h SP=%h flags=%h",value,address,{controller.cpu.reg_pc,1'b0},{controller.cpu.reg_rh[15],controller.cpu.reg_rl[15]},controller.cpu.reg_flag);
        // This bounded host waits for the complete GPIO read tail before a
        // new write. Immediate back-to-back host transfers during a stretched
        // ACK are a separate transport/actual-Z80 qualification gate.
        for(integer i=0;i<2000000 && hwd_clear;i++) step();
        assert(!hwd_clear) else $fatal(1,"firmware host ACK drain timeout");
    endtask
    task automatic receive3;
        for(integer n=0;n<3;n++) begin
            for(integer i=0;i<2000000 && !hrd_full;i++) step();
            assert(hrd_full) else $fatal(1,"firmware reply timeout index=%0d",n);
            for(integer i=0;i<2000000 && hrd_set;i++) step();
            assert(!hrd_set) else $fatal(1,"firmware reply ACK drain timeout");
            result_bytes[n]=ram[0][7:0];hrd_full=0;
            repeat(CE_DIVISOR*8) step();
        end
    endtask
    initial begin
        baseline_control=$test$plusargs("BASELINE_CONTROL");
        assert($value$plusargs("ROM=%s",rom_path)) else $fatal(1,"missing linked firmware ROM");
        for(integer i=0;i<4096;i++) rom[i]=16'h3f00;
        for(integer i=0;i<2048;i++) ram[i]=0;
        $readmemh(rom_path,rom);
        assert(rom[0]==(baseline_control ? 16'h0112 : 16'h4000)) else $fatal(1,"linked/control reset vector mismatch");
        repeat(8) step();power_reset=0;reset=0;
        repeat(CE_DIVISOR*100000) step();
        if(baseline_control) begin
            // Original E7/E8 TV-control mailbox, no banked callback execution.
            send(8'he7);send(8'h55);send(8'he8);
            for(integer i=0;i<2000000 && !hrd_full;i++) step();
            for(integer i=0;i<2000000 && hrd_set;i++) step();
            assert(hrd_full && ram[0][7:0]==8'h55) else $fatal(1,"original firmware E7/E8 control failed");
            $display("PASS: original inherited firmware E7/E8 control CE=%0d; RTC callbacks not used",CE_DIVISOR);
            $finish;
        end
        send(8'hec);send(8'h31);send(8'hc6);send(8'h99);
        send(8'hee);send(8'h12);send(8'h34);send(8'h56);
        repeat(CE_DIVISOR*50000) step();
        assert(valid && calendar==40'hc631123456)
            else $fatal(1,"firmware command RTC program mismatch %h",calendar);
        send(8'hed);receive3();
        assert(result_bytes[0]==8'h31 && result_bytes[1]==8'hc6 && result_bytes[2]==8'h99)
            else $fatal(1,"firmware date reply mismatch %h %h %h",result_bytes[0],result_bytes[1],result_bytes[2]);
        send(8'hef);receive3();
        assert(result_bytes[0]==8'h12 && result_bytes[1]==8'h34 && result_bytes[2]==8'h56)
            else $fatal(1,"firmware time reply mismatch");
        running=0;repeat(64000000) step();running=1;
        send(8'hef);receive3();
        assert(result_bytes[0]==8'h12 && result_bytes[1]==8'h34 && result_bytes[2]==8'h58)
            else $fatal(1,"firmware elapsed-time mismatch %h %h %h",result_bytes[0],result_bytes[1],result_bytes[2]);
        reset=1;hwd_full=0;hrd_full=0;repeat(8) step();reset=0;
        repeat(CE_DIVISOR*100000) step();
        send(8'hed);receive3();
        assert(result_bytes[0]==8'h31 && result_bytes[1]==8'hc6 && result_bytes[2]==0)
            else $fatal(1,"firmware retained clock/software-year reset mismatch");
        $display("PASS: linked inherited firmware real EC/ED/EE/EF mailbox CE=%0d, independent ticking and retained-clock/software-year reset; machine/IRQ/FDC/DMA/native gates separate",CE_DIVISOR);
        $finish;
    end
endmodule
