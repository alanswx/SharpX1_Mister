// SPDX-License-Identifier: GPL-2.0-or-later
// Original standalone service/arbitration fixture; no assets/forced state.
`timescale 1ns/1ps
module dma_service_tb;
    logic clk=0, reset=1;
    always #5 clk=~clk;
    logic irq_enabled=0, condition=0, bus_owned=0;
    logic iei=1, acknowledge=0, reti=0, reset_interrupts=0;
    logic [7:0] candidate_vector=0;
    wire pending, in_service, irq, ieo, block_bus_request;
    wire [7:0] ack_vector;
    integer cases=0;
    logic [7:0] vector_base=0;
    logic vector_modify=0, vector_match=0, vector_eob=0;
    wire [7:0] formed_vector;
    x1_dma_vector formation(.base_vector(vector_base),.status_affects_vector(vector_modify),
        .match_found(vector_match),.end_of_block(vector_eob),.vector(formed_vector));
    x1_dma_service dut(.*);

    task automatic tick;
        @(posedge clk); #1;
        @(negedge clk); #1;
    endtask
    task automatic fresh;
        reset=1; acknowledge=0; reti=0; reset_interrupts=0;
        irq_enabled=0; condition=0; bus_owned=0; iei=1;
        tick(); reset=0; tick();
        assert(!pending && !in_service && !irq && ieo && !block_bus_request)
            else $fatal(1,"reset service state");
    endtask
    task automatic check_service(input logic [7:0] expected);
        assert(irq) else $fatal(1,"no eligible ACK");
        acknowledge=1; #1;
        assert(ack_vector==expected) else $fatal(1,"entry ACK vector");
        tick();
        assert(!pending && in_service && !irq && !ieo && block_bus_request)
            else $fatal(1,"ACK did not enter one service");
        for(integer hold=0;hold<16;hold++) begin
            candidate_vector=8'(hold)^expected;
            iei=hold[0]; irq_enabled=hold[1];
            tick();
            assert(ack_vector==expected && !pending && in_service && !irq && !ieo)
                else $fatal(1,"held ACK/status/IEI/enable changed service/vector");
        end
        acknowledge=0; irq_enabled=1; iei=1; tick();
    endtask

    initial begin
        // Independently check both changed bits and every untouched bit,
        // including odd vectors. These are status bits, not IRQ enable masks.
        for(integer base=0;base<256;base++) for(integer settings=0;settings<8;settings++) begin
            vector_base=8'(base); vector_modify=settings[0];
            vector_match=settings[1]; vector_eob=settings[2]; #1;
            assert(formed_vector==(vector_modify ?
                (8'(base)&8'hf9)|(vector_match ? 8'h02 : 0)|(vector_eob ? 8'h04 : 0) : 8'(base)))
                else $fatal(1,"current-status vector formation");
        end
        // Every byte, condition, enable, physical ownership and IEI state.
        // No transfer CE exists in the DUT: service cannot stop with the CPU
        // or DMA transfer tick. Bus-owned cases withhold a real eligible ACK.
        for(integer vector_byte=0;vector_byte<256;vector_byte++)
        for(integer inputs=0;inputs<16;inputs++) begin
            fresh(); candidate_vector=8'(vector_byte);
            condition=inputs[0]; irq_enabled=inputs[1];
            bus_owned=inputs[2]; iei=inputs[3]; tick();
            assert(pending==(inputs[0] && inputs[1]) && !in_service &&
                   irq==(inputs[0] && inputs[1] && !inputs[2] && inputs[3]) &&
                   ieo==(inputs[3] && !(inputs[0] && inputs[1])))
                else $fatal(1,"condition arbitration vector=%h inputs=%d",vector_byte,inputs);
            if(condition) begin
                irq_enabled=1; tick();
                assert(pending) else $fatal(1,"disabled stored condition lost on enable");
                if(bus_owned || !iei) begin
                    acknowledge=1; tick();
                    assert(pending && !in_service) else $fatal(1,"invalid ACK consumed IP");
                    bus_owned=0; iei=1; tick();
                    assert(pending && !in_service && irq)
                        else $fatal(1,"held invalid ACK became a second ACK");
                    acknowledge=0; tick();
                end
                bus_owned=0; iei=1; check_service(8'(vector_byte));
                // RETI must work with higher-priority IEI low. The same still
                // present condition re-pends only after service is released.
                iei=0; reti=1; tick();
                assert(!in_service && !pending && !irq && !block_bus_request)
                    else $fatal(1,"RETI upstream-blocked release");
                tick(); assert(pending && !irq && !ieo)
                    else $fatal(1,"uncleared condition did not re-pend");
                reti=0; iei=1; tick();
                assert(irq) else $fatal(1,"re-pending condition IEI restoration");
            end
            cases++;
        end

        fresh(); irq_enabled=1; condition=1; candidate_vector=8'hd6; tick();
        irq_enabled=0; condition=0; tick();
        assert(pending && !irq && !ieo) else $fatal(1,"AF cleared IP");
        irq_enabled=1; tick(); check_service(8'hd6);
        irq_enabled=0; tick();
        assert(in_service && !ieo && block_bus_request) else $fatal(1,"AF cleared IUS");
        reset_interrupts=1; tick(); reset_interrupts=0; tick();
        assert(!pending && !in_service && !irq && ieo && !block_bus_request)
            else $fatal(1,"A3 service clear");

        // Clear has priority over simultaneous ACK/RETI/new condition.
        irq_enabled=1; condition=1; tick();
        acknowledge=1; reti=1; reset_interrupts=1; tick();
        assert(!pending && !in_service) else $fatal(1,"A3 collision priority");
        reset_interrupts=0; tick();
        assert(pending && !in_service) else $fatal(1,"clear did not retain external condition");
        tick(); assert(!in_service) else $fatal(1,"held ACK consumed condition after A3");
        acknowledge=0; reti=0; tick(); check_service(candidate_vector);

        // An illegal held RETI cannot release a newly acknowledged service.
        reti=1; tick(); tick();
        acknowledge=1; tick();
        assert(in_service) else $fatal(1,"new service missing with old RETI held");
        repeat(8) tick(); assert(in_service) else $fatal(1,"held RETI released second service");
        acknowledge=0; reti=0; condition=0; tick(); reti=1; tick();
        assert(!in_service && !pending && ieo) else $fatal(1,"fresh RETI did not release");

        // Short reset is recognized without a transfer tick; already-held ACK
        // is quarantined until deassertion. No vector is retained across reset.
        reti=0; condition=1; tick(); acknowledge=1; tick();
        reset=1; tick(); reset=0; tick(); tick();
        assert(pending && !in_service && ack_vector==0)
            else $fatal(1,"reset quarantine/condition capture");
        acknowledge=0; tick(); check_service(candidate_vector);
        condition=0; reti=1; tick(); reti=0; tick();
        assert(!pending && !in_service && ieo) else $fatal(1,"removed condition re-interrupted");
        $display("PASS DMA service: %0d exhaustive vector/enable/ownership/IEI/condition cases, 2048 current-status vector cases plus held ACK/RETI, disable, reset and collision seams",cases);
        $finish;
    end
    initial begin repeat(500000) @(posedge clk); $fatal(1,"DMA service watchdog"); end
endmodule
