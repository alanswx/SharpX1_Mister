// SPDX-License-Identifier: GPL-2.0-only
// Original instruction-driven integration diagnostic, not native 80C49 firmware.
// Proposed replacement-MR16 wiring only: free OP5 -> P1; spare IP1[5] <- T1.
// No machine port, work-RAM interception or forced CPU/RTC state is supplied.
`timescale 1ps/1ps
module rtc_mr16_driver_tb;
    bit clk=0,cpu_reset=1,power_reset=1,cpu_running=1,ready=0;
    longint unsigned cycles=0;
    wire cpu_ce=cpu_running;
    wire [15:0] address,write_data,p1;
    logic [15:0] memory_data=0;
    wire write_enable,memory_cs,t1,oscillator_ce;
    wire [39:0] calendar;
    wire valid;
    bit negative_t1=0,negative_clock=0;
    wire actual_ce=oscillator_ce && !(negative_clock && !cpu_running);
    logic [15:0] rom[2048],ram[2048];
    integer emitted=8;
    x1_rtc_clock_enable clock_source(.clk(clk),.power_reset(power_reset),
        .oscillator_ce(oscillator_ce),.phase());
    x1_cz880_rtc rtc(.clk(clk),.power_reset(power_reset),.oscillator_ce(actual_ce),
        .cs(1'b1),.mcu_p1(p1[7:0]),.mcu_t1(t1),.data_out_sink(),
        .current_state(calendar),.state_valid(valid),.shift_state(),.register_mode(),
        .divider_phase(),.second_tick(),.calendar_advanced(),.month_wrapped());
    mr16_x1 controller(.I_RESET(cpu_reset),.I_CLK(clk),.I_CLKEN(cpu_ce),
        .O_A(address),.O_D(write_data),.I_D(memory_data),.O_WR(write_enable),.O_MEMCS(memory_cs),
        .I_TMRG(1'b0),.O_P0(),.O_P1(),.O_P2(),.O_P3(),.O_P4(),.O_P5(p1),
        .O_P6(),.O_P7(),.O_P8(),.O_P9(),.O_PA(),.O_PB(),
        .I_P0(16'd0),.I_P1({10'd0,negative_t1 ? !t1 : t1,5'd0}),
        .I_P2({15'd0,ready}),.I_P3(16'd0),
        .O_I4(),.O_I5(),.O_I6(),.O_I7(),.O_I8(),.O_I9(),.O_IA(),.O_IB(),
        .I_INT(4'd0),.O_ACK());
    // Same synchronous memory latency as the replacement-controller path.
    always @(posedge clk) begin
        memory_data <= address[12] ? ram[address[11:1]] : rom[address[11:1]];
        if(!cpu_reset && memory_cs && write_enable && address[12])
            ram[address[11:1]] <= write_data;
    end
    task automatic step;
        clk=0;#5;clk=1;#5;cycles++;
    endtask
    task automatic word(input logic [15:0] value);
        assert(emitted<2048) else $fatal(1,"MR16 diagnostic ROM overflow");
        rom[emitted++]=value;
    endtask
    task automatic mov16(input integer regno,input logic [15:0] value);
        word(16'h2700 | 16'(value>>8));
        word(16'h7000 | 16'(regno<<8) | {8'd0,value[7:0]});
    endtask
    task automatic port_write(input logic [7:0] value);
        word(16'h7000 | {8'd0,value}); // MOV r0,#value:8
        word(16'h1e05);              // STM (r14,#10),r0 -- OP5
    endtask
    task automatic mode(input logic [1:0] command);
        port_write(8'h04 | {6'd0,command});
        port_write(8'h0c | {6'd0,command});
        port_write(8'h04 | {6'd0,command});
    endtask
    initial begin
        negative_t1=$test$plusargs("NEGATIVE_T1");
        negative_clock=$test$plusargs("NEGATIVE_CLOCK");
        for(integer i=0;i<2048;i++) begin rom[i]=16'h3f00;ram[i]=0;end
        rom[0]=16'h0010; // actual reset vector, not an injected CPU PC
        mov16(14,16'h2000);mov16(13,16'h1000);mov16(12,16'h1020);
        mode(1);
        for(integer bitno=0;bitno<40;bitno++) begin
            bit value;
            value=1'(40'hc631123456>>bitno);
            port_write(8'h05 | (value ? 8'h10 : 0));
            port_write(8'h25 | (value ? 8'h10 : 0));
            port_write(8'h05 | (value ? 8'h10 : 0));
        end
        mode(2);mode(0);
        word(16'h7001);word(16'h1d00); // firmware marker: calendar loaded
        // Actual firmware status polling, no testbench PC/register forcing.
        word(16'h0e02);word(16'hd001);word(16'h29fe); // LDM IP2; CMP #1; BNE poll
        mode(3);mode(1);
        for(integer bitno=0;bitno<40;bitno++) begin
            word(16'h0e01);word(16'h1c00);word(16'h8c02); // read IP1, store, advance pointer
            port_write(8'h25);port_write(8'h05);
        end
        word(16'h7002);word(16'h1d00);word(16'h2f00); // complete marker; BRA self
        assert(emitted==572) else $fatal(1,"MR16 RTC diagnostic coverage/ROM count mismatch");
        repeat(8) step();power_reset=0;cpu_reset=0;
        for(integer i=0;i<200000 && ram[0]!=1;i++) step();
        assert(ram[0]==1 && valid && calendar==40'hc631123456)
            else $fatal(1,"MR16 RTC serial programming mismatch marker=%h calendar=%h",ram[0],calendar);
        // Two real nominal seconds pass with the controller CE completely stopped.
        cpu_running=0;
        repeat(64000000) step();
        assert(calendar==40'hc631123458 && ram[0]==1)
            else $fatal(1,"MR16 RTC stopped-controller clock mismatch calendar=%h",calendar);
        ready=1;cpu_running=1;
        for(integer i=0;i<200000 && ram[0]!=2;i++) step();
        assert(ram[0]==2) else $fatal(1,"MR16 RTC read driver completion mismatch");
        for(integer bitno=0;bitno<40;bitno++)
            assert(ram[16+bitno]==(1'(40'hc631123458>>bitno) ? 16'h0020 : 16'h0000))
                else $fatal(1,"MR16 RTC T1 readback mismatch bit=%0d actual=%h",bitno,ram[16+bitno]);
        $display("PASS: real MR16 %0d-word original driver programs P1, independent two-second clock while CE stopped, all 40 T1 bits in actual RAM; main mailbox/native MCU integration separate",emitted);
        $finish;
    end
endmodule
