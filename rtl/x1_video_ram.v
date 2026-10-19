// Dual-clock, byte-wide video RAM. CPU read latency is one system cycle;
// video read latency is one video cycle. Cross-clock same-address collision
// semantics are deliberately unspecified and must not be used as a fixture.
// A CPU write returns the written byte on cpu_q (new data), as the board's
// explicit true dual-port block does; inferred RAM here was built as two
// duplicated copies. The VERILATOR branch keeps mem for debug ports.
module x1_video_ram #(parameter AW=11) (
    input cpu_clk,
    input [AW-1:0] cpu_addr,
    input [7:0] cpu_data,
    input cpu_write,
    output [7:0] cpu_q,
    input video_clk,
    input [AW-1:0] video_addr,
    output [7:0] video_q
);
`ifdef VERILATOR
    reg [7:0] mem [0:(1<<AW)-1];
    reg [7:0] cpu_q_r, video_q_r;
    assign cpu_q = cpu_q_r;
    assign video_q = video_q_r;
    always @(posedge cpu_clk) begin
        if (cpu_write) begin
            mem[cpu_addr] <= cpu_data;
            cpu_q_r <= cpu_data;
        end else
            cpu_q_r <= mem[cpu_addr];
    end
    always @(posedge video_clk) video_q_r <= mem[video_addr];
`else
    x1_tdp_ram #(.AW(AW),.DW(8)) ram (
        .clock_a(cpu_clk), .address_a(cpu_addr), .data_a(cpu_data),
        .wren_a(cpu_write), .q_a(cpu_q),
        .clock_b(video_clk), .address_b(video_addr), .data_b(8'd0),
        .wren_b(1'b0), .q_b(video_q));
`endif
endmodule
