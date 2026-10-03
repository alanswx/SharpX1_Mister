// Original base-X1 CG/PCG clock-domain transaction adapter.
// Address is the renderer's character/row, not the low I/O address byte.
// Bundled request data stays stable until the synchronized acknowledgement;
// response stays stable until the next request. This is CDC latency WAIT,
// not the optional inherited scanline AUTO_WAIT trap or Turbo high-speed PCG.
module x1_pcg_access (
    input reset, cpu_clk, video_clk,
    input cpu_select, cpu_write,
    input [1:0] cpu_plane,
    input [7:0] cpu_data,
    output wait_n,
    output reg [7:0] cpu_q,
    input [10:0] beam_addr,
    output reg [10:0] access_addr,
    output [7:0] access_data,
    output [2:0] access_write,
    input [7:0] rom_q, blue_q, red_q, green_q
);
    reg request, busy, done, ack;
    reg [1:0] plane;
    reg write_request;
    reg [7:0] payload, response;
    (* async_reg = "true" *) reg ack_meta, ack_sync;
    (* async_reg = "true" *) reg request_meta, request_sync;
    reg seen;
    reg [1:0] stage;
    assign wait_n = !cpu_select || done;
    assign access_data = payload;
    // One video edge writes exactly one byte. ANK ROM writes are ignored.
    assign access_write = !reset && stage == 1 && write_request
                        ? (plane == 1 ? 3'b001 : plane == 2 ? 3'b010
                           : plane == 3 ? 3'b100 : 3'b000) : 3'b000;

    always @(posedge cpu_clk or posedge reset) begin
        if (reset) begin
            request <= 0; busy <= 0; done <= 0;
            ack_meta <= 0; ack_sync <= 0; cpu_q <= 8'hff;
            plane <= 0; write_request <= 0; payload <= 0;
        end else begin
            ack_meta <= ack;
            ack_sync <= ack_meta;
            if (!cpu_select) done <= 0;
            if (cpu_select && !busy && !done) begin
                plane <= cpu_plane;
                write_request <= cpu_write;
                payload <= cpu_data;
                request <= !request;
                busy <= 1;
            end
            if (busy && ack_sync == request) begin
                cpu_q <= response;
                busy <= 0;
                done <= cpu_select;
            end
        end
    end

    always @(posedge video_clk or posedge reset) begin
        if (reset) begin
            request_meta <= 0; request_sync <= 0; seen <= 0; ack <= 0;
            stage <= 0; access_addr <= 0; response <= 8'hff;
        end else begin
            request_meta <= request;
            request_sync <= request_meta;
            if (stage == 0 && request_sync != seen) begin
                seen <= request_sync;
                access_addr <= beam_addr;
                stage <= 1;
            end else if (stage == 1) begin
                // Registered address is sampled by RAM/font on this edge.
                stage <= 2;
            end else if (stage == 2) begin
                response <= plane == 0 ? rom_q : plane == 1 ? blue_q
                          : plane == 2 ? red_q : green_q;
                ack <= seen;
                stage <= 0;
            end
        end
    end
endmodule
