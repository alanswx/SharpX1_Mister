// Sharp X1 base-machine integration. Shared by MiSTer and simulation.
// See docs/BASE_X1_CONTRACT.md for address-map sources and limitations.
module sharpx1 #(parameter SINGLE_CLOCK = 0, MASTER_HZ = 28636364, TURBO = 0, TURBO_VIDEO_MASTER = 0, TURBO_DMA = 0, TURBO_DMA_IRQ = 0) (
    input clk_sys, clk_28636, reset,
    input pal, scandouble,
    input ioctl_download,
    input [7:0] ioctl_index,
    input ioctl_wr,
    input [24:0] ioctl_addr,
    input [7:0] ioctl_dout,
    output ioctl_wait,
    input ps2_clk_in, ps2_data_in,
    input [7:0] joya_n, joyb_n,
    input disk_ready, img_mounted, disk_wp,
    input [23:0] img_size,
    input disk_ready_b, img_mounted_b, disk_wp_b,
    input [23:0] img_size_b,
    output sd_drive,
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
    output [11:0] rgb12,
    output [15:0] audio
);
    // The actual CPU ACK selects the shared bus. Reset stops CPU execution,
    // but retains that ACK and peripheral enables until an owned pair drains.
    wire core_reset, cpu_run, dma_reset, dma_draining;
    wire dma_busrq_n, cpu_busak_n;
    wire dma_owner = TURBO && TURBO_DMA && !cpu_busak_n;
    generate if (TURBO && TURBO_DMA) begin : dma_reset_domain
        x1_dma_reset reset_guard (
            .clk(clk_sys), .reset_request(reset), .dma_busak_n(cpu_busak_n),
            .dma_busrq_n(dma_busrq_n), .machine_reset(core_reset),
            .cpu_run(cpu_run), .dma_reset(dma_reset), .draining(dma_draining)
        );
    end else begin : compatible_machine_reset
        assign core_reset = reset;
        assign cpu_run = !reset;
        assign dma_reset = reset;
        assign dma_draining = 0;
    end endgenerate
    assign ioctl_wait = TURBO && TURBO_DMA && dma_draining;
    // X3 alone has the independent faster video domain. Assert immediately,
    // release its state only on that clock; base/single reset phase is intact.
    wire video_reset;
    generate if (TURBO_VIDEO_MASTER) begin : video_reset_domain
        x1_reset_release release_reset(clk_28636, core_reset, video_reset);
    end else begin : compatible_video_reset
        assign video_reset = core_reset;
    end endgenerate
    reg [4:0] ce;
    always @(negedge clk_sys or posedge core_reset)
        if (core_reset) ce <= 0;
        else ce <= ce + 1'b1;
    wire fractional_cpu, fractional_psg;
    x1_clock_enables #(.MASTER_HZ(MASTER_HZ)) clock_enables (
        .clk(clk_sys), .reset(core_reset), .cpu_ce(fractional_cpu), .psg_ce(fractional_psg)
    );
    wire pe4M4 = SINGLE_CLOCK ? fractional_cpu : ce[2:0] == 3'b100;
    wire psg_ce = SINGLE_CLOCK ? fractional_psg : ce[3:0] == 4'b1000;
    wire ne4M4 = ce[2:0] == 3'b000;

    wire [15:0] a;
    wire [7:0] di, data_out;
    wire [15:0] cpu_a, dma_a;
    wire [7:0] cpu_data_out, dma_data_out, dma_data;
    wire cpu_mreq, cpu_iorq, cpu_rd, cpu_wr, cpu_m1;
    wire dma_mreq, dma_iorq, dma_rd, dma_wr, dma_unsupported;
    wire cpu_ce = pe4M4 && cpu_run;
    // cpu.v exposes TV80 active-low strobes despite the historical names.
    wire mreq, iorq, rd, wr, m1, halt_n;
    cpu Cpu (
        .reset_n(~core_reset), .clock(clk_sys), .cep(cpu_ce), .cen(ne4M4),
        .int_n(TURBO ? !machine_irq : sub_int_n), .wait_n(cg_wait_n), .halt_n(halt_n),
        .busrq_n(dma_busrq_n), .busak_n(cpu_busak_n), .rfsh_n(),
        .mreq(cpu_mreq), .iorq(cpu_iorq), .rd(cpu_rd), .wr(cpu_wr), .m1(cpu_m1),
        .di(di), .data_out(cpu_data_out), .a(cpu_a), .dir(16'd0), .dirset(1'b0)
    );
    assign a = dma_owner ? dma_a : cpu_a;
    assign data_out = dma_owner ? dma_data_out : cpu_data_out;
    assign mreq = dma_owner ? dma_mreq : cpu_mreq;
    assign iorq = dma_owner ? dma_iorq : cpu_iorq;
    assign rd = dma_owner ? dma_rd : cpu_rd;
    assign wr = dma_owner ? dma_wr : cpu_wr;
    assign m1 = dma_owner ? 1'b1 : cpu_m1;
    wire dma_irq, dma_ieo, dma_irq_pending, dma_in_service;
    wire dma_ack, dma_iei, dma_reti;
    wire [7:0] dma_vector;
    initial begin
        if (TURBO_DMA_IRQ && !(TURBO && TURBO_DMA))
            $error("TURBO_DMA_IRQ requires TURBO and TURBO_DMA");
    end
    wire dma_cs = TURBO && TURBO_DMA && !dma_owner && io_cycle && !dam && a[15:4] == 12'h1f8;
    generate if (TURBO && TURBO_DMA) begin : turbo_dma
        x1_dma #(.COMPLETION_IRQ(TURBO_DMA_IRQ)) engine (
            .iei(dma_iei),.acknowledge(dma_ack),.reti(dma_reti),
            .irq(dma_irq),.ieo(dma_ieo),.irq_pending(dma_irq_pending),
            .irq_in_service(dma_in_service),.ack_vector(dma_vector),
            .clk(clk_sys), .ce(pe4M4), .reset(dma_reset),
            .cpu_cs(dma_cs), .cpu_rd_n(cpu_rd), .cpu_wr_n(cpu_wr),
            .cpu_data_in(cpu_data_out), .cpu_data_out(dma_data),
            .busrq_n(dma_busrq_n), .busak_n(cpu_busak_n),
            .mreq_n(dma_mreq), .iorq_n(dma_iorq), .rd_n(dma_rd), .wr_n(dma_wr),
            .address(dma_a), .data_out(dma_data_out), .data_in(di),
            .wait_n(cg_wait_n), .rdy(!fdc_drq), .unsupported(dma_unsupported)
        );
    end else begin : no_turbo_dma
        assign dma_busrq_n = 1;
        assign dma_mreq = 1; assign dma_iorq = 1;
        assign dma_rd = 1; assign dma_wr = 1;
        assign dma_a = 0; assign dma_data_out = 0;
        assign dma_data = 8'hff; assign dma_unsupported = 0;
        assign dma_irq = 0; assign dma_ieo = 1;
        assign dma_irq_pending = 0; assign dma_in_service = 0;
        assign dma_vector = 8'hff;
    end endgenerate

    wire mem_read = !mreq && !rd;
    wire mem_write = !core_reset && !mreq && !wr;
    // M1 low with IORQ is interrupt acknowledge, not an ordinary I/O cycle.
    wire io_read = !core_reset && !iorq && !rd && m1;
    wire io_write = !core_reset && !iorq && !wr && m1;
    wire io_cycle = io_read || io_write;
    wire sub_cs = io_cycle && !dam && a[15:8] == 8'h19;
    wire ppi_cs = io_cycle && !dam && a[15:8] == 8'h1a;
    wire ipl_set_cs = io_write && !dam && a[15:8] == 8'h1d;
    wire ipl_clear_cs = io_write && !dam && a[15:8] == 8'h1e;

    // CTC is opt-in with the experimental Turbo profile. Bus writes are
    // edge-qualified, not repeated on every master edge of a Z80 strobe.
    wire ctc_cs = TURBO && io_cycle && !dam && a[15:4] == 12'h1fa && !a[2];
    reg ctc_write_old, ctc_trigger_2m;
    always @(posedge clk_sys or posedge core_reset)
        if (core_reset) begin ctc_write_old <= 0; ctc_trigger_2m <= 0; end
        else begin
            ctc_write_old <= ctc_cs && io_write;
            if (pe4M4) ctc_trigger_2m <= !ctc_trigger_2m;
        end
    wire [7:0] ctc_data, ctc_vector, irq_vector;
    wire [3:0] ctc_zc;
    wire ctc_irq, ctc_ack, ctc_reti, ctc_iei, ctc_ieo, ctc_selected;
    wire machine_irq, keyboard_ack;
    // Legacy schematic-derived wiring: constant channel 0, 2 MHz channels
    // 1/2 and channel-0 terminal-count cascade into channel 3. Physical
    // phase/pulse-width and inter-chip priority remain hardware review gates.
    x1_ctc ctc (
        .clk(clk_sys), .reset(core_reset), .ce(pe4M4),
        .wr(ctc_cs && io_write && !ctc_write_old), .channel(a[1:0]),
        .din(data_out), .dout(ctc_data),
        .trigger({ctc_zc[0],ctc_trigger_2m,ctc_trigger_2m,1'b1}),
        .iei(ctc_iei), .irq(ctc_irq), .ieo(ctc_ieo), .ack(ctc_ack),
        .reti(ctc_reti), .vector(ctc_vector), .zc(ctc_zc)
    );
    generate if (TURBO_DMA_IRQ) begin : completion_irq_chain
        // Inspected CZ-851/852 chain; upstream SIO/external are absent here.
        x1_dma_irq_bridge irq_bridge (
            .clk(clk_sys),.reset(core_reset),.m1_n(m1),.mreq_n(mreq),
            .iorq_n(iorq),.rd_n(rd),.data(di),.upstream_iei(1'b1),
            .dma_irq(dma_irq),.dma_ieo(dma_ieo),.dma_in_service(dma_in_service),
            .dma_vector(dma_vector),.dma_ack(dma_ack),.dma_iei(dma_iei),.dma_reti(dma_reti),
            .ctc_irq(ctc_irq),.ctc_ieo(ctc_ieo),.ctc_vector(ctc_vector),
            .keyboard_irq(!sub_int_n),.keyboard_vector(sub_data),
            .irq(machine_irq),.keyboard_ack(keyboard_ack),.ctc_ack(ctc_ack),
            .ctc_iei(ctc_iei),.ctc_reti(ctc_reti),.ack_vector(irq_vector)
        );
        assign ctc_selected = !m1 && !iorq && !dma_irq && ctc_irq;
    end else begin : compatible_irq_chain
        assign dma_iei = 1; assign dma_ack = 0; assign dma_reti = 0;
        assign machine_irq = compatible_irq;
        assign keyboard_ack = compatible_keyboard_ack;
        assign ctc_ack = compatible_ctc_ack; assign ctc_iei = compatible_ctc_iei;
        assign ctc_reti = compatible_ctc_reti; assign ctc_selected = compatible_ctc_selected;
        assign irq_vector = compatible_vector;
    end endgenerate
    // Keep the default instance path/state layout unchanged for v12 snapshots.
    wire compatible_irq, compatible_keyboard_ack, compatible_ctc_ack;
    wire compatible_ctc_iei, compatible_ctc_reti, compatible_ctc_selected;
    wire [7:0] compatible_vector;
    x1_irq_bridge irq_bridge (
        .clk(clk_sys), .reset(core_reset), .m1_n(m1), .mreq_n(mreq),
        .iorq_n(iorq), .rd_n(rd), .data(di),
        .keyboard_irq(TURBO_DMA_IRQ ? 1'b0 : !sub_int_n),
        .ctc_irq(TURBO_DMA_IRQ ? 1'b0 : ctc_irq), .ctc_vector(ctc_vector),
        .ctc_ieo(TURBO_DMA_IRQ ? 1'b1 : ctc_ieo), .keyboard_vector(sub_data),
        .irq(compatible_irq), .keyboard_ack(compatible_keyboard_ack), .ctc_ack(compatible_ctc_ack),
        .ctc_iei(compatible_ctc_iei), .ctc_reti(compatible_ctc_reti),
        .ctc_selected(compatible_ctc_selected), .ack_vector(compatible_vector)
    );

    reg ipl_enabled;
    // Experimental Turbo foundation, not a complete Turbo machine selection.
    // SCRN: graphics raster mode bits 0/1, display page bit 3 (except mode
    // 01's fixed even/odd pages), CPU access page bit 4; write-only on Turbo.
    reg [7:0] turbo_scrn;
    reg [6:0] turbo_black;
    always @(posedge clk_sys or posedge core_reset)
        if (core_reset) begin turbo_scrn <= 0; turbo_black <= 0; end
        else if (TURBO && io_write && !dam) begin
            if (a[15:4] == 12'h1fd) turbo_scrn <= data_out;
            if (a == 16'h1fe0) turbo_black <= data_out[6:0];
        end
    // Stable control latches cross into the renderer. Phase of live changes
    // still needs hardware/CDC review; diagnostics switch while masked.
    (* async_reg = "true" *) reg [7:0] turbo_scrn_meta, turbo_scrn_video;
    (* async_reg = "true" *) reg [6:0] turbo_black_meta, turbo_black_video;
    (* async_reg = "true" *) reg width_meta, width_video;
    always @(posedge clk_28636 or posedge video_reset)
        if (video_reset) begin
            turbo_scrn_meta <= 0; turbo_scrn_video <= 0;
            turbo_black_meta <= 0; turbo_black_video <= 0;
            width_meta <= 0; width_video <= 0;
        end else begin
            turbo_scrn_meta <= turbo_scrn; turbo_scrn_video <= turbo_scrn_meta;
            turbo_black_meta <= turbo_black; turbo_black_video <= turbo_black_meta;
            width_meta <= mode_c[6]; width_video <= width_meta;
        end
    always @(posedge clk_sys or posedge core_reset)
        if (core_reset) ipl_enabled <= 1'b1;
        else if (ipl_set_cs) ipl_enabled <= 1'b1;
        else if (ipl_clear_cs) ipl_enabled <= 1'b0;

    // Index 0: base IPL (4 KiB), experimental Turbo IPL (32 KiB).
    // Index 2: explicit debug/program RAM download.
    // Loader does not wrap invalid addresses and cannot write without download.
    localparam IPL_AW = TURBO ? 15 : 12;
    wire ipl_load = ioctl_download && ioctl_wr && !ioctl_wait && ioctl_index == 0
                    && ioctl_addr < (TURBO ? 25'd32768 : 25'd4096);
    wire ram_load = core_reset && ioctl_download && ioctl_wr && !ioctl_wait && ioctl_index == 2
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
    x1_sub #(.CLOCK_HZ(SINGLE_CLOCK ? MASTER_HZ : 32000000), .PS2_RECEIVE_ONLY(1), .IRQ_ACK_ONCE(TURBO)) subCPU (
        .I_reset(core_reset), .I_clk(clk_sys), .I_cs(sub_cs),
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
        .O_KEY_BRK_n(), .I_SPM1(TURBO ? keyboard_ack : !m1 && !iorq), .I_RETI(1'b0),
        .I_IEI(1'b1), .O_INT_n(sub_int_n), .O_JOY_A(), .O_JOY_B(),
        .dot_7seg(), .num_7seg()
    );

    // Base IPL occupies a 32 KiB read aperture, with only 4 KiB populated.
    // Writes always reach underlying RAM, including when IPL reads are enabled.
    wire rom_selected = ipl_enabled && !a[15];
    assign di = mem_read ? (rom_selected ? (TURBO || a < 16'h1000 ? ipl_data : 8'hff)
                                         : ram_data)
              : !m1 && !iorq ? (TURBO ? irq_vector : sub_data)
              : sub_cs && io_read && !dam ? sub_data
              : ppi_cs && io_read ? ppi_data
              : ctc_cs && io_read ? ctc_data
              : dma_cs && io_read ? dma_data
              : io_read && !dam && a[15:2] == 14'h03fe ? fdc_data
              : io_read && !dam && a[15:8] == 8'h1b ? psg_data
              : (cg_access && io_read) || cg_read_tail ? cg_cpu_data
              : io_read && !dam && a[15:12] == 4'h2 ? attr_cpu
              : io_read && !dam && TURBO && a[15:11] == 5'b00111 ? kan_cpu
              : io_read && !dam && a[15:12] == 4'h3 ? text_cpu
              : io_read && a[15:14] == 2'b01 ? grb_cpu
              : io_read && a[15:14] == 2'b10 ? grr_cpu
              : io_read && a[15:14] == 2'b11 ? grg_cpu
              : 8'hff;

    wire [7:0] ppi_data, mode_c;
    wire vdisp;
    wire ppi_vdisp, ppi_vsync;
    // The X3 profile has a genuinely separate faster video domain. Only its
    // PPI status levels change latency; preserve the established base path.
    x1_video_status #(.SYNCHRONIZE(TURBO_VIDEO_MASTER)) video_status (
        .clk_sys(clk_sys), .reset(core_reset),
        .video_vdisp(vdisp), .video_vsync(VSync),
        .cpu_vdisp(ppi_vdisp), .cpu_vsync(ppi_vsync)
    );
    i8255 ppi (
        .reset(core_reset), .clk_sys(clk_sys), .addr(a[1:0]), .idata(data_out),
        .odata(ppi_data), .cs(ppi_cs), .we(io_write), .oe(io_read),
        .ipa(8'hff), .opa(), .ipb({ppi_vdisp,sub_tx_busy,sub_rx_busy,!ipl_enabled,1'b0,ppi_vsync,1'b0,1'b1}),
        .opb(), .ipc(8'hff), .opc(mode_c),
        .sna_load(1'b0), .sna_opa(8'd0), .sna_opb(8'd0), .sna_opc(8'd0), .sna_control(8'd0)
    );
    reg old_mode5, dam;
    always @(posedge clk_sys or posedge core_reset)
        if (core_reset) begin old_mode5 <= 1; dam <= 0; end
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
        .rst_n(~core_reset), .clk(clk_sys), .clk_en(psg_ce),
        .bdir(io_write && (psg_address || psg_access)),
        .bc1((io_write && psg_address) || (io_read && psg_access)),
        .din(data_out), .sel(1'b1), .dout(psg_data), .sound(psg_sound),
        .A(), .B(), .C(), .sample(), .IOA_in(joya_n), .IOB_in(joyb_n),
        .IOA_out(), .IOB_out(), .IOA_oe(), .IOB_oe()
    );
    assign audio = {psg_sound,6'd0};

    wire [7:0] fdc_data;
    wire fdc_prepare, fdc_fmt_wp, fdc_drq;
    wire [1:0] drive;
    wire disk_side, disk_motor, disk_fm;
    wire [1:0] active_drive;
    wire media_changing, selected_ready, selected_wp, transport_idle;
    wire [23:0] selected_size;
    x1_disk_media disk_media (
        .clk(clk_sys), .selected(drive),
        .mounted({img_mounted_b,img_mounted}),
        .present({disk_ready_b,disk_ready}), .readonly({disk_wp_b,disk_wp}),
        .size_a(img_size), .size_b(img_size_b), .transport_idle(transport_idle),
        .active(active_drive), .changing(media_changing),
        .ready(selected_ready), .wp(selected_wp), .size(selected_size)
    );
    assign sd_drive = active_drive[0];
    x1_disk_control #(.MOTOR_HOLD_CYCLES(SINGLE_CLOCK ? MASTER_HZ * 6 / 5 : 38400000), .PHYSICAL_DRIVES(2)) disk_control (
        .clk(clk_sys), .reset(core_reset), .io_read(io_read && !dam), .io_write(io_write && !dam),
        .address(a), .data(data_out), .drive(drive), .side(disk_side), .motor_on(disk_motor), .fm_mode(disk_fm)
    );
    wd1793 #(.RWMODE(1), .EDSK(1), .HEADLOAD_STATUS(1), .INDEX_CYCLES(800000), .D88_ONLY(1), .PHYSICAL_DRIVES(2)) fdc (
        .clk_sys(clk_sys), .ce(pe4M4), .reset(core_reset),
        .io_en(!dam && a[15:2] == 14'h03fe), .rd(io_read), .wr(io_write),
        .addr(a[1:0]), .din(data_out), .dout(fdc_data),
        .drq(fdc_drq), .intrq(), .busy(), .wp(selected_wp || fdc_fmt_wp), .fmt_wp(fdc_fmt_wp),
        .size_code(3'd1), .layout(1'b0), .side(disk_side), .fm_mode(disk_fm),
        .ready(selected_ready && disk_motor && !fdc_prepare),
        .drive_select(active_drive[0]), .transport_idle(transport_idle),
        .drive_connected(active_drive < 2),
        .img_mounted(media_changing), .img_size(selected_size[19:0]), .img_size_id(selected_size),
        .disk_index(3'd0), .prepare(fdc_prepare),
        .sd_lba(sd_lba), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
        .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout),
        .sd_buff_din(sd_buff_din), .sd_buff_wr(sd_buff_wr),
        .input_active(1'b0), .input_addr(20'd0), .input_data(8'd0), .input_wr(1'b0),
        .buff_addr(), .buff_read(), .buff_din(8'd0)
    );

    wire [13:0] vaddr;
    wire [4:0] graphics_ra;
    wire [14:0] graphics_addr;
    wire [10:0] cgaddr;
    wire [11:0] ank16_addr;
    wire [7:0] ank16_data, cg8_data;
    wire [7:0] text_cpu, text_vid, attr_cpu, attr_vid, cg_data;
    wire [7:0] kan_cpu, kan_vid;
    wire [7:0] grb_cpu, grr_cpu, grg_cpu, grb_vid, grr_vid, grg_vid;
    wire [7:0] pcgb_vid, pcgr_vid, pcgg_vid;
    wire [7:0] pcgb_cpu, pcgr_cpu, pcgg_cpu, cg_rom_cpu, cg_cpu_data;
    wire [10:0] cg_access_addr;
    wire [7:0] cg_access_data;
    wire [2:0] cg_access_write;
    wire cg_wait_n;
    wire cg_read_hold;
    // TV80's inherited IOWait phase can repeat T2 after a long WAIT release,
    // with RD/IORQ already high on its second data-sampling edge. Retain only
    // the completed high-speed read on that inactive-bus CG-address tail.
    // Never override memory, interrupt ACK or another active I/O transaction.
    wire cg_read_tail = TURBO && cg_read_hold && !core_reset && mreq && iorq && m1
                        && a[15:10] == 6'b000101;
    wire [10:0] cg_selected_addr;
    wire [11:0] cg_selected_font_addr, cg_font_cpu_addr;
    wire cg_selected_font16, cg_selected_unsupported;
    wire [7:0] cg_font_cpu_data;
    wire text_write = io_write && !dam && a[15:12] == 4'h3 && (!TURBO || !a[11]);
    wire kan_write = TURBO && io_write && !dam && a[15:11] == 5'b00111;
    wire attr_write = io_write && !dam && a[15:12] == 4'h2;
    wire cg_access = io_cycle && !dam && a[15:10] == 6'b000101;
    generate if (TURBO) begin : turbo_pcg_selector
        x1_pcg_selector selector (
            .clk(clk_sys), .text_write(text_write), .attr_write(attr_write), .kan_write(kan_write),
            .address(a[10:0]), .data(data_out), .nibble(a[3:0]), .plane(a[9:8]),
            .font16_mode(turbo_scrn[6]), .byte_address(cg_selected_addr),
            .font_address(cg_selected_font_addr), .font16_select(cg_selected_font16),
            .unsupported(cg_selected_unsupported), .kanji_select(), .kanji_address()
        );
    end else begin : no_turbo_pcg_selector
        assign cg_selected_addr = 0;
        assign cg_selected_font_addr = 0;
        assign cg_selected_font16 = 0;
        assign cg_selected_unsupported = 0;
    end endgenerate
    x1_pcg_access #(.SEPARATE_VIDEO_RESET(TURBO_VIDEO_MASTER)) cg_bus (
        .video_reset(video_reset),
        .reset(core_reset), .cpu_clk(clk_sys), .video_clk(clk_28636),
        .cpu_select(cg_access), .cpu_write(io_write), .cpu_plane(a[9:8]), .cpu_data(data_out),
        .wait_n(cg_wait_n), .cpu_q(cg_cpu_data), .beam_addr(cgaddr),
        .access_addr(cg_access_addr), .access_data(cg_access_data), .access_write(cg_access_write),
        .rom_q(cg_rom_cpu), .blue_q(pcgb_cpu), .red_q(pcgr_cpu), .green_q(pcgg_cpu),
        .high_speed(TURBO && turbo_scrn[5]), .selected_addr(cg_selected_addr),
        .selected_font16(cg_selected_font16), .selected_unsupported(cg_selected_unsupported),
        .selected_font_addr(cg_selected_font_addr), .video_window(HSync),
        .font_cpu_addr(cg_font_cpu_addr), .font_cpu_q(cg_font_cpu_data),
        .cpu_read_hold(cg_read_hold)
    );
    x1_video_ram #(11) text_ram(clk_sys,a[10:0],data_out,text_write,text_cpu,clk_28636,vaddr[10:0],text_vid);
    x1_video_ram #(11) attr_ram(clk_sys,a[10:0],data_out,attr_write,attr_cpu,clk_28636,vaddr[10:0],attr_vid);
    x1_video_ram #(11) kan_ram(clk_sys,a[10:0],data_out,kan_write,kan_cpu,clk_28636,vaddr[10:0],kan_vid);
    localparam GRAM_AW = TURBO ? 15 : 14;
    wire [GRAM_AW-1:0] gram_cpu_addr = GRAM_AW'({turbo_scrn[4], a[13:0]});
    x1_gram_address #(.TURBO(TURBO)) gram_address (
        .scrn(turbo_scrn_video), .raster(graphics_ra),
        .text_address(vaddr[10:0]), .graphics_address(graphics_addr)
    );
    wire [GRAM_AW-1:0] gram_video_addr = GRAM_AW'(graphics_addr);
    x1_video_ram #(GRAM_AW) gram_b(clk_sys,gram_cpu_addr,data_out,io_write && ((a[15:14] == 1) ^ dam),grb_cpu,clk_28636,gram_video_addr,grb_vid);
    x1_video_ram #(GRAM_AW) gram_r(clk_sys,gram_cpu_addr,data_out,io_write && ((a[15:14] == 2) ^ dam),grr_cpu,clk_28636,gram_video_addr,grr_vid);
    x1_video_ram #(GRAM_AW) gram_g(clk_sys,gram_cpu_addr,data_out,io_write && ((a[15:14] == 3) ^ dam),grg_cpu,clk_28636,gram_video_addr,grg_vid);
    x1_video_ram #(11) pcg_b(clk_28636,cg_access_addr,cg_access_data,cg_access_write[0],pcgb_cpu,clk_28636,cgaddr,pcgb_vid);
    x1_video_ram #(11) pcg_r(clk_28636,cg_access_addr,cg_access_data,cg_access_write[1],pcgr_cpu,clk_28636,cgaddr,pcgr_vid);
    x1_video_ram #(11) pcg_g(clk_28636,cg_access_addr,cg_access_data,cg_access_write[2],pcgg_cpu,clk_28636,cgaddr,pcgg_vid);
    x1_cg8 access_font(clk_28636,cg_access_addr,cg_rom_cpu);
    x1_cg8 font(clk_28636,cgaddr,cg8_data);
    generate if (TURBO) begin : turbo_font
        x1_font16 font16 (
            .cpu_clk(clk_sys), .video_clk(clk_28636),
            .load(ioctl_download && ioctl_wr && !ioctl_wait && ioctl_index == 4),
            .load_address(ioctl_addr), .load_data(ioctl_dout),
            .display_address(ank16_addr), .display_data(ank16_data), .loaded(),
            .cpu_address(cg_font_cpu_addr), .cpu_data(cg_font_cpu_data)
        );
    end else begin : no_turbo_font
        assign ank16_data = 0;
        assign cg_font_cpu_data = 0;
    end endgenerate
    assign cg_data = TURBO && turbo_scrn_video[0] ? ank16_data : cg8_data;
    wire r,g,b;
    x1_vid #(.ENABLE_CRTC(SINGLE_CLOCK || TURBO_VIDEO_MASTER), .TURBO_SUPPORT(TURBO), .TURBO_CLOCKS(TURBO_VIDEO_MASTER), .SEPARATE_VIDEO_RESET(TURBO_VIDEO_MASTER)) display (
        .I_VIDEO_RESET(video_reset),
        .I_TURBO_BLACK(turbo_black_video),
        .I_TURBO_HIGH_SCAN(TURBO && turbo_scrn_video[0]),
        .I_TURBO_TEXT_Y2(TURBO && turbo_scrn_video[2]),
        .I_TURBO_UNDERLINE(TURBO && turbo_scrn_video[7]),
        .I_RESET(core_reset), .I_CCLK(clk_sys), .I_A(a), .I_D(data_out), .O_D(), .O_DE(),
        .I_WR(io_write && !dam), .I_RD(io_read), .O_VWAIT(),
        .I_CRTC_CS(io_cycle && a[15:8] == 8'h18), .I_CG_CS(cg_access),
        .I_PAL_CS(io_cycle && a[15:10] == 6'b000100),
        .I_TXT_CS(1'b0), .I_ATT_CS(1'b0), .I_KAN_CS(1'b0),
        .I_GRB_CS(1'b0), .I_GRR_CS(1'b0), .I_GRG_CS(1'b0),
        .I_VCLK(clk_28636), .I_CLK1(clk1), .O_VQ(), .I_W40(TURBO_VIDEO_MASTER ? width_video : mode_c[6]),
        .O_VA(vaddr), .O_GRAPHICS_RA(graphics_ra), .O_TXT_WE(), .O_ATT_WE(), .O_KAN_WE(),
        .I_TXT_D(text_vid), .I_ATT_D(attr_vid), .I_KAN_D(TURBO ? kan_vid : 8'd0),
        .O_GRB_WE(), .O_GRR_WE(), .O_GRG_WE(),
        .I_GRB_D(grb_vid), .I_GRR_D(grr_vid), .I_GRG_D(grg_vid),
        .O_CGA(cgaddr), .O_ANK16_ADDR(ank16_addr), .I_CG_D(cg_data),
        .I_PCGB_D(pcgb_vid), .I_PCGR_D(pcgr_vid), .I_PCGG_D(pcgg_vid),
        .O_R(r), .O_G(g), .O_B(b), .O_HSYNC(HSync), .O_VSYNC(VSync), .O_VDISP(vdisp),
        .O_HBLANK(HBlank), .O_VBLANK(VBlank), .O_CE_PIXEL(ce_pix)
    );
    assign rgb = {g,r,b};
    // Full-color boundary uses conventional R:G:B nibbles. Digital modes
    // retain their exact eight colors; future Z palette logic belongs here,
    // upstream of both physical output and simulator capture.
    assign rgb12 = {{4{r}}, {4{g}}, {4{b}}};
    assign video = {8{r || g || b}}; // Historical mono output; RGB is authoritative.
endmodule
