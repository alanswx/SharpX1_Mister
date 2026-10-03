// Original fractional-rate enable generator. Never used as a fabric clock.
module x1_clock_enables #(parameter MASTER_HZ = 28636364) (
    input clk, reset,
    output cpu_ce, psg_ce
);
    reg [25:0] cpu_phase, psg_phase;
    assign cpu_ce = cpu_phase >= MASTER_HZ - 4000000;
    assign psg_ce = psg_phase >= MASTER_HZ - 2000000;
    // Prepare enables on the opposite edge, like the original divider.
    always @(negedge clk or posedge reset) begin
        if (reset) begin cpu_phase <= 0; psg_phase <= 0; end
        else begin
            cpu_phase <= cpu_ce ? cpu_phase + 26'd4000000 - MASTER_HZ
                                : cpu_phase + 26'd4000000;
            psg_phase <= psg_ce ? psg_phase + 26'd2000000 - MASTER_HZ
                                : psg_phase + 26'd2000000;
        end
    end
endmodule
