// SPDX-License-Identifier: GPL-2.0-only
// Independent level crossings for PPI B7 (VDISP) and B2 (VSYNC).
// Not a coherent multi-bit snapshot or reset-release/placement guarantee.
module x1_video_status #(parameter SYNCHRONIZE = 0) (
    input clk_sys, reset,
    input video_vdisp, video_vsync,
    output cpu_vdisp, cpu_vsync
);
    generate if (SYNCHRONIZE) begin : crossing
        (* async_reg = "true" *) reg [1:0] status_meta, status_sys;
        always @(posedge clk_sys or posedge reset) begin
            if (reset) begin status_meta <= 0; status_sys <= 0; end
            else begin
                status_meta <= {video_vdisp,video_vsync};
                status_sys <= status_meta;
            end
        end
        assign {cpu_vdisp,cpu_vsync} = status_sys;
    end else begin : compatible
        assign {cpu_vdisp,cpu_vsync} = {video_vdisp,video_vsync};
    end endgenerate
endmodule
