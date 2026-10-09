// SPDX-License-Identifier: GPL-2.0-or-later
// Original experimental controller, NOT selected by a board revision.
// Installed Intel atoms supply clocks; no vendor implementation is bundled.
// mode[0] selects video, mode[2:1] are held output-policy qualifiers.
module x1_hdmi_clock_handoff(
    input wire clk_control, clk_video, clk_hdmi, reset_request,
    input wire [2:0] requested_mode, // already synchronous to clk_control
    input wire video_policy_ready, // synchronous completed native-DV token
    output wire clk_output,
    output reg [2:0] active_mode = 0,
    output reg output_blank = 1,
    output wire busy,
    output reg video_policy_epoch = 0
);
    wire selected_clock, gate_open;
    reg gate_request = 0, blank_request = 1;
    (* preserve *) reg gate_request_meta = 0, gate_request_sample = 0;
    (* preserve *) reg gate_observed_enable = 0;
    reg blank_meta = 1, blank_sample = 1;
    reg blank_ack = 0;
    reg [3:0] blank_age = 0;
    reg generation = 0, generation_meta = 0, generation_sample = 0, seen_generation = 0;
    reg completed_generation = 1, completed_meta = 1, completed_sample = 1;
    reg ack_meta = 0, ack_sample = 0, gate_meta = 0, gate_sample = 0;
    reg [2:0] pending_mode = 0;
    reg [2:0] state = 0;
    reg [2:0] settle = 0;
    localparam START=0, OPEN=1, RUN=2, BLANK=3, CLOSE=4, SWITCH=5, SETTLE=6, RELEASE=7;
    assign busy = state != RUN || reset_request || requested_mode != active_mode;

    cyclonev_clkselect mux(.inclk({clk_video,clk_hdmi,2'b00}),
                           .clkselect({1'b1,active_mode[0]}),.outclk(selected_clock));
    cyclonev_clkena #(.clock_type("Global Clock"),
                      .ena_register_mode("falling edge"),
                      .ena_register_power_up("low"))
        gate(.inclk(selected_clock),.ena(gate_request_sample),
             .enaout(gate_open),.outclk(clk_output));

    // The public primitive's falling-edge enable register is not a substitute
    // for sampling the asynchronous control request. Keep both stages.
    // While the mux changes, its gate and these two samples are already zero.
    always @(posedge selected_clock) begin
        gate_request_meta <= gate_request;
        gate_request_sample <= gate_request_meta;
    end
    // Do not use enaout as a portable hardware closure acknowledgement:
    // the fitted atom exposes the input-side enable there. Require the actual
    // selected falling edge to have sampled the held gate input first.
    // Placement/half-cycle timing of this witness and the native gate remains
    // a separate FPGA gate; this is not a measured physical readback.
    always @(negedge selected_clock)
        gate_observed_enable <= gate_request_sample;

    // Ten selected-output edges flush both native-DV and output pipelines.
    // No acknowledgement is fabricated when the selected source is stopped.
    always @(posedge clk_output) begin
        blank_meta <= blank_request;
        blank_sample <= blank_meta;
        generation_meta <= generation;
        generation_sample <= generation_meta;
        if(generation_sample != seen_generation) begin
            seen_generation <= generation_sample;
            output_blank <= 1;
            blank_age <= 0;
            blank_ack <= 0;
        end else if(blank_sample) begin
            output_blank <= 1;
            if(blank_age != 10) blank_age <= blank_age + 1'b1;
            blank_ack <= blank_age == 10;
            if(blank_age == 10) completed_generation <= seen_generation;
        end else begin
            blank_age <= 0;
            blank_ack <= 0;
            output_blank <= 0;
        end
    end

    // Runtime reset is a request, not an asynchronous clock-selector reset.
    // The held mode can change ONLY after native gate closure is observed.
    // Requests arriving while busy are coalesced only after this pair finishes.
    always @(posedge clk_control) begin
        ack_meta <= blank_ack;
        ack_sample <= ack_meta;
        gate_meta <= gate_observed_enable;
        gate_sample <= gate_meta;
        completed_meta <= completed_generation;
        completed_sample <= completed_meta;
        case(state)
            START: begin
                if(settle == 4) begin gate_request <= 1; state <= OPEN; end
                else settle <= settle + 1'b1;
            end
            OPEN: if(gate_sample && ack_sample && completed_sample == generation &&
                     (!active_mode[0] || video_policy_ready)) begin
                if(reset_request) begin
                    if(active_mode != 0) state <= RUN;
                end else begin
                    blank_request <= 0;
                    state <= RELEASE;
                end
            end
            // Drain the old blank acknowledgement before accepting another
            // request; otherwise a rapid reversal could reuse a stale ACK.
            RELEASE: if(!ack_sample) state <= RUN;
            RUN: begin
                if(reset_request || requested_mode != active_mode) begin
                    pending_mode <= reset_request ? 3'b000 : requested_mode;
                    blank_request <= 1;
                    state <= BLANK;
                end
            end
            BLANK: if(ack_sample) begin gate_request <= 0; state <= CLOSE; end
            CLOSE: if(!gate_sample) state <= SWITCH;
            SWITCH: begin
                active_mode <= pending_mode;
                generation <= !generation;
                if(pending_mode[0]) video_policy_epoch <= !video_policy_epoch;
                settle <= 0;
                state <= SETTLE;
            end
            SETTLE: begin
                if(settle == 4) begin gate_request <= 1; state <= OPEN; end
                else settle <= settle + 1'b1;
            end
            default: state <= START;
        endcase
    end
endmodule
