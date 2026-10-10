//---------------------------------------------------------------------------
// hardware type select
//---------------------------------------------------------------------------
`define X1TURBO      // X1turbo (subset yet)
//`define X1TURBOZ     // future...

//---------------------------------------------------------------------------
// Z80CPU core select
//---------------------------------------------------------------------------
`define USE_FZ80C    // choice fz80 (altanate TV80)

//---------------------------------------------------------------------------
// VIDEO encoder
//---------------------------------------------------------------------------
`define VGA_CONV     // x2 up-scan conveter for VGA output
//`define NTSC_S2    // NTSC S2 encoder with 2x4bit DAC

//---------------------------------------------------------------------------
// sound unit seelctor
//---------------------------------------------------------------------------
`define PSG        // AY-3-8910 PSG sound & 1bit DAC
//`define FM_BOARD   // YM2151 FM sound board (not supported yet)

//---------------------------------------------------------------------------
// additional and support circuit
//---------------------------------------------------------------------------
`define PCG_AUTO_WAIT  // PCG auto wait trap for fast Z80 IP or overclock
`define EXTEND_BIOS  // extend BIOS MENU & NoICE-Z80 resource-free monitor
`define FAKE_KANJI_VRAM // dummp KANJI ROM register for X1turbo check

//`define OVER_CLOCK  // 8MHz overclock mode

//---------------------------------------------------------------------------
// for DEBUG
//---------------------------------------------------------------------------
//`define NO_VIDEO    // disable VIDEO OUTPUT
//`define DEBUG_UV_DLY  // adjust NTSC Y/UV delay
//`define DMA_TEST

// --------------------------
// make internal switch
// --------------------------
// CTC select
`ifdef X1TURBO
  `define Z80_CTC
`endif
`ifdef FM_BOARD
  `ifndef Z80_CTC
  `define Z80_CTC
  `endif
`endif

/****************************************************************************
  nise X1 TOP

  Version 0804xx

  Copyright(C) 2004,2005,2008 Tatsuyuki Satoh

  This software is provided "AS IS", with NO WARRANTY.
  NON-COMMERCIAL USE ONLY

  Histry:
    2008. 4.xx separated by sp3sk model
    2005. 4.12 
    2005. 4.12 .d88 support
    2005. 1.20 added NTSC S2 encoder
    2005. 1.14 Cleanup
           LED all off when eco-mode
    2005. 1.12 1st release

  Note:

  Distributing all and a part is prohibited. 
  Because this version is developer-alpha version.

****************************************************************************/
module sharpx1_legacy(
// DEBUG

// System RESET , System CLOCKs
  I_RESET,
  I_CLK32M,I_CLK28M636,
//  I_CLK4M,

// External CPU Bus (Main RAM)
  O_CBUS_BANK,
  O_CBUS_ADDRESS,
  O_CBUS_DATA,
  I_CBUS_DATA,
  O_CBUS_RD_n,
  O_CBUS_WR_n,
  I_CBUS_WAIT_n,
  O_CBUS_CS_IPL,
  O_CBUS_CS_MRAM,
  O_CBUS_CS_GRAMB,
  O_CBUS_CS_GRAMR,
  O_CBUS_CS_GRAMG,
  O_CBUS_BANK_GRAM_R,
  O_CBUS_BANK_GRAM_W,
// External VIDEO Bus
  O_GRAM_A,
  I_GRAM_D_R,I_GRAM_D_G,I_GRAM_D_B,
// Xilinx Config ROM
  O_XCF_CCLK,O_XCF_RESET,I_XCF_DIN,
// SD / MMC Card
   O_MMC_CLK,O_MMC_CS,O_MMC_DOUT,I_MMC_DIN,
// PS2
   I_PS2_CLK,I_PS2_DAT,
   O_PS2_CLK_T,O_PS2_DAT_T,
// sound
   PCM_L,PCM_R,
// NTSC S1 Video out
`ifdef NTSC_S2
  O_VY,O_VC,
`endif
// Front / Back Panel Switches
  O_LED_FDD_RED,
  O_LED_FDD_GREEN,

  I_NMI_n,
  O_LED_POWER,
  O_LED_TIMER,
`ifdef X1TURBO
  I_IPL_n,
  I_DEFCHR_SW,
  O_LED_HIRESO,
  I_DSW,
 `ifdef X1TURBOZ
  O_LED_ANALOG,
 `endif
`endif
// DIP SW.
// JOYSTICK
  I_JOYA,I_JOYB,
  O_JOYA,O_JOYB,
  T_JOYA,T_JOYB,
// VGA / SCART RGB output
  O_VGA_R,O_VGA_G,O_VGA_B,O_VGA_HS,O_VGA_VS,
// debug port : SUB CPU firmware download
  I_FIRMWARE_EN,
// debug port : SUB CPU number monitor
  O_DBG_NUM4,O_DBG_DOT4,O_DBG_LED8,
// debug port : USART
  I_USART_CLK,I_USART_CLKEN16,I_USART_RX,O_USART_TX
);

/****************************************************************************
  I/O PIN description
****************************************************************************/

input I_RESET;
input I_CLK32M;
input I_CLK28M636;
//input I_CLK4M;

// External CPU Bus (Main RAM)
output [ 3:0] O_CBUS_BANK;     // upper bank address,for FD image access
output [15:0] O_CBUS_ADDRESS;
output [ 7:0] O_CBUS_DATA;
input  [ 7:0] I_CBUS_DATA;
output  O_CBUS_RD_n;
output  O_CBUS_WR_n;
input   I_CBUS_WAIT_n;
output  O_CBUS_CS_IPL;
output  O_CBUS_CS_MRAM;
output  O_CBUS_CS_GRAMB;
output  O_CBUS_CS_GRAMR;
output  O_CBUS_CS_GRAMG;
output  O_CBUS_BANK_GRAM_R;
output  O_CBUS_BANK_GRAM_W;

