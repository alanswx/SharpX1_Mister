//***************************************************************************
//
// mr16c for X1
//
// IRQ source
//  No.1 = Internal Timer Overflow
//  No.2 = INT0 input
//  No.3 = INT1 input
//  No.4 = INT1 input
//  No.5 = INT1 input
//
//***************************************************************************

`define TIMER_MODULE // TIMER MODULE
//`define ADDR_DEPTH 10 // Memory size

module mr16_x1 #(parameter CLOCK_HZ = 32000000)
(
  I_RESET,I_CLK,I_CLKEN,
// Address Bus
  O_A,O_D,I_D,O_WR,O_MEMCS,
// Timer
 I_TMRG,
//GPIO periferal
  O_P0,O_P1,O_P2,O_P3,
  O_P4,O_P5,O_P6,O_P7,
  O_P8,O_P9,O_PA,O_PB,
  I_P0,I_P1,I_P2,I_P3,
  O_I4,O_I5,O_I6,O_I7,
  O_I8,O_I9,O_IA,O_IB,
  //Interrupt source
  I_INT,O_ACK
);
input I_RESET;
input I_CLK;
input I_CLKEN;

// Address Bus
output [15:0] O_A;
output [15:0] O_D;
input  [15:0] I_D;
output O_MEMCS;
output O_WR;

// Timer
input I_TMRG;

// GPIO
output [15:0] O_P0,O_P1,O_P2,O_P3;
output [15:0] O_P4,O_P5,O_P6,O_P7;
output [15:0] O_P8,O_P9,O_PA,O_PB;
input [15:0] I_P0,I_P1,I_P2,I_P3;
output O_I4,O_I5,O_I6,O_I7;
output O_I8,O_I9,O_IA,O_IB;

input [3:0] I_INT;
output [3:0] O_ACK;

//***************************************************************************
// core I/F
//***************************************************************************
reg  [3:0] vector;
wire iack;
wire [15:0] d_addr, d_in , d_out;
wire [1:0] d_wr;

mr16core #(4) cpu(
  .reset(I_RESET),
  .clk(I_CLK),
  .clk_en(I_CLKEN),
  .ivector(vector),
  .iack(iack),
  .d_addr(d_addr), .d_bus_in(d_in), .d_bus_out(d_out), .d_wr(d_wr)
);

//***************************************************************************
// address decoder
//***************************************************************************
wire mem16_cs = 1'b1;// I_CLKEN;
wire mem_cs  = mem16_cs & ~d_addr[13];                           // 0000-1fff
wire io_cs   = mem16_cs &  d_addr[13];                           // 2000-201f
wire tmr_cs  = mem16_cs &  d_addr[13] &  d_addr[4] & d_addr[3];  // 201c-201f

wire wr16 = d_wr[0];

//***************************************************************************
// memory I/O
//***************************************************************************
assign O_A     = d_addr;
assign O_D     = d_out;
assign O_WR    = d_wr[0];
assign O_MEMCS = mem_cs;

//***************************************************************************
// 16bit Timer Unit
//***************************************************************************

wire timer_ack;
wire timer_irq;

