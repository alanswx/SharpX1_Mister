// SPDX-License-Identifier: GPL-2.0-only
`timescale 1ps/1ps
module upd1990_calendar_tb;
    bit [39:0] current_state=0;
    wire state_valid;
    wire [39:0] next_state;
    wire month_wrapped;
    bit negative_bcd=0,negative_leap=0,negative_invalid=0;
    x1_upd1990_calendar dut(.*);
    integer checks=0;
    function automatic logic [7:0] packed_decimal(input integer value);
        return 8'((value/10)*16+value%10);
    endfunction
    function automatic logic [39:0] packed_state(input integer mon,dow,date,h,m,s);
        return {4'(mon),4'(dow),packed_decimal(date),packed_decimal(h),packed_decimal(m),packed_decimal(s)};
    endfunction
    function automatic integer days_in_month(input integer mon);
        integer lengths[12]='{31,28,31,30,31,30,31,31,30,31,30,31};
        return lengths[mon-1];
    endfunction
    task automatic check_valid(input integer mon,dow,date,h,m,s);
        integer total,next_mon,next_dow,next_day;
        bit expected_wrap;
        logic [39:0] expected,observed;
        current_state=packed_state(mon,dow,date,h,m,s);
        total=h*3600+m*60+s+1;
        next_mon=mon;next_dow=dow;next_day=date;expected_wrap=0;
        if(total==86400) begin
            total=0;
            next_dow=(dow+1)%7;
            next_day=date+1;
            if(next_day>days_in_month(mon)) begin
                next_day=1;
                next_mon=mon%12+1;
                expected_wrap=mon==12;
            end
        end
        expected=packed_state(next_mon,next_dow,next_day,total/3600,(total/60)%60,total%60);
        #1;
        observed=next_state;
        // Matched candidate mutations, not weakened/replaced expected rules.
        if(negative_bcd && s%10==9 && s!=59)
            observed[7:0]=current_state[7:0]+8'd1;
        if(negative_leap && mon==2 && date==28 && h==23 && m==59 && s==59)
            observed[39:24]={4'd2,4'(next_dow),8'h29};
        assert(state_valid && observed==expected && month_wrapped==expected_wrap)
            else $fatal(1,"calendar step mismatch in=%h got=%h expected=%h valid=%b wrap=%b/%b",
                        current_state,observed,expected,state_valid,month_wrapped,expected_wrap);
        checks++;
    endtask
    task automatic check_invalid(input logic [39:0] value);
        current_state=value;
        #1;
        assert(!(state_valid || negative_invalid) && next_state==value && !month_wrapped)
            else $fatal(1,"invalid calendar contract violated: %h",value);
        checks++;
    endtask
    initial begin
        negative_bcd=$test$plusargs("NEGATIVE_BCD");
        negative_leap=$test$plusargs("NEGATIVE_LEAP");
        negative_invalid=$test$plusargs("NEGATIVE_INVALID");
        // Exhaust every wall-clock second at four midnight boundaries.
        for(integer profile=0;profile<4;profile++)
        for(integer h=0;h<24;h++)
        for(integer m=0;m<60;m++)
        for(integer s=0;s<60;s++) begin
            case(profile)
                0: check_valid(2,6,28,h,m,s);
                1: check_valid(2,0,29,h,m,s);
                2: check_valid(4,3,30,h,m,s);
                3: check_valid(12,5,31,h,m,s);
            endcase
        end
        // All ordinary calendar dates and manually set Feb.29 at every D/W.
        for(integer mon=1;mon<=12;mon++)
        for(integer day=1;day<=days_in_month(mon)+(mon==2 ? 1 : 0);day++)
        for(integer dow=0;dow<7;dow++) begin
            check_valid(mon,dow,day,23,59,59);
            check_valid(mon,dow,day,12,34,56);
        end
        // Exhaust each byte's invalid aliases independently, plus all zero.
        for(integer field=0;field<5;field++)
        for(integer value=0;value<256;value++) begin
            integer decimal_value;
            bit valid;
            logic [39:0] state;
            decimal_value=(value/16)*10+value%16;
            if(field<4)
                valid=value/16<10 && value%16<10 &&
                      (field<2 ? decimal_value<60 :
                       field==2 ? decimal_value<24 : decimal_value>=1 && decimal_value<=31);
            else valid=value/16>=1 && value/16<=12 && value%16<=6;
            state=packed_state(1,0,1,0,0,0);
            state[field*8+:8]=8'(value);
            if(!valid) check_invalid(state);
        end
        check_invalid(40'd0);
        check_invalid(packed_state(4,0,31,0,0,0));
        check_invalid(packed_state(2,0,30,0,0,0));
        assert(checks==351748) else $fatal(1,"calendar case coverage incomplete: %0d",checks);
        $display("PASS: calendar arithmetic %0d cases; every second, all dates/weekdays, manual Feb.29, invalid aliases; not running/serial RTC",checks);
        $finish;
    end
endmodule
