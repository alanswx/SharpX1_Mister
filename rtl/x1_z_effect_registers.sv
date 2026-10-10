// SPDX-License-Identifier: GPL-2.0-only
// Original default-off CPU storage prototype for 1FC1..1FC4.
// Full-byte readback/reset-to-zero/inactive-AEN policy is provisional.
// No capture sampling, effects, video CDC, native ASIC status or Z signature.
module x1_z_effect_registers (
    input wire clk, reset, enabled, io_read, io_write, clear_read,
    input wire [15:0] address,
    input wire [7:0] data,
    output wire selected,
    output wire [7:0] read_data, held_data,
    output wire read_hold,
    output reg [15:0] held_address=0,
    output reg [7:0] position_control=0, mosaic_control=0,
                     chroma_control=0, scroll_control=0
);
    wire mapped=address>=16'h1fc1 && address<=16'h1fc4;
    reg write_seen=1, completed_read=0;
    reg [7:0] response=0;
    reg [7:0] current_data;
    always_comb begin
        case(address)
            16'h1fc1:current_data=position_control;
            16'h1fc2:current_data=mosaic_control;
            16'h1fc3:current_data=chroma_control;
            16'h1fc4:current_data=scroll_control;
            default:current_data=8'hff;
        endcase
    end
    assign selected=!reset && enabled && mapped && (io_read ^ io_write);
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            position_control<=0;mosaic_control<=0;chroma_control<=0;scroll_control<=0;
            write_seen<=1;completed_read<=0;response<=0;held_address<=0;
        end else begin
            if(!io_write) write_seen<=0;
            else if(!write_seen) begin
                write_seen<=1;
                if(selected) case(address)
                    16'h1fc1:position_control<=data;
                    16'h1fc2:mosaic_control<=data;
                    16'h1fc3:chroma_control<=data;
                    16'h1fc4:scroll_control<=data;
                    default:begin end
                endcase
            end
            if(clear_read) completed_read<=0;
            else if(selected && io_read) begin
                completed_read<=1;response<=current_data;held_address<=address;
            end
        end
    end
    assign read_data=selected && io_read ? current_data : 8'hff;
    assign read_hold=!reset && completed_read;
    assign held_data=read_hold ? response : 8'hff;
endmodule