`ifdef TIMER_MODULE

timer #(.TIMER_WIDTH(16), .CLOCK_HZ(CLOCK_HZ)) timer (
  .I_RESET(I_RESET),
  .I_CLK(I_CLK),
  .I_GATE(I_TMRG),
  .I_A(d_addr[1]),
  .I_CS(tmr_cs),
  .I_WR(wr16),
  .I_D(d_out),
  .O_D(), // no readback
  .O_INT(timer_irq),
  .I_IACK(timer_ack)
);
`else
assign timer_irq = 1'b0;
`endif

//***************************************************************************
// GPIO
//***************************************************************************
reg [15:0] O_P0,O_P1,O_P2,O_P3;
reg [15:0] O_P4,O_P5,O_P6,O_P7;
reg [15:0] O_P8,O_P9,O_PA,O_PB;
reg O_I4,O_I5,O_I6,O_I7;
reg O_I8,O_I9,O_IA,O_IB;

reg [15:0] gpio_in_mux;

always @(posedge I_CLK or posedge I_RESET)
begin
  if(I_RESET)
  begin
    gpio_in_mux <= 16'h0000;
    O_P0        <= 16'h0000;
    O_P1        <= 16'h0000;
    O_P2        <= 16'h0000;
    O_P3        <= 16'h0000;
    O_P4        <= 16'h0000;
    O_P5        <= 16'h0000;
    O_P6        <= 16'h0000;
    O_P7        <= 16'h0000;
    O_P8        <= 16'h0000;
    O_P9        <= 16'h0000;
    O_PA        <= 16'h0000;
    O_PB        <= 16'h0000;
    O_I4        <= 1'b0;
    O_I5        <= 1'b0;
    O_I6        <= 1'b0;
    O_I7        <= 1'b0;
    O_I8        <= 1'b0;
    O_I9        <= 1'b0;
    O_IA        <= 1'b0;
    O_IB        <= 1'b0;
  end else begin
    // IN ack signal
    O_I4 <= io_cs & ~wr16 & (d_addr[4:1]==4'b0100);
    O_I5 <= io_cs & ~wr16 & (d_addr[4:1]==4'b0101);
    O_I6 <= io_cs & ~wr16 & (d_addr[4:1]==4'b0110);
    O_I7 <= io_cs & ~wr16 & (d_addr[4:1]==4'b0111);
    O_I8 <= io_cs & ~wr16 & (d_addr[4:1]==4'b1000);
    O_I9 <= io_cs & ~wr16 & (d_addr[4:1]==4'b1001);
    O_IA <= io_cs & ~wr16 & (d_addr[4:1]==4'b1010);
    O_IB <= io_cs & ~wr16 & (d_addr[4:1]==4'b1011);
    // OUT port
    if(io_cs & wr16)
    begin
      case(d_addr[4:1])
      4'b0000: O_P0  <= d_out;
      4'b0001: O_P1  <= d_out;
      4'b0010: O_P2  <= d_out;
      4'b0011: O_P3  <= d_out;
      4'b0100: O_P4  <= d_out;
      4'b0101: O_P5  <= d_out;
      4'b0110: O_P6  <= d_out;
      4'b0111: O_P7  <= d_out;
      4'b1000: O_P8  <= d_out;
      4'b1001: O_P9  <= d_out;
      4'b1010: O_PA  <= d_out;
      4'b1011: O_PB  <= d_out;
      endcase
    end
    // inport mux
    gpio_in_mux <= d_addr[2:1]==2'b11 ? I_P3 :
                   d_addr[2:1]==2'b10 ? I_P2 :
                   d_addr[2:1]==2'b01 ? I_P1 : I_P0;
  end
end

//***************************************************************************
// interrupt
//***************************************************************************
`define VECTOR_TIMER (16'h0002)
`define VECTOR_INT0  (16'h0004)
`define VECTOR_INT1  (16'h0006)
`define VECTOR_INT2  (16'h0008)
`define VECTOR_INT3  (16'h000A)

always @(posedge I_CLK)
begin
  if(I_CLKEN)
  begin
    vector <= 4'b0000;
    // lowest
    if(I_INT[3])  vector <= `VECTOR_INT3/2;
    if(I_INT[2])  vector <= `VECTOR_INT2/2;
    if(timer_irq) vector <= `VECTOR_TIMER/2;
    if(I_INT[1])  vector <= `VECTOR_INT1/2;
    if(I_INT[0])  vector <= `VECTOR_INT0/2;
     // highest
  end
end

assign O_ACK[0]  = (vector == `VECTOR_INT0/2) & iack;
assign O_ACK[1]  = (vector == `VECTOR_INT1/2) & iack;
assign timer_ack = (vector == `VECTOR_TIMER/2) & iack;
assign O_ACK[2]  = (vector == `VECTOR_INT2/2) & iack;
assign O_ACK[3]  = (vector == `VECTOR_INT3/2) & iack;

//***************************************************************************
// data input mux
//***************************************************************************

reg mem_cs_r;
always @(posedge I_CLK)
  mem_cs_r <= mem_cs;

mux_2 #(16) top_din_mux(
.I0(gpio_in_mux), // GPIO
.I1(I_D),      // memory
.S(mem_cs_r),.O(d_in));

endmodule

//***************************************************************************
// n bit timer module
//
// +----+-----+------+---+---+---+---+
// |I_A | R/W |b15..4|b3 |b2 |b1 |b0 |
// +----+-----+------+---+---+---+---+
// | 0  | WR  |   timer interval     |
// | 1  | WR  | ---  |RST|IEN|RUN|IRQ|
// | x  | RD  |   timer counter      |
// +----+-----+------+---+---+---+---+
//  RST: reset timer counter
//  IEN: interrupt enable
//  RUN: count enable
//  IRQ: interruput request (auto clear)
//
//  if timer==0     then timer reload and set IRQ
//  if I_GATE==1'b1 then timer--;
//
//***************************************************************************
module timer(I_RESET,I_CLK,I_GATE,I_A,I_CS,I_WR,I_D,O_D,O_INT,I_IACK);

parameter TIMER_WIDTH = 16;
parameter CLOCK_HZ = 32000000;

input I_RESET;
input I_CLK;
input I_GATE;
input I_A;
input I_CS;
input I_WR;
input [TIMER_WIDTH-1:0]  I_D;
output [TIMER_WIDTH-1:0] O_D;
output O_INT;
input I_IACK;

reg [TIMER_WIDTH-1:0] timer_cnt , timer_int;
reg [2:0] timer_ctrl; // bit0=IRQ,1=RUN,2=INT EN,3=reset counter

// Firmware timer counts are in 32 MHz units, independent of the master rate.
// Supported machine clocks are 16..32 MHz, requiring one or two virtual ticks.
// Carry overshoot across reloads so a fractional tick is not lost each period.
// All supported clock/rate values are divisible by four; omit constant low
// accumulator bits rather than leave reset-only storage for synthesis.
localparam [23:0] CLOCK_UNITS = CLOCK_HZ / 4;
localparam [23:0] EXTRA_UNITS = (32000000 - CLOCK_HZ) / 4;
localparam [23:0] EXTRA_THRESHOLD = CLOCK_UNITS - EXTRA_UNITS;
wire [23:0] tick_phase;
wire extra_tick = EXTRA_UNITS != 0 && tick_phase >= EXTRA_THRESHOLD;
generate
    if (CLOCK_HZ == 32000000) begin : native_timer_rate
        assign tick_phase = 24'd0;
    end else begin : fractional_timer_rate
        reg [23:0] phase;
        assign tick_phase = phase;
        always @(posedge I_CLK or posedge I_RESET)
            if (I_RESET) phase <= 0;
            else phase <= extra_tick ? phase + EXTRA_UNITS - CLOCK_UNITS
                                     : phase + EXTRA_UNITS;
    end
endgenerate
wire timer_run = timer_ctrl[1] && I_GATE;
wire [TIMER_WIDTH-1:0] timer_step = timer_run ? (extra_tick ? 2 : 1) : 0;
wire [TIMER_WIDTH-1:0] next_timer = timer_cnt - timer_step;
wire timer_overflow = ~timer_cnt[TIMER_WIDTH-1] & next_timer[TIMER_WIDTH-1];
wire timer_ctr_load = (I_CS & I_WR &  I_A);
wire timer_int_load = (I_CS & I_WR & ~I_A);
wire timer_cnt_load = (timer_ctr_load & I_D[3]) | timer_overflow;
wire [TIMER_WIDTH-1:0] reload_timer =
    timer_overflow && extra_tick && timer_cnt == 0 && timer_int != 0
    && !(timer_ctr_load && I_D[3]) ? timer_int - 1'b1 : timer_int;

always @(posedge I_CLK or posedge I_RESET)
begin
  if(I_RESET)
  begin
    timer_cnt <= {TIMER_WIDTH{1'b0}};
    timer_int <= {TIMER_WIDTH{1'b0}};
    timer_ctrl <= 3'b000;
  end else begin

    // timer reload / countup
    timer_cnt <= timer_cnt_load ? reload_timer : next_timer;

    // interval register
    if(timer_int_load)
      timer_int  <= I_D[TIMER_WIDTH-1:0];

    // vector auto clear
    if(I_IACK)
      timer_ctrl[0] <= 1'b0;
    else if(timer_overflow)
      timer_ctrl[0] <= timer_ctrl[2]; // IRQ EN

    // ctrl load
    if(timer_ctr_load)
      timer_ctrl <= I_D[2:0];
  end
end

// interrupt output
assign O_INT = timer_ctrl[0];
assign O_D   = 16'h00;//timer_cnt;

endmodule
