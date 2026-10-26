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
// DDR backing is owned by the explicit external-font machine profile.

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

wire [1:0] ar = cfg[122:121];
wire high_scan;

// Original: the picture a monitor shows. 24 kHz (640x400, 448 of 24.86 kHz
// lines, the PC-98 standard) is 4:3. 15 kHz shows 200 of 258 lines and 640
// of 896 dots: within a TV-standard visible area (52.7 of 63.6 us, 236 of
// 258 lines) that is 0.862 of the width and 0.848 of the height, 1.36:1
// (19:14), slightly wider than 4:3.
assign VIDEO_ARX = (!ar) ? (high_scan ? 13'd4 : 13'd19) : ({11'd0, ar} - 13'd1);
assign VIDEO_ARY = (!ar) ? (high_scan ? 13'd3 : 13'd14) : 13'd0;

`include "build_id.v" 
// Keep any J/j joystick entries LAST in CONF_STR (after V); earlier entries
// can break MiSTer's OSD parsing. Checked by test-osd-config.
// Layout follows the computer-core OSD standard: media first (MGL f/s items
// must name top-page rows), then Machine/Video/Advanced pages; settings take
// effect at the next reset (cfg), "Changes pending" shows until then.
localparam CONF_STR = {
	"SharpX1;;",
	"-;",
	// One entry per drive. Main reports the extension's list position in
	// ioctl_index[7:6] before each mount: 0 = D88 container, 1 = raw X1 2D.
	"SC0,D882D ,Pri. Drive A;",
	"SC1,D882D ,Drive B;",
`ifdef X1_CASSETTE
	// 4-192 kHz TAP waveform images; each mount starts rewound. Not
	// remembered (no C): a core start begins with no tape.
	"S2,TAP,Tape;",
`endif
`ifdef X1_TURBO_FOUNDATION
	// MGLs load the ANK font (f index 4): it must stay on the top page.
	"F4,X1,Load 16-row ANK;",
`endif
	"F0,ROM,Load ROM;",
	"-;",
	"P1,Machine;",
	"P2,Video;",
	"P5,Advanced;",
	"-;",
	"h0-,Changes pending;",
	"R[0],Apply and reset;",

`ifdef X1_TURBO_FOUNDATION
	// X1 Turbo Z additionally decodes the Z palette/mode registers; it is the
	// default (value 0) because Turbo software runs unchanged on it.
`ifdef X1_TURBO_Z_VIDEO_EXPERIMENT
	"P1O[7:6],Model,X1 Turbo Z,X1,X1 Turbo;",
`else
	"P1O[7:6],Model,X1 Turbo,X1;",
`endif
`endif
`ifdef X1_CASSETTE
	// 5x: while the deck plays, the CPU and the tape run five times faster.
	// Quick start: a TAP whose first program is machine code boots from it
	// at once (x1_tape_quickload, offered to the IPL as a ROM cartridge);
	// the rest of the tape then plays at 5x. O[9] (old Fast tape) is unused.
	"P1O[12:11],Tape speed,5x + quick start,5x,Normal;",
	"P1-;",
	"P1T[2],Rewind tape;",
`endif

`ifdef X1_TURBO_FOUNDATION
	// Turbo DIP 1FF0 bit 0 is the monitor type (CSP `monitor_type`): 0 =
	// high-resolution 24 kHz, read by the IPL and Turbo BASIC at start.
	// Standard is the default (as MAME): X1 software reprograms the CRTC for
	// 15 kHz but leaves the IPL's 24 kHz scan bit (1FD0) set, which breaks
	// its display. The X1 model has no DIP switches, so the row is hidden
	// there. Main parses H/h before the page prefix.
	"H1P2O[8],Monitor,Standard,High-res;",
	"h1P2-;",
`endif
	"P2O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
`ifdef X1_CASSETTE
	"P2O[10],Tape overlay,On,Off;",
`endif

`ifdef X1_TURBO_FOUNDATION
	// Turbo DIP 1FF0 boot device (MAME F1/F3/F5/FF).
	"H1P5O[5:4],Boot device,2D,2DD,2HD,SASI;",
	"h1P5-;",
`endif
	"P5O[1],Disk writes,Protected,Enabled;",
	// Firmware loads (normally boot1-3.rom at core start) live here.
	"P5-;",
`ifdef X1_TURBO_FOUNDATION
	// X1 mode boots the index-3 X1 IPL (F3 or boot2.rom) when loaded, else
	// the main IPL's 4 KiB.
	"P5F3,ROM,Load X1 IPL;",
`endif
`ifdef X1_TURBO_Z_EXTERNAL_FONT
	"P5F5,ROM,Load Kanji font;",
`endif
`ifdef X1_CASSETTE
	// The deck controller also loads as boot1.rom (index 0x40).
	"P5F6,BIN,Load tape ctrl.;",
`endif

`ifdef X1_CASSETTE
	"I,Tape ready (rewound),Tape format not supported;",
`endif
	// v1: Model and Monitor value lists reordered (October 23, 2026);
	// v2: Monitor back to Standard first.
	"v,2;",
	"V,v",`BUILD_DATE,
	// x1_joystick_map routes MiSTer bits 4/5 to the X1 PSG trigger A/B pins.
	";J,Trigger A,Trigger B;",
	"jn,A,B;"
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
// OSD settings latched at reset; see the CONF_STR note.
reg  [127:0] cfg = 128'd0;
// User/host reset (latches cfg); quick start may also reset the machine.
wire reset;
wire osd_pending, osd_no_dip;
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
`ifdef X1_CASSETTE
localparam CASSETTE_PROFILE = 1;
`else
localparam CASSETTE_PROFILE = 0;
`endif
localparam VDNUM = CASSETTE_PROFILE ? 3 : 2;
wire [31:0] sd_lba[VDNUM];
wire [7:0] sd_buff_din[VDNUM];
wire [VDNUM-1:0] sd_rd, sd_wr, sd_ack;
wire sd_buff_wr;
wire fdc_sd_rd, fdc_sd_wr, fdc_sd_drive;
wire [31:0] fdc_sd_lba;
wire [7:0] fdc_sd_din;
assign sd_lba[0] = fdc_sd_lba;
assign sd_lba[1] = fdc_sd_lba;
assign sd_buff_din[0] = fdc_sd_din;
assign sd_buff_din[1] = fdc_sd_din;
reg tape_info_req = 0;
reg [7:0] tape_info = 0;
wire [5:0] sd_blk_cnt[VDNUM];
genvar sd_v;
generate for (sd_v = 0; sd_v < VDNUM; sd_v = sd_v + 1) begin : sd_single_block
	assign sd_blk_cnt[sd_v] = 6'd0;
end endgenerate
assign sd_rd[1:0] = fdc_sd_rd ? (fdc_sd_drive ? 2'b10 : 2'b01) : 2'b00;
assign sd_wr[1:0] = fdc_sd_wr ? (fdc_sd_drive ? 2'b10 : 2'b01) : 2'b00;
wire [13:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [VDNUM-1:0] img_mounted;
wire img_readonly;
wire [63:0] img_size;
reg [1:0] media_present = 0;
reg [1:0] media_readonly = 2'b11;
reg [1:0] media_raw = 0;
reg [23:0] media_size [0:1];
initial begin media_size[0] = 0; media_size[1] = 0; end
always @(posedge clk_sys) begin
	for(integer d = 0; d < 2; d = d + 1) if(img_mounted[d]) begin
		media_present[d] <= img_size != 0 && img_size <= 64'd1048575;
		media_size[d] <= img_size[23:0];
		media_readonly[d] <= img_readonly;
		media_raw[d] <= ioctl_index[7:6] == 2'd1;
	end
end

hps_io #(.CONF_STR(CONF_STR), .PS2DIV(1600), .VDNUM(VDNUM), .VIDEO_CDC(TURBO_VIDEO_MASTER)) hps_io
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
	.status_menumask({14'd0, osd_no_dip, osd_pending}), .status_in(128'd0), .status_set(1'b0),
	.info_req(tape_info_req), .info(tape_info), .video_rotated(1'b0), .new_vmode(1'b0),
	.joystick_0(joy0), .joystick_1(joy1),
	.joystick_0_rumble(16'd0), .joystick_1_rumble(16'd0),
	.joystick_2_rumble(16'd0), .joystick_3_rumble(16'd0),
	.joystick_4_rumble(16'd0), .joystick_5_rumble(16'd0),
	.ps2_kbd_clk_out(ps2_clk), .ps2_kbd_data_out(ps2_data),
	.ps2_kbd_clk_in(1'b1), .ps2_kbd_data_in(1'b1),
	.ps2_kbd_led_status(3'd0), .ps2_kbd_led_use(3'd0),
	.ps2_mouse_clk_in(1'b1), .ps2_mouse_data_in(1'b1),
	.img_mounted(img_mounted), .img_readonly(img_readonly), .img_size(img_size),
	.sd_lba(sd_lba), .sd_blk_cnt(sd_blk_cnt), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din), .sd_buff_wr(sd_buff_wr),
	
	.ps2_key(ps2_key)
);

// Read-only tape slot (S2). Mounts survive machine reset; the deck itself
// is the machine's x1_cassette_transport.
wire tape_mount, tape_present, tape_empty;
wire tape_sample_valid, tape_sample_level, tape_sample_last, tape_sample_ready;
// Tape speed (cfg[12:11]): 0 = 5x + quick start, 1 = 5x, 2 = Normal.
wire tape_fast = cfg[12:11] != 2'd2;
wire tape_quick = cfg[12:11] == 2'd0;
// Quick start's ROM port and reset request (x1_tape_quickload).
wire [23:0] cart_addr;
wire cart_read, cart_ready, quick_reset;
wire [7:0] cart_data;
wire tape_underflow, tape_turbo_active;
wire [17:0] tape_sample_hz;
wire [7:0] tape_mode, tape_sensor;
wire tape_loaded, tape_rejected;
wire [31:0] tape_position, tape_length;
wire [41:0] tape_status_word;
wire tape_status_req, tape_status_ack;
generate if (CASSETTE_PROFILE) begin : tape_slot
	// One OSD info message per mount outcome (CONF_STR I entries 1/2).
	reg old_loaded = 0, old_rejected = 0, old_rewind = 0;
	always @(posedge clk_sys) old_rewind <= status[2];
	always @(posedge clk_sys) begin
		old_loaded <= tape_loaded;
		old_rejected <= tape_rejected;
		tape_info_req <= 0;
		if (tape_loaded && !old_loaded) begin tape_info <= 8'd1; tape_info_req <= 1; end
		if (tape_rejected && !old_rejected) begin tape_info <= 8'd2; tape_info_req <= 1; end
	end
	assign sd_wr[2] = 1'b0;
	assign sd_buff_din[2] = 8'hff;
	reg tape_inserted = 0;
	always @(posedge clk_sys) if (img_mounted[2]) tape_inserted <= img_size != 0;
	wire osd_rewind = status[2] && !old_rewind;
	wire stream_mount, stream_present, stream_empty, stream_ready, quick_rewind;
	x1_tap_sd_stream #(.MIN_HZ(4000), .MAX_HZ(192000)) tap_stream (
		.clk(clk_sys), .reset(!turbo_video_locked),
		.img_mounted(img_mounted[2]), .rewind(osd_rewind || quick_rewind), .img_size(img_size),
		.sd_lba(sd_lba[2]), .sd_rd(sd_rd[2]), .sd_ack(sd_ack[2]),
		.sd_buff_addr(sd_buff_addr[8:0]), .sd_buff_dout(sd_buff_dout), .sd_buff_wr(sd_buff_wr),
		.tape_mount(stream_mount), .tape_present(stream_present), .tape_empty(stream_empty),
		.sample_valid(tape_sample_valid), .sample_level(tape_sample_level),
		.sample_last(tape_sample_last), .sample_ready(stream_ready), .sample_hz(tape_sample_hz),
		.loaded(tape_loaded), .rejected(tape_rejected), .position(tape_position), .length(tape_length)
	);
	// Quick start sits between the stream and the deck. A newer drive A disk
	// or an eject disarms it; a user reset boots the eligible tape again.
	x1_tape_quickload tape_quickload (
		.clk(clk_sys), .reset(!turbo_video_locked), .enable(tape_quick),
		.tape_insert((img_mounted[2] && img_size != 0) || (osd_rewind && tape_inserted)),
		.disarm((img_mounted[2] && img_size == 0) || (img_mounted[0] && img_size != 0)),
		.rearm(reset),
		.stream_rewind(quick_rewind), .stream_mount(stream_mount), .stream_present(stream_present),
		.stream_empty(stream_empty), .stream_valid(tape_sample_valid), .stream_level(tape_sample_level),
		.stream_last(tape_sample_last), .stream_rejected(tape_rejected), .stream_ready(stream_ready),
		.stream_hz(tape_sample_hz),
		.deck_ready(tape_sample_ready), .deck_mount(tape_mount), .deck_present(tape_present), .deck_empty(tape_empty),
		.cart_addr(cart_addr), .cart_read(cart_read), .cart_data(cart_data), .cart_ready(cart_ready),
		.reset_request(quick_reset), .busy()
	);
	x1_tape_status tape_status (
		.clk(clk_sys), .loaded(tape_loaded), .playing(tape_mode == 8'd2),
		.fast(tape_turbo_active),
		.position(tape_position), .length(tape_length), .hz(tape_sample_hz),
		.status(tape_status_word), .req(tape_status_req), .ack(tape_status_ack)
	);
end else begin : no_tape_slot
	assign tape_status_word = 0;
	assign tape_status_req = 0;
	assign {tape_loaded, tape_rejected} = 2'b00;
	assign {tape_mount, tape_present, tape_empty} = 3'b000;
	assign {cart_ready, cart_data, quick_reset} = {1'b1, 8'hff, 1'b0};
	assign {tape_sample_valid, tape_sample_level, tape_sample_last} = 3'b000;
	assign tape_sample_hz = 18'd8000;
end endgenerate

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
// Opt-in experiment uses the existing video's actual PLL frequency. With X3
// the master is the X3 PLL (fitted 42,954,545.45 Hz); enables use the
// nominal 42,954,540 Hz divisible by four, a 0.13 ppm rate difference.
assign clk_sys = clk_28636;
localparam SINGLE_CLOCK = 1;
localparam MASTER_HZ = TURBO_VIDEO_MASTER ? 42954540 : 28571428;
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

assign reset = RESET | status[0] | buttons[1] | ioctl_download | !turbo_video_locked;
// The settings the machine runs with, taken from the OSD at every reset
// (Apply and reset, the board's reset, a download, a core reload).
always @(posedge clk_sys) if (reset) cfg <= status;
// "Changes pending": a setting differs from the running one (not reset or
// the Rewind tape button).
assign osd_pending = {status[1], status[12:4], status[122:121]} != {cfg[1], cfg[12:4], cfg[122:121]};
// Monitor and Boot device rows do not apply to the X1 model (no DIP switches).
assign osd_no_dip = TURBO_FOUNDATION && status[7:6] == 2'd1;

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
	if (!TURBO_FOUNDATION || !TURBO_VIDEO_MASTER)
		$error("Z video board experiment requires X3 Turbo video");
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
`elsif X1_TURBO_DMA_FONT
// DMA (completion/restart IRQ) on the X3 external-font core, with the
// explicit DMA/Kanji shared-bus profile; FM and its CTC stay enabled.
localparam TURBO_DMA_PROFILE = 1;
`ifndef X1_TURBO_Z_EXTERNAL_FONT
initial $error("X3 font DMA profile requires the external-font revision");
`endif
`else
localparam TURBO_DMA_PROFILE = 0;
`endif

`ifdef X1_TURBO_Z_EXTERNAL_FONT
localparam TURBO_Z_EXTERNAL_FONT_PROFILE = 1;
`ifdef MISTER_FB
initial $error("External-font DDR reservation excludes framebuffer builds");
`endif
`else
localparam TURBO_Z_EXTERNAL_FONT_PROFILE = 0;
`endif

// Main loads boot1.rom as index 0x40 at core start; MGL may use index 6.
wire cassette_controller_index = CASSETTE_PROFILE && (ioctl_index == 16'd6 || ioctl_index == 16'h0040);
// Boot device -> raw DIP: SW bits 3:1 = 000 2D, 001 2DD, 010 2HD, 111 SASI;
// bit 0 = 1 standard (OSD default), 0 high-resolution monitor.
wire [7:0] boot_dsw = {4'hf, cfg[5:4] == 2'd3 ? 3'b111 : {1'b0, cfg[5:4]}, !cfg[8]};
// Main loads boot2.rom as index 0x80: the X1 IPL slot (index 3).
wire x1_ipl_index = TURBO_FOUNDATION && (ioctl_index == 16'd3 || ioctl_index == 16'h0080);
// Main loads boot3.rom as index 0xC0: the physical Kanji font slot (index 5).
wire kanji_font_index = TURBO_Z_EXTERNAL_FONT_PROFILE && (ioctl_index == 16'd5 || ioctl_index == 16'h00c0);

// Boards start with CAPS LOCK released, like MAME and real keyboards.
sharpx1 #(.TURBO_DSW_RUNTIME(1), .TURBO_Z_RUNTIME(TURBO_Z_VIDEO_PROFILE), .RAW_2D_MEDIA(1), .FDC_DEFER_COMMAND(1), .SUB_CAPS_OFF(1), .SUB_JOY_OFF(1), .CASSETTE_ENABLE(CASSETTE_PROFILE), .CASSETTE_RUNTIME_RATE(CASSETTE_PROFILE), .CART_PORT(CASSETTE_PROFILE), .SINGLE_CLOCK(SINGLE_CLOCK), .MASTER_HZ(MASTER_HZ), .TURBO(TURBO_FOUNDATION), .TURBO_VIDEO_MASTER(TURBO_VIDEO_MASTER),
	.TURBO_DMA(TURBO_DMA_PROFILE), .TURBO_DMA_IRQ(TURBO_DMA_PROFILE), .TURBO_DMA_RESTART_IRQ(TURBO_DMA_PROFILE), .TURBO_FM_CPU(TURBO_FM_PROFILE), .TURBO_FM_CTC(TURBO_FM_PROFILE),
	.TURBO_DMA_KANJI_EXPERIMENT(TURBO_DMA_PROFILE && TURBO_Z_EXTERNAL_FONT_PROFILE),
	.TURBO_Z_PALETTE_CPU(TURBO_Z_VIDEO_PROFILE), .TURBO_Z_VIDEO(TURBO_Z_VIDEO_PROFILE),
	.TURBO_Z_MULTIMODE(TURBO_Z_VIDEO_PROFILE), .TURBO_Z_INTERNAL8(TURBO_Z_VIDEO_PROFILE),
	.TURBO_Z_TEXT_CPU(TURBO_Z_VIDEO_PROFILE),
    .TURBO_KANJI(TURBO_Z_EXTERNAL_FONT_PROFILE), .TURBO_KANJI_RENDER(TURBO_Z_EXTERNAL_FONT_PROFILE),
    .TURBO_Z_KANJI(TURBO_Z_EXTERNAL_FONT_PROFILE), .TURBO_Z_EXTERNAL_FONT(TURBO_Z_EXTERNAL_FONT_PROFILE)) sharpx1
(
	.clk_sys(clk_sys),
	.clk_28636(clk_28636),
	.reset(reset || quick_reset),

	.pal(1'b0),
	.scandouble(forced_scandoubler),
	.model_x1(TURBO_FOUNDATION && cfg[7:6] == 2'd1),
	.model_z(TURBO_Z_VIDEO_PROFILE && cfg[7:6] == 2'd0),
	.turbo_dsw(boot_dsw),
	.ce_pix(ce_pix),

	.ioctl_download(ioctl_download),
	.ioctl_index(cassette_controller_index ? 8'd6 : x1_ipl_index ? 8'd3 : kanji_font_index ? 8'd5 : ioctl_index[7:0]),
	.ioctl_wr(ioctl_wr && ((ioctl_index == 0 && ioctl_addr < (TURBO_FOUNDATION ? 27'd32768 : 27'd4096)) || (TURBO_FOUNDATION && ioctl_index == 4) || kanji_font_index ||
		(cassette_controller_index && ioctl_addr < 27'd8192) || (x1_ipl_index && ioctl_addr < 27'd4096))),
	.ioctl_addr((ioctl_index == 4 && ioctl_addr >= 27'd4096) ||
        (kanji_font_index && ioctl_addr >= 27'd262144)
        ? 25'h1ffffff : ioctl_addr[24:0]),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(machine_ioctl_wait),
    .DDRAM_CLK(DDRAM_CLK), .DDRAM_BUSY(DDRAM_BUSY), .DDRAM_BURSTCNT(DDRAM_BURSTCNT),
    .DDRAM_ADDR(DDRAM_ADDR), .DDRAM_DOUT(DDRAM_DOUT), .DDRAM_DOUT_READY(DDRAM_DOUT_READY),
    .DDRAM_RD(DDRAM_RD), .DDRAM_DIN(DDRAM_DIN), .DDRAM_BE(DDRAM_BE), .DDRAM_WE(DDRAM_WE),
	.ps2_clk_in(ps2_clk), .ps2_data_in(ps2_data),
	.sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),
	.sio_rxd(2'b11),.sio_cts_n(2'b11),.sio_dcd_n(2'b11),
	.sio_txd(),.sio_rts_n(),.sio_dtr_n(),
	.joya_n(joya_n), .joyb_n(joyb_n),
	// Only the X1_CASSETTE revision connects the deck and its controller.
	.tape_mount(tape_mount), .tape_present(tape_present), .tape_empty(tape_empty),
	.tape_sample_valid(tape_sample_valid), .tape_sample_level(tape_sample_level), .tape_sample_last(tape_sample_last), .tape_sample_hz(tape_sample_hz), .fast_tape(tape_fast),
	.cart_addr(cart_addr), .cart_read(cart_read), .cart_data(cart_data), .cart_ready(cart_ready),
	.tape_sample_ready(tape_sample_ready), .tape_underflow(tape_underflow), .tape_turbo_active(tape_turbo_active), .high_scan(high_scan), .tape_mode(tape_mode), .tape_sensor(tape_sensor),
	.disk_ready(media_present[0]), .img_mounted(img_mounted[0]),
	.disk_wp(!cfg[1] || media_readonly[0]), .img_size(media_size[0]),
	.disk_raw(media_raw[0]), .disk_raw_b(media_raw[1]),
	.disk_ready_b(media_present[1]), .img_mounted_b(img_mounted[1]),
	.disk_wp_b(!cfg[1] || media_readonly[1]), .img_size_b(media_size[1]),
	.sd_drive(fdc_sd_drive), .sd_lba(fdc_sd_lba), .sd_rd(fdc_sd_rd), .sd_wr(fdc_sd_wr), .sd_ack(fdc_sd_drive ? sd_ack[1] : sd_ack[0]),
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
// Optional tape status line while the deck plays (Video page).
wire [11:0] overlay_rgb12;
generate if (CASSETTE_PROFILE) begin : tape_status_overlay
	x1_tape_overlay tape_overlay (
		.clk(clk_28636), .ce_pix(ce_pix), .hblank(HBlank), .vblank(VBlank),
		.enable(!cfg[10]),
		.status(tape_status_word), .req(tape_status_req), .ack(tape_status_ack),
		.rgb_in(machine_rgb12), .rgb_out(overlay_rgb12)
	);
end else begin : no_tape_overlay
	assign overlay_rgb12 = machine_rgb12;
	assign tape_status_ack = 0;
end endgenerate
assign VGA_R  = {2{overlay_rgb12[11:8]}};
assign VGA_G  = {2{overlay_rgb12[7:4]}};
assign VGA_B  = {2{overlay_rgb12[3:0]}};

assign LED_USER = ioctl_download | (|sd_rd) | (|sd_wr);

endmodule
