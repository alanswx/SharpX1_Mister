// SPDX-License-Identifier: GPL-2.0-or-later
// Original, standalone functional Z80 DMA subset, 2026.
// Interface encodings/tables: Zilog UM008101-0601 DMA chapter.
// MAME z80dma.cpp/h (Couriersud, BSD-3-Clause) consulted, not translated.
// See docs/DMA_STATUS.md and DMA_MACHINE_STATUS.md: not a pin-timing model;
// shared-machine use is a separate opt-in subset, not native compatibility.
module x1_dma #(parameter bit COMPLETION_IRQ=0) (
    input  logic clk, ce, reset,
    input  logic cpu_cs, cpu_rd_n, cpu_wr_n,
    input  logic [7:0] cpu_data_in,
    output logic [7:0] cpu_data_out,
    output logic busrq_n,
    input  logic busak_n,
    output logic mreq_n, iorq_n, rd_n, wr_n,
    output logic [15:0] address,
    output logic [7:0] data_out,
    input  logic [7:0] data_in,
    input  logic wait_n, rdy,
    output logic unsupported,
    input  logic iei, acknowledge, reti,
    output logic irq, ieo, irq_pending, irq_in_service,
    output logic [7:0] ack_vector
);
    typedef enum logic [3:0] {
        IDLE, REQUEST, READ_SETUP, READ_CYCLE,
        WRITE_SETUP, WRITE_CYCLE, PAUSE, RELEASE
    } state_t;
    state_t state;
    // Associated-byte slots ordered by the published stream grammar.
    localparam integer AL=0, AH=1, NL=2, NH=3, TA=4, TB=5,
        MASK=6, MATCH=7, BL=8, BH=9, IC=10, PULSE=11, VECTOR=12, RM=13;
    logic [13:0] follows;
    logic [7:0] wr0, wr1, wr2, wr3, wr4, wr5;
    logic [7:0] timing_a, timing_b, mask_byte, match_byte;
    logic [7:0] interrupt_control, pulse_control, interrupt_vector;
    logic timing_a_set, timing_b_set, bad_command;
    logic [15:0] start_a, start_b, length;
    logic [15:0] counter_a, counter_b, byte_counter;
    logic [16:0] remaining;
    logic [6:0] read_mask;
    logic [2:0] read_index;
    logic write_seen, read_seen, enabled, loaded, force_ready;
    logic requested, end_of_block, destination_first, match_found, search_stop_pending;
    logic reset_pending, soft_reset_pending;
    logic [1:0] grant_samples;
    logic [2:0] cycle_left;
    logic cycle_io;
    logic [15:0] destination_address;
    logic physical_ready, ready_now, pair_active, write_event, read_event;
    logic byte_match_stop, search_only, source_match;
    integer follow_index;

    // Completion IRQ is a separate explicit qualification profile. Ready/IOR,
    // pulse generation and restart interrupts remain rejected, not emulated
    // by an always-ready request or a fake completion cause.
    wire irq_clear = ce && write_event && follows==0 && !pair_active &&
        state!=PAUSE && state!=REQUEST && cpu_data_in==8'ha3;
    wire irq_reset = reset || reset_pending || soft_reset_pending ||
        (ce && write_event && follows==0 && cpu_data_in==8'hc3);
    wire irq_condition = !enabled && !unsupported &&
        ((interrupt_control[0] && match_found) ||
         (interrupt_control[1] && end_of_block));
    wire irq_bus_block;
    // Quartus 17 requires an explicit generate region here even in .sv.
    generate if(COMPLETION_IRQ) begin : completion_interrupts
        wire [7:0] candidate;
        x1_dma_vector formation(.base_vector(interrupt_vector),
            .status_affects_vector(interrupt_control[5]),.match_found(match_found),
            .end_of_block(end_of_block),.vector(candidate));
        x1_dma_service service(.clk(clk),.reset(irq_reset),
            .irq_enabled(wr3[5]),.condition(irq_condition),
            .bus_owned(!busrq_n || !busak_n),.iei(iei),
            .acknowledge(acknowledge),.reti(reti),.reset_interrupts(irq_clear),
            .candidate_vector(candidate),.pending(irq_pending),.in_service(irq_in_service),
            .irq(irq),.ieo(ieo),.block_bus_request(irq_bus_block),.ack_vector(ack_vector));
    end else begin : no_completion_interrupts
        assign irq=0, ieo=iei, irq_pending=0, irq_in_service=0;
        assign irq_bus_block=0, ack_vector=8'hff;
    end endgenerate

    function automatic logic [15:0] step_address(
        input logic [15:0] value, input logic [7:0] config_byte
    );
        if (config_byte[5]) step_address = value;
        else if (config_byte[4]) step_address = value + 16'd1;
        else step_address = value - 16'd1;
    endfunction

    function automatic logic [16:0] block_size(input logic [15:0] n);
        block_size = n == 0 ? 17'd65537 : {1'b0, n} + 17'd1;
    endfunction

    function automatic logic [16:0] operation_size(input logic [15:0] n);
        // Table 11: pure continuous search uses the programmed number of
        // operations, not sequential/Byte/Burst's pipelined N+1 count.
        if (wr0[1:0] == 2'b10 && wr4[6:5] == 2'b01)
            operation_size = n == 0 ? 17'd65536 : {1'b0,n};
        else operation_size = block_size(n);
    endfunction

    function automatic logic [2:0] first_read(input logic [6:0] bits);
        first_read = 3'd0; // zero mask: deterministic RR0, not silicon claim
        for (integer j=6; j>=0; j=j-1)
            if (bits[j]) first_read = 3'(j);
    endfunction

    function automatic logic [2:0] next_read(
        input logic [6:0] bits, input logic [2:0] current
    );
        next_read = first_read(bits);
        for (integer j=6; j>=0; j=j-1)
            if (bits[j] && j > int'(current)) next_read = 3'(j);
    endfunction

    function automatic logic [7:0] read_register(input logic [2:0] which);
        case (which)
            // Undefined bits 7,6,2 are deterministic zero. D1 follows prose.
            0: read_register = {2'b00, !end_of_block, !match_found, !irq_pending,
                                1'b0, physical_ready, requested};
            1: read_register = byte_counter[7:0];
            2: read_register = byte_counter[15:8];
            3: read_register = counter_a[7:0];
            4: read_register = counter_a[15:8];
            5: read_register = counter_b[7:0];
            6: read_register = counter_b[15:8];
            default: read_register = 0;
        endcase
    endfunction

    always_comb begin
        physical_ready = rdy == wr5[3];
        ready_now = physical_ready || force_ready;
        pair_active = state == READ_SETUP || state == READ_CYCLE ||
                      state == WRITE_SETUP || state == WRITE_CYCLE;
        write_event = cpu_cs && !cpu_wr_n && !write_seen;
        read_event = cpu_cs && !cpu_rd_n && !read_seen;
        byte_match_stop = wr0[1] && wr3[2] &&
            ((data_out | mask_byte) == (match_byte | mask_byte));
        search_only = wr0[1:0] == 2'b10;
        source_match = (data_in | mask_byte) == (match_byte | mask_byte);
        unsupported = bad_command || wr0[1:0] == 0 ||
            (!COMPLETION_IRQ && wr3[5]) || (wr3[2] && (!wr0[1] || (wr4[6:5] != 0 && !search_only))) ||
            wr4[6:5] == 2'b11 ||
            timing_a_set || timing_b_set ||
            (COMPLETION_IRQ ? (|(interrupt_control & 8'hcc) ||
                (wr5[5] && |interrupt_control[1:0])) : interrupt_control != 0);
        follow_index = -1;
        for (integer j=13; j>=0; j=j-1)
            if (follows[j]) follow_index = j;
        busrq_n = !(state == REQUEST || pair_active || state == PAUSE);
        mreq_n = 1; iorq_n = 1; rd_n = 1; wr_n = 1;
        // Integration must retain ACK for the entire requested ownership.
        if (!busak_n && (state == READ_CYCLE || state == WRITE_CYCLE)) begin
            mreq_n = cycle_io;
            iorq_n = !cycle_io;
            rd_n = state != READ_CYCLE;
            wr_n = state != WRITE_CYCLE;
        end
    end

    task automatic hardware_reset;
        state <= IDLE;
        wr0 <= 0; wr1 <= 0; wr2 <= 0; wr3 <= 0; wr4 <= 0; wr5 <= 0;
        timing_a <= 0; timing_b <= 0; mask_byte <= 0; match_byte <= 0;
        interrupt_control <= 0; pulse_control <= 0; interrupt_vector <= 0;
        timing_a_set <= 0; timing_b_set <= 0; bad_command <= 0;
        start_a <= 0; start_b <= 0; length <= 0;
        counter_a <= 0; counter_b <= 0; byte_counter <= 0;
        remaining <= 0; follows <= 0; read_mask <= 1; read_index <= 0;
        write_seen <= 0; read_seen <= 0; cpu_data_out <= 0;
        enabled <= 0; loaded <= 0; force_ready <= 0;
        requested <= 0; end_of_block <= 0; destination_first <= 0;
        match_found <= 0; search_stop_pending <= 0;
        reset_pending <= 0; soft_reset_pending <= 0;
        grant_samples <= 0; cycle_left <= 0; cycle_io <= 0;
        address <= 0; destination_address <= 0; data_out <= 0;
    endtask

    task automatic command_reset;
        // Partial software reset: preserve programmed addresses/length,
        // read mask/sequence, port/search modes and Ready polarity.
        // Six C3 bytes recover a pending stream. This slice requires LOAD
        // again after aborting a block, rather than guessing reset pipelines.
        state <= RELEASE;
        enabled <= 0; loaded <= 0; force_ready <= 0;
        remaining <= 0; byte_counter <= 0;
        wr3[5] <= 0; wr5[5:4] <= 0;
        timing_a_set <= 0; timing_b_set <= 0;
        timing_a <= 0; timing_b <= 0;
        bad_command <= 0; requested <= 0; end_of_block <= 0;
        match_found <= 0; search_stop_pending <= 0;
        soft_reset_pending <= 0; grant_samples <= 0;
    endtask

    always_ff @(posedge clk) begin
        // Record hardware reset even when CE stops. Drain any started pair;
        // with WAIT stuck or CE stopped the owned bus remains stable, not freed.
        if ((reset || reset_pending) && !pair_active) hardware_reset();
        else begin
            if (reset) reset_pending <= 1;
            if (ce) begin
                if (!cpu_cs || cpu_wr_n) write_seen <= 0;
                if (!cpu_cs || cpu_rd_n) read_seen <= 0;
                if (soft_reset_pending && !pair_active) command_reset();
                else begin
                    case (state)
                        IDLE: if (!write_event && !read_event && enabled && follows == 0 && loaded && remaining != 0 &&
                                  ready_now && !unsupported && busak_n && !irq_bus_block) begin
                            state <= REQUEST; grant_samples <= 0;
                            requested <= 1;
                        end
                        REQUEST: begin
                            if (!enabled || unsupported ||
                                (!ready_now && wr4[6:5] != 2'b01)) begin
                                state <= RELEASE; force_ready <= 0;
                            end else if (busak_n) grant_samples <= 0;
                            else if (grant_samples == 2'd1) begin
                                state <= PAUSE; grant_samples <= 0;
                            end else grant_samples <= grant_samples + 2'd1;
                        end
                        PAUSE: begin
                            if (search_stop_pending && (!ready_now || !enabled)) begin
                                // No next read began: Table 12 Ready exception
                                // stops at M reads with count M-1, not M+1.
                                if (!ready_now) byte_counter <= byte_counter - 16'd1;
                                match_found <= 1; search_stop_pending <= 0;
                                enabled <= 0; state <= RELEASE; force_ready <= 0;
                            end else if (!enabled || unsupported || (remaining == 0 && !search_stop_pending) ||
                                (!ready_now && wr4[6:5] != 2'b01)) begin
                                state <= RELEASE; force_ready <= 0;
                            end else if (ready_now && !busak_n && !write_event && !read_event) begin
                                address <= wr0[2] ? counter_a : counter_b;
                                cycle_io <= wr0[2] ? wr1[3] : wr2[3];
                                if (wr0[2])
                                    destination_address <= wr2[5] ? counter_b :
                                        destination_first ? start_b : step_address(counter_b, wr2);
                                else
                                    destination_address <= wr1[5] ? counter_a :
                                        destination_first ? start_a : step_address(counter_a, wr1);
                                state <= READ_SETUP;
                            end
                        end
                        READ_SETUP: if (!busak_n) begin
                            cycle_left <= cycle_io ? 3'd4 : 3'd3;
                            state <= READ_CYCLE;
                        end
                        READ_CYCLE: if (!busak_n) begin
                            if (cycle_left > 1) cycle_left <= cycle_left - 3'd1;
                            else if (!wr5[4] || wait_n) begin
                                data_out <= data_in;
                                if (wr0[2]) counter_a <= step_address(counter_a, wr1);
                                else counter_b <= step_address(counter_b, wr2);
                                if (search_only) begin
                                    if (search_stop_pending) begin
                                        // Complete the genuine extra source read;
                                        // its contents cannot replace the latched match.
                                        search_stop_pending <= 0; match_found <= 1;
                                        byte_counter <= byte_counter + 16'd1;
                                        if (remaining != 0) remaining <= remaining - 17'd1;
                                        if (remaining <= 1) end_of_block <= 1;
                                        enabled <= 0; state <= RELEASE; force_ready <= 0;
                                    end else if (wr3[2] && source_match && wr4[6:5] != 0) begin
                                        remaining <= remaining - 17'd1;
                                        if (remaining == 1) end_of_block <= 1;
                                        if (ready_now && enabled && !reset_pending && !reset &&
                                            !soft_reset_pending && !write_event) begin
                                            // Table 12 Burst/continuous: M+1 reads
                                            // and count M+1. Do not fake that extra read.
                                            byte_counter <= byte_counter + 16'd1;
                                            search_stop_pending <= 1; state <= PAUSE;
                                        end else begin
                                            match_found <= 1; enabled <= 0;
                                            state <= RELEASE; force_ready <= 0;
                                        end
                                    end else begin
                                        // Pure search completes at the source
                                        // read: never write or step the other port.
                                        if (source_match) match_found <= 1;
                                        remaining <= remaining - 17'd1;
                                    // Table 11 Byte EOB: N+1 reads, count N;
                                    // non-Byte EOB counts completed reads. Table
                                    // 12 Byte match counts M reads (NOT M-1).
                                        if (remaining == 1 && wr5[5] && !(wr3[2] && source_match) &&
                                            enabled && !reset_pending && !reset &&
                                            !soft_reset_pending && !write_event) begin
                                        // WR5 end-of-block repeat reloads both
                                        // buffers, not the source-only explicit LOAD.
                                        counter_a <= start_a; counter_b <= start_b;
                                        remaining <= operation_size(length); byte_counter <= 0;
                                        destination_first <= 1; end_of_block <= 0;
                                        match_found <= 0;
                                        end else begin
                                        if (wr4[6:5] != 0 || (wr3[2] && source_match) || remaining != 1)
                                            byte_counter <= byte_counter + 16'd1;
                                        if (remaining == 1) end_of_block <= 1;
                                        if (remaining == 1 || (wr3[2] && source_match)) enabled <= 0;
                                        end
                                        if ((remaining == 1 && !wr5[5]) || !enabled || reset_pending || reset ||
                                            soft_reset_pending || (wr3[2] && source_match) || wr4[6:5] == 0 ||
                                            (wr4[6:5] == 2'b10 && !ready_now)) begin
                                            state <= RELEASE; force_ready <= 0;
                                        end else state <= PAUSE;
                                    end
                                end else state <= WRITE_SETUP;
                            end
                        end
                        WRITE_SETUP: if (!busak_n) begin
                            address <= destination_address;
                            cycle_io <= wr0[2] ? wr2[3] : wr1[3];
                            cycle_left <= (wr0[2] ? wr2[3] : wr1[3]) ? 3'd4 : 3'd3;
                            state <= WRITE_CYCLE;
                        end
                        WRITE_CYCLE: if (!busak_n) begin
                            if (cycle_left > 1) cycle_left <= cycle_left - 3'd1;
                            else if (!wr5[4] || wait_n) begin
                                if (wr0[2]) counter_b <= address;
                                else counter_a <= address;
                                destination_first <= 0;
                                // Standard sequential transfer/search compares the
                                // immutable source byte after its destination write.
                                // Byte-mode Stop on Match completes this write,
                                // then disables without reading the next byte.
                                if (wr0[1] && ((data_out | mask_byte) == (match_byte | mask_byte)))
                                    match_found <= 1;
                                remaining <= remaining - 17'd1;
                                if (remaining == 1 && wr5[5] && !byte_match_stop && enabled &&
                                    !reset_pending && !reset && !soft_reset_pending && !write_event) begin
                                    // Auto restart reloads BOTH address counters, unlike
                                    // explicit LOAD's source-only immediate load. Fixed
                                    // destinations therefore reload too (UM0081 p60).
                                    counter_a <= start_a; counter_b <= start_b;
                                    remaining <= block_size(length); byte_counter <= 0;
                                    destination_first <= 1; end_of_block <= 0;
                                    match_found <= 0;
                                end else if (remaining == 1) begin
                                    end_of_block <= 1; enabled <= 0;
                                end else if (!byte_match_stop) byte_counter <= byte_counter + 16'd1;
                                // Table 12 Byte sequential: M operations, count
                                // M-1, source advanced M, destination M-1.
                                if (byte_match_stop) enabled <= 0;
                                if ((remaining == 1 && !wr5[5]) || !enabled || reset_pending || reset ||
                                    soft_reset_pending || byte_match_stop || wr4[6:5] == 0 ||
                                    (wr4[6:5] == 2'b10 && !ready_now)) begin
                                    state <= RELEASE; force_ready <= 0;
                                end else state <= PAUSE;
                            end
                        end
                        RELEASE: if (busak_n) state <= IDLE;
                        default: state <= IDLE;
                    endcase

                    if (read_event && !pair_active && busrq_n) begin
                        read_seen <= 1;
                        cpu_data_out <= read_register(read_index);
                        read_index <= next_read(read_mask, read_index);
                        enabled <= 0;
                    end
                    if (write_event) begin
                        write_seen <= 1;
                        // Real CPUs cannot write while ACK is active. Only the
                        // abort seam is allowed by this functional interface.
                        if (pair_active || state == PAUSE || state == REQUEST) begin
                            enabled <= 0;
                            if (follows == 0 && cpu_data_in == 8'hc3)
                                soft_reset_pending <= 1;
                            else if (!(follows == 0 && cpu_data_in == 8'h83))
                                bad_command <= 1;
                        end else if (follow_index >= 0) begin
                            enabled <= 0;
                            follows[follow_index] <= 0;
                            case (follow_index)
                                AL: start_a[7:0] <= cpu_data_in;
                                AH: start_a[15:8] <= cpu_data_in;
                                NL: length[7:0] <= cpu_data_in;
                                NH: length[15:8] <= cpu_data_in;
                                TA: begin timing_a <= cpu_data_in; timing_a_set <= 1; end
                                TB: begin timing_b <= cpu_data_in; timing_b_set <= 1; end
                                MASK: mask_byte <= cpu_data_in;
                                MATCH: match_byte <= cpu_data_in;
                                BL: start_b[7:0] <= cpu_data_in;
                                BH: start_b[15:8] <= cpu_data_in;
                                IC: begin
                                    interrupt_control <= cpu_data_in;
                                    follows[PULSE] <= cpu_data_in[3];
                                    follows[VECTOR] <= cpu_data_in[4];
                                end
                                PULSE: pulse_control <= cpu_data_in;
                                VECTOR: interrupt_vector <= cpu_data_in;
                                RM: begin
                                    read_mask <= cpu_data_in[6:0];
                                    if (cpu_data_in[7]) bad_command <= 1;
                                end
                                default: bad_command <= 1;
                            endcase
                        end else begin
                            enabled <= 0; // every control byte except enabling exceptions
                            if ((cpu_data_in & 8'h87) == 8'h04) begin
                                wr1 <= cpu_data_in; follows[TA] <= cpu_data_in[6];
                            end else if ((cpu_data_in & 8'h87) == 0) begin
                                wr2 <= cpu_data_in; follows[TB] <= cpu_data_in[6];
                            end else if (!cpu_data_in[7] && cpu_data_in[1:0] != 0) begin
                                wr0 <= cpu_data_in;
                                follows[AL] <= cpu_data_in[3]; follows[AH] <= cpu_data_in[4];
                                follows[NL] <= cpu_data_in[5]; follows[NH] <= cpu_data_in[6];
                            end else if ((cpu_data_in & 8'h83) == 8'h80) begin
                                wr3 <= cpu_data_in;
                                follows[MASK] <= cpu_data_in[3]; follows[MATCH] <= cpu_data_in[4];
                                if (cpu_data_in[6] && (COMPLETION_IRQ || !cpu_data_in[5]) &&
                                    (!cpu_data_in[2] || (wr0[1] && (wr4[6:5] == 0 || search_only))) &&
                                    !cpu_data_in[4] && !cpu_data_in[3] &&
                                    !unsupported) enabled <= 1;
                            end else if ((cpu_data_in & 8'h83) == 8'h81) begin
                                wr4 <= cpu_data_in;
                                follows[BL] <= cpu_data_in[2]; follows[BH] <= cpu_data_in[3];
                                follows[IC] <= cpu_data_in[4];
                            end else if ((cpu_data_in & 8'hc7) == 8'h82) begin
                                wr5 <= cpu_data_in;
                            end else if ((cpu_data_in & 8'h83) == 8'h83) begin
                                case (cpu_data_in)
                                    8'hc3: command_reset();
                                    8'hc7: begin timing_a_set <= 0; timing_a <= 0; end
                                    8'hcb: begin timing_b_set <= 0; timing_b <= 0; end
                                    8'hcf: begin
                                        if (wr0[2]) counter_a <= start_a;
                                        else counter_b <= start_b;
                                        destination_first <= 1;
                                        remaining <= operation_size(length); byte_counter <= 0;
                                        loaded <= 1; force_ready <= 0;
                                        requested <= 0; end_of_block <= 0;
                                        match_found <= 0; search_stop_pending <= 0;
                                    end
                                    8'hd3: begin
                                        remaining <= operation_size(length); byte_counter <= 0;
                                        end_of_block <= 0; force_ready <= 0;
                                        match_found <= 0; search_stop_pending <= 0;
                                    end
                                    8'haf: wr3[5] <= 0;
                                    8'hab: wr3[5] <= 1;
                                    8'ha3: begin wr3[5] <= 0; force_ready <= 0; end
                                    8'hb7: bad_command <= 1;
                                    8'hbf: begin read_mask <= 1; read_index <= 0; end
                                    8'h8b: begin end_of_block <= 0; match_found <= 0; search_stop_pending <= 0; end
                                    8'ha7: read_index <= first_read(read_mask);
                                    8'hb3: force_ready <= 1;
                                    8'h87: if (!unsupported && loaded && remaining != 0) enabled <= 1;
                                    8'h83: ;
                                    8'hbb: follows[RM] <= 1;
                                    default: bad_command <= 1;
                                endcase
                            end else bad_command <= 1;
                        end
                    end
                end
            end
        end
    end
endmodule
