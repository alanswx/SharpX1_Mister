// SPDX-License-Identifier: GPL-2.0-or-later
// Original standalone SIO asynchronous slice. Public register contract:
// Zilog UM008101-0601. Not translated from an emulator or wired to the X1.
// Supported: polled asynchronous 5..8 bits, N/E/O, 1/1.5/2 TX stops,
// x16/x32/x64 RX/TX event clocks and idle-transmitter Send Break.
// Interrupts, x1, WAIT/Ready, receive/busy-transmit break and modem
// gating, synchronous modes and live frame reconfiguration are unsupported.
// IRQ_ENABLE is used only by the separate standalone interrupt wrapper:
// it adds first/all-character RX, TX-empty and CTS/DCD requests, B-only RR2, A-only return,
// and channel command events. The default polled wrapper remains unchanged.
// FLOW_ENABLE separately opts into functional selected-port WAIT and Ready
// levels; this is not physical W/RDY bus-phase or open-drain implementation.
module x1_sio_async_channel #(parameter IRQ_ENABLE=0, parameter CHANNEL_B=0, parameter FLOW_ENABLE=0) (
    input wire clk, ce, reset,
    input wire cpu_cs, control, cpu_rd_n, cpu_wr_n,
    input wire [7:0] cpu_din,
    output reg [7:0] cpu_dout,
    input wire rx_tick, tx_tick, rxd, cts_n, dcd_n,
    output wire txd, rts_n, dtr_n,
    output reg unsupported,
    input wire interrupt_pending,
    input wire [7:0] rr2,
    output wire request_rx, request_tx, request_external, special_rx,
    output wire [7:0] vector_register,
    output wire status_vector, reset_channel, return_interrupt,
    input wire bus_selected,
    output wire wait_n, ready_n
);
    reg [7:0] wr1, wr2, wr3, wr4, wr5;
    reg [2:0] pointer;
    reg read_seen, write_seen;
    wire read_attempt = cpu_cs && !cpu_rd_n && !read_seen;
    wire write_attempt = cpu_cs && !cpu_wr_n && !write_seen;
    wire wait_mode = FLOW_ENABLE && wr1[7] && !wr1[6];
    wire read_blocked = wait_mode && wr1[5] && !control && fifo_count==0;
    wire write_blocked = wait_mode && !wr1[5] && !control && tx_holding_full;
    wire read_event = read_attempt && !read_blocked;
    wire write_event = write_attempt && !write_blocked;
    // Functional bus handshakes, not physical open-drain/half-clock timings.
    // A completed held strobe never reasserts WAIT after consuming its buffer.
    // Hold through the accepting edge as well: RX data is a clocked response.
    // Releasing merely on FIFO arrival would let a waiting CPU sample the old
    // response on the same edge that latches/pops the new byte.
    assign wait_n = reset || !(wait_mode && !control &&
        ((wr1[5] && read_attempt) || (!wr1[5] && write_attempt)));
    assign ready_n = reset || !(FLOW_ENABLE && wr1[7] && wr1[6] && !bus_selected &&
        (wr1[5] ? (fifo_count!=0 && !(error_locked && error_read_seen)) : !tx_holding_full));
    wire channel_reset = ce && write_event && control && pointer == 0 && cpu_din[5:3] == 3;
    wire error_reset = ce && write_event && control && pointer==0 && cpu_din[5:3]==6;
    wire external_reset = ce && write_event && control && pointer==0 && cpu_din[5:3]==2;
    wire interrupt_write = ce && write_event && control && pointer==1;
    assign reset_channel = channel_reset;
    assign return_interrupt = IRQ_ENABLE && ce && write_event && control && pointer==0 && cpu_din[5:3]==7;
    assign vector_register = wr2;
    assign status_vector = wr1[2];
    function automatic [3:0] character_bits(input [1:0] config_bits);
        case(config_bits)
            0: character_bits=5; 1: character_bits=7;
            2: character_bits=6; 3: character_bits=8;
        endcase
    endfunction
    function automatic [6:0] clock_divisor(input [1:0] config_bits);
        case(config_bits)
            1: clock_divisor=16; 2: clock_divisor=32;
            3: clock_divisor=64; default: clock_divisor=1;
        endcase
    endfunction
    function automatic [11:0] transmit_frame(input [7:0] data,
        input [3:0] bits, input parity_enable, even_parity);
        reg parity;
        transmit_frame=12'hfff; transmit_frame[0]=0; parity=0;
        for(integer bit_index=0;bit_index<8;bit_index=bit_index+1)
            if(bit_index<int'(bits)) begin
                transmit_frame[bit_index+1]=data[bit_index];
                parity=parity^data[bit_index];
            end
        if(parity_enable) transmit_frame[bits+1]=even_parity ? parity : !parity;
    endfunction
    wire supported_interrupts = IRQ_ENABLE ?
        (FLOW_ENABLE || wr1[7:5]==0) : wr1==0;
    wire polled_frame = supported_interrupts && wr4[7:6]!=0 && wr4[5:4]==0 && wr4[3:2]!=0;
    wire rx_enabled = polled_frame && wr3[0] && (wr3 & 8'h3e)==0;
    wire tx_enabled = polled_frame && wr5[3] && (wr5 & 8'h15)==0;
    reg [7:0] fifo_data[0:2];
    reg [6:0] fifo_error[0:2];
    reg fifo_first[0:2];
    reg first_armed;
    reg [1:0] fifo_count;
    reg overrun_latched, parity_latched;
    reg transmit_pending;
    wire first_mode = IRQ_ENABLE && wr1[4:3]==1;
    assign request_rx = IRQ_ENABLE && wr1[4:3]!=0 && fifo_count!=0 &&
        (!first_mode || fifo_first[0] || special_rx);
    assign request_tx = IRQ_ENABLE && wr1[1] && transmit_pending;
    assign special_rx = fifo_count!=0 && (fifo_error[0][6] || overrun_latched ||
        (wr1[4:3]==2 && parity_latched));
    // External inputs are synchronous levels supplied by the caller. Capture
    // on SYS independently of advancement CE, preserving short sampled pulses.
    // While disabled RR0 retains its inherited live-pin behavior.
    reg external_pending;
    reg [1:0] external_previous, external_snapshot;
    wire [1:0] external_pins = {cts_n,dcd_n};
    wire [1:0] external_status = IRQ_ENABLE && wr1[0] && external_pending ?
        external_snapshot : external_pins;
    assign request_external = IRQ_ENABLE && wr1[0] && external_pending;
    always @(posedge clk) begin
        if(reset || channel_reset) begin
            external_pending<=0; external_previous<=external_pins; external_snapshot<=external_pins;
        end else begin
            external_previous<=external_pins;
            if(external_reset || (interrupt_write && !cpu_din[0])) begin
                external_pending<=0; external_snapshot<=external_pins;
            end else if(IRQ_ENABLE && wr1[0] && !external_pending && external_pins!=external_previous) begin
                external_pending<=1; external_snapshot<=external_pins;
            end
        end
    end
    reg rx_busy;
    reg [5:0] rx_phase;
    reg [3:0] rx_bit, rx_bits;
    reg [6:0] rx_divisor, tx_divisor;
    reg rx_has_parity, rx_even, rx_parity, rx_bad_parity;
    reg [7:0] rx_shift;
    reg [5:0] framing_recovery;
    wire [3:0] rx_stop_bit = rx_bits+4'd1+{3'b0,rx_has_parity};
    wire rx_push = rx_tick && rx_enabled && rx_busy && rx_bit == rx_stop_bit &&
                   {1'b0,rx_phase} == rx_divisor-7'd1;
    wire error_locked = first_mode && fifo_count!=0 && (fifo_error[0][6] || overrun_latched);
    // First-character special errors retain their word even after a read.
    // Allow one Ready-paced transfer, then inhibit further DMA reads until
    // Error Reset. CPU inspection remains readable; no FIFO pop is invented.
    // UM008101-0601 printed 237 motivates this functional policy, not exact
    // W/RDY edge timing. The default (FLOW_ENABLE=0) remains unchanged.
    reg error_read_seen;
    wire rx_pop = fifo_count!=0 && ((read_event && !control && !error_locked) ||
        (error_reset && error_locked));
    wire incoming_first = first_mode && first_armed;
    reg tx_holding_full, tx_busy;
    reg [7:0] tx_holding;
    reg [11:0] tx_shift;
    reg [6:0] tx_phase;
    reg [3:0] tx_bit, tx_stop_bit;
    reg [7:0] tx_stop_ticks;
    wire tx_take = tx_tick && tx_enabled && !tx_busy && tx_holding_full;
    // UM0081 printed 288: Send Break forces TxD spacing independently of
    // serial ticks and TX enable. Only idle/no-pending-data use is qualified;
    // frame/queue behavior while breaking remains explicitly unsupported.
    assign txd = wr5[4] ? 1'b0 : tx_busy ? tx_shift[0] : 1'b1;
    assign rts_n = !wr5[1];
    assign dtr_n = !wr5[7];

    always @(posedge clk) begin
        // Chip reset remains effective with advancement enables stopped.
        if (reset || channel_reset) begin
            wr1<=0; wr2<=0; wr3<=0; wr4<=0; wr5<=0; pointer<=0;
            read_seen<=0; write_seen<=channel_reset; cpu_dout<=0; unsupported<=0;
            error_read_seen<=0;
            fifo_count<=0; overrun_latched<=0; parity_latched<=0; transmit_pending<=0;
            first_armed<=0; // Explicit WR0 next-character command arms this subset.
            for(integer i=0;i<3;i=i+1) begin fifo_data[i]<=0; fifo_error[i]<=0; fifo_first[i]<=0; end
            rx_busy<=0; rx_phase<=0; rx_bit<=0; rx_shift<=0; framing_recovery<=0;
            rx_bits<=8; rx_divisor<=16; rx_has_parity<=0; rx_even<=0;
            rx_parity<=0; rx_bad_parity<=0;
            tx_holding_full<=0; tx_busy<=0; tx_holding<=0;
            tx_shift<=12'hfff; tx_phase<=0; tx_bit<=0; tx_stop_bit<=9;
            tx_divisor<=16; tx_stop_ticks<=16;
        end else if (ce) begin
            if(error_reset || !error_locked) error_read_seen<=0;
            else if(read_event && !control) error_read_seen<=1;
            if(!cpu_cs || cpu_rd_n) read_seen<=0;
            if(!cpu_cs || cpu_wr_n) write_seen<=0;
            if(read_event) begin
                read_seen<=1;
                if(!control) cpu_dout<=fifo_count != 0 ? fifo_data[0] : 8'h00;
                else begin
                    case(pointer)
                        // RR0: real buffering/pin levels; no invented IRQ.
                        0: cpu_dout<={1'b0,1'b0,!external_status[1],1'b0,!external_status[0],!tx_holding_full,interrupt_pending,fifo_count!=0};
                        1: cpu_dout<={1'b0,(fifo_count!=0 ? fifo_error[0][6] : 1'b0),
                            overrun_latched,parity_latched,3'b000,!tx_busy && !tx_holding_full};
                        2: begin
                            if(IRQ_ENABLE && CHANNEL_B) cpu_dout<=rr2;
                            else begin cpu_dout<=8'hff; unsupported<=1; end
                        end
                        default: begin cpu_dout<=8'hff; unsupported<=1; end
                    endcase
                    pointer<=0;
                end
            end
            if(write_event) begin
                write_seen<=1;
                if(!control) begin
                    if(wr5[4]) unsupported<=1;
                    transmit_pending<=0;
                    if(tx_holding_full && !tx_take) unsupported<=1;
                    else begin tx_holding<=cpu_din; tx_holding_full<=1; end
                end else if(pointer!=0) begin
                    case(pointer)
                        1: begin
                            wr1<=cpu_din;
                            if(IRQ_ENABLE ? (!FLOW_ENABLE && cpu_din[7:5]!=0) : cpu_din!=0)
                                unsupported<=1;
                            if(!cpu_din[1]) transmit_pending<=0;
                        end
                        2: wr2<=cpu_din; // B consumed only by the interrupt wrapper.
                        3: begin
                            wr3<=cpu_din;
                            if((cpu_din & 8'h3e)!=0 || rx_busy) unsupported<=1;
                        end
                        4: begin
                            wr4<=cpu_din;
                            if(cpu_din[7:6]==0 || cpu_din[5:4]!=0 || cpu_din[3:2]==0 ||
                               rx_busy || tx_busy) unsupported<=1;
                        end
                        5: begin
                            wr5<=cpu_din;
                            if((cpu_din & 8'h05)!=0 || tx_busy || (cpu_din[4] && tx_holding_full)) unsupported<=1;
                        end
                        default: unsupported<=1;
                    endcase
                    pointer<=0;
                end else begin
                    pointer<=cpu_din[2:0];
                    case(cpu_din[5:3])
                        0: ;
                        2: if(!IRQ_ENABLE) unsupported<=1;
                        4: if(!IRQ_ENABLE) unsupported<=1;
                        6: begin overrun_latched<=0; parity_latched<=0; end
                        5: begin
                            if(IRQ_ENABLE) transmit_pending<=0;
                            else unsupported<=1;
                        end
                        7: if(!IRQ_ENABLE || CHANNEL_B) unsupported<=1;
                        default: unsupported<=1;
                    endcase
                    if(cpu_din[7:6]!=0) unsupported<=1;
                end
            end

            // Three physical buffers. The fourth character replaces the
            // third, not the oldest; see primary printed pages 236–237.
            // Framing follows its character; overrun is sticky until WR0 reset.
            case({rx_push,rx_pop})
                2'b01: begin
                    fifo_data[0]<=fifo_data[1]; fifo_data[1]<=fifo_data[2];
                    fifo_error[0]<=fifo_error[1]; fifo_error[1]<=fifo_error[2];
                    fifo_first[0]<=fifo_first[1]; fifo_first[1]<=fifo_first[2];
                    fifo_count<=fifo_count-1'b1;
                    if(fifo_count>1 && fifo_error[1][5]) overrun_latched<=1;
                    if(fifo_count>1 && fifo_error[1][4]) parity_latched<=1;
                end
                2'b10: begin
                    if(fifo_count==3) begin
                        fifo_data[2]<=rx_shift; fifo_error[2]<={!rxd,1'b1,rx_bad_parity,4'b0};
                        fifo_first[2]<=incoming_first;
                    end else begin
                        fifo_data[fifo_count]<=rx_shift; fifo_error[fifo_count]<={!rxd,1'b0,rx_bad_parity,4'b0};
                        fifo_first[fifo_count]<=incoming_first;
                        fifo_count<=fifo_count+1'b1;
                        if(fifo_count==0 && rx_bad_parity) parity_latched<=1;
                    end
                end
                2'b11: begin
                    fifo_data[0]<=fifo_data[1]; fifo_data[1]<=fifo_data[2];
                    fifo_error[0]<=fifo_error[1]; fifo_error[1]<=fifo_error[2];
                    fifo_first[0]<=fifo_first[1]; fifo_first[1]<=fifo_first[2];
                    fifo_data[fifo_count-1'b1]<=rx_shift;
                    fifo_error[fifo_count-1'b1]<={!rxd,1'b0,rx_bad_parity,4'b0};
                    fifo_first[fifo_count-1'b1]<=incoming_first;
                    if(fifo_count>1 && fifo_error[1][5]) overrun_latched<=1;
                    if((fifo_count>1 && fifo_error[1][4]) ||
                       (fifo_count==1 && rx_bad_parity)) parity_latched<=1;
                end
                default: ;
            endcase
            // Pre-edge arming applies to this completion. A same-edge WR0
            // arm applies to the following character, not the completing one.
            if(rx_push && incoming_first) first_armed<=0;
            if(ce && write_event && control && pointer==0 && cpu_din[5:3]==4 && IRQ_ENABLE)
                first_armed<=1;

            if(!rx_enabled) begin rx_busy<=0; framing_recovery<=0; end
            else if(rx_tick) begin
                if(framing_recovery!=0) framing_recovery<=framing_recovery-1'b1;
                else if(!rx_busy) begin
                    if(!rxd) begin
                        rx_busy<=1; rx_bit<=0; rx_phase<=0; rx_shift<=8'hff;
                        rx_bits<=character_bits(wr3[7:6]); rx_divisor<=clock_divisor(wr4[7:6]);
                        rx_has_parity<=wr4[0]; rx_even<=wr4[1]; rx_parity<=0; rx_bad_parity<=0;
                    end
                end else if(rx_bit==0) begin
                    if({1'b0,rx_phase}==(rx_divisor>>1)-7'd1) begin
                        rx_phase<=0;
                        if(rxd) rx_busy<=0; // reject a short false start.
                        else rx_bit<=1;
                    end else rx_phase<=rx_phase+1'b1;
                end else if({1'b0,rx_phase}==rx_divisor-7'd1) begin
                    rx_phase<=0;
                    if(rx_bit==rx_stop_bit) begin
                        rx_busy<=0;
                        if(!rxd) framing_recovery<=6'(rx_divisor>>1);
                    end else begin
                        if(rx_bit<=rx_bits) begin
                            rx_shift[3'(rx_bit-1'b1)]<=rxd;
                            rx_parity<=rx_parity^rxd;
                        end else begin
                            rx_bad_parity<=rxd!=(rx_even ? rx_parity : !rx_parity);
                            if(rx_bits<8) rx_shift[rx_bits[2:0]]<=rxd;
                        end
                        rx_bit<=rx_bit+1'b1;
                    end
                end else rx_phase<=rx_phase+1'b1;
            end

            if(!tx_enabled) begin tx_busy<=0; tx_phase<=0; end
            else if(tx_tick) begin
                if(tx_take) begin
                    // Becoming empty requires actual data, not merely enabling
                    // TX interrupts while its holding register is already empty.
                    // A same-edge replacement keeps holding full and cannot
                    // generate an empty interrupt.
                    if(wr1[1] && !(write_event && !control)) transmit_pending<=1;
                    tx_shift<=transmit_frame(tx_holding,character_bits(wr5[6:5]),wr4[0],wr4[1]);
                    tx_busy<=1; tx_phase<=0; tx_bit<=0;
                    tx_divisor<=clock_divisor(wr4[7:6]);
                    tx_stop_bit<=character_bits(wr5[6:5])+4'd1+{3'b0,wr4[0]};
                    case(wr4[3:2])
                        1: tx_stop_ticks<={1'b0,clock_divisor(wr4[7:6])};
                        2: tx_stop_ticks<={1'b0,clock_divisor(wr4[7:6])}+{1'b0,(clock_divisor(wr4[7:6])>>1)};
                        default: tx_stop_ticks<={clock_divisor(wr4[7:6]),1'b0};
                    endcase
                    // A simultaneous CPU write replaces the taken holding byte.
                    if(!(write_event && !control)) tx_holding_full<=0;
                end else if(tx_busy) begin
                    if({1'b0,tx_phase}+8'd1 == (tx_bit==tx_stop_bit ? tx_stop_ticks : {1'b0,tx_divisor})) begin
                        tx_phase<=0; tx_shift<={1'b1,tx_shift[11:1]};
                        if(tx_bit==tx_stop_bit) tx_busy<=0;
                        else tx_bit<=tx_bit+1'b1;
                    end else tx_phase<=tx_phase+1'b1;
                end
            end
        end
    end
endmodule

module x1_sio_async (
    input wire clk, ce, reset, cpu_cs, cpu_rd_n, cpu_wr_n,
    input wire [1:0] address,
    input wire [7:0] cpu_din,
    output wire [7:0] cpu_dout,
    input wire [1:0] rx_tick, tx_tick, rxd, cts_n, dcd_n,
    output wire [1:0] txd, rts_n, dtr_n,
    output wire unsupported
);
    wire [7:0] channel_data[0:1];
    wire [1:0] unsupported_channel;
    assign cpu_dout = channel_data[address[1]];
    assign unsupported = |unsupported_channel;
    for(genvar channel=0;channel<2;channel=channel+1) begin : channels
        x1_sio_async_channel unit (
            .clk(clk), .ce(ce), .reset(reset), .cpu_cs(cpu_cs && address[1]==1'(channel)),
            .control(address[0]), .cpu_rd_n(cpu_rd_n), .cpu_wr_n(cpu_wr_n),
            .cpu_din(cpu_din), .cpu_dout(channel_data[channel]),
            .rx_tick(rx_tick[channel]), .tx_tick(tx_tick[channel]), .rxd(rxd[channel]),
            .cts_n(cts_n[channel]), .dcd_n(dcd_n[channel]), .txd(txd[channel]),
            .rts_n(rts_n[channel]), .dtr_n(dtr_n[channel]), .unsupported(unsupported_channel[channel]),
            .interrupt_pending(1'b0), .rr2(8'hff), .request_rx(), .request_tx(), .request_external(),
            .special_rx(), .vector_register(), .status_vector(), .reset_channel(), .return_interrupt(),
            .bus_selected(1'b0), .wait_n(), .ready_n()
        );
    end
endmodule
