// Optional models are selected by the build/top, not by the decoder itself.
// Defining them here made the interface depend on source compilation order.

/****************************************************************************
	X1 address decoder

	Version 050414

	Copyright(C) 2004,2005 Tatsuyuki Satoh

	This software is provided "AS IS", with NO WARRANTY.
	NON-COMMERCIAL USE ONLY

	Histry:
		2005. 4.14 cleanup
		2005. 1.11 1st

	Note:

	Distributing all and a part is prohibited. 
	Because this version is developer-alpha version.

****************************************************************************/
module x1_adec(
  I_RESET,
  I_CLK,
  I_A,
  I_MREQ_n,I_IORQ_n,I_RD_n,I_WR_n,
// mode select
  I_IPL_SEL,
  I_DAM,
  I_DEFCHR,
// memory CS
  O_IPL_CS,O_RAM_CS,
//
  O_MIOCS,
// I/O CS
  O_EMM_CS,
  O_EXTROM_CS,
  O_KANROM_CS,
  O_FD5_CS,
  O_PAL_CS,
  O_CG_CS,
  O_CRTC_CS,
  O_SUB_CS,
  O_PIA_CS,
  O_PSG_CS,
  O_IPL_SET_CS,
  O_IPL_RES_CS,
//
  O_ATTR_CS,O_TEXT_CS,
  O_GRB_CS,O_GRR_CS,O_GRG_CS,
// option board
`ifdef FMBOARD
  O_FM_CS,O_FMO_CTC_CS,
`endif
  O_HDD_CS,
  O_FD8_CS,
// X1turbo
`ifdef X1TURBO
  O_KANJI_CS, // 3800-3fff
  O_BMEM_CS,  // 0b00
  O_DMA_CS,   // 1f8x
  O_SIO_CS,   // 1f90-1f93
  O_CTC_CS,   // 1fa0-1fa3
  O_P1FDX_CS,
  O_BLACK_CS, // 1fe0
  O_DIPSW_CS, // 1ff0
`endif
  O_DAM_CLR
);

input I_RESET;
input I_CLK;
input [15:0] I_A;
input I_MREQ_n,I_IORQ_n,I_RD_n,I_WR_n;

input I_IPL_SEL;
input I_DAM;
input I_DEFCHR;

output O_IPL_CS,O_RAM_CS;

output O_MIOCS;

output O_EMM_CS;
output O_EXTROM_CS;
output O_KANROM_CS;
output O_FD5_CS;
output O_PAL_CS;
output O_CG_CS;
output O_CRTC_CS;
output O_SUB_CS;
output O_PIA_CS;
output O_PSG_CS;
output O_IPL_SET_CS;
output O_IPL_RES_CS;


output O_ATTR_CS,O_TEXT_CS;
output O_GRB_CS,O_GRR_CS,O_GRG_CS;

// option board
output O_HDD_CS;
output O_FD8_CS;
`ifdef FMBOARD
output O_FM_CS,O_FMO_CTC_CS;
`endif

`ifdef X1TURBO
output O_KANJI_CS;
output O_BMEM_CS;
output O_DMA_CS;
output O_SIO_CS;
output O_CTC_CS;
output O_P1FDX_CS;
output O_BLACK_CS;
output O_DIPSW_CS;
`endif

output O_DAM_CLR;

////////////////////////////////////////////////////////////////////////////

// memory
// assign O_IPL_CS = I_IPL_SEL & ~I_A[15];
assign O_IPL_CS = ~I_MREQ_n & ~I_RD_n & I_IPL_SEL & ~I_A[15];
assign O_RAM_CS = ~I_MREQ_n;

