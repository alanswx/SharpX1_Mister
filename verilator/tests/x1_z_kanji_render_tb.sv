// SPDX-License-Identifier: GPL-2.0-only
// Original actual-Z80/VRAM/cache/real-CRTC renderer fixture. Generated assets,
// real font frontend/backend and mock DDR; no shared-machine/board profile or native ASIC claim.
`timescale 1ns/1ps
module x1_z_kanji_render_tb #(
    parameter integer CELL_BITS=11, SYS_HALF_PS=15625, VID_HALF_PS=11640, CE_PERIOD=8,
    WIDTH40=0, LIVE_METADATA=0, GLYPH_FAULT=0
);
    localparam integer CELLS=1<<CELL_BITS;
    localparam integer COLUMNS=WIDTH40!=0 ? 40 : 80;
    localparam logic [28:0] BASE=29'h06123400;
    bit clk=0,clk_vid=0,run_vid=1,cpu_reset=1,host_mode=1;
    initial forever begin #(SYS_HALF_PS*1ps);clk=~clk;end
    initial forever begin #(VID_HALF_PS*1ps);if(run_vid) clk_vid=~clk_vid;end
    logic admit_enable=1,host_valid=0;
    logic [2:0] host_select=0;
    logic [CELL_BITS-1:0] host_cell=0;
    logic [7:0] host_data=0;
    wire [15:0] a;
    wire [7:0] data_out;
    wire mreq,iorq,rd,wr,m1,halt_n,busak_n,unused_rfsh_n;
    wire cpu_io_write=!cpu_reset && !iorq && !wr && m1;
    wire cpu_io_read=!cpu_reset && !iorq && !rd && m1;
    wire [2:0] cpu_select={a[15:11]==5'b00111,a[15:12]==4'h2,a[15:11]==5'b00110};
    wire write_valid=host_mode ? host_valid : cpu_io_write && |cpu_select;
    wire [2:0] write_select=host_mode ? host_select : cpu_select;
    wire [CELL_BITS-1:0] write_cell=host_mode ? host_cell : CELL_BITS'(a);
    wire [7:0] write_data=host_mode ? host_data : data_out;
    wire wait_n,idle,write_accepted;
    wire [CELL_BITS-1:0] ram_address,update_cell,update_done_cell;
    wire [7:0] ram_data,ram_text,ram_attr,ram_kan;
    wire [2:0] ram_write;
    wire update_valid,update_ready,update_done,update_done_ready;
    wire [12:0] update_glyph,update_done_glyph;
    wire [31:0] update_descriptor,update_done_descriptor;
    x1_z_kanji_vram_write #(.CELL_BITS(CELL_BITS)) writer(.*);
    // Public-port nonzero seeding represents one possible cold RAM pattern.
    // Writer validity stays unknown; no seed writer runs during ownership.
    bit seed_mode=0;
    logic [CELL_BITS-1:0] seed_cell=0;
    logic [7:0] seed_data=0;
    wire [CELL_BITS-1:0] memory_address=seed_mode ? seed_cell : ram_address;
    wire [7:0] memory_write_data=seed_mode ? seed_data : ram_data;
    wire [2:0] memory_write=seed_mode ? 3'b111 : ram_write;
    wire [7:0] raw_text,raw_attr,raw_kan;
    x1_video_ram #(CELL_BITS) text_ram(clk,memory_address,memory_write_data,memory_write[0],ram_text,clk_vid,vid_cell,raw_text);
    x1_video_ram #(CELL_BITS) attr_ram(clk,memory_address,memory_write_data,memory_write[1],ram_attr,clk_vid,vid_cell,raw_attr);
    x1_video_ram #(CELL_BITS) kan_ram(clk,memory_address,memory_write_data,memory_write[2],ram_kan,clk_vid,vid_cell,raw_kan);
    wire font_read,font_valid,font_response_ack;
    wire [17:0] font_address;
    wire [7:0] font_data;
    bit invalidate=0;
    wire invalidate_done;
    wire vid_request;
    wire [CELL_BITS-1:0] vid_cell;
    wire [4:0] vid_offset;
    wire vid_response_valid,vid_response_hit;
    wire [CELL_BITS-1:0] vid_response_cell;
    wire [4:0] vid_response_offset;
    wire [12:0] vid_response_glyph;
    wire [31:0] vid_response_descriptor;
    wire [7:0] vid_response_data;
    x1_z_kanji_cache #(.CELL_BITS(CELL_BITS),.VID_DESCRIPTOR_HALF_BIT(22)) cache(.clk_sys(clk),.*);
    bit ioctl_download=0,ioctl_wr=0;
    logic [24:0] ioctl_address=0;
    logic [7:0] ioctl_data=0;
    wire ioctl_wait,loaded,upload_error,upload_active,frontend_wait;
    wire DDRAM_CLK,DDRAM_RD,DDRAM_WE;
    wire [7:0] DDRAM_BURSTCNT,DDRAM_BE;
    wire [28:0] DDRAM_ADDR;
    wire [63:0] DDRAM_DIN;
    logic DDRAM_BUSY=0,DDRAM_DOUT_READY=0;
    logic [63:0] DDRAM_DOUT=0;
    x1_z_kanji_frontend #(.BASE_WORD_ADDRESS(BASE)) frontend(
        .clk(clk),.cold_reset(1'b0),.consumer_cancel(1'b0),
        .cpu_read(font_read),.cpu_address(font_address),.cpu_wait(frontend_wait),
        .cpu_valid(font_valid),.cpu_data(font_data),.cpu_response_ack(font_response_ack),
        .ioctl_download(ioctl_download),.ioctl_index(8'd5),.ioctl_address(ioctl_address),
        .ioctl_wr(ioctl_wr),.ioctl_data(ioctl_data),.ioctl_wait(ioctl_wait),
        .upload_permitted(1'b1),.loaded(loaded),.upload_error(upload_error),.upload_active(upload_active),
        .DDRAM_CLK(DDRAM_CLK),.DDRAM_BUSY(DDRAM_BUSY),.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
        .DDRAM_ADDR(DDRAM_ADDR),.DDRAM_DOUT(DDRAM_DOUT),.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
        .DDRAM_RD(DDRAM_RD),.DDRAM_DIN(DDRAM_DIN),.DDRAM_BE(DDRAM_BE),.DDRAM_WE(DDRAM_WE)
    );
    byte unsigned font_image[0:262143];
    bit pending=0,previous_font_read=0,expected_ddr_read=0,force_busy=0;
    integer delay_left=0,writes=0,reads=0,font_offers=0,font_acks=0;
    logic [28:0] pending_word=BASE;
    logic [17:0] expected_font_address=0;
    longint unsigned sys_edges=0,vid_edges=0,replies=0,wait_edges=0;
    integer admissions=0,offers=0,commits=0,cpu_writes=0,cpu_boot=0,completed_boots=0;
    bit owned=0,offered=0;
    integer owned_cell=0;
    logic [2:0] owned_select=0;
    logic [7:0] owned_data=0;
    logic [31:0] owned_descriptor=0;
    logic [12:0] owned_glyph=0;
    logic [31:0] model_descriptor[0:CELLS-1];
    bit model_visible[0:CELLS-1];
    integer trace_fd,program_fd,read_fd;
    bit read_logged;
    initial read_logged=0;
    string trace_path,program_path,read_path;
    function automatic [7:0] font(input integer address_value);
        return 8'((address_value*43)^(address_value>>7)^(address_value>>14)^8'ha7);
    endfunction
    function automatic [63:0] word_at(input logic [28:0] address_value);
        integer first;
        first=(int'(address_value)-int'(BASE))*8;
        for(integer b=0;b<8;b++) word_at[b*8+:8]=font_image[first+b];
    endfunction
    initial forever begin
        @(negedge clk);#1;
        DDRAM_BUSY=force_busy || sys_edges%11==0;
        DDRAM_DOUT=word_at(pending ? pending_word : DDRAM_ADDR);
        DDRAM_DOUT_READY=pending && delay_left==0;
    end
    initial forever begin : sys_oracle
        logic [31:0] descriptor;
        @(posedge clk);sys_edges++;
        assert(busak_n && DDRAM_CLK==clk && DDRAM_BURSTCNT==1 && !(DDRAM_RD&&DDRAM_WE) &&
            frontend_wait==(font_read&&!font_valid)) else $fatal(1,"Z_VRAM_INTERFACE");
        if(write_valid && !wait_n) wait_edges++;
        if(write_accepted) begin
            assert(!owned && loaded && !invalidate && admit_enable && write_valid && idle && $onehot(write_select)) else $fatal(1,"Z_VRAM_ADMISSION");
            owned=1;offered=0;owned_cell=int'(write_cell);
            owned_select=write_select;owned_data=write_data;descriptor=model_descriptor[write_cell];
            for(integer b=0;b<3;b++) if(write_select[b]) begin descriptor[8*b+:8]=write_data;descriptor[24+b]=1;end
            owned_descriptor=descriptor;owned_glyph={descriptor[20:16],descriptor[7:0]};
            font_offers=0;font_acks=0;admissions++;
            if(!host_mode) begin
                cpu_writes++;
                $fdisplay(trace_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d",cpu_boot,a,write_select,write_cell,write_data,owned_descriptor,owned_glyph);
            end
        end
        if(update_valid) begin
            assert(owned && !offered && update_cell==CELL_BITS'(owned_cell) &&
                update_glyph==owned_glyph && update_descriptor==owned_descriptor)
                else $fatal(1,"Z_VRAM_DESCRIPTOR_INTENT");
            if(update_ready) begin offered=1;offers++;end
        end
        if(font_read && !previous_font_read) begin
            assert(owned && offered && font_offers<32 && !expected_ddr_read) else $fatal(1,"Z_VRAM_FONT_OWNER");
            expected_font_address={owned_glyph,5'(font_offers)};font_offers++;expected_ddr_read=1;
        end
        if(font_read) assert(font_address==expected_font_address) else $fatal(1,"Z_VRAM_FONT_ADDRESS");
        previous_font_read=font_read;
        if(font_valid && font_response_ack) font_acks++;
        if(ram_write!=0) begin
            assert(owned && offered && update_done && update_done_ready && font_acks==32 &&
                ram_write==owned_select && ram_address==CELL_BITS'(owned_cell) && ram_data==owned_data && (!write_valid || !wait_n))
                else $fatal(1,"Z_VRAM_COMMIT_OWNER");
            model_descriptor[owned_cell]=owned_descriptor;model_visible[owned_cell]=1;
            owned=0;commits++;
        end
        if(!idle && write_valid && !update_done && ram_write!=0) $fatal(1,"Z_VRAM_EARLY_RAM");
        if(pending) begin if(DDRAM_DOUT_READY) pending=0;else if(delay_left>0) delay_left--;end
        if((DDRAM_RD||DDRAM_WE)&&!DDRAM_BUSY) begin
            if(DDRAM_WE) begin
                assert(writes<262144 && DDRAM_ADDR==BASE+29'(writes/8) &&
                    DDRAM_BE==(8'd1<<(writes%8)) && DDRAM_DIN=={8{font(writes)}})
                    else $fatal(1,"Z_VRAM_UPLOAD_INTENT");
                for(integer b=0;b<8;b++) if(DDRAM_BE[b]) font_image[(int'(DDRAM_ADDR)-int'(BASE))*8+b]=DDRAM_DIN[8*b+:8];
                writes++;
            end else begin
                assert(expected_ddr_read && DDRAM_ADDR==BASE+29'(expected_font_address/8) &&
                    DDRAM_BE==8'hff && !pending) else $fatal(1,"Z_VRAM_DDR_INTENT");
                expected_ddr_read=0;reads++;pending=1;pending_word=DDRAM_ADDR;delay_left=3+reads%5;
            end
        end
    end
    bit video_reset=1,blink_level=0;
    wire [13:0] beam_address;
    wire [4:0] graphics_ra,video_phase;
    wire graphics_start,graphics_load,ce_pixel,graphics_disp,hs,vs,hb,vb;
    wire [2:0] actual_rgb;
    wire [7:0] text_packet,attr_packet,kan_packet,glyph_packet;
    wire packet_valid,packet_partial;
    wire capture_phase=ce_pixel && video_phase==5'b01010;
    wire [17:0] renderer_address;
    wire renderer_select;
    wire unused_miss,unused_unsupported;
    bit crtc_write=0,crtc_rs=0;
    logic [7:0] crtc_data=0;
    string frame_dir;
    integer captures=0,rgb_edges=0,stale_witnesses=0,frames=0;
    x1_z_kanji_video #(.CELL_BITS(CELL_BITS)) adapter(
        .clk_vid(clk_vid),.video_reset(video_reset),.prefetch_start(graphics_start),.consume_capture(capture_phase),
        .allow_partial_ank(1'b0),.packet_partial(packet_partial),
        .beam_cell(beam_address[CELL_BITS-1:0]),.beam_row(graphics_ra[3:0]),
        .cache_request(vid_request),.cache_cell(vid_cell),.cache_offset(vid_offset),
        .cache_response_valid(vid_response_valid),.cache_response_hit(vid_response_hit),
        .cache_response_cell(vid_response_cell),.cache_response_offset(vid_response_offset),
        .cache_response_glyph(vid_response_glyph),.cache_response_descriptor(vid_response_descriptor),
        .cache_response_data(vid_response_data),.packet_valid(packet_valid),
        .text_data(text_packet),.attr_data(attr_packet),.kan_data(kan_packet),.glyph_data(glyph_packet));
    wire [7:0] unused_od;
    wire [2:0] unused_color;
    wire [10:0] unused_cga;
    wire [11:0] unused_ank;
    wire [16:0] unused_kaddr;
    wire [11:0] unused_ports;
    x1_vid #(.ENABLE_CRTC(1),.TURBO_SUPPORT(1),.TURBO_CLOCKS(1),.SEPARATE_VIDEO_RESET(1),
        .SEPARATE_CRTC_BUS(1),.Z_KANJI_RENDER(1),.EXTERNAL_TEXT_PACKET(1)) renderer(
        .I_VIDEO_RESET(video_reset),.I_RESET(video_reset),.I_CCLK(clk),.I_VCLK(clk_vid),
        .I_CRTC_BUS_CLK(clk_vid),.I_CRTC_BUS_RS(crtc_rs),.I_CRTC_BUS_DATA(crtc_data),.I_CRTC_BUS_WRITE(crtc_write),
        .I_TURBO_BLACK(7'd0),.I_TURBO_HIGH_SCAN(1'b1),.I_TURBO_TEXT_Y2(1'b0),.I_TURBO_UNDERLINE(1'b0),
        .I_A(16'd0),.I_D(8'd0),.O_D(unused_od),.O_DE(unused_ports[0]),.I_WR(1'b0),.I_RD(1'b0),.O_VWAIT(unused_ports[1]),
        .I_CRTC_CS(1'b0),.I_CG_CS(1'b0),.I_PAL_CS(1'b0),.I_TXT_CS(1'b0),.I_ATT_CS(1'b0),.I_KAN_CS(1'b0),
        .I_GRB_CS(1'b0),.I_GRR_CS(1'b0),.I_GRG_CS(1'b0),.I_CLK1(blink_level),.I_W40(WIDTH40!=0),
        .O_VQ(video_phase),.O_VA(beam_address),.O_GRAPHICS_RA(graphics_ra),
        .O_GRAPHICS_START(graphics_start),.O_GRAPHICS_LOAD(graphics_load),.O_GRAPHICS_DISP(graphics_disp),
        .O_CG_TRANSPARENT(unused_ports[2]),.O_CG_COLOR(unused_color),.O_TXT_WE(unused_ports[3]),.O_ATT_WE(unused_ports[4]),.O_KAN_WE(unused_ports[5]),
        .I_TXT_D(LIVE_METADATA!=0 ? raw_text : text_packet),
        .I_ATT_D(LIVE_METADATA!=0 ? raw_attr : attr_packet),.I_KAN_D(LIVE_METADATA!=0 ? raw_kan : kan_packet),
        .O_GRB_WE(unused_ports[6]),.O_GRR_WE(unused_ports[7]),.O_GRG_WE(unused_ports[8]),.I_GRB_D(8'd0),.I_GRR_D(8'd0),.I_GRG_D(8'd0),
        .O_CGA(unused_cga),.O_ANK16_ADDR(unused_ank),.I_CG_D(renderer_select ? glyph_packet ^ (GLYPH_FAULT!=0 ? 8'h80 : 8'd0) : 8'd0),
        .I_PCGB_D(8'd0),.I_PCGR_D(8'd0),.I_PCGG_D(8'd0),.O_KANJI_ADDR(unused_kaddr),.O_KANJI_SELECT(unused_ports[9]),.O_KANJI_LEVEL1(unused_ports[10]),
        .O_Z_KANJI_ADDR(renderer_address),.O_Z_KANJI_SELECT(renderer_select),.I_Z_KANJI_VALID(packet_valid),
        .I_TEXT_PACKET_VALID(packet_valid),
        .O_Z_KANJI_MISS(unused_miss),.O_Z_KANJI_UNSUPPORTED(unused_unsupported),
        .O_R(actual_rgb[1]),.O_G(actual_rgb[2]),.O_B(actual_rgb[0]),.O_HSYNC(hs),.O_VSYNC(vs),
        .O_VDISP(unused_ports[11]),.O_HBLANK(hb),.O_VBLANK(vb),.O_CE_PIXEL(ce_pixel));
    logic [1:0] request_history=0;
    logic [CELL_BITS-1:0] expected_cell=0;
    logic [3:0] expected_row=0;
    logic [23:0] expected_metadata=0,captured_metadata=0;
    logic [7:0] expected_data=0,captured_data=0,model_shift=0,model_attr=0;
    bit expected_valid=0,captured_valid=0,model_blank=1,checking_rgb=0;
    initial forever begin : render_oracle
        logic [31:0] descriptor;
        logic [2:0] predicted_rgb;
        bit do_capture,selected;
        logic [17:0] captured_address;
        @(posedge clk_vid);vid_edges++;
        assert(!packet_partial) else $fatal(1,"Z_PIXEL_UNEXPECTED_PARTIAL");
        do_capture=0;captured_address=0;
        predicted_rgb=graphics_disp && !model_blank ?
            (!model_attr[5] && model_shift[7] ? model_attr[2:0] : 3'd0) ^ {3{model_attr[3] ^ (model_attr[4] && blink_level)}} : 3'd0;
        if(video_reset) begin
            request_history=0;expected_metadata=0;expected_data=0;expected_valid=0;
            captured_metadata=0;captured_data=0;captured_valid=0;
            model_shift=0;model_attr=0;model_blank=1;checking_rgb=0;
        end else begin
            if(graphics_start) begin
                assert(beam_address[13:11]==graphics_ra[2:0] && graphics_ra<16) else $fatal(1,"Z_PIXEL_BEAM");
                expected_cell=beam_address[CELL_BITS-1:0];expected_row=graphics_ra[3:0];
                expected_metadata=0;expected_data=0;expected_valid=0;
            end else if(request_history[1]) begin
                assert(vid_response_valid && vid_response_cell==expected_cell && vid_response_offset[4:1]==expected_row)
                    else $fatal(1,"Z_PIXEL_REPLY_TAG");
                replies++;
                if(vid_response_hit) begin
                    if(owned && int'(expected_cell)==owned_cell && vid_response_descriptor==owned_descriptor && font_acks==32)
                        descriptor=owned_descriptor;
                    else begin
                        assert(model_visible[expected_cell] && vid_response_descriptor==model_descriptor[expected_cell])
                            else $fatal(1,"Z_PIXEL_PUBLICATION_OWNER");
                        descriptor=model_descriptor[expected_cell];
                    end
                    assert(vid_response_glyph=={descriptor[20:16],descriptor[7:0]} && vid_response_offset[0]==descriptor[22] &&
                        vid_response_data==font(int'({descriptor[20:16],descriptor[7:0],expected_row,descriptor[22]})))
                        else $fatal(1,"Z_PIXEL_REPLY_BYTE");
                    if(descriptor[31:24]==7) begin
                        expected_metadata=descriptor[23:0];expected_data=font(int'({descriptor[20:16],descriptor[7:0],expected_row,descriptor[22]}));expected_valid=1;
                    end
                end else assert(!model_visible[expected_cell] && vid_response_data==0 && vid_response_glyph==0 && vid_response_descriptor==0 && !vid_response_offset[0])
                    else $fatal(1,"Z_PIXEL_REPLY_MISS");
            end
            request_history={request_history[0],vid_request};
            if(capture_phase) begin
                assert(packet_valid==expected_valid && {kan_packet,attr_packet,text_packet}==expected_metadata && glyph_packet==expected_data &&
                    expected_cell==beam_address[CELL_BITS-1:0] && expected_row==graphics_ra[3:0]) else $fatal(1,"Z_PIXEL_CAPTURE_PACKET");
                captured_metadata=expected_metadata;captured_data=expected_data;captured_valid=expected_valid;captures++;
                if(expected_valid && {raw_kan,raw_attr,raw_text}!=expected_metadata) stale_witnesses++;
                captured_address={expected_metadata[20:16],expected_metadata[7:0],expected_row,expected_metadata[22]};
                do_capture=1;
            end
            if(ce_pixel && (!model_attr[7] || !video_phase[2])) model_shift={model_shift[6:0],1'b0};
            if(graphics_load) begin
                assert(packet_valid==captured_valid && {kan_packet,attr_packet,text_packet}==captured_metadata && glyph_packet==captured_data)
                    else $fatal(1,"Z_PIXEL_LOAD_PACKET");
                selected=!captured_metadata[13] && captured_metadata[23];
                model_shift=selected ? captured_data : 8'd0;model_attr=captured_metadata[15:8];
                model_blank=selected && (|model_attr[7:6] || !captured_valid);
                checking_rgb=1;
            end
        end
        #3;
        if(do_capture) assert(renderer_address==captured_address && renderer_select==(!captured_metadata[13] && captured_metadata[23]))
            else $fatal(1,"Z_PIXEL_RENDERER_CAPTURE");
        if(checking_rgb && !video_reset) begin
            assert(actual_rgb==predicted_rgb) else $fatal(1,"Z_PIXEL_RGB got=%0d expected=%0d",actual_rgb,predicted_rgb);
            rgb_edges++;
        end
    end
    bit frame_requested=0,frame_open=0,old_hs=0,old_vs=0;
    integer frame_number=0,settle_frames=0,frame_fd=0,x=0,y=0,frame_pixels=0;
    task automatic bus_crtc(input bit rs_value,input logic [7:0] value);
        @(negedge clk_vid);crtc_rs=rs_value;crtc_data=value;crtc_write=1;
        @(posedge clk_vid);#2;@(negedge clk_vid);crtc_write=0;
    endtask
    task automatic program_crtc();
        logic [7:0] value;
        for(integer r=0;r<16;r++) begin
            case(r)
                0:value=WIDTH40!=0 ? 8'd55 : 8'd111;
                1:value=8'(COLUMNS);
                2:value=WIDTH40!=0 ? 8'd46 : 8'd92;
                3:value=8'h28;4:value=27;6:value=25;7:value=26;9:value=15;
                default:value=0;
            endcase
            bus_crtc(0,8'(r));bus_crtc(1,value);
        end
    endtask
    task automatic frame_capture(input integer number);
        assert(!frame_requested && !frame_open) else $fatal(1,"Z_PIXEL_FRAME_OWNER");
        frame_number=number;settle_frames=2;frame_requested=1;
        while(frame_requested) @(negedge clk_vid);
    endtask
    initial forever begin : frame_collector
        bit pixel_edge;
        @(posedge clk_vid);pixel_edge=ce_pixel;#4;
        if(video_reset) begin old_hs=0;old_vs=0;end
        else if(pixel_edge) begin
            if(hs && !old_hs && x!=0) begin assert(x==COLUMNS*8) else $fatal(1,"Z_PIXEL_FRAME_WIDTH");x=0;y++;end
            if(vs && !old_vs) begin
                if(frame_open) begin
                    assert(frame_pixels==COLUMNS*8*400 && y==400) else $fatal(1,"Z_PIXEL_FRAME_SIZE");
                    $fclose(frame_fd);frame_fd=0;frame_open=0;frames++;frame_requested=0;
                end
                if(frame_requested) begin
                    if(settle_frames!=0) settle_frames--;
                    else begin
                        frame_fd=$fopen($sformatf("%s/frame-%0d.csv",frame_dir,frame_number),"w");
                        assert(frame_fd!=0) else $fatal(1,"Z_PIXEL_FRAME_OPEN");
                        $fdisplay(frame_fd,"y,x,rgb");frame_open=1;frame_pixels=0;
                    end
                end
                x=0;y=0;
            end
            if(frame_open && !hb && !vb) begin $fdisplay(frame_fd,"%0d,%0d,%0d",y,x,actual_rgb);x++;frame_pixels++;end
            old_hs=hs;old_vs=vs;
        end
    end
    // A real Z80 checks each write with a real IN, writes its own completion
    // marker and HALTs. No forced registers/results. RAM is the diagnostic IPL
    // surrogate; the full font enters only through the real upload interface.
    logic [7:0] memory[0:65535];
    logic [7:0] memory_data,io_data;
    logic io_active;
    integer divider;
    initial divider=0;
    always @(negedge clk) divider<=divider==CE_PERIOD-1 ? 0 : divider+1;
    wire cpu_ce=divider==0;
    wire [7:0] cpu_di=!mreq ? memory_data : io_active ? io_data : 8'hff;
    cpu processor(.clock(clk),.cep(cpu_ce),.cen(1'b0),.reset_n(!cpu_reset),.int_n(1'b1),
        .wait_n(wait_n),.busrq_n(1'b1),.busak_n(busak_n),.di(cpu_di),.a(a),.data_out(data_out),
        .mreq(mreq),.iorq(iorq),.rd(rd),.wr(wr),.m1(m1),.halt_n(halt_n),.rfsh_n(unused_rfsh_n),
        .dir(16'd0),.dirset(1'b0));
    always @(posedge clk) begin
        memory_data<=memory[a];
        io_active<=cpu_io_read;
        io_data<=(cpu_select[0] ? ram_text : cpu_select[1] ? ram_attr : cpu_select[2] ? ram_kan : 8'hff);
        if(!cpu_io_read) read_logged<=0;
        else if(cpu_ce && !read_logged) begin
            $fdisplay(read_fd,"%0d,%0d,%0d",cpu_boot,a,cpu_di);read_logged<=1;
        end
        if(!cpu_reset && !mreq && !wr) memory[a]<=data_out;
    end
    integer code_size=0;
    task automatic emit(input logic [7:0] value);memory[code_size]=value;code_size++;endtask
    task automatic output_check(input logic [15:0] port_value,input logic [7:0] value);
        emit(8'h01);emit(port_value[7:0]);emit(port_value[15:8]);emit(8'h3e);emit(value);emit(8'hed);emit(8'h79);
        emit(8'hed);emit(8'h78);emit(8'hfe);emit(value);emit(8'hc2);emit(0);emit(8'hf1);
    endtask
    task automatic tick(input integer n=1);repeat(n) begin @(posedge clk);#2;end endtask
    task automatic start_host(input integer cell_number,input logic [2:0] select_value,input logic [7:0] value);
        assert(idle && !owned && cell_number>=0 && cell_number<CELLS) else $fatal(1,"Z_VRAM_HOST_START");
        @(negedge clk);host_cell=CELL_BITS'(cell_number);host_select=select_value;host_data=value;host_valid=1;
    endtask
    task automatic finish_host();
        integer n=0,old_commits;
        while(!wait_n && n<15000) begin tick();n++;end
        assert(wait_n && !owned) else $fatal(1,"Z_VRAM_HOST_COMPLETION");
        old_commits=commits;tick(12);
        assert(wait_n && commits==old_commits && ram_write==0 && !idle) else $fatal(1,"Z_VRAM_HELD_REQUEST");
        @(negedge clk);host_valid=0;tick(3);
        assert(idle) else $fatal(1,"Z_VRAM_REARM");
    endtask
    task automatic poison_host();
        tick();@(negedge clk);host_cell=~host_cell;host_select=~host_select;host_data=~host_data;
    endtask
    task automatic boot();
        @(negedge clk);cpu_reset=1;tick(32);cpu_boot++;
        @(negedge clk);cpu_reset=0;
    endtask
    task automatic finish_cpu();
        integer n=0;
        while(halt_n && n<300000) begin tick();n++;end
        assert(!halt_n && memory[16'hf000]==8'ha5) else $fatal(1,"Z_VRAM_CPU_ORACLE marker=%0d boot=%0d writes=%0d",memory[16'hf000],cpu_boot,cpu_writes);
        tick(40);assert(idle && !owned) else $fatal(1,"Z_VRAM_CPU_RETIRE");completed_boots++;
    endtask
    initial begin : scenarios
        integer before_count,busy_ticks;
        assert($value$plusargs("FRAMES=%s",frame_dir)) else $fatal(1,"Z_PIXEL_FRAME_PATH");
        assert($value$plusargs("TRACE=%s",trace_path) && $value$plusargs("PROGRAM=%s",program_path) && $value$plusargs("READ_TRACE=%s",read_path)) else $fatal(1,"Z_VRAM_ARTIFACT_PATHS");
        trace_fd=$fopen(trace_path,"w");program_fd=$fopen(program_path,"w");read_fd=$fopen(read_path,"w");
        assert(trace_fd!=0 && program_fd!=0 && read_fd!=0) else $fatal(1,"Z_VRAM_ARTIFACT_OPEN");
        $fdisplay(trace_fd,"boot,port,select,cell,data,descriptor,glyph");
        $fdisplay(read_fd,"boot,port,value");
        for(integer c=0;c<CELLS;c++) begin model_descriptor[c]=0;model_visible[c]=0;end
        for(integer c=0;c<65536;c++) memory[c]=0;
        emit(8'hf3);emit(8'h31);emit(8'hff);emit(8'hff);emit(8'h3e);emit(0);emit(8'h32);emit(0);emit(8'hf0);
        for(integer g=0;g<8;g++) begin
            output_check(16'h3000|16'(g%3),8'(g*37+11));
            output_check(16'h2800|16'(g%3),8'(g%7+1+((g&1)<<3)+((g&2)<<3)));
            output_check(16'h3800|16'(g%3),8'(32'h80|(g<<4)|g));
        end
        emit(8'h3e);emit(8'ha5);emit(8'h32);emit(0);emit(8'hf0);emit(8'h76);
        memory[16'hf100]=8'h3e;memory[16'hf101]=8'hee;memory[16'hf102]=8'h32;memory[16'hf103]=0;memory[16'hf104]=8'hf0;memory[16'hf105]=8'h76;
        for(integer c=0;c<65536;c++) $fdisplay(program_fd,"%02x",memory[c]);$fclose(program_fd);
        tick(32);
        for(integer c=0;c<CELLS;c++) begin
            @(negedge clk);seed_mode=1;seed_cell=CELL_BITS'(c);seed_data=8'hd1 ^ 8'(c);tick();
        end
        @(negedge clk);seed_mode=0;ioctl_download=1;
        for(integer b=0;b<262144;b++) begin
            while(ioctl_wait) tick();
            @(negedge clk);ioctl_address=25'(b);ioctl_data=font(b);ioctl_wr=1;
            tick();@(negedge clk);ioctl_wr=0;
        end
        @(negedge clk);ioctl_download=0;while(upload_active) tick();
        assert(loaded && !upload_error && writes==262144) else $fatal(1,"Z_VRAM_FONT_LOADED");
        for(integer b=0;b<262144;b++) assert(font_image[b]==font(b)) else $fatal(1,"Z_VRAM_WHOLE_FONT");
        for(integer c=0;c<CELLS;c++) begin
            for(integer v=0;v<3;v++) begin : cold_planes
                integer plane_number;
                plane_number=(c+v)%3;
                start_host(c,3'(1<<plane_number),plane_number==0 ? 8'(c*31+7) :
                    plane_number==1 ? 8'(c%7+1+((c&1)<<3)+((c&2)<<3)) : 8'(32'h80|(c%128)));
                poison_host();finish_host();
            end
        end
        // Block admission, then retain a captured transaction despite lost
        // admission permission, BUSY memory and poisoned live bus inputs.
        admit_enable=0;before_count=admissions;
        start_host(CELLS-1,1,8'h92);tick(20);
        assert(admissions==before_count && !wait_n && idle && ram_write==0) else $fatal(1,"Z_VRAM_BLOCKED_ADMISSION");
        @(negedge clk);admit_enable=1;force_busy=1;poison_host();admit_enable=0;
        busy_ticks=0;while(!DDRAM_RD && busy_ticks<1000) begin tick();busy_ticks++;end
        assert(DDRAM_RD) else $fatal(1,"Z_VRAM_BUSY_OFFER");tick(20);
        assert(!wait_n && !idle && owned && ram_write==0) else $fatal(1,"Z_VRAM_BUSY_DRAIN");
        force_busy=0;finish_host();admit_enable=1;
        // A complete glyph cannot commit VRAM or release WAIT while VID is stopped.
        @(negedge clk_vid);run_vid=0;
        start_host(CELLS-1,4,8'hdf);poison_host();
        while(font_acks!=32) tick();tick(40);
        assert(owned && !wait_n && ram_write==0 && !idle) else $fatal(1,"Z_VRAM_STOPPED_VID");
        run_vid=1;finish_host();
        // Early bus retirement models a CPU reset: the admitted write drains
        // exactly once, and known metadata persists into the following boot.
        start_host(CELLS-2,2,8'h35);tick();@(negedge clk);host_valid=0;
        while(!idle) tick();assert(!owned) else $fatal(1,"Z_VRAM_EARLY_RETIRE");
        program_crtc();video_reset=0;frame_capture(0);
        // Freeze VID just after an actual phase-0 request for cell zero.
        // SYS completes a replacement glyph while the old reply is in flight.
        // Resume: cache publication and raw VRAM commit precede phase 10 at
        // SYS100, but the renderer must keep its older coherent packet.
        while(!(graphics_start && beam_address[10:0]==0 && graphics_ra==0)) @(negedge clk_vid);
        @(posedge clk_vid);@(negedge clk_vid);run_vid=0;
        start_host(0,1,8'h92);poison_host();
        while(font_acks!=32) tick();tick(20);run_vid=1;finish_host();
        host_mode=0;boot();finish_cpu();
        boot();before_count=cpu_writes;
        while(cpu_writes!=before_count+10) tick();
        @(negedge clk);cpu_reset=1;
        while(!idle) tick();
        assert(!owned && memory[16'hf000]!=8'ha5) else $fatal(1,"Z_VRAM_INTERRUPTED_BOOT");
        boot();finish_cpu();
        @(negedge clk);cpu_reset=1;tick(32);
        frame_capture(1);blink_level=1;frame_capture(2);
        @(negedge clk_vid);video_reset=1;tick(32);
        @(negedge clk_vid);video_reset=0;frame_capture(3);
        assert(idle && !owned) else $fatal(1,"Z_PIXEL_INVALIDATE_OWNER");
        @(negedge clk);invalidate=1;while(!invalidate_done) tick();
        for(integer c=0;c<CELLS;c++) model_visible[c]=0;
        frame_capture(4);
        assert(idle && !owned && admissions==CELLS*3+62 && offers==admissions && commits==admissions &&
            cpu_writes==58 && completed_boots==2 && reads==32*admissions && writes==262144 &&
            !pending && !expected_ddr_read && !font_read && wait_edges>1000 && replies>CELLS*32 &&
            captures>1000 && rgb_edges>10000 && frames==5 && (SYS_HALF_PS!=5000 || stale_witnesses>0))
            else $fatal(1,"Z_PIXEL_FINAL_LEDGER");
        $fclose(trace_fd);$fclose(read_fd);
        $display("PASS Z_RENDER cells=%0d admissions=%0d offers=%0d commits=%0d cpu_writes=%0d boots=%0d attempts=%0d reads=%0d writes=%0d wait_edges=%0d replies=%0d sys_half=%0d vid_half=%0d ce_period=%0d sys_edges=%0d vid_edges=%0d captures=%0d rgb_edges=%0d frames=%0d stale=%0d columns=%0d",CELLS,admissions,offers,commits,cpu_writes,completed_boots,cpu_boot,reads,writes,wait_edges,replies,SYS_HALF_PS,VID_HALF_PS,CE_PERIOD,sys_edges,vid_edges,captures,rgb_edges,frames,stale_witnesses,COLUMNS);
        $finish;
    end
    initial begin #800ms;$fatal(1,"Z_VRAM_TEST_TIMEOUT");end
endmodule
