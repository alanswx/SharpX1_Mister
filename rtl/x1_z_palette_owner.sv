// SPDX-License-Identifier: GPL-2.0-only
// Original functional blank-window ownership handshake. This is NOT the
// native IX0868CE BUSRQ/WAIT pin timing contract. A video consumer must honor
// display_allowed, and a CPU operation must honor cpu_permit. No DMA owner.
`timescale 1ps/1ps
module x1_z_palette_owner #(parameter LOCAL_RESET_RELEASE = 0) (
    input wire cpu_clk, video_clk, reset,
    input wire cpu_request, video_blank,
    output wire cpu_permit, display_allowed
);
    typedef enum logic [1:0] {DRAIN, IDLE, REQUEST, OWNED} state_t;
    wire cpu_reset, video_reset;
    generate if (LOCAL_RESET_RELEASE) begin : local_release
        // Both domains assert immediately from the original reset request.
        // Neither domain's release flop drives the other's asynchronous reset.
        x1_reset_release cpu_release(cpu_clk, reset, cpu_reset);
        x1_reset_release video_release(video_clk, reset, video_reset);
    end else begin : compatible_release
        assign cpu_reset = reset;
        assign video_reset = reset;
    end endgenerate
    state_t state=DRAIN;
    reg request_level=0, video_grant=0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] request_sync=0, grant_sync=0;
    always @(posedge cpu_clk or posedge cpu_reset) begin
        if(cpu_reset) begin grant_sync<=0;state<=DRAIN;request_level<=0;end
        else begin
            grant_sync<={grant_sync[0],video_grant};
            case(state)
                DRAIN: if(!grant_sync[1]) state<=IDLE;
                IDLE: if(cpu_request) begin request_level<=1;state<=REQUEST;end
                // Never retract a request before its acknowledgment; otherwise
                // a short request could disappear between video clock edges.
                REQUEST: if(grant_sync[1]) state<=OWNED;
                OWNED: if(!cpu_request) begin request_level<=0;state<=DRAIN;end
                default: begin request_level<=0;state<=DRAIN;end
            endcase
        end
    end
    always @(posedge video_clk or posedge video_reset) begin
        if(video_reset) begin request_sync<=0;video_grant<=0;end
        else begin
            request_sync<={request_sync[0],request_level};
            if(video_grant) begin
                if(!request_sync[1]) video_grant<=0;
            end else if(request_sync[1] && video_blank) video_grant<=1;
        end
    end
    // OWNED can only follow a synchronized grant. DRAIN prevents a new CPU
    // operation from treating the previous grant's delayed deassertion as its
    // own lease. Video resumes only after the synchronized request falls.
    assign cpu_permit=!reset && !cpu_reset && state==OWNED && grant_sync[1] && cpu_request;
    // video_reset already asserts asynchronously from reset. Masking reset
    // again here bypasses destination-local release and sends raw SYS reset
    // through display_read into video-domain palette selection D pins.
    // Compatible mode is unchanged: its video_reset is exactly raw reset.
    assign display_allowed=!video_reset && !video_grant;
endmodule
