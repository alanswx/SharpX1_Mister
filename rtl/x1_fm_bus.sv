// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ps/1ps
// Original CPU-only FM seam: conservative decode, real adapter WAIT and
// retained status through the CPU's trailing I/O sampling phase.
// IRQ/audio are genuine chip outputs, not native routing/mixing claims.
module x1_fm_bus #(parameter integer MASTER_HZ=32000000) (
    input wire clk,reset,enable,cpu_allowed,dam,
    input wire m1_n,mreq_n,iorq_n,rd_n,wr_n,
    input wire [15:0] address,
    input wire [7:0] cpu_data,
    output wire selected,read_tail,wait_n,
    output wire [7:0] response,
    output wire irq_n,sample,protocol_error,
    output wire signed [15:0] left,right
);
    wire read_access;
    wire [7:0] status;
    reg read_hold;
    reg [7:0] held_status;
    x1_fm_decode decode(.enabled(cpu_allowed),.reset(reset),.dam(dam),
        .m1_n(m1_n),.mreq_n(mreq_n),.iorq_n(iorq_n),.rd_n(rd_n),.wr_n(wr_n),
        .address(address),.selected(selected),.read_access(read_access),.write_access());
    x1_fm #(.MASTER_HZ(MASTER_HZ)) device(.clk(clk),.reset(reset),.enable(enable),
        .cpu_cs(selected),.cpu_rd_n(rd_n),.cpu_wr_n(wr_n),.cpu_a0(address[0]),
        .cpu_data_in(cpu_data),.cpu_data_out(status),.wait_n(wait_n),.irq_n(irq_n),
        .ct1(),.ct2(),.sample(sample),.left(left),.right(right),
        .cen_chip(),.cen_half(),.protocol_error(protocol_error));
    always @(posedge clk or posedge reset) begin
        if(reset) begin read_hold<=0;held_status<=8'hff;end
        else if(!mreq_n && !rd_n) read_hold<=0;
        else if(read_access) begin read_hold<=1;held_status<=status;end
    end
    assign read_tail=!reset && mreq_n && read_hold;
    assign response=read_access ? status : held_status;
endmodule
