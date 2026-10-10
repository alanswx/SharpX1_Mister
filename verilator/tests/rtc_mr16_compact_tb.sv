// SPDX-License-Identifier: GPL-2.0-only
// Original compact assembled-driver execution, not shared-machine RTC support.
`timescale 1ps/1ps
module rtc_mr16_compact_tb #(parameter CE_DIVISOR=1, RETAIN_RESPONSE=1);
    bit clk=0,reset=1,power_reset=1,running=1,ready=0;
    longint unsigned cycles=0;
    wire ce=running && cycles%CE_DIVISOR==0;
    wire [15:0] address,write_data,p1;
    logic [15:0] memory_data=0;
    wire write_enable,memory_cs,t1,oscillator_ce;
    wire [39:0] calendar;
    wire valid;
    bit bad_t1=0,bad_clock=0;
    logic [15:0] rom[2048],ram[2048];
    bit [2:0] stores=0;
    integer stack_writes=0,stack_reads=0;
    string rom_path;
    x1_rtc_clock_enable oscillator(.clk(clk),.power_reset(power_reset),
        .oscillator_ce(oscillator_ce),.phase());
    x1_cz880_rtc rtc(.clk(clk),.power_reset(power_reset),
        .oscillator_ce(oscillator_ce && !(bad_clock && !running)),
        .cs(1'b1),.mcu_p1(p1[7:0]),.mcu_t1(t1),.data_out_sink(),
        .current_state(calendar),.state_valid(valid),.shift_state(),.register_mode(),
        .divider_phase(),.second_tick(),.calendar_advanced(),.month_wrapped());
    mr16_x1 #(.RETAIN_RESPONSE(RETAIN_RESPONSE)) controller(.I_RESET(reset),.I_CLK(clk),.I_CLKEN(ce),
        .O_A(address),.O_D(write_data),.I_D(memory_data),.O_WR(write_enable),.O_MEMCS(memory_cs),
        .I_TMRG(1'b0),.O_P0(),.O_P1(),.O_P2(),.O_P3(),.O_P4(),.O_P5(p1),
        .O_P6(),.O_P7(),.O_P8(),.O_P9(),.O_PA(),.O_PB(),
        .I_P0(16'd0),.I_P1({10'd0,bad_t1 ? !t1 : t1,5'd0}),
        .I_P2({15'd0,ready}),.I_P3(16'd0),
        .O_I4(),.O_I5(),.O_I6(),.O_I7(),.O_I8(),.O_I9(),.O_IA(),.O_IB(),
        .I_INT(4'd0),.O_ACK());
    always @(posedge clk) begin
        memory_data <= address[12] ? ram[address[11:1]] : rom[address[11:1]];
        if(!reset && memory_cs && write_enable && address[12]) begin
            ram[address[11:1]] <= write_data;
            if(address>=16'h1020 && address<=16'h1024)
                stores[(int'(address)-32'h00001020)/2] <= 1'b1;
            if(ce && address==16'h17fe) stack_writes++;
        end
        if(!reset && ce && memory_cs && !write_enable && address==16'h17fe) stack_reads++;
    end
    task automatic step;
        clk=0;#5;clk=1;#5;cycles++;
    endtask
    initial begin
        bad_t1=$test$plusargs("NEGATIVE_T1");
        bad_clock=$test$plusargs("NEGATIVE_CLOCK");
        assert($value$plusargs("ROM=%s",rom_path)) else $fatal(1,"compact MR16 missing assembled ROM");
        for(integer i=0;i<2048;i++) begin rom[i]=16'h3f00;ram[i]=0;end
        $readmemh(rom_path,rom);
        assert(rom[0]==16'h0010) else $fatal(1,"compact MR16 reset vector mismatch");
        repeat(8) step();power_reset=0;reset=0;
        for(integer i=0;i<400000 && ram[0]!=1;i++) step();
        assert(ram[0]==1 && valid && calendar==40'hc631123456)
            else $fatal(1,"compact MR16 RTC program mismatch marker=%h calendar=%h",ram[0],calendar);
        // A genuine controller warm reset restarts at ROM[0]; the assembled
        // driver observes retained RAM and must not reprogram the RTC.
        reset=1;repeat(8) step();reset=0;
        repeat(50000) step();
        assert(ram[0]==1 && calendar==40'hc631123456)
            else $fatal(1,"compact MR16 RTC retained-reset mismatch");
        running=0;
        repeat(64000000) step();
        assert(calendar==40'hc631123458 && ram[0]==1)
            else $fatal(1,"compact MR16 RTC stopped-controller mismatch calendar=%h",calendar);
        ready=1;running=1;
        for(integer i=0;i<400000 && ram[0]!=2;i++) step();
        assert(ram[0]==2 && &stores)
            else $fatal(1,"compact MR16 RTC read completion/store mismatch marker=%h stores=%h",ram[0],stores);
        assert(ram[16]==16'h3458 && ram[17]==16'h3112 && ram[18]==16'h00c6)
            else $fatal(1,"compact MR16 RTC packed readback mismatch %h %h %h",ram[16],ram[17],ram[18]);
        assert(stack_writes>=8 && stack_reads>=8)
            else $fatal(1,"compact MR16 stack call/return coverage mismatch %0d %0d",stack_writes,stack_reads);
        $display("PASS: compact assembled real MR16 CE=%0d retain=%0d actual calls/stack/packed RAM, retained-controller reset, two seconds independent of stopped CE; machine/year/IRQ separate",CE_DIVISOR,RETAIN_RESPONSE);
        $finish;
    end
endmodule
