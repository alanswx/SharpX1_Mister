// SPDX-License-Identifier: GPL-2.0-or-later
// Original conservative onboard SIO/0 decode: inspected local MAME maps
// 1F90..1F93, Sharp schematic supplies C/D=A0 and B/A=A1. No ASIC mirrors
// are invented. This is a bus qualifier, not IRQ ownership or a machine profile.
// Inputs synchronous to the caller's bus. DAM traffic, reset, disabled profile,
// interrupt ACK and invalid simultaneous RD/WR are never register accesses.
module x1_sio_decode (
    input wire enabled,reset,dam,m1_n,iorq_n,rd_n,wr_n,
    input wire [15:0] address,
    output wire selected,read_access,write_access
);
    wire slice=enabled && !reset && !dam && m1_n && !iorq_n &&
               address[15:2]==14'h07e4;
    assign read_access=slice && !rd_n && wr_n;
    assign write_access=slice && rd_n && !wr_n;
    assign selected=read_access || write_access;
endmodule
