// SPDX-License-Identifier: GPL-2.0-only
`timescale 1ps/1ps
module rtc_clock_profile #(parameter integer HZ=32000000)(output bit done=0);
    bit clk=0,power_reset=1;
    wire oscillator_ce,correct_ce,wrong_rate_ce;
    wire [$clog2(HZ)-1:0] correct_phase;
    wire [$clog2(HZ+1)-1:0] wrong_rate_phase;
    wire [31:0] phase=negative_rate ? 32'(wrong_rate_phase) : 32'(correct_phase);
    bit negative_rate=0,negative_cpu=0;
    longint unsigned edge_number=0,events=0,next_deadline=0;
    wire consumed_ce=oscillator_ce && (!negative_cpu || edge_number%3==0);
    wire [39:0] current_state;
    wire [14:0] divider_phase;
    wire second_tick,advanced,valid;
    bit set_hold=0,load_time=0;
    bit serial_power_reset=1;
    bit [7:0] mcu_p1=0;
    wire [39:0] serial_state;
    wire [14:0] serial_phase;
    wire serial_valid,serial_tick,serial_advanced;
    integer seconds=0;
    assign oscillator_ce=negative_rate ? wrong_rate_ce : correct_ce;
    x1_rtc_clock_enable #(.CLOCK_HZ(HZ)) source(
        .clk(clk),.power_reset(power_reset),.oscillator_ce(correct_ce),.phase(correct_phase));
    x1_rtc_clock_enable #(.CLOCK_HZ(HZ+1)) wrong_rate_source(
        .clk(clk),.power_reset(power_reset),.oscillator_ce(wrong_rate_ce),.phase(wrong_rate_phase));
    x1_upd1990_counter counter(
        .clk(clk),.power_reset(power_reset),.oscillator_ce(consumed_ce),
        .set_hold(set_hold),.load_time(load_time),.load_state(40'hc631235959),
        .current_state(current_state),.divider_phase(divider_phase),
        .state_valid(valid),.load_accepted(),.second_tick(second_tick),
        .calendar_advanced(advanced),.month_wrapped());
    x1_cz880_rtc serial_device(
        .clk(clk),.power_reset(serial_power_reset),.oscillator_ce(consumed_ce),
        .cs(1'b1),.mcu_p1(mcu_p1),.mcu_t1(),.data_out_sink(),
        .current_state(serial_state),.shift_state(),.state_valid(serial_valid),
        .register_mode(),.divider_phase(serial_phase),.second_tick(serial_tick),
        .calendar_advanced(serial_advanced),.month_wrapped());
    task automatic reset_step;
        clk=0;#1;clk=1;#1;
    endtask
    task automatic serial_mode(input bit [1:0] command);
        mcu_p1=8'h04 | 8'(command);reset_step();
        mcu_p1[3]=1;reset_step();
        mcu_p1[3]=0;reset_step();
    endtask
    task automatic running_step;
        bit expected_event;
        clk=0;#1;
        edge_number++;
        expected_event=(edge_number==next_deadline);
        assert(oscillator_ce==expected_event)
            else $fatal(1,"RTC enable deadline mismatch HZ=%0d edge=%0d",HZ,edge_number);
        if(expected_event) begin
            events++;
            // Independent absolute rational deadline, not the DUT recurrence.
            next_deadline=((events+1)*HZ+32767)/32768;
        end
        clk=1;#1;
        if(second_tick) seconds++;
        assert(divider_phase==15'(events%32768))
            else $fatal(1,"RTC enable consumer phase mismatch HZ=%0d edge=%0d",HZ,edge_number);
        assert(second_tick==(expected_event && events%32768==0) && advanced==second_tick)
            else $fatal(1,"RTC enable consumer tick mismatch HZ=%0d edge=%0d",HZ,edge_number);
        assert(serial_valid && serial_state==current_state && serial_phase==divider_phase
               && serial_tick==second_tick && serial_advanced==advanced)
            else $fatal(1,"RTC enable serial consumer mismatch HZ=%0d edge=%0d",HZ,edge_number);
    endtask
    initial begin
        negative_rate=$test$plusargs("NEGATIVE_RATE");
        negative_cpu=$test$plusargs("NEGATIVE_CPU");
        reset_step();
        assert(!oscillator_ce && phase==0) else $fatal(1,"RTC enable reset mismatch");
        // Program the serial device solely through the native P1 pins, with
        // the clock producer held in configuration reset during initialization.
        serial_power_reset=0;reset_step();serial_mode(1);
        for(integer bitno=0;bitno<40;bitno++) begin
            mcu_p1[4]=1'(40'hc631235959 >> bitno);reset_step();
            mcu_p1[5]=1;reset_step();mcu_p1[5]=0;reset_step();
        end
        serial_mode(2);
        assert(serial_valid && serial_state==40'hc631235959)
            else $fatal(1,"RTC enable serial initialization mismatch");
        serial_mode(0);
        // Initialize the calendar with its real qualified Time Set command
        // interface while configuration reset keeps the producer phase zero.
        power_reset=0;set_hold=1;load_time=1;reset_step();
        assert(valid && current_state==40'hc631235959) else $fatal(1,"RTC counter initialization mismatch");
        load_time=0;set_hold=0;
        // The preceding edge already advanced the producer once; include it
        // in the absolute elapsed-edge oracle rather than forcing its state.
        edge_number=1;
        events=32768/64'(HZ);
        next_deadline=((events+1)*HZ+32767)/32768;
        for(longint unsigned i=1;i<2*HZ+17;i++) running_step();
        assert(events==65536+(17*32768/64'(HZ)) && seconds==2 && current_state==40'h1001000001)
            else $fatal(1,"RTC enable elapsed/calendar mismatch HZ=%0d events=%0d seconds=%0d state=%h",HZ,events,seconds,current_state);
        assert(phase==32'(((2*64'(HZ)+17)*32768)%HZ))
            else $fatal(1,"RTC enable residual mismatch HZ=%0d",HZ);
        power_reset=1;serial_power_reset=1;reset_step();
        assert(phase==0 && !oscillator_ce && !valid) else $fatal(1,"RTC enable power reset mismatch");
        $display("PASS: nominal RTC enable HZ=%0d edges=%0d events=%0d two-second serial/calendar carry; physical crystal/MCU integration separate",HZ,edge_number,events);
        done=1;
    end
endmodule
module rtc_clock_enable_tb;
    wire [4:0] done;
    rtc_clock_profile #(.HZ(32000000)) normal(done[0]);
    rtc_clock_profile #(.HZ(28571428)) board_single(done[1]);
    rtc_clock_profile #(.HZ(28636364)) nominal_single(done[2]);
    rtc_clock_profile #(.HZ(65536)) boundary(done[3]);
    rtc_clock_profile #(.HZ(32768)) every_edge(done[4]);
    initial begin
        wait(&done);
        $display("PASS: all five nominal RTC enable profiles and independent serial/calendar consumers");
        $finish;
    end
endmodule
