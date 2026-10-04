// Sharp X1 base-machine integration. Shared by MiSTer and simulation.
// See docs/BASE_X1_CONTRACT.md for address-map sources and limitations.
module sharpx1 #(parameter SINGLE_CLOCK = 0, MASTER_HZ = 28636364, TURBO = 0) (
    input clk_sys, clk_28636, reset,
    input pal, scandouble,
    input ioctl_download,
    input [7:0] ioctl_index,
    input ioctl_wr,
    input [24:0] ioctl_addr,
    input [7:0] ioctl_dout,
    input ps2_clk_in, ps2_data_in,
    input [7:0] joya_n, joyb_n,
    input disk_ready, img_mounted, disk_wp,
    input [23:0] img_size,
    output [31:0] sd_lba,
    output sd_rd, sd_wr,
    input sd_ack,
    input [8:0] sd_buff_addr,
    input [7:0] sd_buff_dout,
    output [7:0] sd_buff_din,
    input sd_buff_wr,
    output ce_pix,
    output HBlank, HSync, VBlank, VSync,
    output [7:0] video,
    output [2:0] rgb,
    output [15:0] audio
);
    reg [4:0] ce;
    always @(negedge clk_sys or posedge reset)
        if (reset) ce <= 0;
        else ce <= ce + 1'b1;
    wire fractional_cpu, fractional_psg;
    x1_clock_enables #(.MASTER_HZ(MASTER_HZ)) clock_enables (
        .clk(clk_sys), .reset(reset), .cpu_ce(fractional_cpu), .psg_ce(fractional_psg)
    );
    wire pe4M4 = SINGLE_CLOCK ? fractional_cpu : ce[2:0] == 3'b100;
    wire psg_ce = SINGLE_CLOCK ? fractional_psg : ce[3:0] == 4'b1000;
    wire ne4M4 = ce[2:0] == 3'b000;

    wire [15:0] a;
    wire [7:0] di, data_out;
    // cpu.v exposes TV80 active-low strobes despite the historical names.
    wire mreq, iorq, rd, wr, m1, halt_n;
    cpu Cpu (
        .reset_n(~reset), .clock(clk_sys), .cep(pe4M4), .cen(ne4M4),
        .int_n(sub_int_n), .wait_n(cg_wait_n), .halt_n(halt_n),
        .mreq(mreq), .iorq(iorq), .rd(rd), .wr(wr), .m1(m1),
        .di(di), .data_out(data_out), .a(a), .dir(16'd0), .dirset(1'b0)
    );

    wire mem_read = !mreq && !rd;
    wire mem_write = !reset && !mreq && !wr;
    // M1 low with IORQ is interrupt acknowledge, not an ordinary I/O cycle.
    wire io_read = !reset && !iorq && !rd && m1;
    wire io_write = !reset && !iorq && !wr && m1;
    wire io_cycle = io_read || io_write;
    wire sub_cs = io_cycle && !dam && a[15:8] == 8'h19;
    wire ppi_cs = io_cycle && !dam && a[15:8] == 8'h1a;
    wire ipl_set_cs = io_write && !dam && a[15:8] == 8'h1d;
    wire ipl_clear_cs = io_write && !dam && a[15:8] == 8'h1e;

    reg ipl_enabled;
    // Experimental Turbo foundation, not a complete Turbo machine selection.
    // SCRN: display bank bit 3, CPU access bank bit 4; write-only on Turbo.
    reg [7:0] turbo_scrn;
    reg [6:0] turbo_black;
    always @(posedge clk_sys or posedge reset)
        if (reset) begin turbo_scrn <= 0; turbo_black <= 0; end
        else if (TURBO && io_write && !dam) begin
            if (a[15:4] == 12'h1fd) turbo_scrn <= data_out;
            if (a == 16'h1fe0) turbo_black <= data_out[6:0];
        end
    // Stable control latches cross into the renderer. Phase of live changes
    // still needs hardware/CDC review; diagnostics switch while masked.
    (* async_reg = "true" *) reg [7:0] turbo_scrn_meta, turbo_scrn_video;
    (* async_reg = "true" *) reg [6:0] turbo_black_meta, turbo_black_video;
    always @(posedge clk_28636 or posedge reset)
        if (reset) begin
            turbo_scrn_meta <= 0; turbo_scrn_video <= 0;
            turbo_black_meta <= 0; turbo_black_video <= 0;
        end else begin
            turbo_scrn_meta <= turbo_scrn; turbo_scrn_video <= turbo_scrn_meta;
            turbo_black_meta <= turbo_black; turbo_black_video <= turbo_black_meta;
        end
    always @(posedge clk_sys or posedge reset)
        if (reset) ipl_enabled <= 1'b1;
        else if (ipl_set_cs) ipl_enabled <= 1'b1;
        else if (ipl_clear_cs) ipl_enabled <= 1'b0;

    // Index 0: base IPL (4 KiB), experimental Turbo IPL (32 KiB).
    // Index 2: explicit debug/program RAM download.
    // Loader does not wrap invalid addresses and cannot write without download.
    localparam IPL_AW = TURBO ? 15 : 12;
    wire ipl_load = ioctl_download && ioctl_wr && ioctl_index == 0
                    && ioctl_addr < (TURBO ? 25'd32768 : 25'd4096);
    wire ram_load = reset && ioctl_download && ioctl_wr && ioctl_index == 2
                    && ioctl_addr < 25'd65536;
    wire [7:0] ipl_data, ram_data;
    dpram #(8,IPL_AW) IPL (
        .clock(clk_sys), .ram_cs(1'b1), .address_a(ioctl_addr[IPL_AW-1:0]),
        .wren_a(ipl_load), .data_a(ioctl_dout), .q_a(),
        .ram_cs_b(1'b1), .address_b(a[IPL_AW-1:0]), .wren_b(1'b0),
        .data_b(8'd0), .q_b(ipl_data)
    );
    dpram #(8,16) RAM (
        .clock(clk_sys), .ram_cs(1'b1),
        .address_a(ram_load ? ioctl_addr[15:0] : a),
        .wren_a(ram_load || mem_write),
        .data_a(ram_load ? ioctl_dout : data_out), .q_a(ram_data),
        .ram_cs_b(1'b1), .address_b(16'd0), .wren_b(1'b0),
        .data_b(8'd0), .q_b()
    );

    // Host protocol uses the inherited MR16 firmware for now; no DMA/FDC
    // bus ownership is advertised until those devices have their own tests.
    wire [7:0] sub_data;
    wire sub_tx_busy, sub_rx_busy, sub_int_n, clk1;
    x1_sub #(.CLOCK_HZ(SINGLE_CLOCK ? MASTER_HZ : 32000000), .PS2_RECEIVE_ONLY(1)) subCPU (
        .I_reset(reset), .I_clk(clk_sys), .I_cs(sub_cs),
        .I_rd(io_read), .I_wr(io_write), .I_M1_n(m1),
        .I_D(data_out), .O_D(sub_data), .O_DOE(), .O_clk1(clk1),
        .O_FDC_DRQ_n(), .I_FDCS(1'b0), .I_RFSH_n(1'b1),
        .I_RFSH_STB_n(1'b1), .I_DMA_CS(1'b0),
        .O_DMA_BANK(), .O_DMA_A(), .I_DMA_D(8'hff), .O_DMA_D(),
        .O_DMA_MREQ_n(), .O_DMA_IORQ_n(), .O_DMA_RD_n(), .O_DMA_WR_n(),
        .O_DMA_BUSRQ_n(), .I_DMA_BUSAK_n(1'b1), .I_DMA_RDY(1'b0),
        .I_DMA_WAIT_n(1'b1), .I_DMA_IEI(1'b1),
        .O_DMA_INT_n(), .O_DMA_IEO(), .O_PCM(), .O_FD_LAMP(),
        .I_fa(13'd0), .I_fcs(1'b0), .I_PS2C(ps2_clk_in), .I_PS2D(ps2_data_in),
        .O_PS2CT(), .O_PS2DT(), .O_TX_BSY(sub_tx_busy), .O_RX_BSY(sub_rx_busy),
        .O_KEY_BRK_n(), .I_SPM1(!m1 && !iorq), .I_RETI(1'b0),
        .I_IEI(1'b1), .O_INT_n(sub_int_n), .O_JOY_A(), .O_JOY_B(),
        .dot_7seg(), .num_7seg()
    );

    // Base IPL occupies a 32 KiB read aperture, with only 4 KiB populated.
    // Writes always reach underlying RAM, including when IPL reads are enabled.
    wire rom_selected = ipl_enabled && !a[15];
    assign di = mem_read ? (rom_selected ? (TURBO || a < 16'h1000 ? ipl_data : 8'hff)
                                         : ram_data)
              : !m1 && !iorq ? sub_data
              : sub_cs && io_read && !dam ? sub_data
              : ppi_cs && io_read ? ppi_data
              : io_read && !dam && a[15:2] == 14'h03fe ? fdc_data
              : io_read && !dam && a[15:8] == 8'h1b ? psg_data
              : cg_access && io_read ? cg_cpu_data
              : io_read && !dam && a[15:12] == 4'h2 ? attr_cpu
              : io_read && !dam && TURBO && a[15:11] == 5'b00111 ? kan_cpu
              : io_read && !dam && a[15:12] == 4'h3 ? text_cpu
              : io_read && a[15:14] == 2'b01 ? grb_cpu
              : io_read && a[15:14] == 2'b10 ? grr_cpu
              : io_read && a[15:14] == 2'b11 ? grg_cpu
              : 8'hff;

    wire [7:0] ppi_data, mode_c;
    wire vdisp;
    i8255 ppi (
        .reset(reset), .clk_sys(clk_sys), .addr(a[1:0]), .idata(data_out),
        .odata(ppi_data), .cs(ppi_cs), .we(io_write), .oe(io_read),
        .ipa(8'hff), .opa(), .ipb({vdisp,sub_tx_busy,sub_rx_busy,!ipl_enabled,1'b0,VSync,1'b0,1'b1}),
        .opb(), .ipc(8'hff), .opc(mode_c),
        .sna_load(1'b0), .sna_opa(8'd0), .sna_opb(8'd0), .sna_opc(8'd0), .sna_control(8'd0)
    );
    reg old_mode5, dam;
    always @(posedge clk_sys or posedge reset)
        if (reset) begin old_mode5 <= 1; dam <= 0; end
        else begin
            old_mode5 <= mode_c[5];
            if (io_read) dam <= 0;
            else if (old_mode5 && !mode_c[5]) dam <= 1;
        end

    wire [7:0] psg_data;
    wire [9:0] psg_sound;
    wire psg_address = !dam && a[15:8] == 8'h1c;
    wire psg_access = !dam && a[15:8] == 8'h1b;
    jt49_bus psg (
        .rst_n(~reset), .clk(clk_sys), .clk_en(psg_ce),
        .bdir(io_write && (psg_address || psg_access)),
        .bc1((io_write && psg_address) || (io_read && psg_access)),
        .din(data_out), .sel(1'b1), .dout(psg_data), .sound(psg_sound),
        .A(), .B(), .C(), .sample(), .IOA_in(joya_n), .IOB_in(joyb_n),
        .IOA_out(), .IOB_out(), .IOA_oe(), .IOB_oe()
    );
    assign audio = {psg_sound,6'd0};

    wire [7:0] fdc_data;
    wire fdc_prepare, fdc_fmt_wp;
    wire [1:0] drive;
    wire disk_side, disk_motor, disk_fm;
    x1_disk_control #(.MOTOR_HOLD_CYCLES(SINGLE_CLOCK ? MASTER_HZ * 6 / 5 : 38400000)) disk_control (
        .clk(clk_sys), .reset(reset), .io_read(io_read && !dam), .io_write(io_write && !dam),
        .address(a), .data(data_out), .drive(drive), .side(disk_side), .motor_on(disk_motor), .fm_mode(disk_fm)
    );
    wd1793 #(.RWMODE(1), .EDSK(1), .HEADLOAD_STATUS(1), .INDEX_CYCLES(800000), .D88_ONLY(1)) fdc (
        .clk_sys(clk_sys), .ce(pe4M4), .reset(reset),
        .io_en(!dam && a[15:2] == 14'h03fe), .rd(io_read), .wr(io_write),
        .addr(a[1:0]), .din(data_out), .dout(fdc_data),
        .drq(), .intrq(), .busy(), .wp(disk_wp || fdc_fmt_wp), .fmt_wp(fdc_fmt_wp),
        .size_code(3'd1), .layout(1'b0), .side(disk_side), .fm_mode(disk_fm),
        .ready(disk_ready && drive == 0 && disk_motor && !fdc_prepare),
        .img_mounted(img_mounted), .img_size(img_size[19:0]), .img_size_id(img_size),
        .disk_index(3'd0), .prepare(fdc_prepare),
        .sd_lba(sd_lba), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
        .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout),
        .sd_buff_din(sd_buff_din), .sd_buff_wr(sd_buff_wr),
        .input_active(1'b0), .input_addr(20'd0), .input_data(8'd0), .input_wr(1'b0),
        .buff_addr(), .buff_read(), .buff_din(8'd0)
    );

    wire [13:0] vaddr;
    wire [10:0] cgaddr;
    wire [7:0] text_cpu, text_vid, attr_cpu, attr_vid, cg_data;
    wire [7:0] kan_cpu, kan_vid;
    wire [7:0] grb_cpu, grr_cpu, grg_cpu, grb_vid, grr_vid, grg_vid;
    wire [7:0] pcgb_vid, pcgr_vid, pcgg_vid;
    wire [7:0] pcgb_cpu, pcgr_cpu, pcgg_cpu, cg_rom_cpu, cg_cpu_data;
    wire [10:0] cg_access_addr;
    wire [7:0] cg_access_data;
    wire [2:0] cg_access_write;
    wire cg_wait_n;
    wire text_write = io_write && !dam && a[15:12] == 4'h3 && (!TURBO || !a[11]);
    wire kan_write = TURBO && io_write && !dam && a[15:11] == 5'b00111;
    wire attr_write = io_write && !dam && a[15:12] == 4'h2;
    wire cg_access = io_cycle && !dam && a[15:10] == 6'b000101;
    x1_pcg_access cg_bus (
        .reset(reset), .cpu_clk(clk_sys), .video_clk(clk_28636),
        .cpu_select(cg_access), .cpu_write(io_write), .cpu_plane(a[9:8]), .cpu_data(data_out),
        .wait_n(cg_wait_n), .cpu_q(cg_cpu_data), .beam_addr(cgaddr),
        .access_addr(cg_access_addr), .access_data(cg_access_data), .access_write(cg_access_write),
        .rom_q(cg_rom_cpu), .blue_q(pcgb_cpu), .red_q(pcgr_cpu), .green_q(pcgg_cpu)
    );
    x1_video_ram #(11) text_ram(clk_sys,a[10:0],data_out,text_write,text_cpu,clk_28636,vaddr[10:0],text_vid);
    x1_video_ram #(11) attr_ram(clk_sys,a[10:0],data_out,attr_write,attr_cpu,clk_28636,vaddr[10:0],attr_vid);
    x1_video_ram #(11) kan_ram(clk_sys,a[10:0],data_out,kan_write,kan_cpu,clk_28636,vaddr[10:0],kan_vid);
    localparam GRAM_AW = TURBO ? 15 : 14;
    wire [GRAM_AW-1:0] gram_cpu_addr = GRAM_AW'({turbo_scrn[4], a[13:0]});
    wire [GRAM_AW-1:0] gram_video_addr = GRAM_AW'({turbo_scrn_video[3], vaddr});
    x1_video_ram #(GRAM_AW) gram_b(clk_sys,gram_cpu_addr,data_out,io_write && ((a[15:14] == 1) ^ dam),grb_cpu,clk_28636,gram_video_addr,grb_vid);
    x1_video_ram #(GRAM_AW) gram_r(clk_sys,gram_cpu_addr,data_out,io_write && ((a[15:14] == 2) ^ dam),grr_cpu,clk_28636,gram_video_addr,grr_vid);
    x1_video_ram #(GRAM_AW) gram_g(clk_sys,gram_cpu_addr,data_out,io_write && ((a[15:14] == 3) ^ dam),grg_cpu,clk_28636,gram_video_addr,grg_vid);
    x1_video_ram #(11) pcg_b(clk_28636,cg_access_addr,cg_access_data,cg_access_write[0],pcgb_cpu,clk_28636,cgaddr,pcgb_vid);
    x1_video_ram #(11) pcg_r(clk_28636,cg_access_addr,cg_access_data,cg_access_write[1],pcgr_cpu,clk_28636,cgaddr,pcgr_vid);
    x1_video_ram #(11) pcg_g(clk_28636,cg_access_addr,cg_access_data,cg_access_write[2],pcgg_cpu,clk_28636,cgaddr,pcgg_vid);
    x1_cg8 access_font(clk_28636,cg_access_addr,cg_rom_cpu);
    x1_cg8 font(clk_28636,cgaddr,cg_data);
    wire r,g,b;
    x1_vid #(.ENABLE_CRTC(SINGLE_CLOCK), .TURBO_SUPPORT(TURBO)) display (
        .I_TURBO_BLACK(turbo_black_video),
        .I_RESET(reset), .I_CCLK(clk_sys), .I_A(a), .I_D(data_out), .O_D(), .O_DE(),
        .I_WR(io_write && !dam), .I_RD(io_read), .O_VWAIT(),
        .I_CRTC_CS(io_cycle && a[15:8] == 8'h18), .I_CG_CS(cg_access),
        .I_PAL_CS(io_cycle && a[15:10] == 6'b000100),
        .I_TXT_CS(1'b0), .I_ATT_CS(1'b0), .I_KAN_CS(1'b0),
        .I_GRB_CS(1'b0), .I_GRR_CS(1'b0), .I_GRG_CS(1'b0),
        .I_VCLK(clk_28636), .I_CLK1(clk1), .O_VQ(), .I_W40(mode_c[6]),
        .O_VA(vaddr), .O_TXT_WE(), .O_ATT_WE(), .O_KAN_WE(),
        .I_TXT_D(text_vid), .I_ATT_D(attr_vid), .I_KAN_D(8'd0),
        .O_GRB_WE(), .O_GRR_WE(), .O_GRG_WE(),
        .I_GRB_D(grb_vid), .I_GRR_D(grr_vid), .I_GRG_D(grg_vid),
        .O_CGA(cgaddr), .I_CG_D(cg_data),
        .I_PCGB_D(pcgb_vid), .I_PCGR_D(pcgr_vid), .I_PCGG_D(pcgg_vid),
        .O_R(r), .O_G(g), .O_B(b), .O_HSYNC(HSync), .O_VSYNC(VSync), .O_VDISP(vdisp),
        .O_HBLANK(HBlank), .O_VBLANK(VBlank), .O_CE_PIXEL(ce_pix)
    );
    assign rgb = {g,r,b};
    assign video = {8{r || g || b}}; // Historical mono output; RGB is authoritative.
endmodule
