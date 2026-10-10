// Original Sharp X1 bring-up code, GPL-2.0-or-later.
// Standalone nominal MFM DR/DSR experiment, not connected WD/SD/drive RTL.
// All inputs/events synchronous to SYS. fdc_ce is explicit, never capacity-
// derived. Caller supplies one accept pulse per real bus transaction; no raw
// bus decode here. read_release only retires response, NEVER acknowledges DR.
//
// begin_read starts byte assembly: arrival 0 is 32 fdc_ce edges later.
// arm_write requests prefill outside periodic timing. launch_write consumes
// the initial holding byte immediately, starts its serialization slot, and
// requests byte 1 if needed. Missing prefill aborts without any write_emit.
// Caller decides native ID/gap/launch timing; this module does not model it.
// Each later boundary loads another DSR byte (zero on miss). Completion is
// one slot after the last load. Reads similarly have one final service slot
// after the last arrival. This tail is an experimental digital policy.
//
// Tie policy: accepted read consumes OLD DR before arrival; accepted write
// can supply the DSR load on this edge. No claim of native failure-edge ties.
// 27/23 chip-clock guaranteed MFM service maxima are NOT 32-clock exact loss
// deadlines. Loss here marks unread replacement/final expiry or empty load.
// Held responses survive arrivals and stop, but reset/new command discard
// them. Duplicate read accepts while response_valid are ignored unless the
// previous response is released simultaneously. Writes accepted only at DRQ.
`timescale 1ns/1ps
module x1_fdc_stream_adapter (
    input wire clk, reset, fdc_ce,
    input wire begin_read, arm_write, launch_write, stop,
    input wire [10:0] length,
    input wire [7:0] source_byte,
    input wire read_accept, read_release, write_accept,
    input wire [7:0] write_value,
    output wire [7:0] dr_value,
    output wire drq,
    output reg active = 1'b0,
    output reg armed = 1'b0,
    output reg lost = 1'b0,
    output reg done = 1'b0,
    output reg initial_abort = 1'b0,
    output reg [10:0] byte_index = 11'd0,
    output reg [10:0] generation = 11'd0,
    output reg response_valid = 1'b0,
    output reg [7:0] response_data = 8'd0,
    output reg [10:0] response_generation = 11'd0,
    output reg read_ack = 1'b0,
    output reg arrival = 1'b0,
    output reg write_emit = 1'b0,
    output reg [7:0] write_byte = 8'd0,
    output reg [10:0] write_index = 11'd0
);
    reg writing = 1'b0;
    reg full = 1'b0;
    reg [7:0] holding = 8'd0;
    reg [10:0] remaining = 11'd0;
    reg slot_stop = 1'b0;
    wire boundary;
    wire read_event = read_accept && (!response_valid || read_release);
    wire service_read = read_event && !writing && full;
    wire service_write = write_accept && writing && (active || armed) && !full;
    wire launch = launch_write && armed;
    wire have_write = full || service_write;
    wire [7:0] staged_write = service_write ? write_value : holding;
    assign dr_value = holding; // pre-edge value for caller's bus response latch
    assign drq = writing ? ((armed || (active && remaining != 0)) && !full) : full;
    x1_fdc_byte_slots slots (
        .clk(clk), .reset(reset), .fdc_ce(fdc_ce),
        .start(begin_read || (launch && have_write)),
        .stop(stop || arm_write || (slot_stop && !begin_read && !launch)), .fm(1'b0),
        .boundary(boundary), .active()
    );
    always @(posedge clk) begin
        done <= 1'b0;
        initial_abort <= 1'b0;
        read_ack <= 1'b0;
        arrival <= 1'b0;
        write_emit <= 1'b0;
        slot_stop <= 1'b0;
        if (reset) begin
            active <= 1'b0; armed <= 1'b0; writing <= 1'b0;
            full <= 1'b0; holding <= 8'd0; remaining <= 11'd0;
            lost <= 1'b0; byte_index <= 11'd0; generation <= 11'd0;
            response_valid <= 1'b0; response_data <= 8'd0;
            response_generation <= 11'd0;
            write_byte <= 8'd0; write_index <= 11'd0;
        end else begin
            if (read_release) response_valid <= 1'b0;
            if (read_event) begin
                response_valid <= 1'b1;
                response_data <= holding;
                response_generation <= generation;
            end
            if (stop) begin
                active <= 1'b0; armed <= 1'b0; full <= 1'b0;
                remaining <= 11'd0;
                // Retain last DR, loss and an already captured response.
            end else if (begin_read || arm_write) begin
                active <= begin_read; armed <= arm_write; writing <= arm_write;
                full <= 1'b0; remaining <= length; lost <= 1'b0;
                byte_index <= 11'd0; generation <= 11'd0;
                response_valid <= 1'b0;
            end else begin
                if (service_read) begin full <= 1'b0; read_ack <= 1'b1; end
                if (service_write) begin full <= 1'b1; holding <= write_value; end
                if (launch) begin
                    armed <= 1'b0;
                    if (!have_write) begin
                        lost <= 1'b1; initial_abort <= 1'b1; done <= 1'b1;
                        remaining <= 11'd0;
                    end else begin
                        active <= 1'b1; full <= 1'b0;
                        write_emit <= 1'b1; write_byte <= staged_write;
                        write_index <= 11'd0; byte_index <= 11'd1;
                        generation <= 11'd1; remaining <= remaining - 11'd1;
                    end
                end else if (active && boundary) begin
                    if (remaining != 0) begin
                        remaining <= remaining - 11'd1;
                        byte_index <= byte_index + 11'd1;
                        generation <= generation + 11'd1;
                        if (writing) begin
                            write_emit <= 1'b1; write_index <= byte_index;
                            write_byte <= have_write ? staged_write : 8'd0;
                            full <= 1'b0;
                            if (!have_write) lost <= 1'b1;
                        end else begin
                            holding <= source_byte; full <= 1'b1; arrival <= 1'b1;
                            if (full && !service_read) lost <= 1'b1;
                        end
                    end else begin
                        // Last DSR serialized / final read service slot elapsed.
                        if (!writing && full && !service_read) lost <= 1'b1;
                        full <= 1'b0; active <= 1'b0; done <= 1'b1;
                        slot_stop <= 1'b1; // registered; no boundary->stop loop
                    end
                end
            end
        end
    end
`ifndef SYNTHESIS
    always @(posedge clk) if (!reset && !stop && (begin_read || arm_write)) begin
        assert (!(begin_read && arm_write) && length != 0 && length <= 11'd1024)
            else $fatal(1,"stream start contract: exclusive mode, length 1..1024");
    end
`endif
endmodule
