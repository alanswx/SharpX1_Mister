// SPDX-License-Identifier: GPL-2.0-only
// Original normal-mode uPD1990AC time-counter backend. oscillator_ce is ONE
// already synchronous event per 32.768 kHz crystal edge; not a CPU enable.
// set_hold models the register group's Time Set mode (NOT Register Hold).
// The manufacturer specifies divider stages 11..15 reset in Time Set, so
// lower ten stages keep counting while the calendar remains held.
// No serial command decode, TP/test mode, asynchronous pin CDC, MCU year,
// host initialization or battery persistence is supplied by this backend.
// load_time is a caller-qualified single-SYS command pulse; raw STB edge/CS
// qualification belongs to the future serial frontend, not this backend.
module x1_upd1990_counter (
    input wire clk, power_reset,
    input wire oscillator_ce,
    input wire set_hold, load_time,
    input wire [39:0] load_state,
    output logic [39:0] current_state,
    output wire state_valid,
    output logic [14:0] divider_phase,
    output wire load_accepted,
    output logic second_tick, calendar_advanced, month_wrapped
);
    wire [39:0] next_state;
    wire next_month_wrapped;
    x1_upd1990_calendar calendar_step (
        .current_state(current_state), .state_valid(state_valid),
        .next_state(next_state), .month_wrapped(next_month_wrapped)
    );
    assign load_accepted = load_time && set_hold && !power_reset;
    always_ff @(posedge clk) begin
        if (power_reset) begin
            current_state <= 40'd0; // uninitialized, explicitly invalid
            divider_phase <= 15'd0;
            second_tick <= 1'b0;
            calendar_advanced <= 1'b0;
            month_wrapped <= 1'b0;
        end else begin
            second_tick <= 1'b0;
            calendar_advanced <= 1'b0;
            month_wrapped <= 1'b0;
            if (set_hold) begin
                divider_phase <= {5'd0, divider_phase[9:0] + (oscillator_ce ? 10'd1 : 10'd0)};
            end else if (oscillator_ce) begin
                divider_phase <= divider_phase + 15'd1;
                if (divider_phase == 15'h7fff) begin
                    second_tick <= 1'b1;
                    if (state_valid) begin
                        current_state <= next_state;
                        calendar_advanced <= 1'b1;
                        month_wrapped <= next_month_wrapped;
                    end
                end
            end
            if (load_accepted) current_state <= load_state;
        end
    end
endmodule
