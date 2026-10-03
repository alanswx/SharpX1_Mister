// Dual-clock, byte-wide video RAM. CPU read latency is one system cycle;
// video read latency is one video cycle. Cross-clock same-address collision
// semantics are deliberately unspecified and must not be used as a fixture.
module x1_video_ram #(parameter AW=11) (
    input cpu_clk,
    input [AW-1:0] cpu_addr,
    input [7:0] cpu_data,
    input cpu_write,
    output reg [7:0] cpu_q,
    input video_clk,
    input [AW-1:0] video_addr,
    output reg [7:0] video_q
);
    reg [7:0] mem [0:(1<<AW)-1];
    always @(posedge cpu_clk) begin
        cpu_q <= mem[cpu_addr];
        if (cpu_write) mem[cpu_addr] <= cpu_data;
    end
    always @(posedge video_clk) video_q <= mem[video_addr];
endmodule
