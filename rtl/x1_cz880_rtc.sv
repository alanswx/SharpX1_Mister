// SPDX-License-Identifier: GPL-2.0-only
// Original CZ-880 sheet-47 functional RTC serial interface. C2 and TP are
// grounded on this board; the four register commands are the reachable set.
// All inputs must already be synchronous to clk; no physical pin CDC or RC/
// open-drain delay is modeled. MCU P15/14/13/12/11/10 = CLK/DI/STB/OE/C1/C0.
// RTC DATA OUT drives MCU T1. power_reset is configuration loss, NOT the
// MCU/main-core reset. oscillator_ce has the counter backend's crystal contract.
module x1_cz880_rtc (
    input wire clk, power_reset, oscillator_ce,
    input wire cs,
    input wire [7:0] mcu_p1,
    output wire mcu_t1,
    output wire data_out_sink,
    // Diagnostic interfaces, not extra physical device pins.
    output wire [39:0] current_state,
    output logic [39:0] shift_state,
    output wire state_valid,
    output logic [1:0] register_mode,
    output wire [14:0] divider_phase,
    output wire second_tick, calendar_advanced, month_wrapped
);
    wire serial_clk = mcu_p1[5];
    wire data_in = mcu_p1[4];
    wire strobe = mcu_p1[3];
    wire output_enable = mcu_p1[2];
    wire [1:0] command = mcu_p1[1:0];
    logic previous_clk, previous_strobe;
    wire command_event = cs && strobe && !previous_strobe;
    wire shift_event = cs && serial_clk && !previous_clk;
    // Command admission precedes the backend's same-SYS oscillator event.
    // Simultaneous raw CLK/STB is outside the native setup/hold contract.
    wire [1:0] effective_mode = command_event ? command : register_mode;
    wire load_accepted;
    x1_upd1990_counter counter (
        .clk(clk), .power_reset(power_reset), .oscillator_ce(oscillator_ce),
        .set_hold(effective_mode == 2'd2),
        .load_time(command_event && command == 2'd2), .load_state(shift_state),
        .current_state(current_state), .state_valid(state_valid),
        .divider_phase(divider_phase), .load_accepted(load_accepted),
        .second_tick(second_tick), .calendar_advanced(calendar_advanced),
        .month_wrapped(month_wrapped)
    );
    always_ff @(posedge clk) begin
        if (power_reset) begin
            previous_clk <= 1'b0;
            previous_strobe <= 1'b0;
            register_mode <= 2'd0;
            shift_state <= 40'd0;
        end else begin
            previous_clk <= serial_clk;
            previous_strobe <= strobe;
            if (command_event) begin
                register_mode <= command;
                if (command == 2'd3) shift_state <= current_state;
            end else if (shift_event && register_mode == 2'd1) begin
                shift_state <= {data_in, shift_state[39:1]};
            end
        end
    end
    logic data_value;
    always_comb begin
        case (register_mode)
            2'd0: data_value = divider_phase[14];
            2'd1,2'd2: data_value = shift_state[0];
            // Functional .5-Hz policy from live seconds parity. Exact native
            // phase after mode selection/propagation remains unqualified.
            default: data_value = current_state[0];
        endcase
    end
    // Sink/release expresses open drain. A caller must supply the pull-up;
    // mcu_t1 is its resolved digital level, not a push-pull physical driver.
    assign data_out_sink = !power_reset && output_enable && !data_value;
    assign mcu_t1 = !data_out_sink;
endmodule
