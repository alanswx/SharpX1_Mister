// SPDX-License-Identifier: GPL-2.0-only
`timescale 1ps/1ps
module upd1990_counter_tb;
    bit clk=0,power_reset=1,oscillator_ce=0,set_hold=0,load_time=0;
    bit [39:0] load_state=0;
    wire [39:0] current_state;
    wire state_valid,load_accepted,second_tick,calendar_advanced,month_wrapped;
    wire [14:0] divider_phase;
    bit negative_cpu=0,negative_hold=0,negative_phase=0,host_stopped=0;
    wire actual_ce=oscillator_ce && !(negative_cpu && host_stopped);
    x1_upd1990_counter dut(.clk(clk),.power_reset(power_reset),.oscillator_ce(actual_ce),
        .set_hold(negative_hold ? 1'b0 : set_hold),.load_time(load_time),.load_state(load_state),
        .current_state(current_state),.state_valid(state_valid),.divider_phase(divider_phase),
        .load_accepted(load_accepted),.second_tick(second_tick),
        .calendar_advanced(calendar_advanced),.month_wrapped(month_wrapped));
    integer checks=0;
    integer expected_phase=0;
    logic [39:0] expected_state=0;
    bit expected_valid=0;
    function automatic bit valid_preset(input logic [39:0] value);
        integer mon,day;
        integer limits[12]='{31,29,31,30,31,30,31,31,30,31,30,31};
        mon=int'(value[39:36]);
        if(mon<1 || mon>12 || value[35:32]>6) return 0;
        for(integer field=0;field<4;field++) begin
            integer byte_value,decimal_value;
            byte_value=int'(value[field*8+:8]);
            decimal_value=(byte_value/16)*10+byte_value%16;
            if(byte_value/16>9 || byte_value%16>9) return 0;
            if(field<2 && decimal_value>59) return 0;
            if(field==2 && decimal_value>23) return 0;
            if(field==3) begin
                day=decimal_value;
                if(day<1 || day>limits[mon-1]) return 0;
            end
        end
        return 1;
    endfunction
    task automatic edge_check(input bit ce,hold,load,reset,
                              input logic [39:0] preset,
                              input logic [39:0] after_second,
                              input bit expected_wrap=0);
        bit tick,advanced,accepted;
        clk=0; oscillator_ce=ce;set_hold=hold;load_time=load;power_reset=reset;load_state=preset;
        #5;
        accepted=load && hold && !reset;
        tick=!reset && !hold && ce && expected_phase==32767;
        advanced=tick && expected_valid;
        if(reset) begin
            expected_phase=0;expected_state=0;expected_valid=0;
        end else begin
            if(hold) expected_phase=(expected_phase%1024+int'(ce))%1024;
            else expected_phase=(expected_phase+int'(ce))%32768;
            if(advanced) expected_state=after_second;
            if(accepted) begin
                expected_state=preset;
                expected_valid=valid_preset(preset);
            end
        end
        assert(load_accepted==accepted) else $fatal(1,"counter load permission mismatch");
        clk=1;
        #5;
        assert((negative_phase && hold ? divider_phase & 15'h01ff : divider_phase)==15'(expected_phase)
               && current_state==expected_state && state_valid==expected_valid)
            else $fatal(1,"counter state/phase mismatch phase=%0d/%0d state=%h/%h",divider_phase,expected_phase,current_state,expected_state);
        assert(second_tick==tick && calendar_advanced==advanced && month_wrapped==(advanced && expected_wrap))
            else $fatal(1,"counter event mismatch tick=%b/%b advanced=%b/%b",second_tick,tick,calendar_advanced,advanced);
        checks++;
    endtask
    task automatic oscillator_edges(input integer count,input logic [39:0] after_second,
                                     input bit hold=0,wrap=0);
        for(integer i=0;i<count;i++) begin
            // Ordinary host pauses/enables have no wire to this time counter.
            host_stopped=i%3!=0;
            edge_check(1,hold,0,0,0,after_second,wrap);
            // Explicitly stopped oscillator must NOT be mistaken for host halt.
            if(i%17==0) edge_check(0,hold,0,0,0,after_second,wrap);
        end
    endtask
    initial begin
        negative_cpu=$test$plusargs("NEGATIVE_CPU");
        negative_hold=$test$plusargs("NEGATIVE_HOLD");
        negative_phase=$test$plusargs("NEGATIVE_PHASE");
        edge_check(0,0,0,1,0,0);
        // Oscillator can run before initialization, never a valid clock/date.
        oscillator_edges(32768,0);
        assert(!state_valid && current_state==0) else $fatal(1,"invented cold calendar");
        // Load permission requires Time Set. Bad caller load cannot alter state.
        edge_check(0,0,1,0,40'hc631123456,0);
        edge_check(0,1,1,0,40'hc631123456,0);
        oscillator_edges(5000,40'hc631123456,1);
        assert(current_state==40'hc631123456) else $fatal(1,"Time Set did not hold calendar");
        // 5000 held edges leave low-stage phase=904. Release does not reset it.
        oscillator_edges(32768-904,40'hc631123457);
        // Independent host halt across a complete following second.
        oscillator_edges(32768,40'hc631123458);
        // Re-enter Time Set at nonzero full-divider phase with no oscillator.
        oscillator_edges(17017,40'hc631123458);
        edge_check(0,1,0,0,0,0);
        assert(divider_phase==633) else $fatal(1,"Time Set lost retained low stages");
        edge_check(1,1,1,0,40'hc631235959,0);
        // Load/oscillator coincidence cannot increment or produce a stale tick.
        oscillator_edges(32768-634,40'h1001000000,0,1);
        // Leaving/leaving oscillator stopped: exact state/divider/event retention.
        for(integer i=0;i<80;i++) edge_check(0,0,0,0,0,0);
        edge_check(0,1,1,0,40'h2029235959,0);
        oscillator_edges(32768,40'h3101000000);
        // Invalid caller data remain invalid even with a continuing oscillator.
        edge_check(0,1,1,0,40'h2230000000,0);
        oscillator_edges(32768,0);
        assert(!state_valid && current_state==40'h2230000000) else $fatal(1,"invalid loaded state advanced");
        // Boundary phases around the retained-stage carry and full divider wrap.
        for(integer profile=0;profile<5;profile++)
        for(integer ce_at_hold=0;ce_at_hold<2;ce_at_hold++)
        for(integer load_at_hold=0;load_at_hold<2;load_at_hold++) begin
            integer phase,remaining;
            case(profile)
                0: phase=1;
                1: phase=1023;
                2: phase=1024;
                3: phase=31744;
                default: phase=32767;
            endcase
            edge_check(0,0,0,1,0,0);
            edge_check(0,1,1,0,40'hc631123456,0);
            oscillator_edges(phase,0);
            edge_check(1'(ce_at_hold),1,1'(load_at_hold),0,40'hc631123456,0);
            remaining=32768-expected_phase;
            oscillator_edges(remaining,40'hc631123457);
        end
        // Configuration/power reset invalidates the backend, not ordinary warm reset.
        edge_check(1,0,1,1,40'hc631123456,0);
        assert(current_state==0 && !state_valid && divider_phase==0) else $fatal(1,"power reset incomplete");
        assert(checks==1201499) else $fatal(1,"counter case coverage incomplete: %0d",checks);
        $display("PASS: independent oscillator counter %0d edges, exact division/held low stages, elapsed time, midnight/month carry, stopped oscillator and power reset; serial/MCU integration separate",checks);
        $finish;
    end
endmodule
