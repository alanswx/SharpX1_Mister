`define SUB_ROM

/****************************************************************************
	X1 subcpu emulation

	Version 050416

	Copyright(C) 2004,2005 Tatsuyuki Satoh

	This software is provided "AS IS", with NO WARRANTY.
	NON-COMMERCIAL USE ONLY

	Histry:
		2005. 4.16 CPU change MiniRISC to MR16
		2005. 1.11 Ver.0.1

	Note:

	Distributing all and a part is prohibited. 
	Because this version is developer-alpha version.

	original subcpu (80C49) pin assign
	+---+------------------------------+------------+------------------------+
	|pin|name|       X1                | X1turboM10 |  X1turbo(not model10)  |
	+---+----+-------------------------+------------+------------------------+
	|11 |ALE | N.C.                    |     ??     | PULL UP                |
	| 9 |PSEN| N.C.                    |     ??     | PULL UP                |
	|25 |PRG | N.C.                    |     ??     | PULL UP                |
	| 1 |TO  | TV POWER                |     <<     |          <<            |
	| 4 |RESET|                        |     <<     |          <<            |
	|30 |P27 |TV REMORT (W-4)          |     <<     |          <<            |
	|37 |P26 |-KEY INT ENABLE          |     <<     |          <<            |
	|34 |P25 |1Hz                      |     <<     |          <<            |
	|35 |P24 |BRK (F-5,CMT SOLENOID)   |     <<     | YM                     |
	|24 |P23 |REW                      |     ??     | STATUS DATA  (<-CMT)   |
	|23 |P22 |FF                       |     ??     | BUSY OUT     (<-CMT)   |
	|22 |P21 |PLAY                     |     ??     | COMMAND DATA (->CMT)   |
	|21 |P20 |MOTOR                    |     ??     | STROBE OUT   (->CMT)   |
	|39 |T1  |uPD1990AC-9(DO)          |     <<     |          <<            |
	|27 |P10 |uPD1990AC-3(CO)          |     <<     |          <<            |
	|28 |P11 |uPD1990AC-2(C1)          |     <<     |          <<            |
	|29 |P12 |-RESET (MAIN CPU)        |     <<     |          <<            |
	|30 |P13 |uPD1990AC-4(STB)         |     <<     |          <<            |
	|31 |P14 |uPD1990AC-5(DI)          |     <<     |          <<            |
	|32 |P15 |uPD1990AC-8(CLK)         |     <<     |          <<            |
	|31 |P16 | 8255-A0                 |     <<     |          <<            |
	|32 |P17 | 8255-A1                 |     <<     |          <<            |
	| 8 |RD  | 8255 RD                 |     <<     |          <<            |
	|10 |WR  | 8255 WR                 |     <<     |          <<            |
	|19-12   | 8255 D0..7              |     <<     |          <<            |
	| 6 |INT |KEY-DATA                 |     <<     |          <<            |
	+---+----+-------------------------+------------+------------------------+

	80C49 8255 Port
	+---+------------------------------+------------+------------------------+
	|pin|       X1                     | X1turboM10 |  X1turbo               |
	+---+------------------------------+------------+------------------------+
	|PA | HOST data I/F                |    <<      |          <<            |
	+---+------------------------------+------------+------------------------+
	|PC7| OBF                          |    <<      |          <<            |
	|PC6| 80C49RD                      |    <<      |          <<            |
	|PC5| 8255 IBF                     |    <<      |          <<            |
	|PC4| 8255 WE                      |    <<      |          <<            |
	|PC3| N.C.                         | PULL UP?   | PULL UP                |
	|PC2| CASSETE LED (H:READ L:WRITE) |    ??      | CPU MODE               |
	|PC1| Z80A BREAK SIGNAL            |    <<      |          <<            |
	|PC0| CASSETE EJECT                |    ??      | TV MODE                |
	+---+------------------------------+------------+------------------------+
	|PB7| OBF (sense)                  |    <<      |          <<            |
	|PB6| 80C49RD (sense)              |    <<      |          <<            |
	|PB5| APSS                         |    ??      | PULL UP                |
	|PB4| EJECT SENSE                  |    ??      | PULL UP                |
	|PB3| N.C.                         |    ??      | PULL UP                |
	|PB2| CASETTE WRITE PROTECT        |    ??      | PULL UP                |
	|PB1| CASETTE SET                  |    ??      | PULL UP                |
	|PB0| TAPE END                     |    ??      | PULL UP                |
	+---+------------------------------+------------+------------------------+

****************************************************************************/
module x1_sub #(parameter CLOCK_HZ = 32000000)(
  I_reset,
  I_clk,  // 32MHz
// MAIN-SUB communication port
  I_cs,
  I_rd,
  I_wr,
  I_M1_n,
  I_D,
  O_D,
  O_DOE,
// Timer IC Timming Port
  O_clk1,
// FDC emulation
  O_FDC_DRQ_n,
//  O_FDC_INT_n,
  I_FDCS,
  I_RFSH_n,
  I_RFSH_STB_n,
// Z80DMA / FDD memory access
  I_DMA_CS,
  O_DMA_BANK,
  O_DMA_A,
  I_DMA_D,
  O_DMA_D,
  O_DMA_MREQ_n,
  O_DMA_IORQ_n,
  O_DMA_RD_n,
  O_DMA_WR_n,
  O_DMA_BUSRQ_n,
  I_DMA_BUSAK_n,
  I_DMA_RDY,
  I_DMA_WAIT_n,
  I_DMA_IEI,O_DMA_INT_n,O_DMA_IEO,
//
  O_PCM,
  O_FD_LAMP,
// SUBCPU Firmware Access Port
  I_fa,
  I_fcs,
// PS2 keyboard
  I_PS2C,
  I_PS2D,
  O_PS2CT,
  O_PS2DT,
// communication handshake signal 
  O_TX_BSY,
  O_RX_BSY,
  O_KEY_BRK_n,
// subcpu int controll
  I_SPM1,
  I_RETI,
  I_IEI,
  O_INT_n,
// JOYSTICK EMULATION PORT
  O_JOY_A,
  O_JOY_B,
// debug
  dot_7seg,
  num_7seg
);

parameter RAM_DEPTH = 11;
parameter JOY_EMU = 1;

input I_reset;
input I_clk;

input [12:0] I_fa;
input I_fcs;

input I_PS2C;
input I_PS2D;
output O_PS2CT;
output O_PS2DT;

input I_cs;
input I_wr;
input I_rd;
input I_M1_n;
input [7:0] I_D;
output [7:0] O_D;
output O_DOE;

// Timer IC Timming Port
output O_clk1;

// FDC port
output O_FDC_DRQ_n;
//output O_FDC_INT_n;
input I_FDCS;
input I_RFSH_n;
input I_RFSH_STB_n;

// DMA
input I_DMA_CS;
output [3:0] O_DMA_BANK;
output [15:0] O_DMA_A;
input  [7:0] I_DMA_D;
output [7:0] O_DMA_D;
output O_DMA_MREQ_n;
output O_DMA_IORQ_n;
output O_DMA_RD_n;
output O_DMA_WR_n;
output O_DMA_BUSRQ_n;
input I_DMA_BUSAK_n;
input I_DMA_RDY;
input I_DMA_WAIT_n;
input I_DMA_IEI;
output O_DMA_INT_n , O_DMA_IEO;


output [7:0] O_PCM;
output [3:0] O_FD_LAMP;

input I_SPM1,I_RETI;
input I_IEI;
output O_INT_n;

output O_TX_BSY;
output O_RX_BSY;
output O_KEY_BRK_n;

// JOYSTICK EMULATION PORT
output [7:0] O_JOY_A;
output [7:0] O_JOY_B;

//debug
output [3:0] dot_7seg;
output [15:0] num_7seg;

////////////////////////////////////////////
//
// HAND SHANKE
//
////////////////////////////////////////////

////////////////////////////////////////////
// IRQ signal
////////////////////////////////////////////
wire sub_ivec_cycle = (I_SPM1 & I_IEI);

////////////////////////////////////////////
// SUB CPU
////////////////////////////////////////////

wire [15:0] sub_addr;
wire [15:0] wdata , rdata , pgm_data ,wram_data;
wire mem_we;
wire scpu_wait_n;

// GPIO
wire [15:0] OP0,OP1,OP2,OP3; // OUT PORT
wire [15:0] OP4,OP5,OP6,OP7; // OUT PORT
wire [15:0] OP8,OP9,OPA,OPB; // OUT PORT
wire [15:0] IP0,IP1,IP2,IP3; // INPORT
wire IA4,IA5,IA6,IA7;        // IN ACK
wire IA8,IA9,IAA,IAB;        // IN ACK

// IRQ
wire [3:0] iack;
wire ps2_irq , ps2_ack;
wire fdc_irq , fdc_ack;
wire dma_irq , dma_ack;

// mux 2 RAM area
wire mem_cs , pgm_cs , wram_cs;
reg msel;
always @(posedge I_clk)
  msel <= pgm_cs;

assign pgm_cs  = mem_cs & ~sub_addr[12]; // 0000-0FFF
assign wram_cs = mem_cs &  sub_addr[12]; // 1000-1FFF 
assign rdata   = msel ? pgm_data : wram_data;

assign scpu_wait_n = ~(~O_DMA_BUSRQ_n && I_DMA_BUSAK_n);

mr16_x1 #(.CLOCK_HZ(CLOCK_HZ)) sub_cpu
(
  .I_RESET(I_reset),.I_CLK(I_clk),.I_CLKEN(scpu_wait_n),
// Address Bus
  .O_A(sub_addr),.O_D(wdata),.I_D(rdata),.O_WR(mem_we),.O_MEMCS(mem_cs),
// Timer
  .I_TMRG(1'b1),
//GPIO periferal
  .O_P0(OP0),.O_P1(OP1),.O_P2(OP2),.O_P3(OP3),
  .O_P4(OP4),.O_P5(OP5),.O_P6(OP6),.O_P7(OP7),
  .O_P8(OP8),.O_P9(OP9),.O_PA(OPA),.O_PB(OPB),
  .I_P0(IP0),.I_P1(IP1),.I_P2(IP2),.I_P3(IP3),
  .O_I4(IA4),.O_I5(IA5),.O_I6(IA6),.O_I7(IA7),
  .O_I8(IA8),.O_I9(IA9),.O_IA(IAA),.O_IB(IAB),
  //Interrupt source
  .I_INT({1'b0,dma_irq,fdc_irq,ps2_irq}),.O_ACK({iack[3],dma_ack,fdc_ack,ps2_ack})
);

////////////////////////////////////////////
// Program ROM(/RAM) 0000-0FFF
////////////////////////////////////////////
wire [10:0] mem_addr = sub_addr[11:1];

`ifdef SUB_ROM
sub_rom sub_rom(.CLK(I_clk),.A(mem_addr),.DO(pgm_data));
`else
////////////////////////////////////////////
// Program RAM 0000-0FFF
////////////////////////////////////////////

wire fcs_pgm = I_fcs & ~I_fa[12];
wire fl_cs   = fcs_pgm & ~I_fa[0];
wire fh_cs   = fcs_pgm &  I_fa[0];
wire [7:0] f_drl , f_drh;
wire [7:0] f_dr = ~I_fa[0] ? f_drl : f_drh;

//dpram #(11,8) sub_l_ram(
dpram2k8 sub_l_ram(
  .ACLK(I_clk),    .BCLK(I_clk),
  .AA(I_fa[11:1]), .BA(mem_addr),
  .AI(I_D),        .BI(wdata[7:0]),
  .AO(f_drl),      .BO(pgm_data[7:0]),
  .ACS(fl_cs),     .BCS(pgm_cs),
  .AWE(I_wr),      .BWE(mem_we)
);

//dpram #(11,8) sub_h_ram(
dpram2k8 sub_h_ram(
  .ACLK(I_clk),    .BCLK(I_clk),
  .AA(I_fa[11:1]), .BA(mem_addr),
  .AI(I_D),        .BI(wdata[15:8]),
  .AO(f_drh),      .BO(pgm_data[15:8]),
  .ACS(fh_cs),     .BCS(pgm_cs),
  .AWE(I_wr),      .BWE(mem_we)
);
`endif

