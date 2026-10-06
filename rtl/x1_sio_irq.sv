// SPDX-License-Identifier: GPL-2.0-or-later
// Original functional SIO priority/service controller, Zilog UM008101-0601
// printed 228, 275-279, 300. Not physical daisy-chain propagation timing.
// Inputs synchronous to clk; requests are persistent levels owned by their
// channels. ACK is a bus level, consumed once regardless of stopped CE.
// RETI is one locally-qualified event from a bus decoder, not a shared raw
// daisy-chain broadcast. Caller must qualify ownership against upstream IUS.
module x1_sio_irq (
    input wire clk, reset, iei, acknowledge, reti,
    input wire [1:0] reset_channel,
    input wire [5:0] request,
    input wire [1:0] special_rx,
    input wire [7:0] vector_base,
    input wire status_vector,
    output wire irq, ieo, pending,
    output wire [7:0] rr2, ack_vector
);
    reg [5:0] in_service;
    reg ack_seen;
    reg [7:0] held_vector;
    reg eligible, servicing, pending_valid, blocked;
    reg [2:0] selected, service_selected, pending_selected;
    function automatic [7:0] source_vector(input [2:0] source);
        reg [2:0] code;
        case(source)
            0: code=special_rx[0] ? 7 : 6;
            1: code=4; 2: code=5;
            3: code=special_rx[1] ? 3 : 2;
            4: code=0; default: code=1;
        endcase
        source_vector=status_vector ? {vector_base[7:4],code,vector_base[0]} : vector_base;
    endfunction
    always @* begin
        eligible=0; servicing=0; pending_valid=0; blocked=0;
        selected=0; service_selected=0; pending_selected=0;
        for(integer i=0;i<6;i=i+1) begin
            if(request[i] && !pending_valid) begin pending_valid=1; pending_selected=3'(i); end
            if(in_service[i]) begin
                blocked=1;
                if(!servicing) begin servicing=1; service_selected=3'(i); end
            end
            if(!blocked && request[i] && !eligible) begin eligible=1; selected=3'(i); end
        end
    end
    assign pending=|request;
    assign irq=iei && eligible;
    assign ieo=iei && !eligible && !servicing;
    assign rr2=pending_valid ? source_vector(pending_selected) :
        (status_vector ? {vector_base[7:4],3'b011,vector_base[0]} : vector_base);
    assign ack_vector=ack_seen ? held_vector : (irq ? source_vector(selected) : 8'hff);
    always @(posedge clk) begin
        if(reset || reset_channel[0]) begin
            in_service<=0; ack_seen<=0; held_vector<=8'hff;
        end else begin
            ack_seen<=acknowledge;
            if(reti && servicing) in_service[service_selected]<=0;
            if(acknowledge && !ack_seen) begin
                held_vector<=irq ? source_vector(selected) : 8'hff;
                if(irq) in_service[selected]<=1;
            end
            if(reset_channel[1]) in_service[5:3]<=0;
        end
    end
endmodule

// Standalone connected serial/IRQ subset. Not in machine.qip or mapped into
// the X1. RX first/all-character + TX + CTS/DCD supported. Other external
// sources, break and physical bus/pin phase remain separate gates.
// FLOW_ENABLE defaults off; opt-in functional WAIT/Ready is not pin timing.
module x1_sio_interrupt #(parameter FLOW_ENABLE=0) (
    input wire clk, ce, reset, cpu_cs, cpu_rd_n, cpu_wr_n,
    input wire [1:0] address,
    input wire [7:0] cpu_din,
    output wire [7:0] cpu_dout,
    input wire [1:0] rx_tick, tx_tick, rxd, cts_n, dcd_n,
    output wire [1:0] txd, rts_n, dtr_n,
    output wire unsupported,
    input wire iei, acknowledge, reti,
    output wire irq, ieo,
    output wire [7:0] ack_vector,
    output wire [1:0] wait_n, ready_n
);
    wire [7:0] channel_data[0:1], vector_register[0:1], rr2;
    wire [1:0] request_rx, request_tx, request_external, special_rx, status_vector;
    wire [1:0] reset_channel, return_interrupt, unsupported_channel;
    wire pending;
    assign cpu_dout=channel_data[address[1]];
    assign unsupported=|unsupported_channel;
    x1_sio_irq priority_unit (
        .clk(clk), .reset(reset), .iei(iei), .acknowledge(acknowledge),
        .reti(reti || return_interrupt[0]), .reset_channel(reset_channel),
        .request({request_external[1],request_tx[1],request_rx[1],request_external[0],request_tx[0],request_rx[0]}),
        .special_rx(special_rx), .vector_base(vector_register[1]),
        .status_vector(status_vector[1]), .irq(irq), .ieo(ieo),
        .pending(pending), .rr2(rr2), .ack_vector(ack_vector)
    );
    for(genvar channel=0;channel<2;channel=channel+1) begin : channels
        x1_sio_async_channel #(.IRQ_ENABLE(1), .CHANNEL_B(channel), .FLOW_ENABLE(FLOW_ENABLE)) unit (
            .clk(clk), .ce(ce), .reset(reset), .cpu_cs(cpu_cs && address[1]==1'(channel)),
            .control(address[0]), .cpu_rd_n(cpu_rd_n), .cpu_wr_n(cpu_wr_n),
            .cpu_din(cpu_din), .cpu_dout(channel_data[channel]),
            .rx_tick(rx_tick[channel]), .tx_tick(tx_tick[channel]), .rxd(rxd[channel]),
            .cts_n(cts_n[channel]), .dcd_n(dcd_n[channel]), .txd(txd[channel]),
            .rts_n(rts_n[channel]), .dtr_n(dtr_n[channel]), .unsupported(unsupported_channel[channel]),
            .interrupt_pending(channel==0 ? pending : 1'b0), .rr2(channel==1 ? rr2 : 8'hff),
            .request_rx(request_rx[channel]), .request_tx(request_tx[channel]),
            .request_external(request_external[channel]),
            .special_rx(special_rx[channel]), .vector_register(vector_register[channel]),
            .status_vector(status_vector[channel]), .reset_channel(reset_channel[channel]),
            .return_interrupt(return_interrupt[channel]),
            .bus_selected(cpu_cs && (!cpu_rd_n || !cpu_wr_n)),
            .wait_n(wait_n[channel]), .ready_n(ready_n[channel])
        );
    end
endmodule
