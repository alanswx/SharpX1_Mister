// Original X1 experimental interrupt integration, GPL-2.0-or-later.
// CTC > keyboard follows CZ-851/852 schematic IEI/IEO qualification.
// Inputs are synchronous machine-bus levels. ACK ownership/vector stay fixed
// for the full M1/IORQ cycle, including stopped CPU enables.
module x1_irq_bridge (
    input wire clk, reset,
    input wire m1_n, mreq_n, iorq_n, rd_n,
    input wire [7:0] data,
    input wire keyboard_irq, ctc_irq,
    input wire ctc_ieo,
    input wire [7:0] ctc_vector, keyboard_vector,
    output wire irq,
    output wire keyboard_ack, ctc_ack, ctc_iei, ctc_reti,
    output wire ctc_selected,
    output wire [7:0] ack_vector
);
    wire acknowledge = !m1_n && !iorq_n;
    wire fetch = !m1_n && !mreq_n && !rd_n && iorq_n;
    reg ack_old, owner_ctc, owner_keyboard;
    reg [1:0] ack_age;
    reg [7:0] held_vector;
    reg fetch_old, prefix_ed, prefix_cb, prefix_index;
    reg [7:0] fetch_byte;
    // Finish the fetch before decoding: synchronous memory has settled and
    // WAIT/stretched fetches produce exactly one byte. Interrupt ACK and
    // ordinary data/refresh cycles cannot manufacture an ED/4D sequence.
    wire reti = fetch_old && !fetch && prefix_ed && fetch_byte == 8'h4d;
    wire choose_ctc = ack_old ? owner_ctc : ctc_irq;
    wire choose_keyboard = ack_old ? owner_keyboard : (!ctc_irq && ctc_ieo && keyboard_irq);
    assign ctc_iei = 1'b1; // No implemented upstream SIO/DMA/slot device.
    assign irq = (ctc_ieo && keyboard_irq) || ctc_irq;
    assign ctc_selected = acknowledge && choose_ctc;
    assign ack_vector = choose_ctc ? (ack_old ? held_vector : ctc_vector) :
                        choose_keyboard ? (ack_age == 3 ? held_vector : keyboard_vector) : 8'hff;
    assign ctc_ack = acknowledge && !ack_old && choose_ctc;
    assign keyboard_ack = acknowledge && choose_keyboard;
    assign ctc_reti = reti;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ack_old <= 0; owner_ctc <= 0; owner_keyboard <= 0; held_vector <= 0; ack_age <= 0;
            fetch_old <= 0; fetch_byte <= 0; prefix_ed <= 0; prefix_cb <= 0; prefix_index <= 0;
        end else begin
            ack_old <= acknowledge;
            fetch_old <= fetch;
            if (fetch) fetch_byte <= data;
            if (acknowledge && !ack_old) begin
                owner_ctc <= choose_ctc;
                owner_keyboard <= choose_keyboard;
                held_vector <= ctc_vector;
            end
            // MR16 read address needs two master edges to settle. Capture
            // the vector at the same third edge that consumes the mailbox,
            // before firmware may publish its next reply. Normal Z80 T states
            // exceed this latency at both supported master frequencies.
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
                    // DD/FD CB displacement/opcode are non-M1 reads. Do not
                    // suppress the next real instruction as a CB operand.
                    prefix_cb <= fetch_byte == 8'hcb && !prefix_index;
                    prefix_index <= 0;
                end
            end
        end
    end
endmodule
