// SPDX-License-Identifier: GPL-2.0-only
// Original synthetic public-interface oracle. No private DUT state access.
`timescale 1ns/1ps
module x1_z_kanji_ddr_tb #(
    parameter integer HALF_PERIOD_PS=15625,
    parameter logic [28:0] BASE=29'h06123400
);
    localparam realtime WATCHDOG_DELAY=40000000.0 * HALF_PERIOD_PS * 1ps;
    bit clk=0;
    initial forever #(HALF_PERIOD_PS * 1ps) clk=~clk;
    logic reset=0,request_valid=0,request_write=0,response_ready=0;
    logic [17:0] request_address=0;
    logic [7:0] request_data=0;
    wire request_ready,response_valid,response_write;
    wire [7:0] response_data;
    wire DDRAM_CLK,DDRAM_RD,DDRAM_WE;
    wire [7:0] DDRAM_BURSTCNT,DDRAM_BE;
    wire [28:0] DDRAM_ADDR;
    wire [63:0] DDRAM_DIN;
    logic DDRAM_BUSY=0;
    logic [63:0] DDRAM_DOUT=0;
    logic DDRAM_DOUT_READY=0;
    x1_z_kanji_ddr #(.BASE_WORD_ADDRESS(BASE)) dut(.*);
    byte unsigned memory[0:262143];
    // Intent ledger is updated from the accepted PUBLIC request, independently
    // of DDR address/BE and the memory responder. Cancelled writes still drain.
    byte unsigned expected_bytes[0:262143];
    longint unsigned cycles=0,requests=0,commands=0,reads=0,writes=0,responses=0;
    longint unsigned zero_returns=0,delayed_returns=0,stalls=0;
    longint unsigned blocked_command=0,blocked_readwait=0,blocked_response=0;
    integer reset_events=0,always_ready_cases=0;
    bit prior_reset=0;
    logic pending=0,manual_busy=0,force_busy=0;
    integer delay_left=0,delay_override=-1;
    logic [28:0] pending_address=0;
    logic [17:0] issued_address=0;
    logic [7:0] issued_data=0;
    logic issued_write=0;
    longint unsigned command_request=0;
    logic was_stalled=0,held_response=0;
    logic [28:0] old_addr=0;
    logic [63:0] old_din=0;
    logic [7:0] old_be=0,old_response=0;
    logic old_rd=0,old_we=0,old_response_write=0;
    wire accepting=(DDRAM_RD || DDRAM_WE) && !DDRAM_BUSY;
    function automatic [63:0] word_at(input logic [28:0] a);
        integer first;
        first=(int'(a)-int'(BASE))*8;
        for(integer lane=0;lane<8;lane++) word_at[lane*8+:8]=memory[first+lane];
    endfunction
    function automatic [7:0] oracle(input integer a);
        return 8'((a*37) ^ (a>>8) ^ ((a>>17)*167) ^ (a>>3) ^ 8'h5a);
    endfunction
    initial forever begin
        @(negedge clk);
        #1;
        DDRAM_BUSY=manual_busy ? force_busy : ((cycles%7)<2);
        // Inputs are frozen for the DUT's upcoming rising edge. The public
        // observer may update its ledger in the active region, but cannot
        // thereby change DUT data/READY at the sampling edge.
        DDRAM_DOUT=word_at(pending ? pending_address : DDRAM_ADDR);
        DDRAM_DOUT_READY=(pending && delay_left==0) ||
            (DDRAM_RD && !DDRAM_BUSY &&
             (delay_override==0 || (delay_override<0 && DDRAM_ADDR[1:0]==0)));
    end
    initial forever begin
        @(posedge clk);
        cycles++;
        if(reset && !prior_reset) reset_events++;
        prior_reset=reset;
        assert(DDRAM_CLK==clk && DDRAM_BURSTCNT==1 && !(DDRAM_RD && DDRAM_WE))
            else $fatal(1,"Z_DDR_PORT_SHAPE");
        if(was_stalled) begin
            assert({DDRAM_ADDR,DDRAM_DIN,DDRAM_BE,DDRAM_RD,DDRAM_WE}==
                   {old_addr,old_din,old_be,old_rd,old_we})
                else $fatal(1,"Z_DDR_PAYLOAD_NOT_HELD");
        end
        if(held_response && !reset) begin
            assert(response_valid && response_data==old_response && response_write==old_response_write)
                else $fatal(1,"Z_DDR_RESPONSE_NOT_HELD");
        end
        assert(!reset || (!request_ready && !response_valid))
            else $fatal(1,"Z_DDR_RESET_DELIVERY");
        if(DDRAM_RD || DDRAM_WE || pending || response_valid) begin
            assert(!request_ready) else $fatal(1,"Z_DDR_REQUEST_READY_WHILE_OWNED");
            if(DDRAM_RD || DDRAM_WE) blocked_command++;
            if(pending) blocked_readwait++;
            if(response_valid) blocked_response++;
        end
        if(request_valid && request_ready) begin
            requests++;
            issued_address=request_address;issued_write=request_write;issued_data=request_data;
            if(request_write) expected_bytes[int'(request_address)]=request_data;
        end
        if(pending) begin
            if(delay_left==0) begin pending=0;delayed_returns++;end
            else delay_left--;
        end
        if(accepting) begin
            assert(command_request!=requests) else $fatal(1,"Z_DDR_COMMAND_REPLAY");
            command_request=requests;commands++;
            assert(DDRAM_ADDR==BASE+29'(int'(issued_address)/8))
                else $fatal(1,"Z_DDR_WORD_ADDRESS");
            assert(DDRAM_WE==issued_write) else $fatal(1,"Z_DDR_COMMAND_KIND");
            if(DDRAM_WE) begin
                writes++;
                assert(DDRAM_BE==(8'd1 << (int'(issued_address)%8)))
                    else $fatal(1,"Z_DDR_BYTE_ENABLE");
                for(integer lane=0;lane<8;lane++) begin
                    if(DDRAM_BE[lane]) begin
                        assert(DDRAM_DIN[lane*8+:8]==issued_data) else $fatal(1,"Z_DDR_WRITE_PAYLOAD");
                        memory[(int'(DDRAM_ADDR)-int'(BASE))*8+lane]=DDRAM_DIN[lane*8+:8];
                    end
                end
            end else begin
                reads++;
                assert(DDRAM_BE==8'hff && !pending) else $fatal(1,"Z_DDR_READ_OWNERSHIP");
                if(DDRAM_DOUT_READY) zero_returns++;
                else begin
                    pending=1;pending_address=DDRAM_ADDR;
                    delay_left=delay_override>=0 ? delay_override : 1+int'(DDRAM_ADDR[2:0]);
                end
            end
        end
        if(response_valid && response_ready) begin
            assert(response_write==issued_write &&
                   response_data==(issued_write ? issued_data : expected_bytes[int'(issued_address)]))
                else $fatal(1,"Z_DDR_CONSUMER_VALUE");
            responses++;
        end
        was_stalled=(DDRAM_RD || DDRAM_WE) && DDRAM_BUSY;
        if(was_stalled) stalls++;
        old_addr=DDRAM_ADDR;old_din=DDRAM_DIN;old_be=DDRAM_BE;old_rd=DDRAM_RD;old_we=DDRAM_WE;
        held_response=response_valid && !response_ready && !reset;
        old_response=response_data;old_response_write=response_write;
    end
    task automatic tick;
        @(posedge clk);#1;
    endtask
    task automatic send(input bit writing,input integer a,input logic [7:0] value);
        assert(a>=0 && a<262144) else $fatal(1,"Z_DDR_STIMULUS_ADDRESS");
        @(negedge clk);request_valid=1;request_write=writing;request_address=18'(a);request_data=value;
        while(!request_ready) tick();
        tick();
        @(negedge clk);request_valid=0;
        // A caller may change its live pins immediately after capture.
        request_address=~18'(a);request_data=~value;request_write=~writing;
    endtask
    task automatic consume(input bit writing,input logic [7:0] value,input integer hold_cycles);
        integer wait_cycles;
        wait_cycles=0;
        while(!response_valid) begin
            tick();wait_cycles++;
            assert(wait_cycles<100) else $fatal(1,"Z_DDR_RESPONSE_DEADLINE");
        end
        assert(response_write==writing && response_data==value) else $fatal(1,"Z_DDR_BYTE_RESULT");
        repeat(hold_cycles) tick();
        @(negedge clk);response_ready=1;tick();
        @(negedge clk);response_ready=0;
    endtask
    task automatic cancelled_drain(input longint unsigned before_commands,input bit expect_command);
        integer waited;
        waited=0;
        while(!request_ready) begin
            tick();waited++;
            assert(!response_valid) else $fatal(1,"Z_DDR_STALE_AFTER_RESET");
            assert(waited<100) else $fatal(1,"Z_DDR_CANCEL_DRAIN_DEADLINE");
        end
        repeat(10) begin tick();assert(!response_valid) else $fatal(1,"Z_DDR_STALE_AFTER_RESET");end
        assert(commands==before_commands+(expect_command ? 1 : 0)) else $fatal(1,"Z_DDR_CANCEL_COMMAND_COUNT");
    endtask
    task automatic already_ready(input bit writing,input integer a,input logic [7:0] value,input integer latency);
        longint unsigned before_requests,before_commands,before_responses,before_returns;
        integer waited;
        before_requests=requests;before_commands=commands;before_responses=responses;
        before_returns=latency==0 ? zero_returns : delayed_returns;
        delay_override=latency;
        @(negedge clk);response_ready=1;
        send(writing,a,value);
        waited=0;
        while(responses==before_responses) begin
            tick();waited++;
            assert(waited<100) else $fatal(1,"Z_DDR_ALREADY_READY_COMPLETION");
        end
        repeat(5) tick();
        assert(requests==before_requests+1 && commands==before_commands+1 &&
               responses==before_responses+1 && request_ready && !response_valid)
            else $fatal(1,"Z_DDR_ALREADY_READY_COUNTS");
        if(!writing) begin
            assert((latency==0 ? zero_returns : delayed_returns)==before_returns+1)
                else $fatal(1,"Z_DDR_ALREADY_READY_RETURN_PHASE");
        end
        @(negedge clk);response_ready=0;
        always_ready_cases++;
    endtask
    longint unsigned saved_commands;
    longint unsigned saved_requests,saved_responses;
    logic [7:0] changed_byte;
    initial begin
        assert(HALF_PERIOD_PS>1000) else $fatal(1,"Z_DDR_CLOCK_PERIOD");
        for(integer a=0;a<262144;a++) begin memory[a]=0;expected_bytes[a]=0;end
        repeat(4) tick();
        // Complete medium ledger: every physical byte is written then read.
        for(integer a=0;a<262144;a++) begin
            send(1,a,oracle(a));consume(1,oracle(a),(a%8191)==0 ? 9 : 0);
        end
        for(integer a=0;a<262144;a++) begin
            assert(memory[a]==oracle(a)) else $fatal(1,"Z_DDR_WHOLE_FONT_LEDGER");
            send(0,a,0);consume(0,oracle(a),(a%8191)==0 ? 11 : 0);
        end
        assert(requests==524288 && commands==524288 && responses==524288)
            else $fatal(1,"Z_DDR_FULL_COUNTS");
        assert(zero_returns>0 && delayed_returns>0 && stalls>0) else $fatal(1,"Z_DDR_TIMING_COVERAGE");
        manual_busy=1;force_busy=1;delay_override=5;
        // Reset before admission: no requester or DDR command is taken.
        saved_commands=commands;
        @(negedge clk);reset=1;request_valid=1;repeat(3) tick();
        @(negedge clk);request_valid=0;reset=0;
        cancelled_drain(saved_commands,0);
        // Both command kinds must survive reset even BEFORE DDR acceptance.
        for(integer kind=0;kind<2;kind++) begin
            saved_commands=commands;force_busy=1;
            send(1'(kind),131071+kind,oracle(131071+kind));
            @(negedge clk);reset=1;repeat(3) tick();
            @(negedge clk);reset=0;repeat(3) tick();
            assert(!request_ready && !response_valid) else $fatal(1,"Z_DDR_DRAIN_LEASE_LOST");
            force_busy=0;cancelled_drain(saved_commands,1);
        end
        // Accepted read waiting for data; reset must retain return ownership.
        saved_commands=commands;delay_override=12;
        send(0,262143,0);wait(pending);@(negedge clk);reset=1;tick();
        @(negedge clk);reset=0;cancelled_drain(saved_commands,1);
        // Reset on an actual delayed read return edge (not private state).
        saved_commands=commands;delay_override=6;
        send(0,8,0);wait(pending);
        while(delay_left!=0) begin @(negedge clk);end
        reset=1;tick();@(negedge clk);reset=0;cancelled_drain(saved_commands,1);
        // Zero-edge read acceptance with reset: accepted/drained, never delivered.
        saved_commands=commands;force_busy=1;delay_override=0;
        send(0,7,0);@(negedge clk);reset=1;force_busy=0;
        repeat(2) tick();@(negedge clk);reset=0;cancelled_drain(saved_commands,1);
        // Write command accepted on the reset edge: issue exactly once and
        // suppress the acceptance response, without claiming persistence.
        saved_commands=commands;force_busy=1;
        send(1,131072,oracle(131072));@(negedge clk);reset=1;force_busy=0;
        repeat(2) tick();@(negedge clk);reset=0;cancelled_drain(saved_commands,1);
        // Consumer stopped while a held response exists, then warm reset + ACK.
        for(integer kind=0;kind<2;kind++) begin
            send(1'(kind),16+kind,oracle(16+kind));
            wait(response_valid);repeat(16) tick();
            @(negedge clk);reset=1;response_ready=1;tick();
            @(negedge clk);reset=0;response_ready=0;
            repeat(8) begin tick();assert(!response_valid) else $fatal(1,"Z_DDR_STALE_AFTER_RESET");end
            send(0,16+kind,0);consume(0,oracle(16+kind),3);
        end
        // Offer a SECOND valid while COMMAND is stalled; hold it through
        // READ_WAIT and RESPONSE. Only the next IDLE edge may admit it.
        saved_commands=commands;saved_requests=requests;saved_responses=responses;
        force_busy=1;delay_override=8;
        send(0,20,0);
        @(negedge clk);request_valid=1;request_write=1;request_address=21;request_data=8'h93;
        repeat(4) begin
            tick();assert(!request_ready && !response_valid) else $fatal(1,"Z_DDR_QUEUED_COMMAND_READY");
            assert(requests==saved_requests+1) else $fatal(1,"Z_DDR_EARLY_SECOND_ADMISSION");
        end
        @(negedge clk);force_busy=0;tick();
        assert(pending && !request_ready) else $fatal(1,"Z_DDR_QUEUED_READWAIT_READY");
        repeat(3) begin
            tick();assert(pending && !request_ready) else $fatal(1,"Z_DDR_QUEUED_READWAIT_READY");
        end
        while(!response_valid) tick();
        repeat(4) begin
            tick();assert(!request_ready && requests==saved_requests+1)
                else $fatal(1,"Z_DDR_QUEUED_HELD_READY");
        end
        @(negedge clk);response_ready=1;tick();
        assert(request_ready && requests==saved_requests+1) else $fatal(1,"Z_DDR_SAME_EDGE_SECOND_ADMISSION");
        tick();
        assert(requests==saved_requests+2 && !request_ready) else $fatal(1,"Z_DDR_SECOND_ADMISSION_MISSING");
        @(negedge clk);request_valid=0;response_ready=0;
        consume(1,8'h93,3);repeat(5) tick();
        assert(commands==saved_commands+2 && requests==saved_requests+2 && responses==saved_responses+2)
            else $fatal(1,"Z_DDR_SECOND_ADMISSION_COUNTS");
        // Consumer is ready BEFORE the immediate/delayed response appears.
        already_ready(0,20,0,0);
        already_ready(0,21,0,7);
        already_ready(1,22,8'hb6,0);
        // A cancelled write has different contents, then PUBLIC readback.
        changed_byte=oracle(131079)^8'hff;
        saved_commands=commands;force_busy=1;
        send(1,131079,changed_byte);
        @(negedge clk);reset=1;repeat(3) tick();
        @(negedge clk);reset=0;force_busy=0;cancelled_drain(saved_commands,1);
        send(0,131079,0);consume(0,changed_byte,2);
        // Intentionally do NOT retire the old valid across reset/drain. The
        // documented interface has no quarantine: this is a NEW admission.
        saved_commands=commands;saved_requests=requests;saved_responses=responses;
        force_busy=1;delay_override=6;
        @(negedge clk);request_valid=1;request_write=0;request_address=22;request_data=0;
        assert(request_ready) else $fatal(1,"Z_DDR_HELD_RESET_INITIAL_READY");
        tick();
        assert(requests==saved_requests+1 && !request_ready)
            else $fatal(1,"Z_DDR_HELD_RESET_INITIAL_ADMISSION");
        // No valid deassertion here, even for half a cycle.
        @(negedge clk);reset=1;
        repeat(3) tick();
        @(negedge clk);reset=0;force_busy=0;
        while(!request_ready) begin
            tick();assert(!response_valid && requests==saved_requests+1)
                else $fatal(1,"Z_DDR_HELD_RESET_EARLY_ADMISSION");
        end
        tick();
        assert(requests==saved_requests+2) else $fatal(1,"Z_DDR_HELD_RESET_NEW_ADMISSION");
        @(negedge clk);request_valid=0;
        consume(0,8'hb6,3);repeat(5) tick();
        assert(requests==saved_requests+2 && commands==saved_commands+2 && responses==saved_responses+1)
            else $fatal(1,"Z_DDR_HELD_RESET_COUNTS");
        // Independently compare the ENTIRE final medium, including changed
        // queued/cancelled writes; do not assume the original font unchanged.
        for(integer a=0;a<262144;a++) begin
            assert(memory[a]==expected_bytes[a]) else $fatal(1,"Z_DDR_FINAL_MEDIUM_LEDGER");
        end
        assert(always_ready_cases==3 && reset_events==11 &&
               blocked_command>0 && blocked_readwait>0 && blocked_response>0)
            else $fatal(1,"Z_DDR_FOCUSED_COVERAGE");
        $display("PASS Z_DDR_FOCUSED queued_second=1 always_ready=3 cancelled_new_write=1 reset_held_valid=1 blocked_command=%0d blocked_readwait=%0d blocked_response=%0d",blocked_command,blocked_readwait,blocked_response);
        repeat(10) tick();
        assert(commands==requests) else $fatal(1,"Z_DDR_FINAL_REPLAY");
        $display("PASS Z_DDR full_writes=262144 full_reads=262144 lanes=8 reset_cases=%0d commands=%0d requests=%0d responses=%0d zero=%0d delayed=%0d stalls=%0d half_ps=%0d base=%08x",reset_events,commands,requests,responses,zero_returns,delayed_returns,stalls,HALF_PERIOD_PS,BASE);
        $finish;
    end
    initial begin
        #(WATCHDOG_DELAY);
        $fatal(1,"Z_DDR_TEST_TIMEOUT");
    end
endmodule
