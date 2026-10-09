// SPDX-License-Identifier: GPL-2.0-only
// Original storage for CZ-880 sheet 46: three 4096x4 palette memories.
// Component numbers are B=0, R=1, G=2; RGB12 output is R:G:B.
// CPU access/write are ALREADY ACCEPTED local-clock operations, not raw Z80
// strobes. Native ASIC decode, AEN/APEN/APRD, WAIT/ownership and index/bank
// formation belong upstream and are not implemented by this physical store.
// One local edge of read latency. CPU writes forward the new selected nibble;
// cross-clock same-address read/write collision values are unspecified.
// Indices are logical G:R:B nibbles, not the ASIC's permuted physical PA pins.
// FPGA configuration initializes identity colors (Techknow printed 159-160).
// Reset masks/flushes responses, never reinitializes palette RAM.
`timescale 1ps/1ps
module x1_z_palette_ram (
    input wire cpu_clk, video_clk, cpu_reset, video_reset,
    input wire cpu_access, cpu_write,
    input wire [11:0] cpu_address,
    input wire [1:0] cpu_component,
    input wire [3:0] cpu_nibble,
    output wire [3:0] cpu_data,
    output wire cpu_valid,
    input wire display_read,
    input wire [11:0] display_address,
    output wire [11:0] display_rgb12,
    output wire display_valid
);
    reg [3:0] blue [0:4095], red [0:4095], green [0:4095];
    // Constant configuration image, not a reset-time 4096-word clearing loop.
    // This must retain block-RAM inference and must not rerun on IPL reset.
    integer initial_address;
    initial begin
        for(initial_address=0;initial_address<4096;initial_address=initial_address+1) begin
            blue[initial_address]=4'(initial_address);
            red[initial_address]=4'(initial_address>>4);
            green[initial_address]=4'(initial_address>>8);
        end
    end
    reg [3:0] blue_cpu, red_cpu, green_cpu, blue_video, red_video, green_video;
    wire accepted_write=cpu_access && cpu_write && !cpu_reset && cpu_component!=3;
    // Exactly one physical address per local port; no RAM reset or duplicate
    // read address is requested. Inactive readers may clock internal RAM data,
    // but the associated output is masked by the registered selection below.
    always @(posedge cpu_clk) begin
        if(accepted_write && cpu_component==0) begin
            blue[cpu_address]<=cpu_nibble;blue_cpu<=cpu_nibble;
        end else blue_cpu<=blue[cpu_address];
        if(accepted_write && cpu_component==1) begin
            red[cpu_address]<=cpu_nibble;red_cpu<=cpu_nibble;
        end else red_cpu<=red[cpu_address];
        if(accepted_write && cpu_component==2) begin
            green[cpu_address]<=cpu_nibble;green_cpu<=cpu_nibble;
        end else green_cpu<=green[cpu_address];
    end
    always @(posedge video_clk) begin
        blue_video<=blue[display_address];
        red_video<=red[display_address];
        green_video<=green[display_address];
    end
    reg [1:0] component_latched=0;
    reg cpu_selected=0,display_selected=0;
    always @(posedge cpu_clk or posedge cpu_reset) begin
        if(cpu_reset) begin cpu_selected<=0;component_latched<=0;end
        else begin
            cpu_selected<=cpu_access && cpu_component!=3;
            component_latched<=cpu_component;
        end
    end
    always @(posedge video_clk or posedge video_reset)
        if(video_reset) display_selected<=0;
        else display_selected<=display_read;
    assign cpu_valid=cpu_selected && !cpu_reset;
    assign cpu_data=!cpu_valid ? 4'd0 : component_latched==0 ? blue_cpu :
                    component_latched==1 ? red_cpu : green_cpu;
    assign display_valid=display_selected && !video_reset;
    assign display_rgb12=display_valid ? {red_video,green_video,blue_video} : 12'd0;
endmodule
