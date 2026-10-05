// SPDX-License-Identifier: GPL-2.0-or-later
// Original standalone SIO asynchronous slice. Public register contract:
// Zilog UM008101-0601. Not translated from an emulator or wired to the X1.
// Supported serial profile: polled 8N1, x16 RX/TX clocks only. Interrupts,
// WAIT/Ready, break/modem gating, other frame formats and sync are unsupported.
module x1_sio_async_channel (
    input wire clk, ce, reset,
    input wire cpu_cs, control, cpu_rd_n, cpu_wr_n,
    input wire [7:0] cpu_din,
    output reg [7:0] cpu_dout,
    input wire rx_tick, tx_tick, rxd, cts_n, dcd_n,
    output wire txd, rts_n, dtr_n,
    output reg unsupported
);
    reg [7:0] wr1, wr2, wr3, wr4, wr5;
    reg [2:0] pointer;
    reg read_seen, write_seen;
    wire read_event = cpu_cs && !cpu_rd_n && !read_seen;
    wire write_event = cpu_cs && !cpu_wr_n && !write_seen;
    wire channel_reset = ce && write_event && control && pointer == 0 && cpu_din[5:3] == 3;
    wire polled_frame = wr1 == 0 && wr4 == 8'h44;
    wire rx_enabled = polled_frame && wr3 == 8'hc1;
    wire tx_enabled = polled_frame && (wr5 & 8'h7d) == 8'h68;
    reg [7:0] fifo_data[0:2];
    reg [6:0] fifo_error[0:2];
    reg [1:0] fifo_count;
    reg overrun_latched;
    reg rx_busy;
    reg [3:0] rx_phase, rx_bit;
    reg [7:0] rx_shift;
    reg [3:0] framing_recovery;
    wire rx_push = rx_tick && rx_enabled && rx_busy && rx_bit == 9 && rx_phase == 15;
    wire rx_pop = read_event && !control && fifo_count != 0;
    reg tx_holding_full, tx_busy;
    reg [7:0] tx_holding;
    reg [9:0] tx_shift;
    reg [3:0] tx_phase, tx_bit;
    wire tx_take = tx_tick && tx_enabled && !tx_busy && tx_holding_full;
    assign txd = tx_busy ? tx_shift[0] : 1'b1;
    assign rts_n = !wr5[1];
    assign dtr_n = !wr5[7];

    always @(posedge clk) begin
        // Chip reset remains effective with advancement enables stopped.
        if (reset || channel_reset) begin
            wr1<=0; wr2<=0; wr3<=0; wr4<=0; wr5<=0; pointer<=0;
            read_seen<=0; write_seen<=channel_reset; cpu_dout<=0; unsupported<=0;
            fifo_count<=0; overrun_latched<=0;
            for(integer i=0;i<3;i=i+1) begin fifo_data[i]<=0; fifo_error[i]<=0; end
            rx_busy<=0; rx_phase<=0; rx_bit<=0; rx_shift<=0; framing_recovery<=0;
            tx_holding_full<=0; tx_busy<=0; tx_holding<=0;
            tx_shift<=10'h3ff; tx_phase<=0; tx_bit<=0;
        end else if (ce) begin
            if(!cpu_cs || cpu_rd_n) read_seen<=0;
            if(!cpu_cs || cpu_wr_n) write_seen<=0;
            if(read_event) begin
                read_seen<=1;
                if(!control) cpu_dout<=fifo_count != 0 ? fifo_data[0] : 8'h00;
                else begin
                    case(pointer)
                        // RR0: real buffering/pin levels; no invented IRQ.
                        0: cpu_dout<={1'b0,1'b0,!cts_n,1'b0,!dcd_n,!tx_holding_full,1'b0,fifo_count!=0};
                        1: cpu_dout<={1'b0,(fifo_count!=0 ? fifo_error[0][6] : 1'b0),
                            overrun_latched,4'b0000,!tx_busy && !tx_holding_full};
                        default: begin cpu_dout<=8'hff; unsupported<=1; end
                    endcase
                    pointer<=0;
                end
            end
            if(write_event) begin
                write_seen<=1;
                if(!control) begin
                    if(tx_holding_full && !tx_take) unsupported<=1;
                    else begin tx_holding<=cpu_din; tx_holding_full<=1; end
                end else if(pointer!=0) begin
                    case(pointer)
                        1: begin wr1<=cpu_din; if(cpu_din!=0) unsupported<=1; end
                        2: wr2<=cpu_din; // vector retained, IRQ/RR2 not implemented.
                        3: begin wr3<=cpu_din; if(cpu_din!=0 && (cpu_din & 8'hfe)!=8'hc0) unsupported<=1; end
                        4: begin wr4<=cpu_din; if(cpu_din!=8'h44) unsupported<=1; end
                        5: begin wr5<=cpu_din; if((cpu_din & 8'h7d)!=8'h68 && cpu_din!=0) unsupported<=1; end
                        default: unsupported<=1;
                    endcase
                    pointer<=0;
                end else begin
                    pointer<=cpu_din[2:0];
                    case(cpu_din[5:3])
                        0: ;
                        6: overrun_latched<=0;
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
                    fifo_count<=fifo_count-1'b1;
                    if(fifo_count>1 && fifo_error[1][5]) overrun_latched<=1;
                end
                2'b10: begin
                    if(fifo_count==3) begin
                        fifo_data[2]<=rx_shift; fifo_error[2]<={!rxd,1'b1,5'b0};
                    end else begin
                        fifo_data[fifo_count]<=rx_shift; fifo_error[fifo_count]<={!rxd,6'b0};
                        fifo_count<=fifo_count+1'b1;
                    end
                end
                2'b11: begin
                    fifo_data[0]<=fifo_data[1]; fifo_data[1]<=fifo_data[2];
                    fifo_error[0]<=fifo_error[1]; fifo_error[1]<=fifo_error[2];
                    fifo_data[fifo_count-1'b1]<=rx_shift;
                    fifo_error[fifo_count-1'b1]<={!rxd,6'b0};
                    if(fifo_count>1 && fifo_error[1][5]) overrun_latched<=1;
                end
                default: ;
            endcase

            if(!rx_enabled) begin rx_busy<=0; framing_recovery<=0; end
            else if(rx_tick) begin
                if(framing_recovery!=0) framing_recovery<=framing_recovery-1'b1;
                else if(!rx_busy) begin
                    if(!rxd) begin rx_busy<=1; rx_bit<=0; rx_phase<=0; end
                end else if(rx_bit==0) begin
                    if(rx_phase==7) begin
                        rx_phase<=0;
                        if(rxd) rx_busy<=0; // reject a short false start.
                        else rx_bit<=1;
                    end else rx_phase<=rx_phase+1'b1;
                end else if(rx_phase==15) begin
                    rx_phase<=0;
                    if(rx_bit==9) begin
                        rx_busy<=0;
                        if(!rxd) framing_recovery<=8; // extra half-bit on bad stop.
                    end else begin rx_shift[3'(rx_bit-1'b1)]<=rxd; rx_bit<=rx_bit+1'b1; end
                end else rx_phase<=rx_phase+1'b1;
            end

            if(!tx_enabled) begin tx_busy<=0; tx_phase<=0; end
            else if(tx_tick) begin
                if(tx_take) begin
                    tx_shift<={1'b1,tx_holding,1'b0}; tx_busy<=1; tx_phase<=0; tx_bit<=0;
                    // A simultaneous CPU write replaces the taken holding byte.
                    if(!(write_event && !control)) tx_holding_full<=0;
                end else if(tx_busy) begin
                    if(tx_phase==15) begin
                        tx_phase<=0; tx_shift<={1'b1,tx_shift[9:1]};
                        if(tx_bit==9) tx_busy<=0;
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
            .rts_n(rts_n[channel]), .dtr_n(dtr_n[channel]), .unsupported(unsupported_channel[channel])
        );
    end
endmodule
