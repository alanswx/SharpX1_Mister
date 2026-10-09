// Sharp X1 base-machine integration. Shared by MiSTer and simulation.
// See docs/BASE_X1_CONTRACT.md for address-map sources and limitations.
module sharpx1 #(parameter SINGLE_CLOCK = 0, MASTER_HZ = 28636364, TURBO = 0, TURBO_VIDEO_MASTER = 0, TURBO_DMA = 0, TURBO_DMA_IRQ = 0, TURBO_KANJI = 0, TURBO_KANJI_RENDER = 0, TURBO_DSW = 241, TURBO_DMA_RESTART_IRQ = 0, TURBO_Z_PALETTE_CPU = 0, TURBO_Z_VIDEO = 0, TURBO_Z_MULTIMODE = 0, TURBO_Z_INTERNAL8 = 0, TURBO_Z_TEXT_CPU = 0, TURBO_SIO = 0, TURBO_FM_CPU = 0) (
    input clk_sys, clk_28636, reset,
    input pal, scandouble,
    input ioctl_download,
    input [7:0] ioctl_index,
    input ioctl_wr,
    input [24:0] ioctl_addr,
    input [7:0] ioctl_dout,
    output ioctl_wait,
    input ps2_clk_in, ps2_data_in,
    // Experimental serial inputs are already synchronous to clk_sys.
    // Board pin CDC/electrical mapping is not supplied by this interface.
    input sio_external_rx_clock, sio_external_tx_clock,
    input [1:0] sio_rxd, sio_cts_n, sio_dcd_n,
    output [1:0] sio_txd, sio_rts_n, sio_dtr_n,
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
        .int_n(TURBO ? !machine_irq : sub_int_n), .wait_n(machine_wait_n), .halt_n(halt_n),
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
        if(TURBO_Z_PALETTE_CPU && (!TURBO || TURBO_DMA))
            $error("CPU-only Z palette experiment requires TURBO and excludes unqualified DMA ownership");
        if(TURBO_Z_VIDEO && !(TURBO_Z_PALETTE_CPU && TURBO_VIDEO_MASTER && !SINGLE_CLOCK))
            $error("Z video experiment requires palette CPU and enabled X3, not compensated single-clock timing");
        if(TURBO_Z_MULTIMODE && !TURBO_Z_VIDEO)
            $error("Z multi-mode experiment requires Z video");
        if(TURBO_Z_INTERNAL8 && !TURBO_Z_MULTIMODE)
            $error("Z internal eight-color experiment requires Z multi-mode");
        if(TURBO_Z_TEXT_CPU && !TURBO_Z_PALETTE_CPU)
            $error("Z text CPU experiment requires Z palette CPU profile");
        if (TURBO_DMA_IRQ && !(TURBO && TURBO_DMA))
            $error("TURBO_DMA_IRQ requires TURBO and TURBO_DMA");
        if (TURBO_DMA_RESTART_IRQ && !TURBO_DMA_IRQ)
            $error("TURBO_DMA_RESTART_IRQ requires the explicit DMA IRQ profile");
        if (TURBO_KANJI && (!TURBO || TURBO_DMA))
            $error("TURBO_KANJI requires TURBO; combined DMA profile is not qualified");
        if (TURBO_KANJI_RENDER && !TURBO_KANJI)
            $error("TURBO_KANJI_RENDER requires the explicit physical Kanji ROM profile");
        if (TURBO && (TURBO_DSW < 0 || TURBO_DSW > 255))
            $error("TURBO_DSW must be an explicit raw eight-bit switch configuration");
    end
    wire dma_cs = TURBO && TURBO_DMA && !dma_owner && io_cycle && !dam && a[15:4] == 12'h1f8;
    generate if (TURBO && TURBO_DMA) begin : turbo_dma
        x1_dma #(.COMPLETION_IRQ(TURBO_DMA_IRQ), .RESTART_IRQ(TURBO_DMA_RESTART_IRQ)) engine (
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
        assign dma_irq = 0; assign dma_ieo = dma_iei;
        assign dma_irq_pending = 0; assign dma_in_service = 0;
        assign dma_vector = 8'hff;
    end endgenerate

    wire mem_read = !mreq && !rd;
    wire mem_write = !core_reset && !mreq && !wr;
    // M1 low with IORQ is interrupt acknowledge, not an ordinary I/O cycle.
    wire io_read = !core_reset && !iorq && !rd && m1;
    wire io_write = !core_reset && !iorq && !wr && m1;
    wire io_cycle = io_read || io_write;
    wire z_palette_selected, z_palette_wait_n;
    wire z_palette_read_tail;
    wire [7:0] z_palette_data;
    wire z_video_enabled, z_display_allowed, z_palette_valid;
    wire [11:0] z_graphics_index, z_palette_rgb12;
    wire [11:0] z_second_graphics_index;
    wire z_paired_screens;
    wire [7:0] z_priority_video;
    wire [2:0] z_cg_color;
    wire [5:0] z_text_video_bits;
    wire z_text_video_valid,z_text_pixel_selected;
    wire z_composition_enabled;
    wire z_graphics_valid, z_graphics_start, z_graphics_load, z_cg_transparent, z_graphics_disp;
    wire z_gram_read;
    wire [14:0] z_gram_address;
    wire [2:0] z_graphics_mode;
    wire z_graphics_screen, z_graphics_internal;
    wire z_text_selected,z_text_tail;
    wire [7:0] z_text_data;
    wire z_priority_selected,z_priority_tail;
    wire [7:0] z_priority_data;
    wire sio_wait_n;
    wire machine_wait_n=cg_wait_n && z_palette_wait_n && sio_wait_n && fm_wait_n;
    wire fm_selected,fm_read_tail,fm_wait_n,fm_irq_n,fm_sample,fm_protocol_error;
    wire [7:0] fm_data;
    wire signed [15:0] fm_left,fm_right;
    generate if(TURBO && TURBO_FM_CPU) begin : turbo_fm_cpu
        x1_fm_bus #(.MASTER_HZ(SINGLE_CLOCK ? MASTER_HZ : 32000000)) bus(
            .clk(clk_sys),.reset(core_reset),.enable(1'b1),.cpu_allowed(!dma_owner),.dam(dam),
            .m1_n(m1),.mreq_n(mreq),.iorq_n(iorq),.rd_n(rd),.wr_n(wr),
            .address(a),.cpu_data(data_out),.selected(fm_selected),.read_tail(fm_read_tail),
            .wait_n(fm_wait_n),.response(fm_data),.irq_n(fm_irq_n),.sample(fm_sample),
            .left(fm_left),.right(fm_right),.protocol_error(fm_protocol_error));
        // Do not invent the unresolved built-in YM2151 IRQ route or signed
        // PSG/stereo gains. Outputs remain available for diagnostic observers;
        // existing CPU IRQ and unsigned PSG audio paths are unchanged.
    end else begin : no_fm_cpu
        assign fm_selected=0;assign fm_read_tail=0;assign fm_wait_n=1;
        assign fm_data=8'hff;assign fm_irq_n=1;assign fm_sample=0;
        assign fm_left=0;assign fm_right=0;assign fm_protocol_error=0;
    end endgenerate
    generate if(TURBO_Z_PALETTE_CPU) begin : z_palette_cpu
        // Explicit palette experiments; subordinate options add video/internal
        // and text CPU storage. No native Z signature or general decode claim.
        reg [7:0] mode=0, control=0;
        wire [7:0] priority_control;
        if(TURBO_Z_TEXT_CPU) begin : text_cpu
            wire [7:0] live_data,held_data;
            wire read_hold;
            x1_z_text_palette palette(
                .cpu_clk(clk_sys),.video_clk(clk_28636),.reset(core_reset),.video_reset(video_reset),
                .enabled(mode==8'h80 || mode==8'h90),
                .io_read(io_read && !dam),.io_write(io_write && !dam),
                .clear_read(!mreq || !m1 || (io_cycle && !(z_text_selected && io_read))),
                .address(a),.data(data_out),.selected(z_text_selected),.read_data(live_data),
                .read_hold(read_hold),.held_data(held_data),
                .video_index(z_cg_color),.video_bits(z_text_video_bits),.video_valid(z_text_video_valid));
            assign z_text_tail=read_hold && !core_reset && mreq && iorq && m1 &&
                               a[15:3]==13'h3f7 && a[2:0]!=0;
            assign z_text_data=z_text_tail ? held_data : live_data;
            wire [7:0] priority_live,priority_held;
            wire priority_read_hold;
            x1_z_priority_register priority_register(
                .clk(clk_sys),.reset(core_reset),.enabled(mode==8'h80 || mode==8'h90),
                .io_read(io_read && !dam),.io_write(io_write && !dam),
                .clear_read(!mreq || !m1 || (io_cycle && !(z_priority_selected && io_read))),
                .address(a),.data(data_out),.selected(z_priority_selected),.read_data(priority_live),
                .read_hold(priority_read_hold),.held_data(priority_held),.control(priority_control));
            assign z_priority_tail=priority_read_hold && !core_reset && mreq && iorq && m1 && a==16'h1fc0;
            assign z_priority_data=z_priority_tail ? priority_held : priority_live;
        end else begin : no_text_cpu
            assign z_text_video_bits=0;assign z_text_video_valid=0;
            assign priority_control=0;
            assign z_text_selected=0;assign z_text_tail=0;assign z_text_data=8'hff;
            assign z_priority_selected=0;assign z_priority_tail=0;assign z_priority_data=8'hff;
        end
        if(TURBO_Z_VIDEO) begin : controls_crossing
            // Cross one supported-mode predicate, not independently sampled
            // bits of a multi-bit register. Other live controls remain the
            // existing experimental Turbo crossing and require CDC review.
            (* async_reg = "true" *) reg enabled_meta=0, enabled_video=0;
            always @(posedge clk_28636 or posedge video_reset)
                if(video_reset) begin enabled_meta<=0;enabled_video<=0;end
                else begin enabled_meta<=TURBO_Z_MULTIMODE ? (mode==8'h80 || mode==8'h90) : mode==8'h80;enabled_video<=enabled_meta;end
            if(TURBO_Z_MULTIMODE) begin : multimode
                // Priority travels with mode/bank/width in one held payload,
                // not eight independently sampled control bits. No renderer
                // consumes the new byte until composition is qualified.
                wire [31:0] controls;
                wire controls_valid;
                x1_cdc_snapshot #(.WIDTH(32)) snapshot(
                    .source_clk(clk_sys),.destination_clk(clk_28636),
                    .source_data({priority_control,mode,turbo_scrn,turbo_black,mode_c[6]}),
                    .destination_data(controls),.destination_valid(controls_valid));
                wire [7:0] analog_mode=controls[23:16], scrn=controls[15:8];
                assign z_priority_video=controls[31:24];
                wire width40=controls[0];
                wire supported=(analog_mode==8'h80 && (!scrn[0] || (!scrn[1] && (width40 || TURBO_Z_INTERNAL8)))) ||
                               (analog_mode==8'h90 && width40 && !scrn[0]);
                // Compare with timing-domain controls before admitting a
                // character. Coherent payload is held during handshake; live
                // changes still require blanking/software and hardware review.
                assign z_video_enabled=enabled_video && controls_valid && supported &&
                    width40==width_video && scrn==turbo_scrn_video &&
                    !scrn[2] && !scrn[7] && controls[7:1]==0 && turbo_black_video==0;
                assign z_graphics_mode=scrn[0] ? (width40 ? 3'd3 : 3'd4) : !width40 ? 3'd2 :
                                       analog_mode[4] ? (TURBO_Z_TEXT_CPU && controls[28] ? 3'd5 : 3'd1) : 3'd0;
                assign z_graphics_screen=scrn[3];
            end else begin : full_only
                assign z_priority_video=0;
                assign z_video_enabled=enabled_video && width_video && !turbo_scrn_video[0]
                    && !turbo_scrn_video[2] && !turbo_scrn_video[7] && turbo_black_video==0;
                assign z_graphics_mode=0;assign z_graphics_screen=0;
            end
        end else begin : no_video_controls
            assign z_priority_video=0;
            assign z_video_enabled=0;
            assign z_graphics_mode=0;assign z_graphics_screen=0;
        end
        reg control_write_old=0;
        wire control_write=io_write && !dam && (a==16'h1fb0 || a==16'h1fc5);
        always @(posedge clk_sys or posedge core_reset)
            if(core_reset) begin mode<=0;control<=0;control_write_old<=0;end
            else begin
                control_write_old<=control_write;
                if(control_write && !control_write_old) begin
                    if(a==16'h1fb0) mode<=data_out;
                    else control<=data_out;
                end
            end
        wire internal_cpu=TURBO_Z_INTERNAL8 && turbo_scrn[0] && !turbo_scrn[1] && !mode_c[6];
        wire enabled=mode==8'h80 && (control==8'h80 || control==8'h88)
                     && ((!turbo_scrn[0] && mode_c[6]) || internal_cpu);
        // Freeze store ownership at transaction acquisition, not on the
        // later RAM edge. Data/selector remain frozen by the bus adapter.
        reg selected_old=0, internal_owned=0;
        always @(posedge clk_sys or posedge core_reset)
            if(core_reset) begin selected_old<=0;internal_owned<=0;end
            else begin
                selected_old<=z_palette_selected;
                if(z_palette_selected && !selected_old) internal_owned<=internal_cpu;
            end
        wire ram_access,ram_write,ram_valid,read_valid;
        wire read_hold;
        wire [3:0] held_nibble;
        reg tail_pending=0;
        always @(posedge clk_sys or posedge core_reset)
            if(core_reset) tail_pending<=0;
            else if(!mreq || !m1 || (io_cycle && !(z_palette_selected && io_read))) tail_pending<=0;
            else if(read_valid) tail_pending<=1;
        // TV80 can sample a completed WAIT-stretched IN after IORQ/RD rise.
        // Retain only that palette tail; a memory/ACK/other I/O start clears it.
        assign z_palette_read_tail=tail_pending && read_hold && !core_reset
            && mreq && iorq && m1 && a[15:8]>=8'h10 && a[15:8]<=8'h12;
        wire palette_permit, palette_display_allowed;
        assign z_display_allowed=palette_display_allowed;
        wire [11:0] ram_address;
        wire [1:0] ram_component;
        wire [3:0] ram_nibble,ram_data,read_nibble;
        // Provisional functional blank-window policy, not native ASIC pin
        // timing. The return handshake prevents reusing a previous lease.
        x1_z_palette_owner ownership(
            .cpu_clk(clk_sys),.video_clk(clk_28636),.reset(core_reset || video_reset),
            .cpu_request(z_palette_selected && !z_palette_wait_n),.video_blank(VBlank),
            .cpu_permit(palette_permit),.display_allowed(palette_display_allowed)
        );
        x1_z_palette_access access(
            .clk(clk_sys),.reset(core_reset),.external_enabled(enabled),
            .read_mode(control[3]),.permit(palette_permit),
            .io_read(io_read && !dam),.io_write(io_write && !dam),
            .address(a),.data(data_out),.selected(z_palette_selected),
            .wait_n(z_palette_wait_n),.read_valid(read_valid),.read_nibble(read_nibble),
            .read_hold(read_hold),.read_hold_nibble(held_nibble),
            .ram_access(ram_access),.ram_write(ram_write),.ram_address(ram_address),
            .ram_component(ram_component),.ram_nibble(ram_nibble),
            .ram_valid(ram_valid),.ram_data(ram_data)
        );
        // Full-colour experiment honors real ownership and uses the same
        // one-edge palette latency as the legacy registered RGB/blank decision.
        wire [3:0] external_data,internal_data;
        wire external_valid,internal_valid,external_display_valid,internal_display_valid;
        wire [11:0] external_rgb,internal_rgb;
        wire [11:0] display_index;
        wire graphics_present;
        if(TURBO_Z_TEXT_CPU && TURBO_Z_VIDEO && TURBO_Z_MULTIMODE) begin : paired_composition
            // Capture priority alongside the requested/loaded GRAM character.
            // Live CPU controls must not reorder a half-fetched character.
            reg [7:0] requested_priority=0,pixel_priority=0;
            reg requested_composition=0,pixel_composition=0;
            always @(posedge clk_28636 or posedge video_reset)
                if(video_reset) begin
                    requested_priority<=0;pixel_priority<=0;requested_composition<=0;pixel_composition<=0;
                end else if(!z_video_enabled) begin
                    requested_priority<=0;pixel_priority<=0;requested_composition<=0;pixel_composition<=0;
                end
                else begin
                    if(z_graphics_start) begin
                        requested_priority<=z_priority_video;
                        // 1FC0 affects 320x200 multi-color, not 640/400 modes.
                        requested_composition<=z_graphics_mode==0 || z_graphics_mode==1 || z_graphics_mode==5;
                    end
                    if(z_graphics_load) begin
                        pixel_priority<=requested_priority;pixel_composition<=requested_composition;
                    end
                end
            assign z_composition_enabled=pixel_composition && z_graphics_valid;
            wire defined_order;
            wire [1:0] selected_source;
            x1_z_layer_order order(
                .enabled(z_composition_enabled),.two_screen_mode(z_paired_screens),.selected_screen(1'b0),
                .priority_control(pixel_priority),.text_visible(!z_cg_transparent),
                .screen0_visible(z_graphics_index!=0),.screen1_visible(z_second_graphics_index!=0),
                .defined(defined_order),.source(selected_source));
            wire [11:0] back_index=pixel_priority[3] ? z_graphics_index : z_second_graphics_index;
            // Explicit experimental raw-code opacity, not palette RGB. When
            // all graphics codes are zero, text-on-top/between falls through
            // to graphics entry zero; graphics-on-top ends at fixed text zero.
            // Opacity is the raw glyph/graphics code, never programmed RGB.
            assign display_index=!z_paired_screens ? z_graphics_index :
                selected_source==2 ? z_graphics_index : selected_source==3 ? z_second_graphics_index : back_index;
            assign graphics_present=!z_composition_enabled ||
                (defined_order && (selected_source>=2 || (selected_source==0 && !pixel_priority[0])));
            assign z_text_pixel_selected=defined_order && selected_source==1;
        end else begin : no_paired_composition
            assign z_composition_enabled=0;
            assign display_index=z_graphics_index;
            assign graphics_present=1;
            assign z_text_pixel_selected=0;
        end
        wire display_read=TURBO_Z_VIDEO && z_video_enabled && z_graphics_valid && graphics_present &&
                          (z_cg_transparent || z_composition_enabled) && z_graphics_disp && palette_display_allowed;
        assign ram_data=internal_owned ? internal_data : external_data;
        assign ram_valid=internal_owned ? internal_valid : external_valid;
        assign z_palette_valid=external_display_valid || internal_display_valid;
        assign z_palette_rgb12=internal_display_valid ? internal_rgb : external_rgb;
        x1_z_palette_ram store(
            .cpu_clk(clk_sys),.video_clk(clk_28636),.cpu_reset(core_reset),.video_reset(video_reset),
            .cpu_access(ram_access && !internal_owned),.cpu_write(ram_write),.cpu_address(ram_address),
            .cpu_component(ram_component),.cpu_nibble(ram_nibble),
            .cpu_data(external_data),.cpu_valid(external_valid),
            .display_read(display_read && !z_graphics_internal),
            .display_address(display_index),.display_rgb12(external_rgb),.display_valid(external_display_valid)
        );
        if(TURBO_Z_INTERNAL8) begin : internal_store
            x1_z_palette_ram #(.INTERNAL8(1)) store(
                .cpu_clk(clk_sys),.video_clk(clk_28636),.cpu_reset(core_reset),.video_reset(video_reset),
                .cpu_access(ram_access && internal_owned),.cpu_write(ram_write),.cpu_address(ram_address),
                .cpu_component(ram_component),.cpu_nibble(ram_nibble),
                .cpu_data(internal_data),.cpu_valid(internal_valid),
                .display_read(display_read && z_graphics_internal),
                .display_address(z_graphics_index),.display_rgb12(internal_rgb),.display_valid(internal_display_valid));
        end else begin : no_internal_store
            assign internal_data=0;assign internal_valid=0;
            assign internal_rgb=0;assign internal_display_valid=0;
        end
        // Upper nibble is a provisional experimental value, NOT qualified
        // native pin behavior. CPU acceptance must mask to the lower nibble.
        assign z_palette_data=read_valid ? {4'd0,read_nibble} :
                              z_palette_read_tail ? {4'd0,held_nibble} : 8'hff;
    end else begin : no_z_palette_cpu
        assign z_text_video_bits=0;assign z_text_video_valid=0;assign z_text_pixel_selected=0;assign z_composition_enabled=0;
        assign z_text_selected=0;assign z_text_tail=0;assign z_text_data=8'hff;
        assign z_priority_selected=0;assign z_priority_tail=0;assign z_priority_data=8'hff;
        assign z_palette_selected=0;
        assign z_palette_wait_n=1;
        assign z_palette_data=8'hff;
        assign z_palette_read_tail=0;
        assign z_video_enabled=0;
        assign z_priority_video=0;
        assign z_graphics_mode=0;assign z_graphics_screen=0;
        assign z_display_allowed=0;
        assign z_palette_valid=0;
        assign z_palette_rgb12=0;
    end endgenerate
    wire dsw_selected;
    wire [7:0] dsw_data;
    x1_turbo_dsw #(.ENABLED(TURBO)) dip_switches (
        .io_read(io_read), .dam(dam), .address(a), .switches(TURBO_DSW[7:0]),
        .selected(dsw_selected), .data(dsw_data)
    );
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
    wire sio_irq,sio_ieo,sio_ack,sio_iei,sio_reti,sio_in_service;
    wire [7:0] sio_vector,sio_data;
    wire sio_selected,sio_read_tail,sio_unsupported;
    wire [1:0] sio_rx_overflow,sio_tx_overflow;
    generate if(TURBO && TURBO_SIO) begin : turbo_sio
        wire [1:0] rx_clock,tx_clock,rx_tick,tx_tick,sampled_rxd,flow_wait;
        x1_sio_decode decode(.enabled(!dma_owner),.reset(core_reset),.dam(dam),
            .m1_n(m1),.iorq_n(iorq),.rd_n(rd),.wr_n(wr),.address(a),
            .selected(sio_selected),.read_access(),.write_access());
        // CTC ZC is currently a terminal EVENT, not a qualified native pin
        // waveform. Keep this opt-in route experimental, never a board claim.
        x1_sio_clocks_851 clocks(.dtr_b_n(sio_dtr_n[1]),
            .external_rx_clock(sio_external_rx_clock),.external_tx_clock(sio_external_tx_clock),
            .ctc_clock(ctc_zc),.rx_clock(rx_clock),.tx_clock(tx_clock));
        x1_sio_edge_clock events(.clk(clk_sys),.reset(core_reset),.ce(pe4M4),
            .rx_clock(rx_clock),.tx_clock(tx_clock),.rxd(sio_rxd),
            .rx_tick(rx_tick),.tx_tick(tx_tick),.sampled_rxd(sampled_rxd),
            .rx_overflow(sio_rx_overflow),.tx_overflow(sio_tx_overflow));
        x1_sio_interrupt #(.FLOW_ENABLE(1)) device(.clk(clk_sys),.ce(pe4M4),.reset(core_reset),
            .cpu_cs(sio_selected),.cpu_rd_n(rd),.cpu_wr_n(wr),.address(a[1:0]),
            .cpu_din(data_out),.cpu_dout(sio_data),.rx_tick(rx_tick),.tx_tick(tx_tick),
            .rxd(sampled_rxd),.cts_n(sio_cts_n),.dcd_n(sio_dcd_n),
            .txd(sio_txd),.rts_n(sio_rts_n),.dtr_n(sio_dtr_n),.unsupported(sio_unsupported),
            .iei(sio_iei),.acknowledge(sio_ack),.reti(sio_reti),.irq(sio_irq),.ieo(sio_ieo),
            .service_active(sio_in_service),.ack_vector(sio_vector),.wait_n(flow_wait),.ready_n());
        assign sio_wait_n=&flow_wait;
        reg read_tail;
        always @(posedge clk_sys)
            if(core_reset || mem_read) read_tail<=0;
            else if(sio_selected && io_read) read_tail<=1;
        assign sio_read_tail=read_tail && mreq;
    end else begin : no_turbo_sio
        assign sio_irq=0;assign sio_ieo=sio_iei;assign sio_in_service=0;
        assign sio_vector=8'hff;assign sio_data=8'hff;
        assign sio_selected=0;assign sio_read_tail=0;assign sio_wait_n=1;
        assign sio_txd=3;assign sio_rts_n=3;assign sio_dtr_n=3;
        assign sio_unsupported=0;assign sio_rx_overflow=0;assign sio_tx_overflow=0;
    end endgenerate
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
    generate if(TURBO && TURBO_SIO) begin : serial_irq_chain
        x1_sio_irq_bridge irq_bridge(
            .clk(clk_sys),.reset(core_reset),.m1_n(m1),.mreq_n(mreq),
            .iorq_n(iorq),.rd_n(rd),.data(di),.upstream_iei(1'b1),
            .sio_irq(sio_irq),.sio_ieo(sio_ieo),.sio_in_service(sio_in_service),
            .sio_vector(sio_vector),.sio_ack(sio_ack),.sio_iei(sio_iei),.sio_reti(sio_reti),
            .dma_irq(dma_irq),.dma_ieo(dma_ieo),.dma_in_service(dma_in_service),
            .dma_vector(dma_vector),.dma_ack(dma_ack),.dma_iei(dma_iei),.dma_reti(dma_reti),
            .ctc_irq(ctc_irq),.ctc_ieo(ctc_ieo),.ctc_vector(ctc_vector),
            .keyboard_irq(!sub_int_n),.keyboard_vector(sub_data),
            .irq(machine_irq),.keyboard_ack(keyboard_ack),.ctc_ack(ctc_ack),
            .ctc_iei(ctc_iei),.ctc_reti(ctc_reti),.ack_vector(irq_vector));
        assign ctc_selected=!m1 && !iorq && !sio_irq && !dma_irq && ctc_irq;
    end else if (TURBO_DMA_IRQ) begin : completion_irq_chain
        assign sio_iei=1;assign sio_ack=0;assign sio_reti=0;
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
        assign sio_iei=1;assign sio_ack=0;assign sio_reti=0;
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
        .keyboard_irq((TURBO_DMA_IRQ || (TURBO && TURBO_SIO)) ? 1'b0 : !sub_int_n),
        .ctc_irq((TURBO_DMA_IRQ || (TURBO && TURBO_SIO)) ? 1'b0 : ctc_irq), .ctc_vector(ctc_vector),
        .ctc_ieo((TURBO_DMA_IRQ || (TURBO && TURBO_SIO)) ? 1'b1 : ctc_ieo), .keyboard_vector(sub_data),
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
              : (sio_selected && io_read) || sio_read_tail ? sio_data
              : (fm_selected && io_read) || fm_read_tail ? fm_data
              : sub_cs && io_read && !dam ? sub_data
              : ppi_cs && io_read ? ppi_data
              : ctc_cs && io_read ? ctc_data
              : dma_cs && io_read ? dma_data
              : dsw_selected ? dsw_data
              : (z_text_selected && io_read) || z_text_tail ? z_text_data
              : (z_priority_selected && io_read) || z_priority_tail ? z_priority_data
              : (z_palette_selected && io_read) || z_palette_read_tail ? z_palette_data
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
    wire dam;
    x1_dam_control dam_control(.clk(clk_sys),.reset(core_reset),
        .mode5(mode_c[5]),.io_read(io_read),.io_write(io_write),.dam(dam));

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
    wire cg_selected_kanji, kanji_loaded, kanji_load_error, kanji_cpu_valid, kanji_cpu_read;
    wire [16:0] cg_selected_kanji_addr, kanji_cpu_addr;
    wire [7:0] kanji_cpu_data;
    wire [16:0] kanji_display_addr;
    wire kanji_display_select, kanji_display_level1;
    wire [7:0] kanji_display_data;
    wire text_write = io_write && !dam && a[15:12] == 4'h3 && (!TURBO || !a[11]);
    wire kan_write = TURBO && io_write && !dam && a[15:11] == 5'b00111;
    wire attr_write = io_write && !dam && a[15:12] == 4'h2;
    wire cg_access = io_cycle && !dam && a[15:10] == 6'b000101;
    generate if (TURBO) begin : turbo_pcg_selector
        x1_pcg_selector #(.KANJI_SUPPORT(TURBO_KANJI)) selector (
            .clk(clk_sys), .text_write(text_write), .attr_write(attr_write), .kan_write(kan_write),
            .address(a[10:0]), .data(data_out), .nibble(a[3:0]), .plane(a[9:8]),
            .font16_mode(turbo_scrn[6]), .byte_address(cg_selected_addr),
            .font_address(cg_selected_font_addr), .font16_select(cg_selected_font16),
            .unsupported(cg_selected_unsupported), .kanji_select(cg_selected_kanji), .kanji_address(cg_selected_kanji_addr)
        );
    end else begin : no_turbo_pcg_selector
        assign cg_selected_addr = 0;
        assign cg_selected_font_addr = 0;
        assign cg_selected_font16 = 0;
        assign cg_selected_unsupported = 0;
        assign cg_selected_kanji = 0;
        assign cg_selected_kanji_addr = 0;
    end endgenerate
    x1_pcg_access #(.SEPARATE_VIDEO_RESET(TURBO_VIDEO_MASTER), .KANJI_SUPPORT(TURBO_KANJI)) cg_bus (
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
        .cpu_read_hold(cg_read_hold), .selected_kanji(cg_selected_kanji), .selected_kanji_addr(cg_selected_kanji_addr),
        .kanji_available(kanji_loaded), .kanji_cpu_valid(kanji_cpu_valid), .kanji_cpu_q(kanji_cpu_data),
        .kanji_cpu_addr(kanji_cpu_addr), .kanji_cpu_read(kanji_cpu_read)
    );
    // Explicit physical first-level ROM upload, not an emulator filename/JIS
    // conversion. The host must hold both resets through the falling commit.
    // Rendering is a separate opt-in provisional X Millennium row policy.
    generate if (TURBO && TURBO_KANJI) begin : turbo_kanji
        x1_kanji_rom rom (
            .cpu_clk(clk_sys), .video_clk(clk_28636),
            .cpu_reset(core_reset), .video_reset(video_reset),
            .upload(ioctl_download && ioctl_index == 5),
            .load(ioctl_wr && !ioctl_wait && ioctl_index == 5),
            .load_address(ioctl_addr), .load_data(ioctl_dout),
            .cpu_read(kanji_cpu_read), .cpu_address(kanji_cpu_addr),
            .cpu_data(kanji_cpu_data), .cpu_valid(kanji_cpu_valid),
            .display_select(kanji_display_level1), .display_address(kanji_display_addr),
            .display_data(kanji_display_data), .display_valid(),
            .loaded(kanji_loaded), .load_error(kanji_load_error)
        );
    end else begin : no_turbo_kanji
        assign kanji_loaded = 0;
        assign kanji_load_error = 0;
        assign kanji_cpu_data = 0;
        assign kanji_cpu_valid = 0;
        assign kanji_display_data = 0;
    end endgenerate
    x1_video_ram #(11) text_ram(clk_sys,a[10:0],data_out,text_write,text_cpu,clk_28636,vaddr[10:0],text_vid);
    x1_video_ram #(11) attr_ram(clk_sys,a[10:0],data_out,attr_write,attr_cpu,clk_28636,vaddr[10:0],attr_vid);
    x1_video_ram #(11) kan_ram(clk_sys,a[10:0],data_out,kan_write,kan_cpu,clk_28636,vaddr[10:0],kan_vid);
    localparam GRAM_AW = TURBO ? 15 : 14;
    wire [GRAM_AW-1:0] gram_cpu_addr = GRAM_AW'({turbo_scrn[4], a[13:0]});
    x1_gram_address #(.TURBO(TURBO)) gram_address (
        .scrn(turbo_scrn_video), .raster(graphics_ra),
        .text_address(vaddr[10:0]), .graphics_address(graphics_addr)
    );
    wire [GRAM_AW-1:0] gram_video_addr = GRAM_AW'(z_gram_read ? z_gram_address : graphics_addr);
    generate if(TURBO_Z_VIDEO) begin : z_graphics
        x1_z_graphics graphics(
            .clk(clk_28636),.reset(video_reset),.enabled(z_video_enabled),
            .character_start(z_graphics_start),.character_load(z_graphics_load),.pixel_step(ce_pix),
            .base_address(graphics_addr[13:0]),.read_enable(z_gram_read),.read_address(z_gram_address),
            .mode(z_graphics_mode),.screen(z_graphics_screen),.raster_odd(graphics_ra[0]),
            .blue_q(grb_vid),.red_q(grr_vid),.green_q(grg_vid),.internal_palette(z_graphics_internal),
            .palette_index(z_graphics_index),.index_valid(z_graphics_valid),
            .paired_screens(z_paired_screens),.second_palette_index(z_second_graphics_index)
        );
    end else begin : no_z_graphics
        assign z_gram_read=0;assign z_gram_address=0;
        assign z_graphics_index=0;assign z_graphics_valid=0;
        assign z_graphics_internal=0;
        assign z_paired_screens=0;assign z_second_graphics_index=0;
    end endgenerate
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
    // Missing/unloaded/level-2 Kanji is blank, never an ANK substitution.
    assign cg_data = kanji_display_select ? kanji_display_data :
                     TURBO && turbo_scrn_video[0] ? ank16_data : cg8_data;
    wire r,g,b;
    x1_vid #(.ENABLE_CRTC(SINGLE_CLOCK || TURBO_VIDEO_MASTER), .TURBO_SUPPORT(TURBO), .TURBO_CLOCKS(TURBO_VIDEO_MASTER), .SEPARATE_VIDEO_RESET(TURBO_VIDEO_MASTER), .KANJI_RENDER(TURBO_KANJI_RENDER)) display (
        .I_VIDEO_RESET(video_reset),
        .I_TURBO_BLACK(turbo_black_video),
        .I_TURBO_HIGH_SCAN(TURBO && turbo_scrn_video[0]),
        .I_TURBO_TEXT_Y2(TURBO && turbo_scrn_video[2]),
        .I_TURBO_UNDERLINE(TURBO && turbo_scrn_video[7]),
        .I_RESET(core_reset), .I_CCLK(clk_sys), .I_A(a), .I_D(data_out), .O_D(), .O_DE(),
        .I_WR(io_write && !dam), .I_RD(io_read), .O_VWAIT(),
        .I_CRTC_CS(io_cycle && a[15:8] == 8'h18), .I_CG_CS(cg_access),
        .I_PAL_CS(io_cycle && a[15:10] == 6'b000100 && !z_palette_selected),
        .I_TXT_CS(1'b0), .I_ATT_CS(1'b0), .I_KAN_CS(1'b0),
        .I_GRB_CS(1'b0), .I_GRR_CS(1'b0), .I_GRG_CS(1'b0),
        .I_VCLK(clk_28636), .I_CLK1(clk1), .O_VQ(), .I_W40(TURBO_VIDEO_MASTER ? width_video : mode_c[6]),
        .O_VA(vaddr), .O_GRAPHICS_RA(graphics_ra),
        .O_GRAPHICS_START(z_graphics_start),.O_GRAPHICS_LOAD(z_graphics_load),
        .O_CG_TRANSPARENT(z_cg_transparent),.O_GRAPHICS_DISP(z_graphics_disp),.O_CG_COLOR(z_cg_color),
        .O_TXT_WE(), .O_ATT_WE(), .O_KAN_WE(),
        .I_TXT_D(text_vid), .I_ATT_D(attr_vid), .I_KAN_D(TURBO ? kan_vid : 8'd0),
        .O_GRB_WE(), .O_GRR_WE(), .O_GRG_WE(),
        .I_GRB_D(grb_vid), .I_GRR_D(grr_vid), .I_GRG_D(grg_vid),
        .O_CGA(cgaddr), .O_ANK16_ADDR(ank16_addr), .I_CG_D(cg_data),
        .O_KANJI_ADDR(kanji_display_addr), .O_KANJI_SELECT(kanji_display_select), .O_KANJI_LEVEL1(kanji_display_level1),
        .I_PCGB_D(pcgb_vid), .I_PCGR_D(pcgr_vid), .I_PCGG_D(pcgg_vid),
        .O_R(r), .O_G(g), .O_B(b), .O_HSYNC(HSync), .O_VSYNC(VSync), .O_VDISP(vdisp),
        .O_HBLANK(HBlank), .O_VBLANK(VBlank), .O_CE_PIXEL(ce_pix)
    );
    assign rgb = {g,r,b};
    // Full-color boundary uses conventional R:G:B nibbles. Digital modes
    // retain their exact eight colors; future Z palette logic belongs here,
    // upstream of both physical output and simulator capture.
    generate if(TURBO_Z_VIDEO) begin : z_output
        reg graphics_selected=0;
        always @(posedge clk_28636 or posedge video_reset)
            if(video_reset) graphics_selected<=0;
            else graphics_selected<=z_video_enabled && z_cg_transparent && z_graphics_disp;
        // Default transparent-text prototype retains digital opaque text.
        // The combined paired/text experiment below adds provisional analog
        // text; neither profile establishes native Z opacity/blackclip.
        // A denied/invalid graphics response is black, never stale RAM color.
        if(TURBO_Z_TEXT_CPU && TURBO_Z_MULTIMODE) begin : paired_text
            reg composition_active=0,text_selected=0,text_valid=0;
            reg [11:0] text_rgb=0;
            always @(posedge clk_28636 or posedge video_reset)
                if(video_reset) begin
                    composition_active<=0;text_selected<=0;text_valid<=0;text_rgb<=0;
                end else begin
                    composition_active<=z_video_enabled && z_composition_enabled && z_graphics_disp;
                    text_selected<=z_text_pixel_selected;
                    text_valid<=z_text_video_valid;
                    // Explicit experimental eX1/MAME intensity policy:
                    // 00/01/10/11 -> 0/5/A/F. Not qualified DAC pin order.
                    text_rgb<={{2{z_text_video_bits[3:2]}},{2{z_text_video_bits[5:4]}},{2{z_text_video_bits[1:0]}}};
                end
            assign rgb12=composition_active ?
                (text_selected ? (text_valid ? text_rgb : 12'd0) : (z_palette_valid ? z_palette_rgb12 : 12'd0)) :
                graphics_selected ? (z_palette_valid ? z_palette_rgb12 : 12'd0) : {{4{r}}, {4{g}}, {4{b}}};
        end else begin : no_paired_text
            assign rgb12=graphics_selected ? (z_palette_valid ? z_palette_rgb12 : 12'd0)
                                          : {{4{r}}, {4{g}}, {4{b}}};
        end
    end else begin : digital_output
        assign rgb12 = {{4{r}}, {4{g}}, {4{b}}};
    end endgenerate
    assign video = {8{r || g || b}}; // Historical mono output; RGB is authoritative.
endmodule