// External VIDEO Bus
output [13:0] O_GRAM_A;
input [7:0] I_GRAM_D_R;
input [7:0] I_GRAM_D_G;
input [7:0] I_GRAM_D_B;

// PS2 keyboard / mouse
input  I_PS2_CLK;
input  I_PS2_DAT;
output O_PS2_CLK_T;
output O_PS2_DAT_T;

// MMC/SDCard
output O_MMC_CLK;
output O_MMC_CS;
output O_MMC_DOUT;
input  I_MMC_DIN;

// 1bit SigmaDelta SOUND DAC
output [15:0] PCM_L;
output [15:0] PCM_R;

`ifdef NTSC_S2
// NTSC S1 Video out
output [3:0] O_VY;
output [3:0] O_VC;
`endif

// Front Panel
output [3:0] O_LED_FDD_RED;
output [3:0] O_LED_FDD_GREEN;

input I_NMI_n;
input I_IPL_n;
input I_DEFCHR_SW;

output O_LED_POWER;
output O_LED_TIMER;
`ifdef X1TURBO
output O_LED_HIRESO;
  `ifdef X1TURBOZ
  input [5:0] I_DSW;
  output O_LED_ANALOG;
  `else
  input [3:0] I_DSW;
  `endif
`endif

// JOYSTICK port
input  [7:0] I_JOYA,I_JOYB;
output [7:0] O_JOYA,O_JOYB;
output T_JOYA,T_JOYB;

// VGA monitor
output O_VGA_R,O_VGA_G,O_VGA_B;
output O_VGA_HS,O_VGA_VS;

// CFG ROM
output O_XCF_CCLK;
output O_XCF_RESET;
input  I_XCF_DIN;

// debug port : SUB CPU firmware download
input I_FIRMWARE_EN;

// debug port : SUB CPU number monitor
output [15:0] O_DBG_NUM4;
output [ 3:0] O_DBG_DOT4;
output [ 7:0] O_DBG_LED8;

// RS232C serial port
input I_USART_CLK;     // base clock
input I_USART_CLKEN16; // x16 clock enable
input I_USART_RX;
output O_USART_TX;

/****************************************************************************
  button / switch function
****************************************************************************/
wire ext_8mhz    = 1'b0;

wire ext_ipl_kill  = 1'b0;
wire ext_trap_en   = 1'b0; // NMI break & boot No-ICE Monitor
`ifdef X1TURBO
wire defchr_enable = ~I_DEFCHR_SW;
`else
wire defchr_enable = 1'b1;
`endif

/****************************************************************************
  clock generator
****************************************************************************/
wire clk_reset = I_RESET;

wire clk28M636 = I_CLK28M636;
wire clk32M    = I_CLK32M;

/****************************************************************************
  basic clock divider
****************************************************************************/

reg [3:0] pris32m;
reg cpu_clk;     // Z80 clock 4MHz / 8MHz

always @(posedge clk32M or posedge clk_reset)
begin
  if(clk_reset)
  begin
  pris32m <= 4'b0000;
  cpu_clk <= 0;
  end else begin
  pris32m  <= pris32m + 1;
  if(pris32m[0] & (pris32m[1]|ext_8mhz) )
    cpu_clk  <= ~cpu_clk;
  end
end
/* wire clk8M = pris32m[1]; */
wire clk2M   = pris32m[3];

/****************************************************************************
  system reset signal
****************************************************************************/

