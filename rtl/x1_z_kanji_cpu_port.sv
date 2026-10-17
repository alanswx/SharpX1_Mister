// SPDX-License-Identifier: GPL-2.0-only
// Original SYS adapter between the shared PCG controller and font arbiter.
// The PCG controller captures data before lowering pcg_read. Keep the arbiter
// reply owned until that low is observed, even if VID/window acknowledgement
// arrives much later than DDR data. cpu_cancel must ALSO reach the arbiter;
// this bridge cannot cancel or reset an owned memory transaction.
// Keep the raw read visible during cancellation: gating it with cancel would
// falsely rearm the arbiter while an old PCG request remained high.
// Standalone qualification only; outside machine.qip and all board profiles.
`timescale 1ns/1ps
module x1_z_kanji_cpu_port (
    input wire pcg_read,
    input wire [17:0] pcg_address,
    output wire pcg_valid,
    output wire [7:0] pcg_data,
    input wire cpu_cancel,
    output wire cpu_read,
    output wire [17:0] cpu_address,
    input wire cpu_valid,
    input wire [7:0] cpu_data,
    output wire cpu_response_ack
);
    assign cpu_read=pcg_read;
    assign cpu_address=pcg_address;
    assign pcg_valid=pcg_read && cpu_valid && !cpu_cancel;
    assign pcg_data=pcg_valid ? cpu_data : 8'd0;
    assign cpu_response_ack=cpu_valid && !pcg_read && !cpu_cancel;
endmodule
