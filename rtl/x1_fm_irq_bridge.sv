// Original X1 experimental interrupt integration, GPL-2.0-or-later.
// x1_irq_bridge plus an expansion-slot FM-board CTC (CZ-8BS1, 0704-0707) at
// the top of the chain: FM CTC > main CTC > keyboard. Slot devices sit
// upstream of the internal chain (cf. upstream_iei in the DMA/SIO bridges);
// MAME orders x1kb before ctc_ym with a "verify order" TODO, so the native
// position is unresolved and this is a provisional policy.
// Inputs are synchronous machine-bus levels. ACK ownership/vector stay fixed
// for the full M1/IORQ cycle, including stopped CPU enables.
// RETI routing: while an FM CTC channel is in service the main CTC's IEI is
// low, so it cannot be interrupted into service; every RETI in that window
// belongs to the FM CTC. A service depth counter tracks acknowledged FM
// interrupts; other RETIs go to the main CTC.
module x1_fm_irq_bridge (
    input wire clk, reset,
    input wire m1_n, mreq_n, iorq_n, rd_n,
    input wire [7:0] data,
    input wire keyboard_irq, ctc_irq, fm_ctc_irq,
    input wire ctc_ieo,
    input wire [7:0] ctc_vector, fm_ctc_vector, keyboard_vector,
    output wire irq,
    output wire keyboard_ack, ctc_ack, fm_ctc_ack, ctc_reti, fm_ctc_reti,
    output wire [7:0] ack_vector,
    output wire [2:0] fm_service_depth
);
    wire acknowledge = !m1_n && !iorq_n;
    wire fetch = !m1_n && !mreq_n && !rd_n && iorq_n;
    reg ack_old, owner_fm, owner_ctc, owner_keyboard;
    reg [1:0] ack_age;
    reg [7:0] held_vector;
    reg fetch_old, prefix_ed, prefix_cb, prefix_index;
    reg [7:0] fetch_byte;
    reg [2:0] fm_depth;
    wire reti = fetch_old && !fetch && prefix_ed && fetch_byte == 8'h4d;
    // ctc_irq/ctc_ieo already include the FM CTC's IEO through the main
    // CTC's IEI input.
    wire choose_fm = ack_old ? owner_fm : fm_ctc_irq;
    wire choose_ctc = ack_old ? owner_ctc : (!fm_ctc_irq && ctc_irq);
    wire choose_keyboard = ack_old ? owner_keyboard :
        (!fm_ctc_irq && !ctc_irq && ctc_ieo && keyboard_irq);
    assign irq = fm_ctc_irq || ctc_irq || (ctc_ieo && keyboard_irq);
    assign ack_vector = choose_fm ? (ack_old ? held_vector : fm_ctc_vector) :
                        choose_ctc ? (ack_old ? held_vector : ctc_vector) :
                        choose_keyboard ? (ack_age == 3 ? held_vector : keyboard_vector) : 8'hff;
    assign fm_ctc_ack = acknowledge && !ack_old && choose_fm;
    assign ctc_ack = acknowledge && !ack_old && choose_ctc;
    assign keyboard_ack = acknowledge && choose_keyboard;
    assign fm_ctc_reti = reti && fm_depth != 0;
    assign ctc_reti = reti && fm_depth == 0;
    assign fm_service_depth = fm_depth;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ack_old <= 0; owner_fm <= 0; owner_ctc <= 0; owner_keyboard <= 0;
            held_vector <= 0; ack_age <= 0; fm_depth <= 0;
            fetch_old <= 0; fetch_byte <= 0; prefix_ed <= 0; prefix_cb <= 0; prefix_index <= 0;
        end else begin
            ack_old <= acknowledge;
            fetch_old <= fetch;
            if (fetch) fetch_byte <= data;
            if (acknowledge && !ack_old) begin
                owner_fm <= choose_fm;
                owner_ctc <= choose_ctc;
                owner_keyboard <= choose_keyboard;
                held_vector <= choose_fm ? fm_ctc_vector : ctc_vector;
            end
            if (fm_ctc_ack && !fm_ctc_reti && fm_depth != 3'd7) fm_depth <= fm_depth + 1'b1;
            else if (fm_ctc_reti && !fm_ctc_ack) fm_depth <= fm_depth - 1'b1;
            // MR16 read address needs two master edges to settle; see
            // x1_irq_bridge for the keyboard vector capture timing.
            if (!acknowledge) ack_age <= 0;
            else if (ack_age != 3) ack_age <= ack_age + 1'b1;
            if (acknowledge && ack_age == 2 && choose_keyboard)
                held_vector <= keyboard_vector;
            if (fetch_old && !fetch) begin
                if (prefix_ed || prefix_cb) begin
                    prefix_ed <= 0; prefix_cb <= 0; prefix_index <= 0;
                end else if (fetch_byte == 8'hdd || fetch_byte == 8'hfd) begin
                    prefix_index <= 1;
                end else begin
                    prefix_ed <= fetch_byte == 8'hed;
                    prefix_cb <= fetch_byte == 8'hcb && !prefix_index;
                    prefix_index <= 0;
                end
            end
        end
    end
endmodule