reg reset_dly;
always @(posedge clk32M or posedge clk_reset)
begin
  if(clk_reset)
  reset_dly <= 1'b1;
  else if(pris32m==4'b1111)
  reset_dly <= 1'b0;
end
wire sys_reset = reset_dly | ~I_IPL_n;

/****************************************************************************
  Z80
****************************************************************************/
wire [15:0] ZA;
wire [7:0] ZDO,ZDI;
wire ZMREQ_n,ZIORQ_n,ZM1_n,ZRD_n,ZWR_n, ZRFSH_n;
wire ZCLK, ZINT_n, ZRESET_n, ZWAIT_n;
wire ZNMI_n , ZHALT_n;
wire ZBUSRQ_n , ZBUSAK_n;

wire debug_mode;
wire [3:0] ice_bank;
wire cg_wait_n;

`ifdef EXTEND_BIOS
/* BIOS / debug monitor */
wire H_MREQ_n;
wire H_NMI_n;
wire H_INT_n;
wire [7:0] H_DR;

noicez80 noicez80 (
  .I_REM_CLK(I_USART_CLK),
  .I_REM_CLKE(I_USART_CLKEN16),
  .I_REM_RXD(I_USART_RX),
  .O_REM_TXD(O_USART_TX),
  .O_REM_MODE(debug_mode),
  .I_TRAP_ENABLE(ext_trap_en),
  .O_BANK(ice_bank),
// Inputs
  .I_RESET_n(ZRESET_n),
  .I_CLK(ZCLK),
  .I_INT_n(ZINT_n),
  .I_NMI_n(ZNMI_n),
  .I_M1_n(ZM1_n),
  .I_MREQ_n(H_MREQ_n),
  .I_IORQ_n(ZIORQ_n),
  .I_RD_n(ZRD_n),
  .I_WR_n(ZWR_n),
  .I_HALT_n(ZHALT_n),
  .I_A(ZA),
  .I_DW(ZDO),
  .I_DR(ZDI),
  // Outputs (hooked)
  .O_MREQ_n(ZMREQ_n),
  .O_NMI_n(H_NMI_n),
  .O_INT_n(H_INT_n),
  .O_DR(H_DR)
);
`endif

`ifdef USE_FZ80C
fz80c Z80(
`else
tv80c Z80(
`endif
  .reset_n(ZRESET_n),
  .clk(ZCLK),
`ifdef EXTEND_BIOS
  .mreq_n(H_MREQ_n), 
  .int_n(H_INT_n),
  .nmi_n(H_NMI_n),
  .di(H_DR),
`else
  .mreq_n(ZMREQ_n), 
  .int_n(ZINT_n),
  .nmi_n(ZNMI_n),
  .di(ZDI),
`endif
  .A(ZA), .dout(ZDO),
  .m1_n(ZM1_n), .iorq_n(ZIORQ_n), 
  .rd_n(ZRD_n), .wr_n(ZWR_n),
`ifdef  DMA_TEST
  .wait_n(ZWAIT_n & ~switch[0]), .rfsh_n(ZRFSH_n),.halt_n(ZHALT_n),
  .busrq_n(ZBUSRQ_n & ~(button[1]&button[0])),.busak_n(ZBUSAK_n)
`else
  .wait_n(ZWAIT_n), .rfsh_n(ZRFSH_n),.halt_n(ZHALT_n),
  .busrq_n(ZBUSRQ_n),.busak_n(ZBUSAK_n)
`endif
);

assign ZNMI_n = I_NMI_n;
assign ZCLK   = cpu_clk;
assign ZWAIT_n  = cg_wait_n & I_CBUS_WAIT_n;
assign ZRESET_n = ~I_RESET; // ~sys_reset

/****************************************************************************
  Z80 daisychain INT
****************************************************************************/

`ifdef X1TURBO
wire slot1_int_n , slot1_iei , slot1_ieo;
wire slot2_int_n , slot2_iei , slot2_ieo;
wire sio_int_n   , sio_iei   , sio_ieo;
wire dma_int_n   , dma_iei   , dma_ieo;
wire ctc_int_n   , ctc_iei   , ctc_ieo;
wire sub_int_n   , sub_iei;

// DUMMY
assign slot1_int_n = 1'b1;
assign slot1_ieo   = 1'b1;
assign slot2_int_n = 1'b1;
assign slot2_ieo   = 1'b1;
assign sio_int_n   = 1'b1;
assign sio_ieo     = 1'b1;

// daisychain
assign slot2_iei = slot1_ieo;
assign sio_iei = slot2_ieo;
assign dma_iei = sio_ieo;
assign ctc_iei = dma_ieo;
assign sub_iei = ctc_ieo;

// wired or
assign ZINT_n  = slot1_int_n & slot2_int_n & sio_int_n & dma_int_n & ctc_int_n & sub_int_n;

`else // X1

assign sub_iei = 1'b1;
assign ZINT_n  = sub_int_n;

`endif

/****************************************************************************
  system bus MUX

  master
  Z80DMA  (with RFSH hack access for FDD data)
  Z80 CPU (with Z80 DEBUGGER)
****************************************************************************/
wire [3:0]  dma_bank;
wire [15:0] dma_a;
wire [7:0] dma_do,dma_di;
wire dma_mreq_n,dma_iorq_n,dma_rd_n,dma_wr_n;
wire dma_sel;

wire [7:0] sdi;

// SYNC / ASYNC BUS SIGNAL SELECTOR
`define SYNC_Z80_BUS

`ifdef  SYNC_Z80_BUS
// SYNC / LATCHED Z80 BUS
reg [7:0] sdo;
reg  [3:0]  sbank;
reg [15:0] sa;
reg sm1_n,smreq_n,sireq_n,srd_n,swr_n;

always @(posedge clk32M or negedge ZRESET_n)
begin
  if(~ZRESET_n)
  begin
  sbank <= 0;
  sa    <= 16'h0000;
  sdo   <= 8'h00;
  smreq_n <= 1'b1;
  sireq_n <= 1'b1;
  srd_n <= 1'b1;
  swr_n <= 1'b1;
  end else begin
  sbank <= dma_sel ? dma_bank : ice_bank;
  sa    <= dma_sel ? dma_a    : ZA;
  sdo   <= dma_sel ? dma_do   : ZDO;
  smreq_n <= dma_sel ? dma_mreq_n : ZMREQ_n;
  sireq_n <= dma_sel ? dma_iorq_n : ZIORQ_n;
  srd_n <= dma_sel ? dma_rd_n : ZRD_n;
  swr_n <= dma_sel ? dma_wr_n : ZWR_n;
  end
end
`else
// ASYNC / NON LATCHED Z80 BUS
wire [3:0]  sbank;
wire [15:0] sa;
wire sm1_n,smreq_n,siorq_n,srd_n,swr_n;

assign sbank   = dma_sel ? dma_bank   : ice_bank;
assign sa    = dma_sel ? dma_a    : ZA;
assign smreq_n = dma_sel ? dma_mreq_n : ZMREQ_n;
assign sireq_n = dma_sel ? dma_iorq_n : ZIORQ_n;
assign srd_n   = dma_sel ? dma_rd_n   : ZRD_n;
assign swr_n   = dma_sel ? dma_wr_n   : ZWR_n;

assign sdo     = dma_sel ? dma_do   : ZDO;

`endif

assign ZDI    = sdi;
assign dma_di = sdi;

/****************************************************************************
  Z80 interruput support signal
****************************************************************************/
wire zreti;
wire zspm1;

z80_reti z80_reti(
  .I_RESET(~ZRESET_n),
  .I_CLK(ZCLK),
  .I_CLKEN(1'b1),
  .I_M1_n(ZM1_n),
  .I_MREQ_n(smreq_n),
  .I_IORQ_n(sireq_n),
  .I_D(sdo),
//
  .O_RETI(zreti),
  .O_SPM1(zspm1)
);

/****************************************************************************
  Address Decoder
****************************************************************************/
wire ipl_enable;
wire dam_enable;

wire ipl_sel;
wire dam;

// chip selects
wire ipl_cs;
wire ram_cs;
wire ipl_set_cs;
wire ipl_res_cs;
wire emm_cs;
wire exrom_cs;
wire kanrom_cs;
wire fd5_cs;
wire pal_cs;
wire cg_cs;
wire crtc_cs;
wire sub_cs;
wire pia_cs;
wire psg_cs;
wire attr_cs;
wire text_cs;
wire gr_b_cs;
wire gr_r_cs;
wire gr_g_cs;
wire dam_clr;
`ifdef FM_BOARD
wire fm_cs;
wire fm_ctc_cs;
`endif
`ifdef X1TURBO
wire ktext_cs;
wire bmem_cs;
wire dma_cs;
wire sio_cs;
wire ctc_cs;
wire p1fd0_cs;
wire black_cs;
wire dipsw_cs;
`endif

assign ipl_enable = ~debug_mode & ~ext_ipl_kill & ZRFSH_n;
assign dam_enable = ~debug_mode;

x1_adec x1_adec(
  .I_RESET(sys_reset),
  .I_CLK(clk32M),
  .I_A(sa),
  .I_MREQ_n(smreq_n),.I_IORQ_n(sireq_n),.I_RD_n(srd_n),.I_WR_n(swr_n),
// mode / switch
  .I_IPL_SEL(ipl_sel & ipl_enable),
  .I_DAM(dam & dam_enable),
  .I_DEFCHR(defchr_enable),
// memory
  .O_IPL_CS(ipl_cs),.O_RAM_CS(ram_cs),
// chip select
  .O_EMM_CS(emm_cs),
  .O_EXTROM_CS(exrom_cs),
  .O_KANROM_CS(kanrom_cs),
  .O_FD5_CS(fd5_cs),
  .O_PAL_CS(pal_cs),
  .O_CG_CS(cg_cs),
  .O_CRTC_CS(crtc_cs),
  .O_SUB_CS(sub_cs),
  .O_PIA_CS(pia_cs),
  .O_PSG_CS(psg_cs),
  .O_IPL_SET_CS(ipl_set_cs),
  .O_IPL_RES_CS(ipl_res_cs),
// VRAM
  .O_ATTR_CS(attr_cs),.O_TEXT_CS(text_cs),
  .O_GRB_CS(gr_b_cs),.O_GRR_CS(gr_r_cs),.O_GRG_CS(gr_g_cs),
// option board
`ifdef FM_BOARD
  .O_FM_CS(fm_cs),.O_FMCTC_CS(fm_ctc_cs),
`endif
// X1turbo adittional
`ifdef X1TURBO
  .O_HDD_CS(),
  .O_FD8_CS(),
  .O_BMEM_CS(bmem_cs),
  .O_DMA_CS(dma_cs),
  .O_SIO_CS(sio_cs),
  .O_CTC_CS(ctc_cs),
  .O_P1FDX_CS(p1fd0_cs),
  .O_BLACK_CS(black_cs),
  .O_DIPSW_CS(dipsw_cs),
  .O_KANJI_CS(ktext_cs),
`endif
// DOUJI access mode clear
  .O_DAM_CLR(dam_clr)
);

// subcpu debug download mode
wire firm_en = I_FIRMWARE_EN;
wire firm_cs = firm_en & ~ZMREQ_n;

// data input
wire [7:0] sram_dr;   // MAIN RAM
wire [7:0] exrom_dr;  // external ROM
wire [7:0] sub_rd;    // subcpu RD / 5'FDD
wire [7:0] text_rd;   // text VRAM
wire [7:0] attr_rd;   // attribute VRAM
wire [7:0] cg_mux_dr; // CG / PSG
wire [7:0] pia_dr;    // PIA8255
wire [7:0] psg_dr;    // PSG (JOYSTICK)

`ifdef Z80_CTC
wire [7:0] ctc_rd;    // Z80 CTC
wire ctc_doe;
`endif
`ifdef FM_BOARD
wire [7:0] fm_rd;   // YM2151
`endif
`ifdef X1TURBO
//wire [7:0] dma_rd;    // Z80 DMAC
wire [7:0] sio_rd;    // Z80 SIO
wire [7:0] ktext_rd;  // KANJI VRAM

wire dma_doe = 1'b0;
wire sio_doe = 1'b0;
`endif

// address decoder
wire sub_doe;
wire sram_doe = ipl_cs | ram_cs | gr_b_cs | gr_r_cs | gr_g_cs;

assign sdi    =
`ifdef Z80_CTC
  ctc_doe   ? ctc_rd  :
`endif
`ifdef X1TURBO
//  dma_doe   ? dma_rd  :
  sio_doe   ? sio_rd  :
`endif
  sub_doe   ? sub_rd  :
//
  cg_cs     ? cg_mux_dr :
  pia_cs    ? pia_dr  :
  psg_cs    ? psg_dr  :
  exrom_cs    ? exrom_dr :
  sram_doe    ? sram_dr :
  text_cs   ? text_rd :
  attr_cs   ? attr_rd :
`ifdef X1TURBO
  ktext_cs    ? ktext_rd :
`endif
`ifdef FM_BOARD
  fm_cs     ? fm_rd :
`endif
  8'hff;

/****************************************************************************
  SUB CPU
****************************************************************************/
wire sub_tx_bsy;
wire sub_rx_bsy;
wire key_brk_n;

wire [15:0] num_7seg;
wire [3:0]  dot_7seg;

// JOYSTICK EMULATION
wire [7:0] joy_ea,joy_eb;

// FDC emulation
wire fd5_drq;
// FD physical emulation
wire [3:0] fd5_lamp;
wire [7:0] pcm_out; // SEEK SOUND

// TimerTimming port;
wire clk1;   // for text Blink

// firmware download
wire sub_reset = I_RESET; // | firm_en;  // sys_reset

// DMA / fdd emu
assign dma_sel = (~ZRFSH_n | ~ZBUSAK_n) & ~firm_en;

x1_sub #(11,1) x1_sub(
  .I_reset(sub_reset),
  .I_rtc_power_reset(1'b0),
// SUBCPU (DMAC) basic clock
  .I_clk(clk32M),
// Z80 system bus
  .I_cs(sub_cs),
  .I_rd(~srd_n),
  .I_wr(~swr_n),
  .I_M1_n(ZM1_n),
  .I_D(sdo),
  .O_D(sub_rd),
  .O_DOE(sub_doe),
// handshake
  .O_TX_BSY(sub_tx_bsy),
  .O_RX_BSY(sub_rx_bsy),
  .O_KEY_BRK_n(key_brk_n),
// subcpu int controll
  .I_SPM1(zspm1),
  .I_RETI(zreti),
  .I_IEI(sub_iei),
  .O_INT_n(sub_int_n),
// SUBCPU Firmware Access Port
  .I_fa(sa[12:0]),
  .I_fcs(firm_cs),
// FD emulation
  .O_FDC_DRQ_n(fd5_drq),
  .I_FDCS(fd5_cs),
  .I_RFSH_n(ZRFSH_n),
  .I_RFSH_STB_n(H_MREQ_n),
//
  .I_DMA_CS(dma_cs),
  .O_DMA_BANK(dma_bank),
  .O_DMA_A(dma_a),
  .I_DMA_D(dma_di),
  .O_DMA_D(dma_do),
  .O_DMA_MREQ_n(dma_mreq_n),
  .O_DMA_IORQ_n(dma_iorq_n),
  .O_DMA_RD_n(dma_rd_n),
  .O_DMA_WR_n(dma_wr_n),
  .O_DMA_BUSRQ_n(ZBUSRQ_n),
  .I_DMA_BUSAK_n(ZBUSAK_n),
  .I_DMA_RDY(fd5_drq),
  .I_DMA_WAIT_n(ZWAIT_n),
  .I_DMA_IEI(dma_iei),
  .O_DMA_INT_n(dma_int_n),
  .O_DMA_IEO(dma_ieo),
//
  .O_FD_LAMP(fd5_lamp),
// PCM SOUND
  .O_PCM(pcm_out),
// debug monitor
  .num_7seg(O_DBG_NUM4),
  .dot_7seg(O_DBG_DOT4),
// PS2 KeyPort
  .I_PS2C(I_PS2_CLK),
  .I_PS2D(I_PS2_DAT),
  .O_PS2CT(O_PS2_CLK_T),
  .O_PS2DT(O_PS2_DAT_T),
// TEXT Blick clock
  .O_clk1(clk1),
// JOY EMU
  .O_JOY_A(joy_ea),
  .O_JOY_B(joy_eb)
);

// Front Panel
assign O_LED_FDD_RED = fd5_lamp;
assign O_LED_FDD_GREEN = 4'b0000;

/****************************************************************************
  8255 PIA
****************************************************************************/
wire [7:0] lpt_data;
wire vblank_n; // with latch ~RA0
wire vsync , hsync;
wire lpt_rdy = 1'b0;
wire cmt_read = 1'b0;

wire [7:0] pia_a; // printer output data;
`ifdef X1TURBO
wire [7:0] pia_b = {vblank_n,sub_tx_bsy,sub_rx_bsy,ipl_sel,lpt_rdy,vsync,cmt_read,key_brk_n};
`else
wire [7:0] pia_b = {vblank_n,sub_tx_bsy,sub_rx_bsy,1'b1,lpt_rdy,vsync,cmt_read,key_brk_n};
`endif

wire [7:0] pia_c;
wire lpt_stb   = pia_c[7];
wire width40   = pia_c[6];
wire dam_en_n  = pia_c[5]; // DOUJI ACCESS fall trigger
wire sm_scrl_n = pia_c[4]; // smooth scroll (L)

PIA8255 pia(
  .I_RESET(sys_reset),
  .I_A(sa[1:0]),
  .I_CS(pia_cs),
  .I_RD(~srd_n),
  .I_WR(~swr_n),
  .I_D(sdo),
  .O_D(pia_dr),
//
  .I_PA(8'h00), .O_PA(pia_a),
//
  .I_PB(pia_b), .O_PB(),
//
  .I_PC(8'h00), .O_PC(pia_c)
);

/****************************************************************************
  JOY STICK MUX
****************************************************************************/
wire [7:0] joy_mux_a , joy_mux_b;

assign joy_mux_a = joy_ea;// & I_JOYA;
assign joy_mux_b = joy_eb & I_JOYB;

assign O_JOYA = 8'hff;
assign O_JOYB = 8'hff;
assign T_JOYA = 1'b1;
assign T_JOYB = 1'b1;

/****************************************************************************
  AY-3-8910
****************************************************************************/

wire [7:0] PSG_OUT;

`ifdef PSG
wire [9:0] PSG_OUT_A,PSG_OUT_B,PSG_OUT_C;

ay8910 PSG(
  .rst_n(~sys_reset),
  .clk(clk2M),
  .clken(1'b1),
  .asel(~sa[8]),
  .cs_n(~psg_cs),
  //.direct_sel(0),
  .wr_n(swr_n),
  .rd_n(srd_n),
  .di(sdo),
  .dout(psg_dr),
  .A(PSG_OUT_A) ,
  .B(PSG_OUT_B) ,
  .C(PSG_OUT_C) ,
  .pa_i(joy_mux_a) ,
  .pb_i(joy_mux_b) ,
  .pa_o() ,
  .pa_t() ,
  .pb_o() ,
  .pb_t()
);

wire [11:0] PSG_MIX = PSG_OUT_A + PSG_OUT_B + PSG_OUT_C + {pcm_out,2'b00};
// PCM output
assign PCM_L = {PSG_MIX,4'b0000};
assign PCM_R = {PSG_MIX,4'b0000};
`else
assign psg_dr = joy_mux_a;
assign PCM_L = 0;
assign PCM_R = 0;
`endif


/****************************************************************************
  mode swithes
****************************************************************************/

x1_mode x1_mode(
  .I_RESET(sys_reset),
  .C_CLK(ZCLK),
  .I_A(sa),
  .I_D(sdo),
  .I_RD(~srd_n),
  .I_WR(~swr_n),
// IPL select,
  .I_IPL_SET_CS(ipl_set_cs),
  .I_IPL_RES_CS(ipl_res_cs),
  .O_IPL_SEL(ipl_sel),
// DOUJI access mode (GRAPHIC)
  .C_DAM_SET_n(dam_en_n), // fall clk
  .I_DAM_CLR(dam_clr),   // async 
  .O_DAM(dam)
);

`ifdef X1TURBO
/****************************************************************************
  X1turbo mode swithes
****************************************************************************/
wire hireso;
wire line400;
wire text12;
wire gram_rp;
wire gram_wp;
wire pcg_mode;
wire cg16;
wire udline;
wire [2:0] black_col;
wire txt_black;
wire gr0_black;
wire gr1_black;
wire blk_black;

wire [7:0] x1tm_rd;
wire x1tm_doe;

x1t_mode x1t_mode(
  .I_RESET(sys_reset),
  .CLK(ZCLK),
  .I_D(sdo),
  .O_D(x1tm_rd),
  .O_DOE(x1tm_doe),
  .I_WR(~swr_n),
  .I_RD(~srd_n),
  .I_P1FD0_CS(p1fd0_cs),
  .I_P1FE0_CS(black_cs),
  .O_HIRESO(hireso),
  .O_LINE400(line400),
  .O_TEXT12(text12),
  .O_GRAM_RP(gram_rp),
  .O_GRAM_WP(gram_wp),
  .O_PCG_TURBO(pcg_mode),
  .O_CG16(cg16),
  .O_UDLINE(udline),
  .O_BLACK_COL(black_col),
  .O_TXT_BLACK(txt_black),
  .O_GR0_BLACK(gr0_black),
  .O_GR1_BLACK(gr1_black),
  .O_BLK_BLACK(blk_black)
);
`endif

/****************************************************************************
  VIDEO circuit
****************************************************************************/
wire vclk = clk28M636;
wire [4:0] vid_q; // video timming

wire vid_re;
wire [7:0] vid_dr;

wire vwait;

wire [7:0] txt_dr , att_dr , ktxt_dr;

wire [13:0] vaddr;

wire [10:0] cg_a;
wire [7:0]  cg_dr,pcgb_dr,pcgr_dr,pcgg_dr;
wire [7:0]  grb_dr,grr_dr,grg_dr;

wire red,green,blue;

x1_vid x1_vid(
  .I_RESET(sys_reset),
// CPU I/F
  .I_CCLK(ZCLK),
  .I_A(sa),
  .I_D(sdo),
  .O_D(vid_dr),
  .O_DE(vid_re),
  .I_WR(~swr_n),
  .I_RD(~srd_n),
  .O_VWAIT(vwait),
// CHIP SELECT
  .I_CRTC_CS(crtc_cs & defchr_enable),
  .I_CG_CS(cg_cs),
  .I_PAL_CS(pal_cs),
  .I_TXT_CS(text_cs), .I_ATT_CS(attr_cs), .I_KAN_CS(ktext_cs),
  .I_GRB_CS(gr_b_cs), .I_GRR_CS(gr_r_cs), .I_GRG_CS(gr_g_cs),
// VIDEO CLOCK
  .I_VCLK(vclk),  .I_CLK1(clk1),
  .O_VQ(vid_q),
// VIDEO MODE
  .I_W40(width40),
`ifdef X1TURBO
  .I_HIRESO(hireso),
  .I_LINE400(line400),
  .I_TEXT12(text12),
  .I_PCG_TURBO(pcg_mode),
  .I_CG16(cg16),
  .I_UDLINE(udline),
  .I_BLACK_COL(black_col),
  .I_TXT_BLACK(txt_black),
  .I_GR0_BLACK(gr0_black),
  .I_GR1_BLACK(gr1_black),
  .I_BLK_BLACK(blk_black),
`endif
// VRAM / GRAM
  .O_VA(vaddr),
// VRAM
  .O_TXT_WE(), .O_ATT_WE(), .O_KAN_WE(),
  .I_TXT_D(txt_dr),  .I_ATT_D(att_dr),.I_KAN_D(ktxt_dr),
// GRAM
  .O_GRB_WE(), .O_GRR_WE(), .O_GRG_WE(),
  .I_GRB_D(grb_dr) , .I_GRR_D(grr_dr),  .I_GRG_D(grg_dr),
// CG ROM/RAM
  .O_CGA(cg_a),
  .I_CG_D(cg_dr) ,
  .I_PCGB_D(pcgb_dr) , .I_PCGR_D(pcgr_dr) , .I_PCGG_D(pcgg_dr),
// VIDEO OUTPUT
  .O_R(red)  , .O_G(green)   , .O_B(blue),
  .O_HSYNC(hsync) , .O_VSYNC(vsync), .O_VDISP(vblank_n)
);

`ifdef X1TURBO
/****************************************************************************
  X1turbo hard sync PCG set wait controll
****************************************************************************/
assign pcg_wait_n = ~(~hsync & pcg_mode & cg_cs);
`else
assign pcg_wait_n = 1'b0;
`endif

/****************************************************************************
  X1 soft sync PCG wait TRAP
****************************************************************************/
`ifdef PCG_AUTO_WAIT
wire cg_auto_wait_n;

pcg_wait pcg_wait(
  .I_RESET(sys_reset),
  .I_CCLK(ZCLK),
  .I_CG_CS(cg_cs),
  .I_A(sa),
  .I_VDISP(vblank_n),
  .I_QD(vid_q[4]),
  .I_RA0(vaddr[11]),
  .O_CG_WAIT_n(cg_auto_wait_n)
);
assign cg_wait_n = pcg_wait_n & cg_auto_wait_n;
`else
assign cg_wait_n = pcg_wait_n;
`endif

`ifdef Z80_CTC
/****************************************************************************
  Z80 CTC (turbo / FM board)
****************************************************************************/

`ifdef X1TURBO
wire z80ctc_cs = ctc_cs;    // HIGH priority
`else
wire z80ctc_cs = fm_ctc_cs;   // LOW priority
`endif

wire [3:0] ctc_to;
wire [3:0] ctc_ti;

assign ctc_ti[0] = 1'b1;
assign ctc_ti[1] = clk2M;
assign ctc_ti[2] = clk2M;
assign ctc_ti[3]   = ctc_to[0]; // Ch0 -> CH3 chain

z80ctc z80ctc(
  .I_RESET(sys_reset),
  .I_CLK(ZCLK),
  .I_CLKEN(1'b1),
  .I_A(sa[1:0]),
  .I_D(sdo),
  .O_D(ctc_rd),
  .O_DOE(ctc_doe),
  .I_CS_n(~z80ctc_cs),
  .I_WR_n(swr_n),
  .I_RD_n(srd_n),
  .I_M1_n(ZM1_n),
// irq handling
  .I_SPM1(zspm1),
  .I_RETI(zreti),
  .I_IEI(ctc_iei),
  .O_IEO(ctc_ieo),
  .O_INT_n(ctc_int_n),
//
  .I_TI(ctc_ti),
  .O_TO(ctc_to)
);
`endif

/****************************************************************************
  FM sound board (YM2151)
****************************************************************************/
`ifdef FM_BOARD
assign fm_rd = 8'h03; // YM2151 , DUMMY STATUS
`endif

/****************************************************************************
  Z80SIO
****************************************************************************/
`ifdef X1TURBO
assign sio_rd = 8'h00;
`endif

/****************************************************************************
  Z80DMA
****************************************************************************/
`ifdef X1TURBO
//assign dma_rd = 8'h00;
`endif

/****************************************************************************
  ATTR / TEXT / KANJI VRAM
****************************************************************************/

// VRAM R/W bus
wire [10:0] ca;
wire cwe,crd;
wire [10:0] vram_addr;

assign ca   = sa[10:0];
assign cwe    = ~swr_n;
assign crd    = ~srd_n;

dpram2k text_ram(
// CPU I/F
  .CCLK(ZCLK),
  .CA(ca),
  .CDI(sdo),
  .CDO(text_rd),
  .CCS(text_cs),
  .CWE(cwe),
  .CRD(crd),
// VIDEO 
  .VCLK(vclk),
  .VA(vaddr[10:0]),
  .VDO(txt_dr)
);

dpram2k att_ram(
// CPU I/F
  .CCLK(ZCLK),
  .CA(ca),
  .CDI(sdo),
  .CDO(attr_rd),
  .CCS(attr_cs),
  .CWE(cwe),
  .CRD(crd),
// VIDEO 
  .VCLK(vclk),
  .VA(vaddr[10:0]),
  .VDO(att_dr)
);

`ifdef X1TURBO
`ifdef FAKE_KANJI_VRAM
// KANJI VRAM , fake port
reg [7:0] ktext_fake_d;
always @(posedge ZCLK)
begin
  if(ktext_cs & cwe)
  ktext_fake_d <= sdo;
end
assign ktext_rd = ktext_fake_d;
`else // FAKE_KANJI_VRAM
dpram2k kanji_ram(
// CPU I/F
  .CCLK(ZCLK),
  .CA(ca),
  .CDI(sdo),
  .CDO(ktext_rd),
  .CCS(ktext_cs),
  .CWE(cwe),
  .CRD(crd),
// VIDEO 
  .VCLK(vclk),
  .VA(vaddr[10:0]),
  .VDO(ktxt_dr)
);
`endif // FAKE_KANJI_VRAM
`endif // X1TURBO

/****************************************************************************
  CG ROM
****************************************************************************/
x1_cg8 x1_cg8( .I_CLK(vclk), .I_ADDR(cg_a), .O_DATA(cg_dr) );

/****************************************************************************
  PCG RAM
****************************************************************************/

wire cg_wr   = cg_cs & ~swr_n & defchr_enable & cg_wait_n;
wire pcgb_wr = cg_wr & (sa[9:8]==2'b01); // 15xx
wire pcgr_wr = cg_wr & (sa[9:8]==2'b10); // 16xx
wire pcgg_wr = cg_wr & (sa[9:8]==2'b11); // 17xx

// CPU CG read
assign cg_mux_dr =
  (sa[9:8]==2'b00) ? cg_dr   :
  (sa[9:8]==2'b01) ? pcgb_dr :
  (sa[9:8]==2'b10) ? pcgr_dr :
           pcgg_dr ;
dpram2k pcg_b_ram(
// CPU I/F
  .CCLK(ZCLK),
  .CA(cg_a),
  .CDI(sdo),
  .CDO(),
  .CCS(1'b1),
  .CWE(pcgb_wr),
  .CRD(1'b1),
// VIDEO 
  .VCLK(vclk),
  .VA(cg_a),
  .VDO(pcgb_dr)
);

dpram2k pcg_r_ram(
// CPU I/F
  .CCLK(ZCLK),
  .CA(cg_a),
  .CDI(sdo),
  .CDO(),
  .CCS(1'b1),
  .CWE(pcgr_wr),
  .CRD(1'b1),
// VIDEO 
  .VCLK(vclk),
  .VA(cg_a),
  .VDO(pcgr_dr)
);

dpram2k pcg_g_ram(
// CPU I/F
  .CCLK(ZCLK),
  .CA(cg_a),
  .CDI(sdo),
  .CDO(),
  .CCS(1'b1),
  .CWE(pcgg_wr),
  .CRD(1'b1),
// VIDEO 
  .VCLK(vclk),
  .VA(cg_a),
  .VDO(pcgg_dr)
);

/****************************************************************************
  video converter
****************************************************************************/

//wire pclk_en = width40 ? ~vid_q[0] : ~vid_q[1];
wire pclk_en = width40 ? vid_q[0] : ~vid_q[1];

`ifdef NO_VIDEO
assign O_VGA_R = 0;
assign O_VGA_G = 0;
assign O_VGA_B = 0;
assign O_VGA_HS =0;
assign O_VGA_VS =0;
`else //NO_VIDEO

`ifdef VGA_CONV
/* VGA upscanconverter */

wire vc_r,vc_g,vc_b;
wire vc_hsync,vc_vsync;

dbl_scan dbl_scan(
  .I_CLK(clk28M636),
//
  .I_ICLK_EN(pclk_en),
  .I_R(red),
  .I_G(green),
  .I_B(blue),
  .I_HSYNC(hsync),
  .I_VSYNC(vsync),
//
  .I_OCLK_EN(1'b1),
  .O_R(vc_r),
  .O_G(vc_g),
  .O_B(vc_b),
  .O_HSYNC(vc_hsync),
  .O_VSYNC(vc_vsync)
);

assign O_VGA_R = vc_r;
assign O_VGA_G = vc_g;
assign O_VGA_B = vc_b;
assign O_VGA_HS = vc_hsync;
assign O_VGA_VS = vc_vsync;
`else // VGA_CONV
assign O_VGA_R = red;
assign O_VGA_G = green;
assign O_VGA_B = blue;
assign O_VGA_HS = hsync;
assign O_VGA_VS = vsync;
`endif // VGA_CONV
`endif // NO_VIDEO

/****************************************************************************
  NTSC video converter
****************************************************************************/
`ifdef NTSC_S2
wire [1:0] sc = width40 ? ~{vid_q[2:1]} : ~{vid_q[3:2]};

`ifdef DEBUG_UV_DLY
reg [3:0] du,dv;
always @(posedge ZCLK)
begin
  if(sa[15:8]==0 && ~sireq_n && ~swr_n)
  {du,dv} <= sdo;
end
`endif // DEBUG_UV_DLY

ntsc_enc ntsc_enc(
  .I_CLK(clk28M636),
//
  .I_ICLK_EN(pclk_en),
  .I_SC(sc),
  .I_R(red),
  .I_G(green),
  .I_B(blue),
  .I_DISP(vblank_n),
  .I_HSYNC(hsync),
  .I_VSYNC(vsync),
//
`ifdef DEBUG_UV_DLY
  .I_DU(du),
  .I_DV(dv),
`endif //DEBUG_UV_DLY
  .O_Y(O_VY),
  .O_C(O_VC)
);
`endif //NTSC_S2

/****************************************************************************
  external SRAM
****************************************************************************/

// External CPU Bus (Main RAM)
assign O_CBUS_BANK    = sbank;
assign O_CBUS_ADDRESS = sa;
assign O_CBUS_DATA    = sdo;
assign sram_dr     = I_CBUS_DATA;
assign O_CBUS_RD_n = srd_n;
assign O_CBUS_WR_n = swr_n;
assign O_CBUS_CS_IPL = ipl_cs;
assign O_CBUS_CS_MRAM = ram_cs & ~firm_cs; // block SUB-CPU FIRM CS
assign O_CBUS_CS_GRAMB = gr_b_cs;
assign O_CBUS_CS_GRAMR = gr_r_cs;
assign O_CBUS_CS_GRAMG = gr_g_cs;

`ifdef X1TURBO
assign O_CBUS_BANK_GRAM_R = gram_rp;
assign O_CBUS_BANK_GRAM_W = gram_wp;
`endif

// External VIDEO Bus
assign O_GRAM_A = vaddr;
assign grr_dr = I_GRAM_D_R;
assign grg_dr = I_GRAM_D_G;
assign grb_dr = I_GRAM_D_B;

/****************************************************************************
  SPI I/F
****************************************************************************/

// I_MMC_DIN
reg spi_clk;
reg [1:0] spi_cs;
reg [3:0] spi_cnt;
reg [7:0] spi_sreg;
reg spi_do;

wire [2:0] spi_in;

wire spi_din = (spi_cs[1] & I_MMC_DIN) | (I_XCF_DIN & spi_cs[0]);

always @(posedge clk32M or negedge ZRESET_n)
begin
  if(~ZRESET_n)
  begin
  spi_clk  <= 1'b0;
  spi_cs   <= 2'b00;
  spi_cnt  <= 4'b0000;
  spi_sreg <= 8'h00;
  spi_do   <= 1'b0;
  end else begin
   if(~spi_clk)
     spi_do <= sdo[0];

  // cs access
  if(exrom_cs & ~swr_n)
  begin
    spi_cnt  <= sa[3:0];
    spi_cs   <= sa[5:4];
    if(~sa[6])
    begin
    spi_sreg <= sdo[7:0];
    end
  end else begin
    if(spi_cnt != 0)
    begin
    // flip clock
    spi_clk <= ~spi_clk;
    // shift in
    if(~spi_clk)
      spi_sreg <= {spi_din,spi_sreg[7:1]}; // LSB first in
    // bit count ,output change
    if(spi_clk)
      spi_cnt <= spi_cnt - 1;
    end
  end
  end
end

// XCF Config-ROM
assign O_XCF_RESET =  spi_cs[0];
assign O_XCF_CCLK  =  spi_clk;

// MMC
assign O_MMC_CS   = ~spi_cs[1];
assign O_MMC_CLK  =  spi_clk;
assign O_MMC_DOUT =  spi_do;

// Read Shift Register
assign exrom_dr    = spi_sreg;

endmodule
