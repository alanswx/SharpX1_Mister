// SPDX-License-Identifier: GPL-2.0-only
// Original uPD1990AC calendar arithmetic from NEC 1983 data book pp.795-798.
// This is a next-second function, NOT a serial RTC, oscillator or MCU year.
// Packed state, high to low: {hex month, weekday, BCD day/hour/minute/second}.
// Invalid input is explicitly outside this helper's contract: preserve it and
// deassert state_valid. Callers must not treat that policy as native silicon.
module x1_upd1990_calendar (
    input wire [39:0] current_state,
    output logic state_valid,
    output logic [39:0] next_state,
    output logic month_wrapped
);
    function automatic logic bcd_valid(input logic [7:0] value);
        bcd_valid = value[7:4] <= 4'd9 && value[3:0] <= 4'd9;
    endfunction
    function automatic logic [7:0] bcd_increment(input logic [7:0] value);
        bcd_increment = value + (value[3:0] == 4'd9 ? 8'd7 : 8'd1);
    endfunction
    function automatic logic [7:0] last_day(input logic [3:0] month);
        case (month)
            4'd2: last_day = 8'h28;
            4'd4,4'd6,4'd9,4'd11: last_day = 8'h30;
            default: last_day = 8'h31;
        endcase
    endfunction
    wire [7:0] second = current_state[7:0];
    wire [7:0] minute = current_state[15:8];
    wire [7:0] hour = current_state[23:16];
    wire [7:0] day = current_state[31:24];
    wire [3:0] weekday = current_state[35:32];
    wire [3:0] month = current_state[39:36];
    always_comb begin
        // Manually setting Feb.29 is documented even though automatic carry
        // skips it. The following midnight must therefore accept/roll Feb.29.
        state_valid = bcd_valid(second) && second <= 8'h59
                   && bcd_valid(minute) && minute <= 8'h59
                   && bcd_valid(hour) && hour <= 8'h23
                   && bcd_valid(day) && day != 8'd0
                   && day <= (month == 4'd2 ? 8'h29 : last_day(month))
                   && weekday <= 4'd6 && month >= 4'd1 && month <= 4'd12;
        next_state = current_state;
        month_wrapped = 1'b0;
        if (state_valid) begin
            next_state[7:0] = bcd_increment(second);
            if (second == 8'h59) begin
                next_state[7:0] = 8'd0;
                next_state[15:8] = bcd_increment(minute);
                if (minute == 8'h59) begin
                    next_state[15:8] = 8'd0;
                    next_state[23:16] = bcd_increment(hour);
                    if (hour == 8'h23) begin
                        next_state[23:16] = 8'd0;
                        next_state[35:32] = weekday == 4'd6 ? 4'd0 : weekday + 4'd1;
                        next_state[31:24] = bcd_increment(day);
                        if (day >= last_day(month)) begin
                            next_state[31:24] = 8'h01;
                            next_state[39:36] = month == 4'd12 ? 4'd1 : month + 4'd1;
                            month_wrapped = month == 4'd12;
                        end
                    end
                end
            end
        end
    end
endmodule