////////////////////////////////////////////
// Work RAM 1000-17FF(1FFF)
////////////////////////////////////////////
wire rfsh_busy;

wire [15:0] h_wram_rd;

wire dma_ivec_sel = I_DMA_IEI & ~O_DMA_IEO & I_SPM1;
wire p8255_hs_cs  = (sub_ivec_cycle | I_cs);

`ifdef SUB_ROM
wire fw_wram_cs = 1'b0;
`else
wire fw_wram_cs = (I_fcs & I_fa[12]);
`endif

// WorkRAM CPU side Address MUX
wire [9:0] h_wram_a =

  dma_ivec_sel    ? {10'b00_0000_0100}         : // 1008:Z80DMA IRQ VECTOR
  p8255_hs_cs     ? { 9'b00_0000_000,I_wr}     : // 1000:HOST RD( or subcpu int vct) / 1002:WR
  I_DMA_CS        ? { 9'b00_0000_001,I_wr}     : // 1004:Z80DMA  RD      / 1006:Z80DMA WR
  fw_wram_cs      ? I_fa[10:1]                : // ALL :DEBUG(low 8bit)
                    { 7'b00_0000_1,I_fa[2:0]}  ; // 1010-101F FDC

wire h_wram_cs = I_FDCS | I_DMA_CS | I_cs | sub_ivec_cycle | fw_wram_cs | dma_ivec_sel;
wire wram_wr   = I_wr;
wire [15:0] h_wram_wd = {8'h00,I_D};
/*
//dpram #(10,16) sub_w_ram(
dpram1k16 sub_w_ram(
  .ACLK(I_clk),    .BCLK(I_clk),
  .AA(h_wram_a),     .BA(mem_addr[9:0]),
  .AI(h_wram_wd),    .BI(wdata),
  .AO(h_wram_rd),    .BO(wram_data),
  .ACS(h_wram_cs),   .BCS(wram_cs),
  .AWE(wram_wr),     .BWE(mem_we)
);
*/
dpram #(16, 10) sub_w_ram  // 1024 words (2 KiB), shared host/sub-CPU
(
	.clock      (I_clk         ),
	.address_a  (h_wram_a      ),
	.ram_cs     (h_wram_cs     ),
	.wren_a     (h_wram_cs && wram_wr),
	.data_a     (h_wram_wd     ),
	.q_a        (h_wram_rd     ),

	.ram_cs_b   (wram_cs       ),
	.wren_b     (wram_cs && mem_we),
	.address_b  (mem_addr[9:0] ),
	.data_b     (wdata         ),
	.q_b        (wram_data     )
);


////////////////////////////////////////////
// periferal
////////////////////////////////////////////

// joystick enulation
wire [7:0] joya_emu , joyb_emu;

// hand shake , host I/F
reg hwd_full;
reg hrd_full;
wire hwd_clr;
wire hrd_set;

// PIO status
wire irq_en;
wire O_KEY_BRK_n;

/////////////////////////////////////
// GPIO assign
/////////////////////////////////////
wire main_we;   // HOST CPU Write Enable
wire main_re;   // HOST CPU Read Enable

// HOST <-> SUB handshake
assign hrd_set = IA4;
assign hwd_clr = IA5;
assign IP1     = {11'h00,O_clk1,irq_en,O_KEY_BRK_n,hwd_full & ~main_we,hrd_full | main_re};
assign O_KEY_BRK_n = OP1[2];
assign irq_en      = OP1[3];
assign O_clk1      = OP1[4];
assign O_INT_n     = ~(irq_en & hrd_full & I_IEI);

// PS/2 RAW I/F
assign IP2     = {14'h0000,I_PS2C,I_PS2D};
assign O_PS2DT = OP2[0];
assign O_PS2CT = OP2[1];

// JOY EMU
assign joya_emu = OP6[7:0];
assign joyb_emu = OP6[15:8];

/////////////////////////////////////
// PS2 SUBCPU IRQ
/////////////////////////////////////

reg [1:0] ps2_ct_r;
assign ps2_irq = (ps2_ct_r==2'b10); // fall PS2C

always @(posedge I_clk)
begin
  if(I_reset)
  begin
    ps2_ct_r    <= 2'b00;
  end else
  begin
    if(ps2_ack)
    begin
      ps2_ct_r <= 2'b00; // clear irq
    end else begin
      if( ps2_ct_r != 2'b10) // fall I_PS2C
        ps2_ct_r <= {ps2_ct_r[0],I_PS2C};
    end
  end
end

////////////////////////////////////////////
// MAIN WD -> SUB handshake (8255 mode0)
////////////////////////////////////////////
assign main_we = I_cs & I_wr;

always @(posedge I_clk)
begin
  if(I_reset)
  begin
    hwd_full <= 1'b0;
  end else begin
    if(main_we)      hwd_full <= 1'b1;
    else if(hwd_clr) hwd_full <= 1'b0;
  end
end

////////////////////////////////////////////
// SUB -> MAIN RD (8255 mode0)
////////////////////////////////////////////
assign main_re = (I_cs & I_rd) | sub_ivec_cycle; // I/O or vector read

always @(posedge I_clk)
begin
  if(I_reset)
  begin
    hrd_full  <= 1'b0;
  end else begin
    if(main_re)      hrd_full <= 1'b0;
    else if(hrd_set) hrd_full <= 1'b1;
  end
end

////////////////////////////////////////////
// handshake output
////////////////////////////////////////////
assign O_TX_BSY =  hwd_full;
assign O_RX_BSY = ~hrd_full;

////////////////////////////////////////////
// JOYSTICK EMULATION
////////////////////////////////////////////
assign O_JOY_A = JOY_EMU ? joya_emu : 8'hff;
assign O_JOY_B = JOY_EMU ? joyb_emu : 8'hff;

////////////////////////////////////////////
// FDC emulation
////////////////////////////////////////////

// FDC resgister cs
reg fdc_drq;
wire fd_sts_cs = I_FDCS & (I_fa[2:0]==3'b000);
wire fd_cmd_wr = I_FDCS & (I_fa[2:0]==3'b000) & I_wr;
wire fd_dat_cs = I_FDCS & (I_fa[2:0]==3'b011) & fdc_drq;

// FDC auto DRQ controll I/O
wire fd_drq_set = IA6;
wire fd_drq_clr = IA7;

// FDC interface
wire [7:0] fd_sts;  // FD status port
wire fdc_hlt  = 1'b1; // HLT
wire fdc_wprt = 1'b1; // write protect

assign fd_sts  = OP3[7:0] | {6'b000000,fdc_drq,1'b0};
assign IP3     = {5'b00000,fdc_drq,fdc_wprt,fdc_hlt,OP3[7:0]};

// auto DRQ controll
reg fd_dat_cs_r;
wire drq_set = fd_drq_set;
wire drq_clr = fd_drq_clr | (fd_dat_cs_r & ~fd_dat_cs);

always @(posedge I_clk)
begin
  if(I_reset)
  begin
    fdc_drq     <= 1'b0;
    fd_dat_cs_r <= 1'b0;
  end else begin
    fd_dat_cs_r <= fd_dat_cs;
    if(drq_set)      fdc_drq <= 1'b1;
    else if(drq_clr) fdc_drq <= 1'b0;
  end
end

// FDC output signal
assign O_FDC_DRQ_n = ~fdc_drq;
//assign O_FDC_INT_n = 1'b1;
//
// Access LAMP
assign O_FD_LAMP = OP4[3:0];          // FD Access LAMP

// SEEK SOUND PCM
assign O_PCM     = OPB[7:0];          // PCM SEEK SOUND

////////////////////////////////////////////
// Z80DMA / RFSH bus hack
////////////////////////////////////////////

// RFSH REQ/ACK CONTROLL
reg rfsh_r , rfsh_rdy , rfsh_cyc;
//wire rfsh_busy;
wire rfsh_req;
reg [7:0] dma_d_r;

// RDY signal handling
wire dma_rdy;
wire dma_rdy_dir,dma_rdy_ena,dma_rdy_frc;

// INT controll
wire dma_int_res; // RESET & DI command
wire dma_int_set; // irq set request
wire dma_int_ena; // interrupt enable


// DMA BUS
assign O_DMA_D      = OP0[7:0];                                        // DMA write data
assign IP0          = {5'h00,dma_rdy,rfsh_busy,I_DMA_BUSAK_n,dma_d_r}; // DMA read data & status
assign O_DMA_BANK   = OP9[3:0]; // 1MB upper bank
assign O_DMA_A      = OP8;
assign O_DMA_BUSRQ_n= (~OP9[11]);
assign O_DMA_MREQ_n = (~OP9[12]);
assign O_DMA_IORQ_n = (~OP9[13]);
assign O_DMA_RD_n   = (~OP9[14]);
assign O_DMA_WR_n   = (~OP9[15]) | (I_DMA_BUSAK_n & I_RFSH_STB_n);
assign rfsh_req     =   OP9[8];

// RDY / INT controll
assign dma_rdy_frc  = OPA[0];  //(wr5.0)
assign dma_rdy_dir  = OPA[3];  // wr5.3
assign dma_int_ena  = OPA[5];  // wr3.5
assign dma_rdy_ena  = OPA[6];  // wr3.6
assign dma_int_res  = OPA[1];  // interrupt reset
assign dma_int_set  = OPA[2];  // interrupt set

////////////////////////////////////////////////////
wire dma_cycle   = (~I_DMA_BUSAK_n) || (~I_RFSH_n & rfsh_busy);

always @(posedge I_clk)
begin
  if(dma_cycle & (~O_DMA_RD_n) ) 
     dma_d_r  <= I_DMA_D;
end

////////////////////////////////////////////////////
// DMA INT
////////////////////////////////////////////////////
reg dma_int_req , dma_int_srv , dma_int_req_s;

always @(posedge I_clk)
begin
  if(I_reset)
  begin
    dma_int_req   <= 1'b0;
    dma_int_srv   <= 1'b0;
    dma_int_req_s <= 1'b0;

  end else begin

    // keep interrupt request in M1 cycle
    if(I_M1_n)
      dma_int_req_s <= dma_int_req & I_DMA_IEI & dma_int_ena;

    // interrupt request trigger
    if(dma_int_set)
      dma_int_req <= 1'b1;

    // ISR enter , service mode set
    if(I_DMA_IEI & I_SPM1 & dma_int_req_s)
    begin
      dma_int_srv <= 1'b1;
      dma_int_req <= 1'b0;
    end

    // service mode clear
    if(I_RETI)
      dma_int_srv <= 1'b0;

    // INT reset COMMAND
    if(dma_int_res)
    begin
      dma_int_req <= 1'b0;
      dma_int_srv <= 1'b0;
    end
  end
end

assign O_DMA_INT_n = ~(I_DMA_IEI &  dma_int_req_s);
assign O_DMA_IEO   = I_DMA_IEI & ~dma_int_req_s & ~dma_int_srv;

// RFSH one shot access 
assign rfsh_busy      = rfsh_req & (rfsh_rdy | rfsh_cyc);
always @(posedge I_clk)
begin
  if(I_reset)
  begin
    rfsh_rdy   <= 1'b0;
    rfsh_r     <= 1'b0;
    rfsh_cyc   <= 1'b0;
  end else begin
    rfsh_r <= I_RFSH_n;

    // raise RFSH -> finish
    if(~rfsh_r & I_RFSH_n)
      rfsh_cyc <= 1'b0;

    // disable RFSH REQ
    if(~rfsh_req)
      rfsh_rdy <= 1'b1;
    else begin
      if(rfsh_rdy & rfsh_r & ~I_RFSH_n)
      begin
        // fall RFSH -> start
        rfsh_rdy <= 1'b0;
        rfsh_cyc <= 1'b1;
      end
    end
  end
end

////////////////////////////////////////////
// FDC access trap IRQ
////////////////////////////////////////////
reg [3:0] fd_acc_port;
reg fd_irq;
reg fd_acc1;

wire fd_iack = 1'b0;
wire fd_access = I_FDCS & (I_rd | I_wr);

// FDC resgister cs
always @(posedge I_clk)
begin
  if(I_reset)
  begin
    fd_irq  <= 1'b0;
    fd_acc1 <= 1'b0;
  end else begin
    fd_acc1 <= fd_access;
    if(fd_access)
      fd_acc_port <= {I_fa[2:0],I_rd};

    // IRQ 
    if(fd_acc1 & ~fd_access) fd_irq <= 1'b1;
    else if(fd_iack)         fd_irq <= 1'b0;
  end
end


/////////////////////////////////////
// FDC COMMAND WR TRAP IRQ
/////////////////////////////////////
reg [1:0] fdc_tarp_r;
assign fdc_irq = (fdc_tarp_r==2'b10); // access end

always @(posedge I_clk)
begin
  if(I_reset)
  begin
    fdc_tarp_r    <= 2'b00;
  end else
  begin
    if(fdc_ack)
    begin
      fdc_tarp_r <= 2'b00; // clear irq
    end else begin
      if( fdc_tarp_r != 2'b10)
        fdc_tarp_r <= {fdc_tarp_r[0],fd_cmd_wr};
    end
  end
end

/////////////////////////////////////
// Z80DMA WR TRAP IRQ
/////////////////////////////////////
reg [1:0] dma_tarp_r;

assign dma_rdy = ((I_DMA_RDY == dma_rdy_dir) | dma_rdy_frc) & dma_rdy_ena & (~rfsh_busy);
assign dma_irq = (dma_tarp_r==2'b10) | dma_rdy; // access end

wire dma_rw = I_DMA_CS & (I_rd | I_wr);
always @(posedge I_clk)
begin
  if(I_reset)
  begin
    dma_tarp_r    <= 2'b00;
  end else
  begin
    if(dma_ack)
    begin
      dma_tarp_r <= 2'b00; // clear irq
    end else begin
      if( dma_tarp_r != 2'b10)
        dma_tarp_r <= {dma_tarp_r[0],dma_rw};
    end
  end
end

/////////////////////////////////////
// CPU read data multiplex
/////////////////////////////////////
`ifdef SUB_ROM
// SPM1 > FDC Status > FDC reg / HOST RD
assign O_D   = (sub_ivec_cycle | ~fd_sts_cs) ? h_wram_rd[7:0] : fd_sts;
assign O_DOE = h_wram_cs;
`else
assign O_D   =
   fcs_pgm       ? f_dr :
   (sub_ivec_cycle | ~fd_sts_cs) ? h_wram_rd[7:0] : fd_sts;

assign O_DOE = h_wram_cs | fcs_pgm;
`endif

/****************************************************************************
 debug monitor
****************************************************************************/

// 7segment
assign num_7seg = OP7;
//assign dot_7seg = {O_TX_BSY,~O_RX_BSY,~O_INT_n,I_reset};
assign dot_7seg = {O_TX_BSY,~O_RX_BSY,fdc_drq,fd_sts[0]};

endmodule
