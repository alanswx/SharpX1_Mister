// SPDX-License-Identifier: GPL-2.0-only
`timescale 1ps/1ps
module cz880_rtc_tb;
    bit clk=0,power_reset=1,oscillator_ce=0,cs=1;
    bit [7:0] mcu_p1=0;
    wire mcu_t1,data_out_sink,state_valid,second_tick,calendar_advanced,month_wrapped;
    wire [39:0] current_state,shift_state;
    wire [1:0] register_mode;
    wire [14:0] divider_phase;
    bit negative_clock=0,negative_command=0,negative_oe=0;
    wire [7:0] actual_p1={mcu_p1[7:6],negative_clock ? mcu_p1[4] : mcu_p1[5],
        mcu_p1[4:3],negative_oe ? 1'b1 : mcu_p1[2],
        negative_command ? {mcu_p1[0],mcu_p1[1]} : mcu_p1[1:0]};
    x1_cz880_rtc dut(.clk(clk),.power_reset(power_reset),.oscillator_ce(oscillator_ce),
        .cs(cs),.mcu_p1(actual_p1),.mcu_t1(mcu_t1),.data_out_sink(data_out_sink),
        .state_valid(state_valid),.second_tick(second_tick),.calendar_advanced(calendar_advanced),
        .month_wrapped(month_wrapped),.current_state(current_state),.shift_state(shift_state),
        .register_mode(register_mode),.divider_phase(divider_phase));
    integer checks=0;
    task automatic step(input bit osc=0);
        clk=0;oscillator_ce=osc;#5;clk=1;#5;
        checks++;
    endtask
    task automatic mode(input logic [1:0] command);
        mcu_p1[5:3]=0;mcu_p1[1:0]=command;step();
        mcu_p1[3]=1;step();
        // Held STB, even with altered command wires, cannot issue another command.
        mcu_p1[1:0]=~command;repeat(4) step();
        assert(register_mode==command) else $fatal(1,"RTC command edge/pin mapping mismatch");
        mcu_p1[3]=0;mcu_p1[1:0]=command;step();
    endtask
    task automatic serial_bit(input bit value);
        mcu_p1[5]=0;mcu_p1[4]=value;step();
        mcu_p1[5]=1;step();
        // Keeping CLK high must not shift again.
        repeat(2) step();
        mcu_p1[5]=0;step();
    endtask
    task automatic write_word(input logic [39:0] value);
        mode(1);
        for(integer i=0;i<40;i++) serial_bit(value[i]);
        assert(shift_state==value) else $fatal(1,"RTC 40-bit serial input mismatch");
    endtask
    task automatic read_word(input logic [39:0] expected);
        logic [39:0] observed;
        mode(1);
        for(integer i=0;i<40;i++) begin
            // Observe stable current LSB before the next rising shift edge.
            observed[i]=mcu_t1;
            serial_bit(0);
        end
        assert(observed==expected) else $fatal(1,"RTC T1 serial output mismatch got=%h expected=%h",observed,expected);
    endtask
    initial begin
        negative_clock=$test$plusargs("NEGATIVE_CLOCK");
        negative_command=$test$plusargs("NEGATIVE_COMMAND");
        negative_oe=$test$plusargs("NEGATIVE_OE");
        step();power_reset=0;step();
        assert(!state_valid && current_state==0) else $fatal(1,"invented RTC initialization");
        mcu_p1[2]=0;step();
        assert(mcu_t1 && !data_out_sink) else $fatal(1,"RTC OE/open-drain mismatch");
        mcu_p1[2]=1;step();
        // Entire shift register, no calendar-validity assumption for bit tests.
        for(integer bitno=0;bitno<40;bitno++) begin
            logic [39:0] walking;
            walking=40'd1 << bitno;
            write_word(walking);
            read_word(walking);
            write_word(~walking);
            read_word(~walking);
        end
        write_word(40'hc631123456);
        mode(2);
        assert(current_state==40'hc631123456 && state_valid) else $fatal(1,"RTC serial Time Set mismatch");
        // Mode Set holds through oscillator events, CS deassertion and CLK pulses.
        for(integer i=0;i<5000;i++) step(1);
        assert(current_state==40'hc631123456 && divider_phase==904) else $fatal(1,"RTC Time Set hold/divider mismatch");
        cs=0;
        for(integer i=0;i<40;i++) serial_bit(1);
        assert(current_state==40'hc631123456 && shift_state==40'hc631123456) else $fatal(1,"RTC CS isolation mismatch");
        // Changing CS with already-high CLK/STB cannot fabricate pin edges.
        mcu_p1[3]=1;mcu_p1[5]=1;mcu_p1[1:0]=1;step();
        cs=1;step();
        assert(register_mode==2 && shift_state==40'hc631123456) else $fatal(1,"RTC CS invented edge mismatch");
        mcu_p1[3]=0;mcu_p1[5]=0;step();
        mode(3);
        assert(shift_state==40'hc631123456) else $fatal(1,"RTC Time Read capture mismatch");
        // Coherent read snapshot is retained while the calendar advances.
        for(integer i=0;i<32768-904;i++) step(1);
        assert(current_state==40'hc631123457 && shift_state==40'hc631123456)
            else $fatal(1,"RTC independent advance/read snapshot mismatch");
        mode(3);read_word(40'hc631123457);
        // Register Hold, not Time Set, allows timekeeping and prohibits shifts.
        mode(0);
        for(integer i=0;i<40;i++) serial_bit(1);
        assert(shift_state==0) else $fatal(1,"RTC Register Hold allowed shift");
        for(integer i=0;i<32768;i++) step(1);
        assert(current_state==40'hc631123458) else $fatal(1,"RTC Register Hold stopped clock");
        mode(3);read_word(40'hc631123458);
        mode(0);cs=0;
        for(integer i=0;i<32768;i++) begin
            // Unrelated P16/P17, CS, and ignored serial activity cannot gate
            // the battery clock or change the retained register command.
            mcu_p1[7:6]=2'(i%4);
            mcu_p1[5:3]=3'(i%8);
            mcu_p1[1:0]=2'(i%4);
            step(1);
        end
        assert(current_state==40'hc631123459 && register_mode==0 && shift_state==0)
            else $fatal(1,"RTC running CS isolation mismatch");
        mcu_p1[5:3]=0;step();cs=1;step();
        mode(3);read_word(40'hc631123459);
        // Output permission is independent of valid data and selected mode.
        write_word(40'h0123456789);
        for(integer command=0;command<4;command++) begin
            mode(2'(command));mcu_p1[2]=0;step();
            assert(mcu_t1 && !data_out_sink) else $fatal(1,"RTC OE/open-drain mismatch");
            mcu_p1[2]=1;step();
        end
        power_reset=1;step();
        assert(current_state==0 && shift_state==0 && !state_valid && mcu_t1)
            else $fatal(1,"RTC configuration reset mismatch");
        assert(checks==137050) else $fatal(1,"RTC serial coverage count mismatch got=%0d",checks);
        $display("PASS: CZ-880 RTC serial %0d SYS edges, all 40 walking/complement bits, held strobes/clock, CS/OE isolation, real serial set/read and independent elapsed counter; MCU/native phase separate",checks);
        $finish;
    end
endmodule
