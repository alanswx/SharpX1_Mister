// Original fractional-rate enable generator. Never used as a fabric clock.
module x1_clock_enables #(parameter MASTER_HZ = 28636364) (
    input clk, reset,
    output cpu_ce, psg_ce
);
    // Supported masters and both rates are divisible by four. Dropping those
    // constant low bits preserves the exact sequence and avoids reset-only bits.
    localparam [23:0] MASTER_UNITS = MASTER_HZ / 4;
    reg [23:0] cpu_phase, psg_phase;
    assign cpu_ce = cpu_phase >= MASTER_UNITS - 24'd1000000;
    assign psg_ce = psg_phase >= MASTER_UNITS - 24'd500000;
    // Prepare enables on the opposite edge, like the original divider.
    always @(negedge clk or posedge reset) begin
        if (reset) begin cpu_phase <= 0; psg_phase <= 0; end
        else begin
            cpu_phase <= cpu_ce ? cpu_phase + 24'd1000000 - MASTER_UNITS
                                : cpu_phase + 24'd1000000;
            psg_phase <= psg_ce ? psg_phase + 24'd500000 - MASTER_UNITS
                                : psg_phase + 24'd500000;
        end
    end
endmodule
