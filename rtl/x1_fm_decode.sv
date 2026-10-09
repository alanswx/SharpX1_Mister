// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ps/1ps
// Original conservative FM bus qualifier: exact 0700/0701 from inspected
// local MAME and X Millennium. Sharp shows A0/IOWE/IORD/select at YM2151,
// but ASIC aliases/WAIT and IRQ routing are not established by this decoder.
// Caller must disable it during actual DMA ownership for CPU-only access.
module x1_fm_decode (
    input wire enabled,reset,dam,m1_n,mreq_n,iorq_n,rd_n,wr_n,
    input wire [15:0] address,
    output wire selected,read_access,write_access
);
    wire slice=enabled && !reset && !dam && m1_n && mreq_n && !iorq_n &&
               address[15:1]==15'h0380;
    assign read_access=slice && !rd_n && wr_n;
    assign write_access=slice && rd_n && !wr_n;
    assign selected=read_access || write_access;
endmodule
