//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = TURBO_FM_PROFILE;
assign AUDIO_L = TURBO_FM_PROFILE ? machine_audio_left : machine_audio;
assign AUDIO_R = TURBO_FM_PROFILE ? machine_audio_right : machine_audio;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 13'd4 : ({11'd0, ar} - 13'd1);
assign VIDEO_ARY = (!ar) ? 13'd3 : 13'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"SharpX1;;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"F0,ROM,Load IPL;",
`ifdef X1_TURBO_FOUNDATION
	"F4,X1,Load 16-row ANK;",
`endif
	"S0,D88,Drive A;",
	"S1,D88,Drive B;",
	"O[1],Disk writes,Protected,Enabled;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

wire        ioctl_download;
wire [15:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire ps2_clk, ps2_data;
wire [31:0] joy0, joy1;
wire [7:0] joya_n, joyb_n;
x1_joystick_map joya_map (.joystick(joy0), .pins_n(joya_n));
x1_joystick_map joyb_map (.joystick(joy1), .pins_n(joyb_n));
wire [31:0] sd_lba[2];
wire [7:0] sd_buff_din[2];
wire [1:0] sd_rd, sd_wr, sd_ack;
wire sd_buff_wr;
wire fdc_sd_rd, fdc_sd_wr, fdc_sd_drive;
wire [31:0] fdc_sd_lba;
wire [7:0] fdc_sd_din;
assign sd_lba[0] = fdc_sd_lba;
assign sd_lba[1] = fdc_sd_lba;
assign sd_buff_din[0] = fdc_sd_din;
assign sd_buff_din[1] = fdc_sd_din;
assign sd_rd = fdc_sd_rd ? (fdc_sd_drive ? 2'b10 : 2'b01) : 2'b00;
assign sd_wr = fdc_sd_wr ? (fdc_sd_drive ? 2'b10 : 2'b01) : 2'b00;
wire [13:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [1:0] img_mounted;
wire img_readonly;
wire [63:0] img_size;
reg [1:0] media_present = 0;
reg [1:0] media_readonly = 2'b11;
reg [23:0] media_size [0:1];
initial begin media_size[0] = 0; media_size[1] = 0; end
always @(posedge clk_sys) begin
	for(integer d = 0; d < 2; d = d + 1) if(img_mounted[d]) begin
		media_present[d] <= img_size != 0 && img_size <= 64'd1048575;
		media_size[d] <= img_size[23:0];
		media_readonly[d] <= img_readonly;
	end
end

hps_io #(.CONF_STR(CONF_STR), .PS2DIV(1600), .VDNUM(2), .VIDEO_CDC(TURBO_VIDEO_MASTER)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	//ioctl
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_upload_req(1'b0), .ioctl_upload_index(8'd0),
	.ioctl_din(8'd0), .ioctl_wait(machine_ioctl_wait),

	.buttons(buttons),
	.status(status),
	.status_menumask(16'd0), .status_in(128'd0), .status_set(1'b0),
	.info_req(1'b0), .info(8'd0), .video_rotated(1'b0), .new_vmode(1'b0),
	.joystick_0(joy0), .joystick_1(joy1),
	.joystick_0_rumble(16'd0), .joystick_1_rumble(16'd0),
	.joystick_2_rumble(16'd0), .joystick_3_rumble(16'd0),
	.joystick_4_rumble(16'd0), .joystick_5_rumble(16'd0),
	.ps2_kbd_clk_out(ps2_clk), .ps2_kbd_data_out(ps2_data),
	.ps2_kbd_clk_in(1'b1), .ps2_kbd_data_in(1'b1),
	.ps2_kbd_led_status(3'd0), .ps2_kbd_led_use(3'd0),
	.ps2_mouse_clk_in(1'b1), .ps2_mouse_data_in(1'b1),
	.img_mounted(img_mounted), .img_readonly(img_readonly), .img_size(img_size),
	.sd_lba(sd_lba), .sd_blk_cnt('{6'd0,6'd0}), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din), .sd_buff_wr(sd_buff_wr),
	
	.ps2_key(ps2_key)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys, clk_28636, clk_sys_pll, legacy_video_pll;
wire turbo_video_locked;
`ifdef X1_TURBO_VIDEO_MASTER
localparam TURBO_VIDEO_MASTER = 1;
x1_turbo_video_pll turbo_video_pll(.refclk(CLK_50M), .video_clk(clk_28636), .locked(turbo_video_locked));
`else
localparam TURBO_VIDEO_MASTER = 0;
assign clk_28636 = legacy_video_pll;
assign turbo_video_locked = 1'b1;
`endif
`ifdef X1_SINGLE_CLOCK
// Opt-in experiment uses the existing video's actual PLL frequency.
assign clk_sys = clk_28636;
localparam SINGLE_CLOCK = 1;
localparam MASTER_HZ = 28571428;
`else
assign clk_sys = clk_sys_pll;
localparam SINGLE_CLOCK = 0;
localparam MASTER_HZ = 28636364;
`endif
pll pll
(
	.refclk(CLK_50M),
	.rst(1'b0),
	.outclk_0(clk_sys_pll),   // 32 MHz baseline; unused in one-clock mode.
	.outclk_1(legacy_video_pll)  // Checked-in PLL: 28.571428 MHz; unchanged old profiles.
);

wire reset = RESET | status[0] | buttons[1] | ioctl_download | !turbo_video_locked;

//////////////////////////////////////////////////////////////////

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [7:0] video;
wire [11:0] machine_rgb12;
wire [15:0] machine_audio;
wire signed [15:0] machine_audio_left,machine_audio_right;
wire machine_ioctl_wait;
`ifdef X1_TURBO_FOUNDATION
localparam TURBO_FOUNDATION = 1;
`else
localparam TURBO_FOUNDATION = 0;
`endif
`ifdef X1_TURBO_FM_CPU
localparam TURBO_FM_PROFILE = 1;
initial if (!TURBO_FOUNDATION) $error("FM board experiment requires Turbo foundation");
`else
localparam TURBO_FM_PROFILE = 0;
`endif
// Default-off combined analog-video qualification, not a native Z identity.
`ifdef X1_TURBO_Z_VIDEO_EXPERIMENT
localparam TURBO_Z_VIDEO_PROFILE = 1;
initial begin
	if (!TURBO_FOUNDATION || !TURBO_VIDEO_MASTER || SINGLE_CLOCK)
		$error("Z video board experiment requires independent X3 Turbo video");
end
`else
localparam TURBO_Z_VIDEO_PROFILE = 0;
`endif
// Separate hardware qualification profile; inherited board revisions stay off.
`ifdef X1_TURBO_DMA_RESTART
localparam TURBO_DMA_PROFILE = 1;
initial begin
	if (!TURBO_FOUNDATION || !SINGLE_CLOCK || TURBO_VIDEO_MASTER)
		$error("DMA restart board profile requires single-clock Turbo foundation");
end
`else
localparam TURBO_DMA_PROFILE = 0;
`endif

sharpx1 #(.SINGLE_CLOCK(SINGLE_CLOCK), .MASTER_HZ(MASTER_HZ), .TURBO(TURBO_FOUNDATION), .TURBO_VIDEO_MASTER(TURBO_VIDEO_MASTER),
	.TURBO_DMA(TURBO_DMA_PROFILE), .TURBO_DMA_IRQ(TURBO_DMA_PROFILE), .TURBO_DMA_RESTART_IRQ(TURBO_DMA_PROFILE), .TURBO_FM_CPU(TURBO_FM_PROFILE),
	.TURBO_Z_PALETTE_CPU(TURBO_Z_VIDEO_PROFILE), .TURBO_Z_VIDEO(TURBO_Z_VIDEO_PROFILE),
	.TURBO_Z_MULTIMODE(TURBO_Z_VIDEO_PROFILE), .TURBO_Z_INTERNAL8(TURBO_Z_VIDEO_PROFILE),
	.TURBO_Z_TEXT_CPU(TURBO_Z_VIDEO_PROFILE)) sharpx1
(
	.clk_sys(clk_sys),
	.clk_28636(clk_28636),
	.reset(reset),

	.pal(1'b0),
	.scandouble(forced_scandoubler),
	.ce_pix(ce_pix),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index[7:0]),
	.ioctl_wr(ioctl_wr && ((ioctl_index == 0 && ioctl_addr < (TURBO_FOUNDATION ? 27'd32768 : 27'd4096)) || (TURBO_FOUNDATION && ioctl_index == 4))),
	.ioctl_addr(ioctl_index == 4 && ioctl_addr >= 27'd4096 ? 25'h1ffffff : ioctl_addr[24:0]),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(machine_ioctl_wait),
	.ps2_clk_in(ps2_clk), .ps2_data_in(ps2_data),
	.sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),
	.sio_rxd(2'b11),.sio_cts_n(2'b11),.sio_dcd_n(2'b11),
	.sio_txd(),.sio_rts_n(),.sio_dtr_n(),
	.joya_n(joya_n), .joyb_n(joyb_n),
	.disk_ready(media_present[0]), .img_mounted(img_mounted[0]),
	.disk_wp(!status[1] || media_readonly[0]), .img_size(media_size[0]),
	.disk_ready_b(media_present[1]), .img_mounted_b(img_mounted[1]),
	.disk_wp_b(!status[1] || media_readonly[1]), .img_size_b(media_size[1]),
	.sd_drive(fdc_sd_drive), .sd_lba(fdc_sd_lba), .sd_rd(fdc_sd_rd), .sd_wr(fdc_sd_wr), .sd_ack(sd_ack[fdc_sd_drive]),
	.sd_buff_addr(sd_buff_addr[8:0]), .sd_buff_dout(sd_buff_dout),
	.sd_buff_din(fdc_sd_din), .sd_buff_wr(sd_buff_wr),

	.HBlank(HBlank),
	.HSync(HSync),
	.VBlank(VBlank),
	.VSync(VSync),

	.video(video), .rgb(), .rgb12(machine_rgb12), .audio(machine_audio),
	.audio_left(machine_audio_left), .audio_right(machine_audio_right), .audio_mono(), .audio_sample()
);

assign CLK_VIDEO = clk_28636;
assign CE_PIXEL = ce_pix;

assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;
assign VGA_R  = {2{machine_rgb12[11:8]}};
assign VGA_G  = {2{machine_rgb12[7:4]}};
assign VGA_B  = {2{machine_rgb12[3:0]}};

assign LED_USER = ioctl_download | (|sd_rd) | (|sd_wr);

endmodule
