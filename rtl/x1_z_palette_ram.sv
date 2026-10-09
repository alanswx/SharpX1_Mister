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
// INTERNAL8 is the separate 8x12 store (Techknow printed 156/160/161).
// Physical PA8/PA4/PA0 correspond to logical CPU index bits 11/7/3.
module x1_z_palette_ram #(parameter INTERNAL8 = 0) (
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
    localparam ADDRESS_BITS=INTERNAL8 ? 3 : 12;
    localparam ENTRIES=1<<ADDRESS_BITS;
    wire [ADDRESS_BITS-1:0] cpu_index=INTERNAL8 ?
        ADDRESS_BITS'({cpu_address[11],cpu_address[7],cpu_address[3]}) : ADDRESS_BITS'(cpu_address);
    wire [ADDRESS_BITS-1:0] display_index=INTERNAL8 ?
        ADDRESS_BITS'({display_address[11],display_address[7],display_address[3]}) : ADDRESS_BITS'(display_address);
    reg [3:0] blue [0:ENTRIES-1], red [0:ENTRIES-1], green [0:ENTRIES-1];
    // Constant configuration image, not a reset-time 4096-word clearing loop.
    // This must retain block-RAM inference and must not rerun on IPL reset.
    integer initial_address;
    initial begin
        for(initial_address=0;initial_address<ENTRIES;initial_address=initial_address+1) begin
            blue[initial_address]=INTERNAL8 ? {4{initial_address[0]}} : 4'(initial_address);
            red[initial_address]=INTERNAL8 ? {4{initial_address[1]}} : 4'(initial_address>>4);
            green[initial_address]=INTERNAL8 ? {4{initial_address[2]}} : 4'(initial_address>>8);
        end
    end
    reg [3:0] blue_cpu, red_cpu, green_cpu, blue_video, red_video, green_video;
    wire accepted_write=cpu_access && cpu_write && !cpu_reset && cpu_component!=3;
    // Exactly one physical address per local port; no RAM reset or duplicate
    // read address is requested. Inactive readers may clock internal RAM data,
    // but the associated output is masked by the registered selection below.
    always @(posedge cpu_clk) begin
        if(accepted_write && cpu_component==0) begin
            blue[cpu_index]<=cpu_nibble;blue_cpu<=cpu_nibble;
        end else blue_cpu<=blue[cpu_index];
        if(accepted_write && cpu_component==1) begin
            red[cpu_index]<=cpu_nibble;red_cpu<=cpu_nibble;
        end else red_cpu<=red[cpu_index];
        if(accepted_write && cpu_component==2) begin
            green[cpu_index]<=cpu_nibble;green_cpu<=cpu_nibble;
        end else green_cpu<=green[cpu_index];
    end
    always @(posedge video_clk) begin
        blue_video<=blue[display_index];
        red_video<=red[display_index];
        green_video<=green[display_index];
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