// iorq glidge safe
`ifdef IOCYCLE_LATCH
reg iorq_r;
always @(posedge I_CLK) iorq_r <= ~I_IORQ_n;
`else
wire iorq_r = ~I_IORQ_n;
`endif

// common signal
wire sys_io = ~I_DAM & iorq_r;
wire miocs      = sys_io&(I_A[15:13]==3'b000); // 0000-1FFF I/O expect DOUJI

// VRAM
assign O_ATTR_CS  = sys_io&(I_A[15:12]==4'h2);   // 2000-2fff ATTR VRAM
`ifdef X1TURBO
assign O_TEXT_CS  = sys_io&(I_A[15:11]==5'b0011_0); // 3000-37ff TEXT VRAM
assign O_KANJI_CS = sys_io&(I_A[15:11]==5'b0011_1); // 3800-3fff KANJI VRAM
`else
assign text_cs  = sys_io&(I_A[15:12]==4'h3);      // 3000-3fff TEXT VRAM
`endif

// GRAM access                                        //           nor / DAM
                                                      // 0000-3FFF --- / BRG
assign O_GRB_CS  = iorq_r&((I_A[15:14]==2'b01)^I_DAM); // 4000-7FFF B-- / -RG
assign O_GRR_CS  = iorq_r&((I_A[15:14]==2'b10)^I_DAM); // 8000-BFFF -R- / B-G
assign O_GRG_CS  = iorq_r&((I_A[15:14]==2'b11)^I_DAM); // C000-FFFF --G / BR-

// CS on system I/O
`ifdef FMBOARD
assign O_FM_CS      = miocs & (I_A[12:8]==5'h07) & ~I_A[2]; // 0700-0703
assign O_FMO_CTC_CS  = miocs & (I_A[12:8]==5'h07) &  I_A[2]; // 0704-0707
`endif

`ifdef X1TURBO
assign O_BMEM_CS    = miocs & (I_A[12:8]==5'h0b);         // 0B
`endif
assign O_EMM_CS    = miocs & (I_A[12:8]==5'h0d);       // 0Dxx
assign O_EXTROM_CS = miocs & (I_A[12:7]==6'b0_1110_0); // 0E00-0E03 ROM BASIC
assign O_KANROM_CS = miocs & (I_A[12:7]==6'b0_1110_1); // 0E80-0E82 KANJI-ROM(X1)

// strage
wire storage_cs = miocs & (I_A[12:6]==7'b0_1111_11); // 0fc0-fff
assign O_HDD_CS     = storage_cs & (I_A[5:2]==4'b01_00); // 0FD0-0FD3
assign O_FD8_CS     = storage_cs & (I_A[5:3]==3'b10_1);  // 0FE8-0FEF
assign O_FD5_CS     = storage_cs & (I_A[5:3]==3'b11_1);  // 0FF8-0FFF

// video controll
assign O_PAL_CS     = miocs & (I_A[12:10]==3'b100);      // 10xx-13xx
assign O_CG_CS      = miocs & (I_A[12:10]==3'b101);      // 14xx-17xx
assign O_CRTC_CS    = miocs & (I_A[12:8]==5'h18);        // 18xx
assign O_SUB_CS     = miocs & (I_A[12:8]==5'h19);        // 19xx
assign O_PIA_CS     = miocs & (I_A[12:8]==5'h1a);        // 1axx
assign O_PSG_CS     = miocs & ( (I_A[12:8]==5'h1b) | (I_A[12:8]==5'h1c) ); //1bxx-1cxx
// memory bank controll
assign O_IPL_SET_CS = miocs & (I_A[12:8]==5'h1d);        // 1dxx
assign O_IPL_RES_CS = miocs & (I_A[12:8]==5'h1e);        // 1exx

`ifdef X1TURBO
wire   io1fxx = miocs & (I_A[12:7]==6'b1_1111_1); // 1f80-1fff
assign O_DMA_CS     = io1fxx & (I_A[6:4]==3'b000);    // 1F8x
assign O_SIO_CS     = io1fxx & (I_A[6:2]==5'b001_00); // 1F90-1F93
assign O_CTC_CS     = io1fxx & (I_A[6:2]==5'b010_00); // 1FA0-1FA3
`ifdef X1TURBOZ
// 1FB0 ZMODE
// 1FB9-1FBF Z TEXT PALETTE
// 1FC0 ZPRIO
// 1FC1 ZCAP_HPOS
// 1FC2 ZCAP_MODE
// 1FC3 ZCHROM
// 1FC4 ZSCROLL
// 1FC5 ZPAL_MODE
`endif
assign O_P1FDX_CS   = io1fxx & (I_A[6:4]==3'b101);    // 1FDx
assign O_BLACK_CS   = io1fxx & (I_A[6:4]==3'b110);    // 1FEx
assign O_DIPSW_CS   = io1fxx & (I_A[6:4]==3'b111);    // 1FFx
`endif

// DAM clear signal
assign O_DAM_CLR = iorq_r & ~I_RD_n;
// for EXT board
assign O_MIOCS = miocs;

endmodule
